package com.jnesis.capacitor.brightcoveplayer.model

import kotlinx.serialization.Serializable

@Serializable
data class DownloadStateMediaInfo(
        val mediaId: String? = null,
        val status: Status? = null,
        val estimatedSize: Long? = -1,
        val maxSize: Long? = -1,
        val downloadedBytes: Long? = -1,
        val progress: Double? = 0.0,
        val reason: String? = "",
        val token: String? = null,
        val title: String? = null,

) {
    enum class Status {
        REQUESTED,
        IN_PROGRESS,
        PAUSED,
        CANCELED,
        COMPLETED,
        DELETED,
        FAILED
    }
}
