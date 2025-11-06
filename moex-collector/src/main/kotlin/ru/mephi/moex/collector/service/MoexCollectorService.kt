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

@Service
class MoexCollectorService(
    private val moexApiClient: MoexApiClient,
    private val kafkaProducerService: KafkaProducerService,
    private val deduplicationService: TradeDeduplicationService,
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
     */
    @Scheduled(fixedDelayString = "\${moex.collector.interval-ms:5000}")
    fun collectTrades() {
        if (!moexConfig.collector.enabled || !isInitialized) {
            return
        }

        try {
            logger.debug { "Starting trade collection cycle" }

            val trades = when (tickerConfig.mode) {
                TickerMode.ALL -> collectAllTrades()
                TickerMode.SPECIFIC -> collectSpecificTrades()
            }

            if (trades.isNotEmpty()) {
                // Фильтровать дубликаты
                val newTrades = deduplicationService.filterNewTrades(trades)

                if (newTrades.isNotEmpty()) {
                    logger.info { "Collected ${newTrades.size} new trades (${trades.size - newTrades.size} duplicates filtered)" }

                    // Отправить в Kafka
                    kafkaProducerService.sendTrades(newTrades)

                    // Отметить как обработанные
                    deduplicationService.markAllAsProcessed(newTrades)
                } else {
                    logger.debug { "No new trades found" }
                }
            } else {
                logger.debug { "No trades received from MOEX API" }
            }
        } catch (e: Exception) {
            logger.error(e) { "Error during trade collection" }
        }
    }

    /**
     * Собрать сделки для всех инструментов
     */
    private fun collectAllTrades(): List<Trade> {
        return moexApiClient.getAllTrades(limit = 500)
    }

    /**
     * Собрать сделки для конкретных инструментов
     */
    private fun collectSpecificTrades(): List<Trade> {
        val allTrades = mutableListOf<Trade>()

        for (ticker in tickerConfig.symbols) {
            try {
                val trades = moexApiClient.getTradesBySecurityId(ticker, limit = 100)
                allTrades.addAll(trades)

                // Rate limiting уже встроен в клиент
                logger.trace { "Collected ${trades.size} trades for $ticker" }
            } catch (e: Exception) {
                logger.error(e) { "Failed to collect trades for $ticker" }
            }
        }

        return allTrades
    }

    /**
     * Получить статистику сбора данных
     */
    fun getStats(): Map<String, Any> {
        return mapOf(
            "enabled" to moexConfig.collector.enabled,
            "mode" to tickerConfig.mode,
            "configured_tickers" to tickerConfig.symbols,
            "processed_trades" to deduplicationService.getStats()
        )
    }
}
