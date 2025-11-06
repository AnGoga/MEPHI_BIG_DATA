package ru.mephi.moex.collector.model

import com.fasterxml.jackson.annotation.JsonIgnoreProperties
import com.fasterxml.jackson.annotation.JsonProperty

/**
 * Общая структура ответа MOEX ISS API
 */
@JsonIgnoreProperties(ignoreUnknown = true)
data class MoexResponse<T>(
    @JsonProperty("trades")
    val trades: DataBlock? = null,

    @JsonProperty("securities")
    val securities: DataBlock? = null,

    @JsonProperty("marketdata")
    val marketdata: DataBlock? = null
)

@JsonIgnoreProperties(ignoreUnknown = true)
data class DataBlock(
    @JsonProperty("columns")
    val columns: List<String> = emptyList(),

    @JsonProperty("data")
    val data: List<List<Any?>> = emptyList()
)
