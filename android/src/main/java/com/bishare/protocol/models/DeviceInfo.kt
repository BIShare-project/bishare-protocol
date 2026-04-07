package com.bishare.protocol.models

import com.bishare.protocol.constants.BIShareConfig
import com.bishare.protocol.constants.BISharePort
import com.google.gson.annotations.SerializedName

data class DeviceInfo(
    val alias: String,
    val version: String = BIShareConfig.VERSION,
    val deviceModel: String? = null,
    val deviceType: String? = null,
    val fingerprint: String,
    val port: Int = BISharePort.MAIN,
    @SerializedName("protocol") val protocol_: String = BIShareConfig.PROTOCOL_SCHEME,
    val download: Boolean = false,
    val publicKey: String? = null,
    val supportsBinary: Boolean? = true,
    val supportsCompression: Boolean? = null
)
