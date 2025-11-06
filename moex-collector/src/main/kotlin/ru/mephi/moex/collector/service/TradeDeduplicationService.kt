package ru.mephi.moex.collector.service

import mu.KotlinLogging
import org.springframework.stereotype.Service
import ru.mephi.moex.collector.model.Trade
import java.util.concurrent.ConcurrentHashMap

/**
 * Сервис для предотвращения дублирования сделок
 * Хранит ID последних обработанных сделок
 */
@Service
class TradeDeduplicationService {
    private val logger = KotlinLogging.logger {}

    // Хранилище обработанных сделок: securityId -> Set<tradeNo>
    private val processedTrades = ConcurrentHashMap<String, MutableSet<Long>>()

    // Максимальное количество хранимых ID сделок для каждого инструмента
    private val maxStoredTradesPerSecurity = 10000

    /**
     * Проверить, была ли уже обработана сделка
     */
    fun isProcessed(trade: Trade): Boolean {
        return processedTrades[trade.securityId]?.contains(trade.tradeNo) ?: false
    }

    /**
     * Отметить сделку как обработанную
     */
    fun markAsProcessed(trade: Trade) {
        val trades = processedTrades.getOrPut(trade.securityId) { ConcurrentHashMap.newKeySet() }
        trades.add(trade.tradeNo)

        // Очистка старых записей если превышен лимит
        if (trades.size > maxStoredTradesPerSecurity) {
            val toRemove = trades.size - maxStoredTradesPerSecurity
            val sortedTrades = trades.sorted()
            sortedTrades.take(toRemove).forEach { trades.remove(it) }
            logger.debug { "Cleaned up $toRemove old trade IDs for ${trade.securityId}" }
        }
    }

    /**
     * Фильтровать новые сделки (убрать дубликаты)
     */
    fun filterNewTrades(trades: List<Trade>): List<Trade> {
        return trades.filter { trade ->
            !isProcessed(trade).also { isProcessed ->
                if (isProcessed) {
                    logger.trace { "Skipping duplicate trade: ${trade.securityId}:${trade.tradeNo}" }
                }
            }
        }
    }

    /**
     * Отметить список сделок как обработанные
     */
    fun markAllAsProcessed(trades: List<Trade>) {
        trades.forEach { markAsProcessed(it) }
    }

    /**
     * Получить статистику по обработанным сделкам
     */
    fun getStats(): Map<String, Int> {
        return processedTrades.mapValues { it.value.size }
    }

    /**
     * Очистить все обработанные сделки
     */
    fun clear() {
        processedTrades.clear()
        logger.info { "Cleared all processed trades" }
    }
}
