package com.jnesis.capacitor.brightcoveplayer.events

import com.getcapacitor.JSObject

data class VideoPlayerProgressEvent(val data: JSObject? = null)
data class VideoPlayerCloseEvent(val data: JSObject? = null)
data class AudioNotificationCloseEvent(val data: JSObject? = null)
data class DownloadStateChangeEvent(val data: JSObject? = null)
