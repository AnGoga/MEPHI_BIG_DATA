package ru.mephi.moex.collector.config

import org.springframework.context.annotation.Configuration

@Configuration
class KafkaConfig {
    companion object {
        const val TRADES_TOPIC = "moex.trades"
        const val INSTRUMENTS_TOPIC = "moex.instruments"
    }
}
