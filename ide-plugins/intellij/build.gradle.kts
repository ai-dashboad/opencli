plugins {
    id("org.jetbrains.intellij") version "1.16.0"
    kotlin("jvm") version "1.9.0"
}

group = "dev.opencli"
version = "0.1.0"

repositories {
    mavenCentral()
}

dependencies {
    implementation("org.msgpack:msgpack-core:0.9.5")
}

intellij {
    version.set("2023.2")
    plugins.set(listOf("Dart:232.8660.185"))
}

tasks {
    patchPluginXml {
        sinceBuild.set("232")
        untilBuild.set("241.*")
    }

    signPlugin {
        certificateChain.set(System.getenv("CERTIFICATE_CHAIN"))
        privateKey.set(System.getenv("PRIVATE_KEY"))
        password.set(System.getenv("PRIVATE_KEY_PASSWORD"))
    }

    publishPlugin {
        token.set(System.getenv("PUBLISH_TOKEN"))
    }
}
