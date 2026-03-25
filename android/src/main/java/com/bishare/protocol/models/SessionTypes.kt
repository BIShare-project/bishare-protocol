package com.bishare.protocol.models

/** Active transfer session (in-memory tracking on server side). */
data class TransferSession(
    val sessionId: String,
    val senderInfo: DeviceInfo,
    val files: Map<String, FileMetadata>,
    val tokens: Map<String, String>,
    val uploadedFiles: MutableSet<String> = mutableSetOf(),
    val createdAt: Long = System.currentTimeMillis(),
    var encryptionKey: ByteArray? = null
)

/** Received file metadata. */
data class ReceivedFile(
    val id: String,
    val fileName: String,
    val size: Long,
    val fileType: String,
    val savedPath: String,
    val senderAlias: String,
    val receivedAt: Long = System.currentTimeMillis(),
    val verified: Boolean = true,
    var encrypted: Boolean = false
)

/** File info for browser download list. */
data class SharedFileInfo(
    val index: Int,
    val fileName: String,
    val fileType: String,
    val size: Long
)
