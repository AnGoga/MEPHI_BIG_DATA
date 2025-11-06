package ru.mephi.moex.collector.service

import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule
import mu.KotlinLogging
import org.springframework.stereotype.Service
import java.io.File
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

/**
 * Сервис для хранения курсора сбора данных
 * Сохраняет последнее время обработанных сделок на диск
 * Позволяет продолжить сбор данных после перезапуска приложения
 */
@Service
class CollectionCursorService {
    private val logger = KotlinLogging.logger {}
    private val objectMapper = ObjectMapper().registerModule(JavaTimeModule())
    private val cursorFile = File("data/collection-cursor.json")

    companion object {
        val DATE_TIME_FORMATTER: DateTimeFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss")
    }

    init {
        // Создать директорию если не существует
        cursorFile.parentFile?.mkdirs()
    }

    /**
     * Загрузить курсор из файла
     */
    fun loadCursor(): CollectionCursor {
        return if (cursorFile.exists()) {
            try {
                val cursor = objectMapper.readValue(cursorFile, CollectionCursor::class.java)
                logger.info { "Loaded cursor from file: $cursor" }
                cursor
            } catch (e: Exception) {
                logger.error(e) { "Failed to load cursor from file, using default" }
                createDefaultCursor()
            }
        } else {
            logger.info { "No cursor file found, creating default" }
            createDefaultCursor()
        }
    }

    /**
     * Сохранить курсор в файл
     */
    fun saveCursor(cursor: CollectionCursor) {
        try {
            objectMapper.writerWithDefaultPrettyPrinter().writeValue(cursorFile, cursor)
            logger.debug { "Saved cursor to file: $cursor" }
        } catch (e: Exception) {
            logger.error(e) { "Failed to save cursor to file" }
        }
    }

    /**
     * Обновить время последней обработанной сделки
     */
    fun updateLastTradeTime(time: LocalDateTime) {
        val cursor = loadCursor()
        cursor.lastTradeTime = time
        cursor.lastUpdateTime = LocalDateTime.now()
        saveCursor(cursor)
    }

    /**
     * Обновить статистику
     */
    fun updateStats(tradesCollected: Int, cyclesCompleted: Int) {
        val cursor = loadCursor()
        cursor.totalTradesCollected += tradesCollected
        cursor.totalCyclesCompleted += cyclesCompleted
        cursor.lastUpdateTime = LocalDateTime.now()
        saveCursor(cursor)
    }

    /**
     * Отметить завершение Initial Load
     */
    fun markInitialLoadComplete() {
        val cursor = loadCursor()
        cursor.initialLoadComplete = true
        cursor.lastUpdateTime = LocalDateTime.now()
        saveCursor(cursor)
        logger.info { "Marked initial load as complete" }
    }

    /**
     * Проверить, завершен ли Initial Load
     */
    fun isInitialLoadComplete(): Boolean {
        return loadCursor().initialLoadComplete
    }

    /**
     * Получить последнее время обработанных сделок
     */
    fun getLastTradeTime(): LocalDateTime {
        return loadCursor().lastTradeTime
    }

    /**
     * Сбросить курсор (для тестирования)
     */
    fun reset() {
        val cursor = createDefaultCursor()
        saveCursor(cursor)
        logger.warn { "Cursor has been reset" }
    }

    /**
     * Создать курсор по умолчанию (начало текущего дня)
     */
    private fun createDefaultCursor(): CollectionCursor {
        val startOfDay = LocalDateTime.now().toLocalDate().atStartOfDay()
        return CollectionCursor(
            lastTradeTime = startOfDay,
            initialLoadComplete = false,
            totalTradesCollected = 0,
            totalCyclesCompleted = 0,
            lastUpdateTime = LocalDateTime.now()
        )
    }

    /**
     * Форматировать время для MOEX API
     */
    fun formatForMoexApi(time: LocalDateTime): String {
        return time.format(DATE_TIME_FORMATTER)
    }
}

/**
 * Курсор сбора данных
 */
data class CollectionCursor(
    var lastTradeTime: LocalDateTime = LocalDateTime.now(),
    var initialLoadComplete: Boolean = false,
    var totalTradesCollected: Long = 0,
    var totalCyclesCompleted: Long = 0,
    var lastUpdateTime: LocalDateTime = LocalDateTime.now()
)
