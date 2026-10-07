plugins {
    id("com.gradleup.shadow")
}

// Jars embedded inside orange.jar and unpacked at runtime.
val embeddedHooks: Configuration by configurations.creating { isTransitive = false }
val embeddedPlugin: Configuration by configurations.creating { isTransitive = false }

// Building the plugin needs repo.papermc.io. Pass -PwithoutPlugin to build the launcher without it.
val withPlugin = !project.hasProperty("withoutPlugin")

dependencies {
    implementation(project(":orange-api"))
    implementation("org.yaml:snakeyaml:2.7")
    compileOnly(project(":orange-hooks"))

    embeddedHooks(project(":orange-hooks"))
    if (withPlugin) {
        embeddedPlugin(project(":orange-plugin"))
    }
}

tasks.processResources {
    from(embeddedHooks) {
        into("META-INF/orange")
        rename { "orange-hooks.jar" }
    }
    from(embeddedPlugin) {
        into("META-INF/orange")
        rename { "orange-plugin.jar" }
    }
}

tasks.shadowJar {
    archiveFileName.set("orange.jar")
    // SnakeYAML is only used by the launcher; relocate it so it can never shadow the server's copy.
    // ASM stays at org.objectweb.asm because mods compile against it.
    relocate("org.yaml.snakeyaml", "com.perwd.orange.libs.snakeyaml")
    exclude("module-info.class", "META-INF/versions/*/module-info.class")
    manifest {
        attributes(
            "Main-Class" to "com.perwd.orange.launcher.OrangeLauncher",
            "Premain-Class" to "com.perwd.orange.agent.OrangeAgent",
            "Implementation-Title" to "Orange",
            "Implementation-Version" to project.version,
        )
    }
}

tasks.jar { enabled = false }
tasks.assemble { dependsOn(tasks.shadowJar) }
