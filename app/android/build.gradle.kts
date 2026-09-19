allprojects {
    repositories {
        google()
        mavenCentral()
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

// flutter_native_splash 2.4.4 ships its own Android module hardcoded to
// compileSdkVersion 31 (fixed upstream in 2.4.8, which we can't take yet —
// it bumps `archive` to a major version incompatible with `excel`, see
// EXECUTE.md 7.4 decision log). Newer AndroidX transitive deps need 34+, so
// override just this module's compileSdk to match the app's.
subprojects {
    if (project.name == "flutter_native_splash") {
        afterEvaluate {
            extensions.findByType(com.android.build.gradle.BaseExtension::class.java)
                ?.compileSdkVersion(36)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
