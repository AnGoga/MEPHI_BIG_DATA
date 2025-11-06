package ru.mephi.moex.collector.config

import org.springframework.boot.context.properties.ConfigurationProperties
import org.springframework.context.annotation.Configuration

@Configuration
@ConfigurationProperties(prefix = "tickers")
data class TickerConfig(
    var mode: TickerMode = TickerMode.SPECIFIC,
    var symbols: List<String> = emptyList()
)

enum class TickerMode {
    SPECIFIC,  // Мониторинг конкретных тикеров
    ALL        // Мониторинг всех доступных инструментов
}
