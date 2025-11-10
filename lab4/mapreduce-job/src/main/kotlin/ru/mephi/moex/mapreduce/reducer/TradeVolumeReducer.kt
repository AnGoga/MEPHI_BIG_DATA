package ru.mephi.moex.mapreduce.reducer

import org.apache.hadoop.io.DoubleWritable
import org.apache.hadoop.io.Text
import org.apache.hadoop.mapreduce.Reducer

/**
 * Reducer: суммирует объемы торгов по каждому инструменту и часу
 *
 * Input: Key = "secid|hour_start - hour_end", Values = [volume1, volume2, ...]
 * Output: "secid|hour_start - hour_end → total_volume"
 */
class TradeVolumeReducer : Reducer<Text, DoubleWritable, Text, Text>() {

    private val outputValue = Text()

    override fun reduce(key: Text, values: Iterable<DoubleWritable>, context: Context) {
        // Суммируем все объемы для данного ключа
        var totalVolume = 0.0
        for (value in values) {
            totalVolume += value.get()
        }

        // Форматируем результат: "secid|hour_start - hour_end → total_volume"
        outputValue.set("→ $totalVolume")

        context.write(key, outputValue)
    }
}
