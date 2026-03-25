package com.bishare.protocol.models

/** A file shared within a transfer room. */
data class RoomFileItem(
    val id: String,
    val fileName: String,
    val fileType: String,
    val size: Long,
    val ownerAlias: String,
    val ownerFingerprint: String,
    val addedAt: String
)

/** A member within a transfer room. */
data class RoomMember(
    val fingerprint: String,
    val alias: String,
    val deviceType: String,
    val host: String,
    val port: Int
)

/** Room metadata returned by GET /api/v1/room/info. */
data class RoomInfo(
    val code: String,
    val hostAlias: String,
    val hostFingerprint: String,
    val memberCount: Int,
    val fileCount: Int
)
