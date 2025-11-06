package ru.mephi.moex.collector.client

import com.fasterxml.jackson.databind.ObjectMapper
import mu.KotlinLogging
import org.springframework.stereotype.Component
import org.springframework.web.reactive.function.client.WebClient
import org.springframework.web.reactive.function.client.bodyToMono
import reactor.core.publisher.Mono
import ru.mephi.moex.collector.config.MoexConfig
import ru.mephi.moex.collector.model.DataBlock
import ru.mephi.moex.collector.model.MoexResponse
import ru.mephi.moex.collector.model.Security
import ru.mephi.moex.collector.model.Trade
import java.math.BigDecimal
import java.time.Duration

@Component
class MoexApiClient(
    private val moexConfig: MoexConfig,
    private val objectMapper: ObjectMapper
) {
    private val logger = KotlinLogging.logger {}
    private val webClient: WebClient = WebClient.builder()
        .baseUrl(moexConfig.api.baseUrl)
        .codecs { configurer ->
            // Увеличить лимит буфера до 10MB (MOEX может возвращать большие ответы)
            configurer.defaultCodecs().maxInMemorySize(10 * 1024 * 1024)
        }
        .build()

    private var lastRequestTime: Long = 0

    /**
     * Получить список всех доступных торговых инструментов
     */
    fun getSecurities(): List<Security> {
        logger.debug { "Fetching securities from MOEX API" }

        return executeWithRateLimit {
            webClient.get()
                .uri("/engines/${moexConfig.collector.engine}/markets/${moexConfig.collector.market}/securities.json")
                .retrieve()
                .bodyToMono<MoexResponse<Any>>()
                .timeout(Duration.ofSeconds(10))
                .doOnError { error ->
                    logger.error(error) { "Error fetching securities from MOEX API" }
                }
        }?.securities?.let { parseSecurities(it) } ?: emptyList()
    }

    /**
     * Получить последние сделки для всех инструментов
     */
    fun getAllTrades(limit: Int = 100): List<Trade> {
        logger.debug { "Fetching all trades from MOEX API (limit: $limit)" }

        return executeWithRateLimit {
            webClient.get()
                .uri("/engines/${moexConfig.collector.engine}/markets/${moexConfig.collector.market}/trades.json?reversed=1&limit=$limit")
                .retrieve()
                .bodyToMono<MoexResponse<Any>>()
                .timeout(Duration.ofSeconds(10))
                .doOnError { error ->
                    logger.error(error) { "Error fetching trades from MOEX API" }
                }
        }?.trades?.let { parseTrades(it) } ?: emptyList()
    }

    /**
     * Получить сделки с пагинацией
     * @param limit максимальное количество записей (рекомендуется 5000)
     * @param start смещение (offset) для пагинации
     * @param reversed true = новые сначала, false = старые сначала
     */
    fun getAllTradesWithPagination(
        limit: Int = 5000,
        start: Int = 0,
        reversed: Boolean = true
    ): List<Trade> {
        val reversedParam = if (reversed) 1 else 0
        logger.debug { "Fetching trades with pagination (limit: $limit, start: $start, reversed: $reversed)" }

        return executeWithRateLimit {
            webClient.get()
                .uri("/engines/${moexConfig.collector.engine}/markets/${moexConfig.collector.market}/trades.json?reversed=$reversedParam&limit=$limit&start=$start")
                .retrieve()
                .bodyToMono<MoexResponse<Any>>()
                .timeout(Duration.ofSeconds(10))
                .doOnError { error ->
                    logger.error(error) { "Error fetching trades with pagination from MOEX API" }
                }
        }?.trades?.let { parseTrades(it) } ?: emptyList()
    }

    /**
     * Получить сделки в заданном временном диапазоне с пагинацией
     * @param from начало временного диапазона (формат: yyyy-MM-dd HH:mm:ss)
     * @param till конец временного диапазона (формат: yyyy-MM-dd HH:mm:ss)
     * @param limit максимальное количество записей
     * @param start смещение (offset) для пагинации
     * @param reversed true = новые сначала, false = старые сначала
     */
    fun getTradesByTimeRange(
        from: String,
        till: String,
        limit: Int = 5000,
        start: Int = 0,
        reversed: Boolean = false
    ): List<Trade> {
        val reversedParam = if (reversed) 1 else 0
        logger.debug { "Fetching trades by time range: $from to $till (limit: $limit, start: $start)" }

        return executeWithRateLimit {
            webClient.get()
                .uri("/engines/${moexConfig.collector.engine}/markets/${moexConfig.collector.market}/trades.json?from=$from&till=$till&reversed=$reversedParam&limit=$limit&start=$start")
                .retrieve()
                .bodyToMono<MoexResponse<Any>>()
                .timeout(Duration.ofSeconds(10))
                .doOnError { error ->
                    logger.error(error) { "Error fetching trades by time range from MOEX API" }
                }
        }?.trades?.let { parseTrades(it) } ?: emptyList()
    }


    fun getAllTradesInTimeRangeForInit(
        from: String,
        till: String,
        batchSize: Int = 5000,
        loadCallback: (List<Trade>) -> Unit
    ): Int {
        logger.info { "Fetching ALL trades in time range: $from to $till" }
        var tradesCnt = 0
        var start = 0

        while (true) {
            val batch = getTradesByTimeRange(
                from = from,
                till = till,
                limit = batchSize,
                start = start,
                reversed = false
            )

            if (batch.isEmpty()) {
                logger.debug { "No more trades in time range at start=$start" }
                break
            }

            tradesCnt += batch.size
            loadCallback(batch)

            logger.debug { "Fetched ${batch.size} trades (total: ${tradesCnt})" }

            if (batch.size < batchSize) {
                // Последний батч, все данные получены
                break
            }

            start += batchSize
        }

        logger.info { "Completed fetching trades in time range: ${tradesCnt} total trades" }
        return tradesCnt
    }


    /**
     * Получить ВСЕ сделки в заданном временном диапазоне (автоматическая пагинация)
     * Будет делать несколько запросов, если данных больше чем limit
     */
    fun getAllTradesInTimeRange(
        from: String,
        till: String,
        batchSize: Int = 5000
    ): List<Trade> {
        logger.info { "Fetching ALL trades in time range: $from to $till" }
        val allTrades = mutableListOf<Trade>()
        var start = 0

        while (true) {
            val batch = getTradesByTimeRange(
                from = from,
                till = till,
                limit = batchSize,
                start = start,
                reversed = false
            )

            if (batch.isEmpty()) {
                logger.debug { "No more trades in time range at start=$start" }
                break
            }

            allTrades.addAll(batch)
            logger.debug { "Fetched ${batch.size} trades (total: ${allTrades.size})" }

            if (batch.size < batchSize) {
                // Последний батч, все данные получены
                break
            }

            start += batchSize
        }

        logger.info { "Completed fetching trades in time range: ${allTrades.size} total trades" }
        return allTrades
    }

    /**
     * Получить последние сделки для конкретного инструмента
     */
    fun getTradesBySecurityId(securityId: String, limit: Int = 100): List<Trade> {
        logger.debug { "Fetching trades for $securityId from MOEX API (limit: $limit)" }

        return executeWithRateLimit {
            webClient.get()
                .uri("/engines/${moexConfig.collector.engine}/markets/${moexConfig.collector.market}/securities/$securityId/trades.json?reversed=1&limit=$limit")
                .retrieve()
                .bodyToMono<MoexResponse<Any>>()
                .timeout(Duration.ofSeconds(10))
                .doOnError { error ->
                    logger.error(error) { "Error fetching trades for $securityId from MOEX API" }
                }
        }?.trades?.let { parseTrades(it) } ?: emptyList()
    }

    /**
     * Получить сделки конкретного инструмента в заданном временном диапазоне с пагинацией
     * @param securityId ID инструмента (например, SBER, GAZP)
     * @param from начало временного диапазона (формат: yyyy-MM-dd HH:mm:ss)
     * @param till конец временного диапазона (формат: yyyy-MM-dd HH:mm:ss)
     * @param limit максимальное количество записей
     * @param start смещение (offset) для пагинации
     * @param reversed true = новые сначала, false = старые сначала
     */
    fun getTradesBySecurityIdInTimeRange(
        securityId: String,
        from: String,
        till: String,
        limit: Int = 5000,
        start: Int = 0,
        reversed: Boolean = false
    ): List<Trade> {
        val reversedParam = if (reversed) 1 else 0
        logger.debug { "Fetching trades for $securityId by time range: $from to $till (limit: $limit, start: $start)" }

        return executeWithRateLimit {
            webClient.get()
                .uri("/engines/${moexConfig.collector.engine}/markets/${moexConfig.collector.market}/securities/$securityId/trades.json?from=$from&till=$till&reversed=$reversedParam&limit=$limit&start=$start")
                .retrieve()
                .bodyToMono<MoexResponse<Any>>()
                .timeout(Duration.ofSeconds(10))
                .doOnError { error ->
                    logger.error(error) { "Error fetching trades for $securityId by time range from MOEX API" }
                }
        }?.trades?.let { parseTrades(it) } ?: emptyList()
    }

    /**
     * Получить ВСЕ сделки конкретного инструмента в заданном временном диапазоне (автоматическая пагинация)
     * @param securityId ID инструмента (например, SBER, GAZP)
     * @param from начало временного диапазона
     * @param till конец временного диапазона
     * @param batchSize размер батча для одного запроса
     */
    fun getAllTradesBySecurityIdInTimeRange(
        securityId: String,
        from: String,
        till: String,
        batchSize: Int = 5000
    ): List<Trade> {
        logger.info { "Fetching ALL trades for $securityId in time range: $from to $till" }
        val allTrades = mutableListOf<Trade>()
        var start = 0

        while (true) {
            val batch = getTradesBySecurityIdInTimeRange(
                securityId = securityId,
                from = from,
                till = till,
                limit = batchSize,
                start = start,
                reversed = false
            )

            if (batch.isEmpty()) {
                logger.debug { "No more trades for $securityId in time range at start=$start" }
                break
            }

            allTrades.addAll(batch)
            logger.debug { "Fetched ${batch.size} trades for $securityId (total: ${allTrades.size})" }

            if (batch.size < batchSize) {
                // Последний батч, все данные получены
                break
            }

            start += batchSize
        }

        logger.info { "Completed fetching trades for $securityId in time range: ${allTrades.size} total trades" }
        return allTrades
    }

    /**
     * Получить ВСЕ сделки конкретного инструмента в заданном временном диапазоне с callback
     * Используется для Initial Load чтобы не накапливать все данные в памяти
     * @param securityId ID инструмента
     * @param from начало временного диапазона
     * @param till конец временного диапазона
     * @param batchSize размер батча для одного запроса
     * @param loadCallback callback вызывается для каждого батча
     * @return количество загруженных сделок
     */
    fun getAllTradesBySecurityIdInTimeRangeForInit(
        securityId: String,
        from: String,
        till: String,
        batchSize: Int = 5000,
        loadCallback: (List<Trade>) -> Unit
    ): Int {
        logger.info { "Fetching ALL trades for $securityId in time range: $from to $till" }
        var tradesCnt = 0
        var start = 0

        while (true) {
            val batch = getTradesBySecurityIdInTimeRange(
                securityId = securityId,
                from = from,
                till = till,
                limit = batchSize,
                start = start,
                reversed = false
            )

            if (batch.isEmpty()) {
                logger.debug { "No more trades for $securityId in time range at start=$start" }
                break
            }

            tradesCnt += batch.size
            loadCallback(batch)

            logger.debug { "Fetched ${batch.size} trades for $securityId (total: ${tradesCnt})" }

            if (batch.size < batchSize) {
                // Последний батч, все данные получены
                break
            }

            start += batchSize
        }

        logger.info { "Completed fetching trades for $securityId in time range: ${tradesCnt} total trades" }
        return tradesCnt
    }

    /**
     * Выполнить запрос с учетом rate limit (1 запрос в секунду)
     */
    private fun <T> executeWithRateLimit(block: () -> Mono<T>): T? {
        synchronized(this) {
            val now = System.currentTimeMillis()
            val timeSinceLastRequest = now - lastRequestTime

            if (timeSinceLastRequest < moexConfig.api.rateLimitMs) {
                val sleepTime = moexConfig.api.rateLimitMs - timeSinceLastRequest
                logger.trace { "Rate limiting: sleeping for ${sleepTime}ms" }
                Thread.sleep(sleepTime)
            }

            lastRequestTime = System.currentTimeMillis()
        }

        return try {
            block().block()
        } catch (e: Exception) {
            logger.error(e) { "Error executing MOEX API request" }
            null
        }
    }

    /**
     * Парсинг сделок из DataBlock
     */
    private fun parseTrades(dataBlock: DataBlock): List<Trade> {
        val columnIndexMap = dataBlock.columns.withIndex().associate { it.value to it.index }

        return dataBlock.data.mapNotNull { row ->
            try {
                Trade(
                    tradeNo = (row.getOrNull(columnIndexMap["TRADENO"] ?: 0) as? Number)?.toLong() ?: 0L,
                    tradeTime = row.getOrNull(columnIndexMap["TRADETIME"] ?: 1)?.toString() ?: "",
                    securityId = row.getOrNull(columnIndexMap["SECID"] ?: 2)?.toString() ?: "",
                    boardId = row.getOrNull(columnIndexMap["BOARDID"] ?: 3)?.toString() ?: "",
                    price = (row.getOrNull(columnIndexMap["PRICE"] ?: 4) as? Number)?.let { BigDecimal(it.toString()) }
                        ?: BigDecimal.ZERO,
                    quantity = (row.getOrNull(columnIndexMap["QUANTITY"] ?: 5) as? Number)?.toLong() ?: 0L,
                    value = (row.getOrNull(columnIndexMap["VALUE"] ?: 6) as? Number)?.let { BigDecimal(it.toString()) }
                        ?: BigDecimal.ZERO,
                    period = columnIndexMap["PERIOD"]?.let { row.getOrNull(it)?.toString() },
                    tradingSession = columnIndexMap["TRADINGSESSION"]?.let { row.getOrNull(it)?.toString() },
                    buySell = columnIndexMap["BUYSELL"]?.let { row.getOrNull(it)?.toString() },
                    systemTime = columnIndexMap["SYSTIME"]?.let { row.getOrNull(it)?.toString() },
                    tsOffset = columnIndexMap["TS_OFFSET"]?.let { (row.getOrNull(it) as? Number)?.toLong() }
                )
            } catch (e: Exception) {
                logger.warn(e) { "Failed to parse trade from row: $row" }
                null
            }
        }
    }

    /**
     * Парсинг инструментов из DataBlock
     */
    private fun parseSecurities(dataBlock: DataBlock): List<Security> {
        val columnIndexMap = dataBlock.columns.withIndex().associate { it.value to it.index }

        return dataBlock.data.mapNotNull { row ->
            try {
                Security(
                    securityId = row.getOrNull(columnIndexMap["SECID"] ?: 0)?.toString() ?: "",
                    boardId = row.getOrNull(columnIndexMap["BOARDID"] ?: 1)?.toString() ?: "",
                    shortName = columnIndexMap["SHORTNAME"]?.let { row.getOrNull(it)?.toString() },
                    securityName = columnIndexMap["SECNAME"]?.let { row.getOrNull(it)?.toString() },
                    prevPrice = columnIndexMap["PREVPRICE"]?.let { (row.getOrNull(it) as? Number)?.let { BigDecimal(it.toString()) } },
                    lotSize = columnIndexMap["LOTSIZE"]?.let { (row.getOrNull(it) as? Number)?.toInt() },
                    faceValue = columnIndexMap["FACEVALUE"]?.let { (row.getOrNull(it) as? Number)?.let { BigDecimal(it.toString()) } },
                    status = columnIndexMap["STATUS"]?.let { row.getOrNull(it)?.toString() },
                    marketPrice = columnIndexMap["MARKETPRICE"]?.let { (row.getOrNull(it) as? Number)?.let { BigDecimal(it.toString()) } },
                    currencyId = columnIndexMap["CURRENCYID"]?.let { row.getOrNull(it)?.toString() }
                )
            } catch (e: Exception) {
                logger.warn(e) { "Failed to parse security from row: $row" }
                null
            }
        }
    }
}
