package ru.mephi.moex.collector.service

import com.fasterxml.jackson.databind.ObjectMapper
import mu.KotlinLogging
import org.springframework.kafka.core.KafkaTemplate
import org.springframework.kafka.support.SendResult
import org.springframework.stereotype.Service
import ru.mephi.moex.collector.config.KafkaConfig
import ru.mephi.moex.collector.model.Security
import ru.mephi.moex.collector.model.Trade
import java.util.concurrent.CompletableFuture

@Service
class KafkaProducerService(
    private val kafkaTemplate: KafkaTemplate<String, String>,
    private val objectMapper: ObjectMapper
) {
    private val logger = KotlinLogging.logger {}

    /**
     * Отправить информацию о сделке в Kafka
     */
    fun sendTrade(trade: Trade): CompletableFuture<SendResult<String, String>> {
        val json = objectMapper.writeValueAsString(trade)
        val key = "${trade.securityId}:${trade.tradeNo}"

//        logger.debug { "Sending trade to Kafka: $key" }

        return kafkaTemplate.send(KafkaConfig.TRADES_TOPIC, key, json)
            .whenComplete { result, ex ->
                if (ex != null) {
                    logger.error(ex) { "Failed to send trade to Kafka: $key" }
                } else {
                    logger.trace {
                        "Trade sent successfully: $key to partition ${result?.recordMetadata?.partition()}"
                    }
                }
            }
    }

    /**
     * Отправить информацию о торговом инструменте в Kafka
     */
    fun sendSecurity(security: Security): CompletableFuture<SendResult<String, String>> {
        val json = objectMapper.writeValueAsString(security)
        val key = security.securityId

        logger.debug { "Sending security to Kafka: $key" }

        return kafkaTemplate.send(KafkaConfig.INSTRUMENTS_TOPIC, key, json)
            .whenComplete { result, ex ->
                if (ex != null) {
                    logger.error(ex) { "Failed to send security to Kafka: $key" }
                } else {
                    logger.trace {
                        "Security sent successfully: $key to partition ${result?.recordMetadata?.partition()}"
                    }
                }
            }
    }

    /**
     * Отправить множество сделок в Kafka
     */
    fun sendTrades(trades: List<Trade>) {
//        logger.info { "Sending ${trades.size} trades to Kafka" }
        trades.forEach { sendTrade(it) }
    }

    /**
     * Отправить множество инструментов в Kafka
     */
    fun sendSecurities(securities: List<Security>) {
//        logger.info { "Sending ${securities.size} securities to Kafka" }
        securities.forEach { sendSecurity(it) }
    }
}
