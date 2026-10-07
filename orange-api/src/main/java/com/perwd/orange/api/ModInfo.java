package com.perwd.orange.api;

import java.nio.file.Path;

public record ModInfo(String id, String name, String version, Path source) {
}
