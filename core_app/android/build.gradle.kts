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
    afterEvaluate {
        if (project.hasProperty("android")) {
            val android = project.extensions.getByName("android")
            
            // Force compileSdk to 36 to override older packages (like isar_flutter_libs)
            try {
                android.javaClass.getMethod("setCompileSdkVersion", Int::class.java).invoke(android, 36)
            } catch (e: Exception) {
                try {
                    android.javaClass.getMethod("setCompileSdk", Int::class.java).invoke(android, 36)
                } catch (e2: Exception) {}
            }

            try {
                android.javaClass.getMethod("setTargetSdkVersion", Int::class.java).invoke(android, 36)
            } catch (e: Exception) {
                 try {
                    android.javaClass.getMethod("setTargetSdk", Int::class.java).invoke(android, 36)
                } catch (e2: Exception) {}
            }
            
            try {
                val getNamespace = android.javaClass.getMethod("getNamespace")
                val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                if (getNamespace.invoke(android) == null) {
                    // Specific fix for isar_flutter_libs or other libraries lacking namespace
                    if (project.name.contains("isar")) {
                        setNamespace.invoke(android, "dev.isar.isar_flutter_libs")
                    } else {
                        setNamespace.invoke(android, "com.carnama.labs.${project.name.replace("-", "_")}")
                    }
                }
            } catch (e: Exception) {
                // Skip if property missing or inaccessible
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
