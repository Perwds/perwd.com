// A plugin written the Folia way (region/global/entity/async schedulers, folia-supported: true).
// The server test loads it next to regular plugins to prove both kinds run on the same server.
val paperApiVersion: String by project

dependencies {
    compileOnly("io.papermc.paper:paper-api:$paperApiVersion")
}

tasks.jar {
    archiveFileName.set("FoliaTest.jar")
}
