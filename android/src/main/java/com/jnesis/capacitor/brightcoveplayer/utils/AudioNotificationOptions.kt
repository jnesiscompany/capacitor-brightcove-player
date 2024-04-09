package com.jnesis.capacitor.brightcoveplayer.utils


object AudioNotificationOptions {
    private const val DEFAULT_NOTIFICATION_FORWARD_INCREMENT_MS: Long = 15000
    private const val DEFAULT_NOTIFICATION_REWIND_INCREMENT_MS: Long = 15000
    
    var audioNotificationForwardIncrementMs: Long = DEFAULT_NOTIFICATION_FORWARD_INCREMENT_MS
    var audioNotificationRewindIncrementMs: Long = DEFAULT_NOTIFICATION_REWIND_INCREMENT_MS
}
