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
 * Input: JSON строка с одной или несколькими сделками
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
        val line = value.toString()

        // Входная строка может содержать несколько JSON объектов подряд: {...}{...}{...}
        // Разбиваем по границам объектов
        val jsonObjects = splitJsonObjects(line)

        // Обрабатываем каждый JSON объект
        for (jsonStr in jsonObjects) {
            try {
                // 1. Парсим JSON в объект Trade
                val trade = gson.fromJson(jsonStr, Trade::class.java)

                // 2. Парсим время сделки
                // tradetime содержит только время "HH:mm:ss", берем дату из systime
                val systimeDateTime = LocalDateTime.parse(trade.systime ?: "2024-01-01 00:00:00", INPUT_FORMATTER)
                val timeParts = trade.tradeTime.split(":")

                val tradeDateTime = systimeDateTime
                    .withHour(timeParts[0].toInt())
                    .withMinute(timeParts[1].toInt())
                    .withSecond(timeParts[2].toInt())

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
                // Пропускаем некорректные JSON
                System.err.println("Error parsing trade JSON: ${e.message}")
            }
        }
    }

    /**
     * Разбивает строку с несколькими JSON объектами на отдельные объекты
     */
    private fun splitJsonObjects(line: String): List<String> {
        val jsonObjects = mutableListOf<String>()
        var depth = 0
        var currentJson = StringBuilder()

        for (char in line) {
            currentJson.append(char)
            when (char) {
                '{' -> depth++
                '}' -> {
                    depth--
                    if (depth == 0 && currentJson.isNotEmpty()) {
                        jsonObjects.add(currentJson.toString())
                        currentJson = StringBuilder()
                    }
                }
            }
        }

        return jsonObjects
    }
}
