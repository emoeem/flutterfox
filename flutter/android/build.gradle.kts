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
// Phase 7：老插件子工程自带 compileSdk（如 dynamic_color 的 android-31）
// 低于其传递依赖 androidx.appcompat 1.5 的最低要求（≥32），AAR 元数据
// 检查直接失败。统一抬到 36（与 app 一致）；仅影响构建期编译目标，
// 不改变运行时行为。targetSdk/minSdk 仍由各插件声明托管。
// 注意：afterEvaluate 必须先于 evaluationDependsOn 注册（后者会强制求值）。
subprojects {
    afterEvaluate {
        extensions.findByName("android")?.let { ext ->
            if (ext is com.android.build.gradle.BaseExtension &&
                (ext.compileSdkVersion?.substringAfter("android-")?.toIntOrNull() ?: 0) < 32
            ) {
                ext.compileSdkVersion(36)
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
