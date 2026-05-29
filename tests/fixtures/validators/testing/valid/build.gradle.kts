plugins {
    java
}

repositories {
    mavenCentral()
    maven("https://repo.papermc.io/repository/maven-public/")
}

dependencies {
    testImplementation("org.junit.jupiter:junit-jupiter:5.11.0")
    testImplementation("org.mockbukkit.mockbukkit:mockbukkit-v1.21:4.0.0")
}

tasks.test {
    useJUnitPlatform()
}
