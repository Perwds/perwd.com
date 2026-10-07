rootProject.name = "orange"

include("orange-hooks", "orange-api", "orange-launcher", "examples:example-mod")

// The plugin needs repo.papermc.io; -PwithoutPlugin builds everything else.
if (!providers.gradleProperty("withoutPlugin").isPresent) {
    include("orange-plugin")
}
