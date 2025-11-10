package ru.mephi.moex.mapreduce.mapper

import com.google.gson.Gson
import org.apache.hadoop.io.DoubleWritable
import org.apache.hadoop.io.LongWritable
import org.apache.hadoop.io.Text
import org.apache.hadoop.mapreduce.Mapper
import ru.mephi.moex.mapreduce.Trade
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

/**
 * Mapper: читает JSON сделки из Hive и вычисляет объем торгов
 *
 * Input: JSON строка сделки
 * Output: Key = "secid|hour_start - hour_end", Value = price * quantity
 */
class TradeVolumeMapper : Mapper<LongWritable, Text, Text, DoubleWritable>() {

    private val gson = Gson()
    private val outputKey = Text()
    private val outputValue = DoubleWritable()

    companion object {
        private val INPUT_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss")
        private val OUTPUT_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:00:00")
    }

    override fun map(key: LongWritable, value: Text, context: Context) {
        try {
            // 1. Парсим JSON в объект Trade
            val trade = gson.fromJson(value.toString(), Trade::class.java)

            // 2. Парсим время сделки и округляем до часа
            val tradeDateTime = LocalDateTime.parse(trade.tradeTime, INPUT_FORMATTER)
            val hourStart = tradeDateTime.withMinute(0).withSecond(0).withNano(0)
            val hourEnd = hourStart.plusHours(1)

            // 3. Формируем ключ: "SECID|YYYY-MM-DD HH:00:00 - HH:00:00"
            val hourStartStr = hourStart.format(OUTPUT_FORMATTER)
            val hourEndStr = hourEnd.format(OUTPUT_FORMATTER)
            val compositeKey = "${trade.secId}|$hourStartStr - $hourEndStr"

            // 4. Вычисляем объем сделки
            val volume = trade.price * trade.quantity

            // 5. Emit (key, value)
            outputKey.set(compositeKey)
            outputValue.set(volume)
            context.write(outputKey, outputValue)

        } catch (e: Exception) {
            // Пропускаем некорректные строки
            System.err.println("Error parsing trade: ${value.toString()}: ${e.message}")
        }
    }
}
