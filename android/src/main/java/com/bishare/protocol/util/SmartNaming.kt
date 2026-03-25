package com.bishare.protocol.util

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Smart file naming for received files.
 */
object SmartNaming {

    private val dateFormatter = SimpleDateFormat("yyyy-MM-dd", Locale.US)

    /**
     * Generate a smart file name in the format: {date}_{sender}_{filename}.
     * @param originalName The original file name.
     * @param senderAlias The sender's device alias.
     * @param date The date of receipt (defaults to now).
     * @return A formatted file name.
     */
    fun format(originalName: String, senderAlias: String, date: Date = Date()): String {
        val dateStr = dateFormatter.format(date)
        val safeSender = senderAlias
            .replace(" ", "-")
            .replace("/", "_")
            .replace(":", "_")
        return "${dateStr}_${safeSender}_${originalName}"
    }
}
