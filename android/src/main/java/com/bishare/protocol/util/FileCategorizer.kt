package com.bishare.protocol.util

import com.bishare.protocol.constants.BIShareFileCategory
import java.io.File

/**
 * Maps MIME types to storage folder categories.
 */
object FileCategorizer {

    /**
     * Get the storage subfolder name for a given MIME type.
     * @param mimeType The file's MIME type (e.g., "image/jpeg").
     * @return The folder name (e.g., "Images").
     */
    fun category(mimeType: String): String {
        return BIShareFileCategory.from(mimeType).folderName
    }

    /**
     * Get the full storage path under the BIShare documents directory.
     * @param mimeType The file's MIME type.
     * @param baseDir The base BIShare documents directory.
     * @return The categorized directory.
     */
    fun categoryDirectory(mimeType: String, baseDir: File): File {
        return File(baseDir, category(mimeType))
    }
}
