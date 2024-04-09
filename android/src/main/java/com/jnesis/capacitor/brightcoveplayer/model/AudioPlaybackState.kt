package com.jnesis.capacitor.brightcoveplayer.model

data class AudioPlaybackState(
        val state: State = State.NONE,
        val currentMillis: Long = 0,
        val totalMillis: Long = 0,
        val error: String? = null,
        val remainingTime: Long? = null
) {
    enum class State {
        NONE,
        ERROR,
        LOADING,
        LOADED,
        RUNNING,
        PAUSED,
        STOPPED,
        ENDED
    }
}
