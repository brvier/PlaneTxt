allprojects {
    repositories {
        google()
        mavenCentral()
    }
    // home_widget declares androidx.glance:glance-appwidget:1.+, which now
    // resolves to 1.3.0-alpha02 and requires compileSdk 37 + AGP 9.1. Pin to
    // the latest stable until home_widget pins its own dependency.
    configurations.all {
        resolutionStrategy {
            force("androidx.glance:glance-appwidget:1.1.1")
            force("androidx.glance:glance:1.1.1")
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
