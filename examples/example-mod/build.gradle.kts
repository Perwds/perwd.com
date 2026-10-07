// A sample Orange mod. Build it with `gradle :examples:example-mod:jar` and drop the jar into orange-mods/.
dependencies {
    compileOnly(project(":orange-api"))
    compileOnly(project(":orange-hooks"))
}
