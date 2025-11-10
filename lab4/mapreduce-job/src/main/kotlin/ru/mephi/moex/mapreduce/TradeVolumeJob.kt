package ru.mephi.moex.mapreduce

import org.apache.hadoop.conf.Configuration
import org.apache.hadoop.fs.Path
import org.apache.hadoop.io.DoubleWritable
import org.apache.hadoop.io.Text
import org.apache.hadoop.mapreduce.Job
import org.apache.hadoop.mapreduce.lib.input.FileInputFormat
import org.apache.hadoop.mapreduce.lib.output.FileOutputFormat
import ru.mephi.moex.mapreduce.mapper.TradeVolumeMapper
import ru.mephi.moex.mapreduce.reducer.TradeVolumeReducer

/**
 * MapReduce Job для подсчета суммарного объема торгов
 * по каждому инструменту с интервалом 1 час
 *
 * Входные данные: /user/hive/warehouse/moex_data.db/trades/ (JSON)
 * Выходные данные: /user/hive/warehouse/moex_data.db/trade_volumes_hourly/
 *
 * Формат вывода: SBER|2024-01-15 10:00:00 - 11:00:00 → 38850.0
 */
object TradeVolumeJob {

    @JvmStatic
    fun main(args: Array<String>) {
        // Проверка аргументов
        if (args.size != 2) {
            System.err.println("Usage: TradeVolumeJob <input path> <output path>")
            System.err.println()
            System.err.println("Example:")
            System.err.println("  hadoop jar moex-mapreduce-1.0.0-all.jar \\")
            System.err.println("    /user/hive/warehouse/moex_data.db/trades \\")
            System.err.println("    /user/hive/warehouse/moex_data.db/trade_volumes_hourly")
            System.exit(-1)
        }

        val inputPath = args[0]
        val outputPath = args[1]

        println("=" * 60)
        println("MOEX Trade Volume Hourly Aggregation")
        println("=" * 60)
        println("Input:  $inputPath")
        println("Output: $outputPath")
        println("=" * 60)

        // Создаем конфигурацию
        val conf = Configuration()

        // Создаем Job
        val job = Job.getInstance(conf, "MOEX Trade Volume Hourly Aggregation")
        job.setJarByClass(TradeVolumeJob::class.java)

        // Настраиваем Mapper и Reducer
        job.setMapperClass(TradeVolumeMapper::class.java)
        job.setReducerClass(TradeVolumeReducer::class.java)

        // Типы данных Mapper
        job.setMapOutputKeyClass(Text::class.java)
        job.setMapOutputValueClass(DoubleWritable::class.java)

        // Типы данных Reducer
        job.setOutputKeyClass(Text::class.java)
        job.setOutputValueClass(Text::class.java)

        // Пути ввода/вывода
        FileInputFormat.addInputPath(job, Path(inputPath))
        FileOutputFormat.setOutputPath(job, Path(outputPath))

        // Запускаем Job и ждем завершения
        val success = job.waitForCompletion(true)

        println()
        if (success) {
            println("✅ Job completed successfully!")
            println("Results written to: $outputPath")
        } else {
            println("❌ Job failed!")
        }

        System.exit(if (success) 0 else 1)
    }
}

// Helper для повторения строки
private operator fun String.times(n: Int): String = this.repeat(n)
