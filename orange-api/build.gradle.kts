// The API that Orange mods compile against.
dependencies {
    api("org.ow2.asm:asm:9.10.1")
    api("org.ow2.asm:asm-tree:9.10.1")
    // Provided at runtime from the bootstrap class path by the agent.
    compileOnlyApi(project(":orange-hooks"))
}
