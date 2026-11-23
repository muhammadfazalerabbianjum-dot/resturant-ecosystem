allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// ARCH-1 LEDGER (pre-existing gap unblocked, not introduced by this batch):
// `isar_flutter_libs 3.1.0+1` (pub-cache plugin, pulled by the labs path dep)
// predates AGP 8's mandatory `namespace` and fails configuration under the
// shell's pinned AGP 8.11.1 ("Namespace not specified"). This reflection-based
// hook injects the namespace from each subproject's manifest `package` attr
// when AGP never received one — the standard pre-AGP-8-plugin shim. The same
// gap exists in core_app's android config (identical AGP pin) — mirroring the
// fix into the GENERATOR's android template is ARCH-2 territory (Rule 4:
// template before shell; hand-mirrored here with this note in the meantime).
subprojects {
    afterEvaluate {
        val androidExt = extensions.findByName("android") ?: return@afterEvaluate
        val methods = androidExt.javaClass.methods
        val getNamespace = methods.firstOrNull { it.name == "getNamespace" } ?: return@afterEvaluate
        if (getNamespace.invoke(androidExt) != null) return@afterEvaluate
        val setNamespace = methods.firstOrNull { it.name == "setNamespace" } ?: return@afterEvaluate
        val manifest = projectDir.resolve("src/main/AndroidManifest.xml")
        if (!manifest.exists()) return@afterEvaluate
        val pkg = Regex("package\\s*=\\s*\"([^\"]+)\"")
            .find(manifest.readText())?.groupValues?.get(1) ?: return@afterEvaluate
        setNamespace.invoke(androidExt, pkg)
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
