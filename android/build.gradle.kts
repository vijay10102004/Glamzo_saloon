allprojects {
    repositories {
        google()
        mavenCentral()
        // PhonePe Payment SDK
        maven { url = uri("https://phonepe.mycloudrepo.io/public/repositories/phonepe-intentsdk-android") }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
