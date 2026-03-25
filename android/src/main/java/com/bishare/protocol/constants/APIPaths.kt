package com.bishare.protocol.constants

/**
 * All API endpoint paths used by BIShare protocol.
 */
object BIShareAPI {
    // Transfer Endpoints (port: MAIN)
    const val INFO = "/api/v1/info"
    const val PREPARE = "/api/v1/prepare"
    const val UPLOAD = "/api/v1/upload"
    const val CANCEL = "/api/v1/cancel"
    const val FILES = "/api/v1/files"
    const val DOWNLOAD = "/api/v1/download"
    const val DOWNLOAD_ALL = "/api/v1/download-all"
    const val BROWSER_UPLOAD = "/api/v1/browser-upload"
    const val INSTANT = "/api/v1/instant"
    const val REQUEST = "/api/v1/request"
    const val VERIFY_PIN = "/api/v1/verify-pin"
    const val GOODBYE = "/api/v1/goodbye"

    // Room Endpoints (port: ROOM)
    const val ROOM_INFO = "/api/v1/room/info"
    const val ROOM_JOIN = "/api/v1/room/join"
    const val ROOM_FILES = "/api/v1/room/files"
    const val ROOM_DOWNLOAD = "/api/v1/room/download"
    const val ROOM_FILE_ADDED = "/api/v1/room/file-added"
    const val ROOM_KICKED = "/api/v1/room/kicked"
    const val ROOM_MEMBER_JOINED = "/api/v1/room/member-joined"
    const val ROOM_MEMBER_LEFT = "/api/v1/room/member-left"
}
