package com.perwd.orange.launcher;

/** A problem the user can fix; printed without a stack trace. */
final class LauncherException extends RuntimeException {
    LauncherException(String message) {
        super(message);
    }
}
