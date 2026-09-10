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
// Bazı eklentiler (file_picker → flutter_plugin_android_lifecycle) compileSdk
// 36 istiyor ama kendi modülleri Flutter varsayılanıyla (34) derleniyor.
// Tüm eklenti alt-projelerini 36'ya çekiyoruz. Bu blok, aşağıdaki
// evaluationDependsOn(":app") çağrısından ÖNCE gelmeli — yoksa afterEvaluate
// "project already evaluated" hatası verir.
subprojects {
    afterEvaluate {
        extensions.findByName("android")?.let { ext ->
            val android = ext as com.android.build.gradle.BaseExtension
            android.compileSdkVersion(36)
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
