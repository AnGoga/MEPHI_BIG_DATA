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
                    tradeNo = (row[columnIndexMap["TRADENO"] ?: 0] as? Number)?.toLong() ?: 0L,
                    tradeTime = row[columnIndexMap["TRADETIME"] ?: 1]?.toString() ?: "",
                    securityId = row[columnIndexMap["SECID"] ?: 2]?.toString() ?: "",
                    boardId = row[columnIndexMap["BOARDID"] ?: 3]?.toString() ?: "",
                    price = (row[columnIndexMap["PRICE"] ?: 4] as? Number)?.let { BigDecimal(it.toString()) }
                        ?: BigDecimal.ZERO,
                    quantity = (row[columnIndexMap["QUANTITY"] ?: 5] as? Number)?.toLong() ?: 0L,
                    value = (row[columnIndexMap["VALUE"] ?: 6] as? Number)?.let { BigDecimal(it.toString()) }
                        ?: BigDecimal.ZERO,
                    period = row[columnIndexMap["PERIOD"] ?: -1]?.toString(),
                    tradingSession = row[columnIndexMap["TRADINGSESSION"] ?: -1]?.toString(),
                    buySell = row[columnIndexMap["BUYSELL"] ?: -1]?.toString(),
                    systemTime = row[columnIndexMap["SYSTIME"] ?: -1]?.toString(),
                    tsOffset = (row[columnIndexMap["TS_OFFSET"] ?: -1] as? Number)?.toLong()
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
                    securityId = row[columnIndexMap["SECID"] ?: 0]?.toString() ?: "",
                    boardId = row[columnIndexMap["BOARDID"] ?: 1]?.toString() ?: "",
                    shortName = row[columnIndexMap["SHORTNAME"] ?: -1]?.toString(),
                    securityName = row[columnIndexMap["SECNAME"] ?: -1]?.toString(),
                    prevPrice = (row[columnIndexMap["PREVPRICE"] ?: -1] as? Number)?.let { BigDecimal(it.toString()) },
                    lotSize = (row[columnIndexMap["LOTSIZE"] ?: -1] as? Number)?.toInt(),
                    faceValue = (row[columnIndexMap["FACEVALUE"] ?: -1] as? Number)?.let { BigDecimal(it.toString()) },
                    status = row[columnIndexMap["STATUS"] ?: -1]?.toString(),
                    marketPrice = (row[columnIndexMap["MARKETPRICE"] ?: -1] as? Number)?.let { BigDecimal(it.toString()) },
                    currencyId = row[columnIndexMap["CURRENCYID"] ?: -1]?.toString()
                )
            } catch (e: Exception) {
                logger.warn(e) { "Failed to parse security from row: $row" }
                null
            }
        }
    }
}
