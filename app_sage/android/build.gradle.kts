
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.6.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.25")
    }
}


allprojects {
    repositories {
        google()
        mavenCentral()
    }

        // 👇 Force Gradle to use desugar_jdk_libs 2.1.4 globally
    configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "com.android.tools" && requested.name == "desugar_jdk_libs") {
                useVersion("2.1.4")
                because("flutter_local_notifications requires at least 2.1.4")
            }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
