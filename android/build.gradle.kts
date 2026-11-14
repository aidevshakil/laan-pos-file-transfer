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
fun configureProjectSdk(proj: Project) {
    val android = proj.extensions.findByName("android")
    if (android != null) {
        try {
            val setter = android.javaClass.methods.firstOrNull { it.name == "setCompileSdk" }
            setter?.invoke(android, 36)
        } catch (_: Exception) {}
        try {
            val method = android.javaClass.methods.firstOrNull {
                it.name == "compileSdkVersion" && it.parameterTypes.size == 1 && it.parameterTypes[0] == Int::class.javaPrimitiveType
            }
            method?.invoke(android, 36)
        } catch (_: Exception) {}
    }
    proj.tasks.matching { it.name.contains("AarMetadata") }.configureEach {
        try {
            val setCompileSdk = this.javaClass.methods.firstOrNull { it.name == "setCompileSdkVersion" }
            setCompileSdk?.invoke(this, 36)
        } catch (_: Exception) {}
    }
}

subprojects {
    val proj = this
    if (proj.state.executed) {
        configureProjectSdk(proj)
    } else {
        proj.afterEvaluate {
            configureProjectSdk(proj)
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
