package ru.mephi.moex.collector.config

import org.springframework.boot.context.properties.ConfigurationProperties
import org.springframework.context.annotation.Configuration

@Configuration
@ConfigurationProperties(prefix = "moex")
data class MoexConfig(
    var api: ApiConfig = ApiConfig(),
    var collector: CollectorConfig = CollectorConfig()
)

data class ApiConfig(
    var baseUrl: String = "https://iss.moex.com/iss",
    var rateLimitMs: Long = 1000
)

data class CollectorConfig(
    var enabled: Boolean = true,
    var intervalMs: Long = 5000,
    var engine: String = "stock",
    var market: String = "shares"
)
