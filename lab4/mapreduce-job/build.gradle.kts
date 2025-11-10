plugins {
    kotlin("jvm") version "1.9.22"
    id("com.github.johnrengelman.shadow") version "8.1.1"
}

group = "ru.mephi.moex"
version = "1.0.0"

repositories {
    mavenCentral()
}

val hadoopVersion = "3.2.1"

dependencies {
    // Hadoop MapReduce (provided - already in cluster)
    compileOnly("org.apache.hadoop:hadoop-client:$hadoopVersion")
    compileOnly("org.apache.hadoop:hadoop-mapreduce-client-core:$hadoopVersion")
    compileOnly("org.apache.hadoop:hadoop-common:$hadoopVersion")

    // JSON parsing
    implementation("com.google.code.gson:gson:2.10.1")

    // Kotlin
    implementation(kotlin("stdlib"))
}

tasks {
    shadowJar {
        archiveBaseName.set("moex-mapreduce")
        archiveVersion.set(version.toString())
        archiveClassifier.set("all")

        mergeServiceFiles()

        // Exclude Hadoop dependencies (already in cluster)
        dependencies {
            exclude(dependency("org.apache.hadoop:.*"))
        }

        manifest {
            attributes["Main-Class"] = "ru.mephi.moex.mapreduce.TradeVolumeJob"
        }
    }

    build {
        dependsOn(shadowJar)
    }
}

kotlin {
    jvmToolchain(11)
}
