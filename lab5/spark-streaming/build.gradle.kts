plugins {
    kotlin("jvm") version "1.9.22"
    id("com.github.johnrengelman.shadow") version "8.1.1"  // Fat JAR plugin
}

group = "ru.mephi.moex"
version = "1.0.0"

repositories {
    mavenCentral()
}

val sparkVersion = "3.5.0"
val scalaVersion = "2.12"

dependencies {
    // Spark Core and SQL (provided - already in cluster)
    compileOnly("org.apache.spark:spark-core_$scalaVersion:$sparkVersion")
    compileOnly("org.apache.spark:spark-sql_$scalaVersion:$sparkVersion")

    // Kafka Connector (include in JAR)
    implementation("org.apache.spark:spark-sql-kafka-0-10_$scalaVersion:$sparkVersion")

    // Kotlin
    implementation(kotlin("stdlib"))
    implementation(kotlin("reflect"))

    // Logging
    implementation("io.github.microutils:kotlin-logging-jvm:3.0.5")
    implementation("org.slf4j:slf4j-api:2.0.9")
}

tasks {
    shadowJar {
        archiveBaseName.set("moex-streaming")
        archiveVersion.set(version.toString())
        archiveClassifier.set("all")

        mergeServiceFiles()

        // Exclude provided dependencies (they're in Spark cluster)
        dependencies {
            exclude(dependency("org.apache.spark:spark-core_$scalaVersion:.*"))
            exclude(dependency("org.apache.spark:spark-sql_$scalaVersion:.*"))
            exclude(dependency("org.scala-lang:.*"))
        }

        // Manifest for Main class
        manifest {
            attributes["Main-Class"] = "ru.mephi.moex.streaming.MoexCurrentPriceCalculator"
        }
    }

    // Make shadowJar the default build task
    named("build") {
        dependsOn(shadowJar)
    }
}

kotlin {
    jvmToolchain(11)
}
