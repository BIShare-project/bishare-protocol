package com.bishare.protocol.models

import com.bishare.protocol.constants.BISharePort

data class FileRequestMessage(
    val requestId: String,
    val requesterAlias: String,
    val requesterFingerprint: String,
    val requesterHost: String,
    val requesterPort: Int = BISharePort.MAIN,
    val message: String? = null,
    val requestedTypes: List<String>? = null
)

data class FileRequestResponse(
    val requestId: String,
    val accepted: Boolean
)
