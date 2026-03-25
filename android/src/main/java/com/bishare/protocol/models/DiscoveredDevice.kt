package com.bishare.protocol.models

/** Discovered peer device on the local network. */
data class DiscoveredDevice(
    val id: String,
    val alias: String,
    val deviceModel: String,
    val deviceType: String,
    val fingerprint: String,
    val version: String,
    val host: String,
    val port: Int,
    var quicPort: Int? = null,
    var lastSeen: Long = System.currentTimeMillis(),
    var latencyMs: Int = 0
) {
    val supportsQUIC: Boolean get() = quicPort != null
}
