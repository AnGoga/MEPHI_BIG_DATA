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

        // 3. Filter valid trades (only BUY and SELL)
        logger.info { "Filtering valid trades (BUY and SELL only)" }
        val validTrades = trades
            .filter(
                col("buysell").isNotNull
                    .and(col("buysell").isin("B", "S"))
            )
            .withColumn("event_time", to_timestamp(col("systime"), "yyyy-MM-dd HH:mm:ss"))

        // 4. Group by time windows and calculate VWAP components
        logger.info { "Grouping by windows (10 sec window, 5 sec slide)" }
        val aggregated = validTrades
            .withWatermark("event_time", "30 seconds")  // Allow 30 sec late data
            .groupBy(
                window(col("event_time"), "10 seconds", "5 seconds"),
                col("secid"),
                col("buysell")
            )
            .agg(
                sum(col("price").multiply(col("quantity"))).alias("total_value"),
                sum("quantity").alias("total_quantity")
            )

        // 5. Pivot BUY/SELL into separate columns
        logger.info { "Pivoting BUY/SELL into columns" }
        val pivoted = aggregated
            .groupBy(col("window"), col("secid"))
            .pivot("buysell", listOf("B", "S"))
            .agg(
                first("total_value").alias("value"),
                first("total_quantity").alias("quantity")
            )
            .withColumnRenamed("B_value", "buy_total_value")
            .withColumnRenamed("B_quantity", "buy_total_quantity")
            .withColumnRenamed("S_value", "sell_total_value")
            .withColumnRenamed("S_quantity", "sell_total_quantity")

        // 6. Calculate VWAP (Volume-Weighted Average Price) for BUY and SELL
        logger.info { "Calculating VWAP and current prices" }
        val currentPrices = pivoted
            // Calculate VWAP for BUY: sum(price*quantity) / sum(quantity)
            .withColumn(
                "buy_vwap",
                `when`(col("buy_total_quantity").isNotNull.and(col("buy_total_quantity").gt(0)),
                    col("buy_total_value").divide(col("buy_total_quantity"))
                ).otherwise(lit(null))
            )
            // Calculate VWAP for SELL: sum(price*quantity) / sum(quantity)
            .withColumn(
                "sell_vwap",
                `when`(col("sell_total_quantity").isNotNull.and(col("sell_total_quantity").gt(0)),
                    col("sell_total_value").divide(col("sell_total_quantity"))
                ).otherwise(lit(null))
            )
            // Current price = average between BUY and SELL VWAP
            .withColumn(
                "current_price",
                `when`(
                    col("buy_vwap").isNotNull.and(col("sell_vwap").isNotNull),
                    col("buy_vwap").plus(col("sell_vwap")).divide(lit(2.0))
                ).otherwise(
                    coalesce(col("buy_vwap"), col("sell_vwap"))
                )
            )
            .withColumn("timestamp", current_timestamp())
            .withColumn("window_start", col("window.start").cast(DataTypes.StringType))
            .withColumn("window_end", col("window.end").cast(DataTypes.StringType))
            .select(
                col("secid"),
                col("current_price"),
                col("buy_vwap"),
                col("sell_vwap"),
                col("buy_total_quantity"),
                col("sell_total_quantity"),
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
