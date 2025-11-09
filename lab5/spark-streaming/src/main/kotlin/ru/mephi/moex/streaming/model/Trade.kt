package ru.mephi.moex.streaming.model

/**
 * Trade data model matching JSON from moex.trades Kafka topic
 */
data class Trade(
    val tradeno: Long,
    val tradetime: String,
    val secid: String,
    val boardid: String,
    val price: Double,
    val quantity: Long,
    val value: Double,
    val buysell: String?,
    val period: String? = null,
    val tradingsession: String? = null,
    val systime: String? = null,
    val ts_offset: Long? = null
)
