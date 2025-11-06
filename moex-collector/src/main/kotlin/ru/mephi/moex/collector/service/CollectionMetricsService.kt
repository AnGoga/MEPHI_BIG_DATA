package ru.mephi.moex.collector.service

import mu.KotlinLogging
import org.springframework.stereotype.Service
import java.time.Duration
import java.time.LocalDateTime
import java.util.concurrent.atomic.AtomicLong

/**
 * Сервис для сбора метрик процесса сбора данных
 */
@Service
class CollectionMetricsService {
    private val logger = KotlinLogging.logger {}

    // Счетчики
    private val totalTradesCollected = AtomicLong(0)
    private val totalDuplicatesFiltered = AtomicLong(0)
    private val totalCyclesCompleted = AtomicLong(0)
    private val totalApiCalls = AtomicLong(0)
    private val totalErrors = AtomicLong(0)

    // Временные метки
    private var lastCycleStartTime: LocalDateTime? = null
    private var lastCycleEndTime: LocalDateTime? = null
    private var applicationStartTime: LocalDateTime = LocalDateTime.now()

    /**
     * Начало цикла сбора данных
     */
    fun startCollectionCycle() {
        lastCycleStartTime = LocalDateTime.now()
    }

    /**
     * Завершение цикла сбора данных
     */
    fun endCollectionCycle(tradesCollected: Int, duplicatesFiltered: Int, apiCalls: Int) {
        lastCycleEndTime = LocalDateTime.now()
        totalTradesCollected.addAndGet(tradesCollected.toLong())
        totalDuplicatesFiltered.addAndGet(duplicatesFiltered.toLong())
        totalApiCalls.addAndGet(apiCalls.toLong())
        totalCyclesCompleted.incrementAndGet()

        val cycleDuration = lastCycleStartTime?.let { start ->
            Duration.between(start, lastCycleEndTime).toMillis()
        } ?: 0

        logger.info {
            "Collection cycle completed: " +
                    "collected=$tradesCollected, " +
                    "duplicates=$duplicatesFiltered, " +
                    "api_calls=$apiCalls, " +
                    "duration=${cycleDuration}ms"
        }
    }

    /**
     * Зафиксировать ошибку
     */
    fun recordError() {
        totalErrors.incrementAndGet()
    }

    /**
     * Получить все метрики
     */
    fun getMetrics(): CollectionMetrics {
        val uptime = Duration.between(applicationStartTime, LocalDateTime.now())
        val avgTradesPerCycle = if (totalCyclesCompleted.get() > 0) {
            totalTradesCollected.get().toDouble() / totalCyclesCompleted.get()
        } else {
            0.0
        }

        val lastCycleDuration = if (lastCycleStartTime != null && lastCycleEndTime != null) {
            Duration.between(lastCycleStartTime, lastCycleEndTime).toMillis()
        } else {
            0L
        }

        return CollectionMetrics(
            totalTradesCollected = totalTradesCollected.get(),
            totalDuplicatesFiltered = totalDuplicatesFiltered.get(),
            totalCyclesCompleted = totalCyclesCompleted.get(),
            totalApiCalls = totalApiCalls.get(),
            totalErrors = totalErrors.get(),
            avgTradesPerCycle = avgTradesPerCycle,
            lastCycleDurationMs = lastCycleDuration,
            uptimeSeconds = uptime.seconds,
            applicationStartTime = applicationStartTime
        )
    }

    /**
     * Вывести метрики в лог
     */
    fun logMetrics() {
        val metrics = getMetrics()
        logger.info {
            """
            |
            |===== Collection Metrics =====
            |Total Trades Collected: ${metrics.totalTradesCollected}
            |Total Duplicates Filtered: ${metrics.totalDuplicatesFiltered}
            |Total Cycles Completed: ${metrics.totalCyclesCompleted}
            |Total API Calls: ${metrics.totalApiCalls}
            |Total Errors: ${metrics.totalErrors}
            |Avg Trades Per Cycle: ${"%.2f".format(metrics.avgTradesPerCycle)}
            |Last Cycle Duration: ${metrics.lastCycleDurationMs}ms
            |Uptime: ${metrics.uptimeSeconds}s (${metrics.uptimeSeconds / 60}m)
            |Started At: ${metrics.applicationStartTime}
            |==============================
            """.trimMargin()
        }
    }

    /**
     * Сбросить метрики
     */
    fun reset() {
        totalTradesCollected.set(0)
        totalDuplicatesFiltered.set(0)
        totalCyclesCompleted.set(0)
        totalApiCalls.set(0)
        totalErrors.set(0)
        applicationStartTime = LocalDateTime.now()
        logger.warn { "Metrics have been reset" }
    }
}

/**
 * Snapshot метрик
 */
data class CollectionMetrics(
    val totalTradesCollected: Long,
    val totalDuplicatesFiltered: Long,
    val totalCyclesCompleted: Long,
    val totalApiCalls: Long,
    val totalErrors: Long,
    val avgTradesPerCycle: Double,
    val lastCycleDurationMs: Long,
    val uptimeSeconds: Long,
    val applicationStartTime: LocalDateTime
)
