package com.bishare.protocol.constants

/**
 * File category for organizing received files into folders.
 */
enum class BIShareFileCategory(val folderName: String) {
    IMAGES("Images"),
    VIDEOS("Videos"),
    AUDIO("Audio"),
    DOCUMENTS("Documents"),
    ARCHIVES("Archives"),
    OTHER("Other");

    companion object {
        /** Determine the category from a MIME type string. */
        fun from(mimeType: String): BIShareFileCategory {
            val type = mimeType.lowercase()
            return when {
                type.startsWith("image/") -> IMAGES
                type.startsWith("video/") -> VIDEOS
                type.startsWith("audio/") -> AUDIO
                type.startsWith("text/") || type == "application/pdf" -> DOCUMENTS
                type.contains("zip") || type.contains("tar") || type.contains("compress") || type.contains("archive") -> ARCHIVES
                else -> OTHER
            }
        }
    }
}
