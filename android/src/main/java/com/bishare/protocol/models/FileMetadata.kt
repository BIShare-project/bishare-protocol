package com.bishare.protocol.models

data class FileMetadata(
    val id: String,
    val fileName: String,
    val size: Long,
    val fileType: String,
    val sha256: String? = null,
    val preview: String? = null,
    val expiresInSeconds: Int? = null
)
