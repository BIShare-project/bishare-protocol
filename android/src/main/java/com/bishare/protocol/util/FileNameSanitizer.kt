package com.bishare.protocol.util

import java.io.File

/**
 * File name sanitization to prevent path traversal attacks.
 */
object FileNameSanitizer {

    /**
     * Sanitize a file name by stripping path components and replacing dangerous characters.
     * @param name The raw file name from the sender.
     * @return A safe file name, or "unnamed" if the input is empty.
     */
    fun sanitize(name: String): String {
        // Use only the last path component
        var sanitized = File(name).name

        // Replace dangerous characters
        sanitized = sanitized.replace("..", "_")
        sanitized = sanitized.replace("/", "_")
        sanitized = sanitized.replace(":", "_")
        sanitized = sanitized.replace("\\", "_")

        // Reject empty
        if (sanitized.isBlank()) {
            return "unnamed"
        }

        return sanitized
    }
}
