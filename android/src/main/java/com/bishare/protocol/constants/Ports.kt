package com.bishare.protocol.constants

/**
 * BIShare network port definitions.
 * All ports are in the dynamic/private range (49152–65535).
 */
object BISharePort {
    /** Main transfer server — TCP HTTP */
    const val MAIN: Int = 58317

    /** QUIC transport + Clipboard sync — UDP */
    const val QUIC: Int = 58318

    /** Transfer Rooms — TCP HTTP */
    const val ROOM: Int = 58319

    /** WebDAV Server — TCP */
    const val WEBDAV: Int = 58320
}
