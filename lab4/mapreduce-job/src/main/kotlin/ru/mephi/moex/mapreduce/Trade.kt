package ru.mephi.moex.mapreduce

import com.google.gson.annotations.SerializedName

/**
 * Модель сделки из Hive таблицы moex_data.trades
 */
data class Trade(
    @SerializedName("tradeno")
    val tradeNo: Long = 0,

    @SerializedName("tradetime")
    val tradeTime: String = "",

    @SerializedName("secid")
    val secId: String = "",

    @SerializedName("boardid")
    val boardId: String = "",

    @SerializedName("price")
    val price: Double = 0.0,

    @SerializedName("quantity")
    val quantity: Long = 0,

    @SerializedName("value")
    val value: Double = 0.0,

    @SerializedName("buysell")
    val buySell: String = ""
)
