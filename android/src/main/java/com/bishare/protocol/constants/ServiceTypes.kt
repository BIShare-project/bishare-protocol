package com.bishare.protocol.constants

/**
 * Bonjour/mDNS service type identifiers for discovery.
 */
object BIShareService {
    /** Main device discovery — with trailing dot for Android NSD */
    const val DISCOVERY = "_bishare._tcp."

    /** Main device discovery — without trailing dot (for matching/comparison) */
    const val DISCOVERY_RAW = "_bishare._tcp"

    /** Transfer room discovery — with trailing dot for Android NSD */
    const val ROOM = "_bishare-room._tcp."

    /** Transfer room discovery — without trailing dot */
    const val ROOM_RAW = "_bishare-room._tcp"

    /** Wi-Fi Aware service type (iOS 26+ WiFiAwareServices naming) */
    const val AWARE = "_bishare-aware._tcp"

    /** Android Wi-Fi Aware (NAN) service name (lowercase, WifiAwareManager) */
    const val AWARE_NAN = "bishare-aware"
}
