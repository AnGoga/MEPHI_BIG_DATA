package ru.mephi.moex.collector.model

import com.fasterxml.jackson.annotation.JsonFormat
import com.fasterxml.jackson.annotation.JsonProperty
import java.math.BigDecimal
import java.time.LocalDateTime

/**
 * Информация о сделке на бирже
 */
data class Trade(
    @JsonProperty("tradeno")
    val tradeNo: Long,

    @JsonProperty("tradetime")
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    val tradeTime: String,

    @JsonProperty("secid")
    val securityId: String,

    @JsonProperty("boardid")
    val boardId: String,

    @JsonProperty("price")
    val price: BigDecimal,

    @JsonProperty("quantity")
    val quantity: Long,

    @JsonProperty("value")
    val value: BigDecimal,

    @JsonProperty("period")
    val period: String? = null,

    @JsonProperty("tradingsession")
    val tradingSession: String? = null,

    @JsonProperty("buysell")
    val buySell: String? = null,  // "B" для покупки, "S" для продажи

    @JsonProperty("systime")
    val systemTime: String? = null,

    @JsonProperty("ts_offset")
    val tsOffset: Long? = null
) {
    val totalVolume: BigDecimal
        get() = price * BigDecimal(quantity)

    val timestamp: Long
        get() = System.currentTimeMillis()
}

/**
 * Информация о торговом инструменте
 */
data class Security(
    @JsonProperty("secid")
    val securityId: String,

    @JsonProperty("boardid")
    val boardId: String,

    @JsonProperty("shortname")
    val shortName: String? = null,

    @JsonProperty("secname")
    val securityName: String? = null,

    @JsonProperty("prevprice")
    val prevPrice: BigDecimal? = null,

    @JsonProperty("lotsize")
    val lotSize: Int? = null,

    @JsonProperty("facevalue")
    val faceValue: BigDecimal? = null,

    @JsonProperty("status")
    val status: String? = null,

    @JsonProperty("marketprice")
    val marketPrice: BigDecimal? = null,

    @JsonProperty("currencyid")
    val currencyId: String? = null
)
