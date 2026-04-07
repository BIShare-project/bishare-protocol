package com.bishare.protocol.models

data class PrepareRequest(
    val info: DeviceInfo,
    val files: Map<String, FileMetadata>
)

data class PrepareResponse(
    val sessionId: String,
    val files: Map<String, String>,
    val publicKey: String? = null,
    val maxConcurrent: Int? = null,
    val chunkSize: Int? = null,
    val windowSize: Int? = null,
    val supportsCompression: Boolean? = null
)

data class UploadResponse(
    val success: Boolean,
    val verified: Boolean? = null,
    val encrypted: Boolean? = null,
    val message: String? = null
)

data class ErrorResponse(
    val message: String
)
