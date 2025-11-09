package ru.mephi.moex.streaming.model

/**
 * Current price data model for output to moex.current_prices Kafka topic
 */
data class CurrentPrice(
    val secid: String,
    val current_price: Double,
    val buy_avg: Double?,
    val sell_avg: Double?,
    val timestamp: String,
    val window_start: String,
    val window_end: String
)
