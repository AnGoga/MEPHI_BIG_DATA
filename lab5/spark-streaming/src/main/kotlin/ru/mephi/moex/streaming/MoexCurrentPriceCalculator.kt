package ru.mephi.moex.streaming

import mu.KotlinLogging
import org.apache.spark.sql.SparkSession
import org.apache.spark.sql.functions.*
import org.apache.spark.sql.streaming.Trigger
import org.apache.spark.sql.types.*


object MoexCurrentPriceCalculator {

    private val logger = KotlinLogging.logger {}

    @JvmStatic
    fun main(args: Array<String>) {
        logger.info { "Starting MOEX Current Price Calculator" }

        val spark = SparkSession.builder()
            .appName("MOEX Current Price Calculator")
            .config("spark.sql.streaming.schemaInference", "true")
            .config("spark.sql.streaming.statefulOperator.checkCorrectness.enabled", "false")
            .getOrCreate()

        logger.info { "Spark Session created: ${spark.version()}" }
        logger.info { "Spark Master: ${spark.sparkContext().getConf().get("spark.master", "local")}" }

        // Define schema for Trade JSON
        val tradeSchema = DataTypes.createStructType(arrayOf(
            DataTypes.createStructField("tradeno", DataTypes.LongType, false),
            DataTypes.createStructField("tradetime", DataTypes.StringType, false),
            DataTypes.createStructField("secid", DataTypes.StringType, false),
            DataTypes.createStructField("boardid", DataTypes.StringType, false),
            DataTypes.createStructField("price", DataTypes.DoubleType, false),
            DataTypes.createStructField("quantity", DataTypes.LongType, false),
            DataTypes.createStructField("value", DataTypes.DoubleType, false),
            DataTypes.createStructField("buysell", DataTypes.StringType, true),
            DataTypes.createStructField("period", DataTypes.StringType, true),
            DataTypes.createStructField("tradingsession", DataTypes.StringType, true),
            DataTypes.createStructField("systime", DataTypes.StringType, true),
            DataTypes.createStructField("ts_offset", DataTypes.LongType, true)
        ))

        // 1. Read from Kafka topic moex.trades
        logger.info { "Reading from Kafka topic: moex.trades" }
        val rawStream = spark.readStream()
            .format("kafka")
            .option("kafka.bootstrap.servers", "kafka:29092")
            .option("subscribe", "moex.trades")
            .option("startingOffsets", "latest")
            .option("failOnDataLoss", "false")
            .load()

        // 2. Parse JSON from Kafka value
        logger.info { "Parsing JSON messages" }
        val trades = rawStream
            .selectExpr("CAST(value AS STRING) as json")
            .select(from_json(col("json"), tradeSchema).alias("data"))
            .select("data.*")

        // 3. Filter valid trades (only BUY and SELL) and calculate weighted price
        logger.info { "Filtering valid trades and calculating weighted prices" }
        val validTrades = trades
            .filter(
                col("buysell").isNotNull
                    .and(col("buysell").isin("B", "S"))
            )
            .withColumn("weighted_price", col("price").multiply(col("quantity")))
            .withColumn("event_time", to_timestamp(col("systime"), "yyyy-MM-dd HH:mm:ss"))

        // 4. Group by time windows and aggregate
        logger.info { "Grouping by windows (10 sec window, 5 sec slide)" }
        val aggregated = validTrades
            .withWatermark("event_time", "30 seconds")  // Allow 30 sec late data
            .groupBy(
                window(col("event_time"), "10 seconds", "5 seconds"),
                col("secid"),
                col("buysell")
            )
            .agg(avg("weighted_price").alias("avg_weighted_price"))

        // 5. Pivot BUY/SELL into separate columns
        logger.info { "Pivoting BUY/SELL into columns" }
        val pivoted = aggregated
            .groupBy(col("window"), col("secid"))
            .pivot("buysell", listOf("B", "S"))
            .agg(first("avg_weighted_price"))
            .withColumnRenamed("B", "buy_avg")
            .withColumnRenamed("S", "sell_avg")

        // 6. Calculate current price as average of BUY and SELL
        logger.info { "Calculating current prices" }
        val currentPrices = pivoted
            .withColumn(
                "current_price",
                `when`(
                    col("buy_avg").isNotNull.and(col("sell_avg").isNotNull),
                    col("buy_avg").plus(col("sell_avg")).divide(lit(2.0))
                ).otherwise(
                    coalesce(col("buy_avg"), col("sell_avg"))
                )
            )
            .withColumn("timestamp", current_timestamp())
            .withColumn("window_start", col("window.start").cast(DataTypes.StringType))
            .withColumn("window_end", col("window.end").cast(DataTypes.StringType))
            .select(
                col("secid"),
                col("current_price"),
                col("buy_avg"),
                col("sell_avg"),
                col("timestamp"),
                col("window_start"),
                col("window_end")
            )

        // 7. Write results to Kafka topic moex.current_prices
        logger.info { "Writing to Kafka topic: moex.current_prices" }
        val query = currentPrices
            .selectExpr("secid as key", "to_json(struct(*)) as value")
            .writeStream()
            .format("kafka")
            .option("kafka.bootstrap.servers", "kafka:29092")
            .option("topic", "moex.current_prices")
            .option("checkpointLocation", "/tmp/spark-checkpoint/moex-current-prices")
            .outputMode("update")
            .trigger(Trigger.ProcessingTime("5 seconds"))
            .start()

        logger.info { "Streaming query started. Awaiting termination..." }
        logger.info { "Monitor at: http://localhost:8083 (Spark Master UI)" }
        logger.info { "View output: docker exec -it moex-kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic moex.current_prices" }

        query.awaitTermination()
    }
}
