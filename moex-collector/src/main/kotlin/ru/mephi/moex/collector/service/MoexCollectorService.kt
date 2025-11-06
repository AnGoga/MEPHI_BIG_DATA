package ru.mephi.moex.collector.service

import jakarta.annotation.PostConstruct
import mu.KotlinLogging
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Service
import ru.mephi.moex.collector.client.MoexApiClient
import ru.mephi.moex.collector.config.MoexConfig
import ru.mephi.moex.collector.config.TickerConfig
import ru.mephi.moex.collector.config.TickerMode
import ru.mephi.moex.collector.model.Trade
import java.time.LocalDateTime

@Service
class MoexCollectorService(
    private val moexApiClient: MoexApiClient,
    private val kafkaProducerService: KafkaProducerService,
    private val deduplicationService: TradeDeduplicationService,
    private val cursorService: CollectionCursorService,
    private val metricsService: CollectionMetricsService,
    private val tickerConfig: TickerConfig,
    private val moexConfig: MoexConfig
) {
    private val logger = KotlinLogging.logger {}

    private var isInitialized = false
    private var availableSecurities: Set<String> = emptySet()

    @PostConstruct
    fun init() {
        if (!moexConfig.collector.enabled) {
            logger.info { "MOEX collector is disabled" }
            return
        }

        logger.info { "Initializing MOEX collector service" }
        logger.info { "Ticker mode: ${tickerConfig.mode}" }

        // Загрузить курсор
        val cursor = cursorService.loadCursor()
        logger.info { "Loaded cursor: lastTradeTime=${cursor.lastTradeTime}, initialLoadComplete=${cursor.initialLoadComplete}" }

        when (tickerConfig.mode) {
            TickerMode.ALL -> {
                logger.info { "Collecting data for ALL available instruments" }
                loadAvailableSecurities()
            }

            TickerMode.SPECIFIC -> {
                logger.info { "Collecting data for specific tickers: ${tickerConfig.symbols}" }
                if (tickerConfig.symbols.isEmpty()) {
                    logger.warn { "No specific tickers configured! Please add tickers to tickers.yml" }
                }
            }
        }

        isInitialized = true
    }

    /**
     * Загрузить список доступных инструментов с биржи
     */
    private fun loadAvailableSecurities() {
        try {
            val securities = moexApiClient.getSecurities()
            availableSecurities = securities.map { it.securityId }.toSet()
            logger.info { "Loaded ${availableSecurities.size} available securities from MOEX" }

            // Отправить информацию об инструментах в Kafka
            kafkaProducerService.sendSecurities(securities)
        } catch (e: Exception) {
            logger.error(e) { "Failed to load available securities" }
        }
    }

    /**
     * Периодический сбор данных о сделках
     * Два режима: Initial Load (загрузка всех данных с начала дня) и Incremental (догоняние новых)
     */
    @Scheduled(fixedDelayString = "\${moex.collector.interval-ms:3000}")
    fun collectTrades() {
        if (!moexConfig.collector.enabled || !isInitialized) {
            return
        }

        try {
            if (!cursorService.isInitialLoadComplete()) {
                performInitialLoad()
            } else {
                performIncrementalLoad()
            }
        } catch (e: Exception) {
            logger.error(e) { "Error during trade collection" }
            metricsService.recordError()
        }
    }

    /**
     * Initial Load: загрузить все сделки с начала дня до текущего момента
     * Используется при первом запуске или после сброса курсора
     */
    private fun performInitialLoad() {
        logger.info { "=== Starting INITIAL LOAD ===" }
        metricsService.startCollectionCycle()

        val from = cursorService.getLastTradeTime()
        val till = LocalDateTime.now()

        logger.info { "Loading ALL trades from $from to $till" }

        val fromStr = cursorService.formatForMoexApi(from)
        val tillStr = cursorService.formatForMoexApi(till)

        // Загрузить сделки в зависимости от режима
        val tradesCnt = when (tickerConfig.mode) {
            TickerMode.ALL -> {
                // Режим ALL: загружаем все инструменты одним запросом
                logger.info { "Initial load mode: ALL instruments" }
                moexApiClient.getAllTradesInTimeRangeForInit(
                    from = fromStr,
                    till = tillStr,
                    batchSize = 5000
                ) { trades ->
                    kafkaProducerService.sendTrades(trades)
                }
            }

            TickerMode.SPECIFIC -> {
                // Режим SPECIFIC: загружаем каждый тикер отдельно
                logger.info { "Initial load mode: SPECIFIC tickers ${tickerConfig.symbols}" }
                var totalTrades = 0

                tickerConfig.symbols.forEach { ticker ->
                    logger.info { "Loading initial trades for ticker: $ticker" }
                    val tickerTrades = moexApiClient.getAllTradesBySecurityIdInTimeRangeForInit(
                        securityId = ticker,
                        from = fromStr,
                        till = tillStr,
                        batchSize = 5000
                    ) { trades ->
                        kafkaProducerService.sendTrades(trades)
                    }
                    logger.info { "Loaded $tickerTrades trades for $ticker" }
                    totalTrades += tickerTrades
                }

                totalTrades
            }
        }

        logger.info { "Initial load completed: ${tradesCnt} trades fetched" }
            // Обновить курсор
            cursorService.updateLastTradeTime(till)

            // Обновить статистику
            cursorService.updateStats(tradesCnt, 1)

        // Отметить Initial Load как завершенный
        cursorService.markInitialLoadComplete()

        // Подсчитать количество API вызовов (примерно)
        val apiCalls = (tradesCnt / 5000) + 1
        metricsService.endCollectionCycle(tradesCnt, 0, apiCalls)

        logger.info { "=== INITIAL LOAD COMPLETE ===" }
        metricsService.logMetrics()
    }

    /**
     * Incremental Load: догонять новые сделки с последнего сохраненного времени
     * Используется в нормальном режиме работы
     */
    private fun performIncrementalLoad() {
        logger.debug { "Starting incremental load cycle" }
        metricsService.startCollectionCycle()

        val from = cursorService.getLastTradeTime()
        val now = LocalDateTime.now()

        // Если gap слишком большой (> 5 минут), грузим порциями по 5 минут
        val maxGapMinutes = 5L
        val gapDuration = java.time.Duration.between(from, now)

        val till = if (gapDuration.toMinutes() > maxGapMinutes) {
            val limitedTill = from.plusMinutes(maxGapMinutes)
            logger.warn { "Large gap detected: ${gapDuration.toMinutes()} minutes. Loading in chunks. Current chunk: $from to $limitedTill" }
            limitedTill
        } else {
            now
        }

        val fromStr = cursorService.formatForMoexApi(from)
        val tillStr = cursorService.formatForMoexApi(till)

        logger.trace { "Fetching trades from $from to $till" }

        // Загрузить сделки в зависимости от режима
        val trades = when (tickerConfig.mode) {
            TickerMode.ALL -> {
                // Режим ALL: загружаем все инструменты одним запросом
                moexApiClient.getAllTradesInTimeRange(
                    from = fromStr,
                    till = tillStr,
                    batchSize = 5000
                )
            }

            TickerMode.SPECIFIC -> {
                // Режим SPECIFIC: загружаем каждый тикер отдельно и объединяем
                val allTrades = mutableListOf<Trade>()

                tickerConfig.symbols.forEach { ticker ->
                    val tickerTrades = moexApiClient.getAllTradesBySecurityIdInTimeRange(
                        securityId = ticker,
                        from = fromStr,
                        till = tillStr,
                        batchSize = 5000
                    )
                    logger.trace { "Fetched ${tickerTrades.size} trades for $ticker" }
                    allTrades.addAll(tickerTrades)
                }

                allTrades
            }
        }

        if (trades.isNotEmpty()) {
            // Фильтровать дубликаты (на всякий случай, если временные окна перекрылись)
            val newTrades = deduplicationService.filterNewTrades(trades)
            val duplicates = trades.size - newTrades.size

            if (newTrades.isNotEmpty()) {
                logger.info { "Collected ${newTrades.size} new trades (${duplicates} duplicates filtered)" }

                // Отправить в Kafka
                kafkaProducerService.sendTrades(newTrades)

                // Отметить как обработанные
                deduplicationService.markAllAsProcessed(newTrades)

                // Обновить курсор
                cursorService.updateLastTradeTime(till)

                // Обновить статистику
                cursorService.updateStats(newTrades.size, 1)
            } else {
                logger.debug { "All ${trades.size} trades were duplicates" }
                // Все равно обновляем курсор даже если дубликаты
                cursorService.updateLastTradeTime(till)
            }

            // Подсчитать количество API вызовов
            val apiCalls = (trades.size / 5000) + 1
            metricsService.endCollectionCycle(newTrades.size, duplicates, apiCalls)
        } else {
            logger.trace { "No new trades in time range" }
            // Все равно обновляем курсор, чтобы двигаться вперед
            cursorService.updateLastTradeTime(till)
            metricsService.endCollectionCycle(0, 0, 1)
        }
    }

    /**
     * Периодический вывод метрик (каждые 60 секунд)
     */
    @Scheduled(fixedDelay = 60000)
    fun logMetricsPeriodically() {
        if (moexConfig.collector.enabled && isInitialized) {
            metricsService.logMetrics()
        }
    }

    /**
     * Получить статистику сбора данных
     */
    fun getStats(): Map<String, Any> {
        val cursor = cursorService.loadCursor()
        val metrics = metricsService.getMetrics()

        return mapOf(
            "enabled" to moexConfig.collector.enabled,
            "mode" to tickerConfig.mode,
            "configured_tickers" to tickerConfig.symbols,
            "initial_load_complete" to cursor.initialLoadComplete,
            "last_trade_time" to cursor.lastTradeTime,
            "total_trades_collected" to metrics.totalTradesCollected,
            "total_cycles_completed" to metrics.totalCyclesCompleted,
            "total_api_calls" to metrics.totalApiCalls,
            "total_errors" to metrics.totalErrors,
            "uptime_seconds" to metrics.uptimeSeconds
        )
    }
}
