package com.bishare.protocol.models

/** Payload for UDP clipboard sync broadcast. */
data class ClipboardPayload(
    val type: String = "clipboard",
    val text: String,
    val sender: String,
    val alias: String
)
