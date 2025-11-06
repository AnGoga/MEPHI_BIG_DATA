package ru.mephi.moex.collector

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.context.properties.ConfigurationPropertiesScan
import org.springframework.boot.runApplication
import org.springframework.kafka.annotation.EnableKafka
import org.springframework.scheduling.annotation.EnableScheduling

@SpringBootApplication
@EnableKafka
@EnableScheduling
@ConfigurationPropertiesScan
class MoexCollectorApplication

fun main(args: Array<String>) {
    runApplication<MoexCollectorApplication>(*args)
}
