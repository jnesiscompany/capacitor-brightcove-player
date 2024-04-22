package com.jnesis.capacitor.brightcoveplayer.service

import android.app.Activity
import android.app.Notification
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.*
import androidx.core.app.NotificationCompat
import com.brightcove.player.controller.ExoPlayerSourceSelector
import com.brightcove.player.dash.BrightcoveDashManifestParser
import com.brightcove.player.dash.OfflineDashManifestParser
import com.brightcove.player.model.Video
import com.brightcove.player.offline.MultiDataSource
import com.getcapacitor.PluginCall
import com.google.android.exoplayer2.ExoPlayer
import com.google.android.exoplayer2.MediaItem
import com.google.android.exoplayer2.PlaybackException
import com.google.android.exoplayer2.Player
import com.google.android.exoplayer2.source.MediaSource
import com.google.android.exoplayer2.source.dash.DashMediaSource
import com.google.android.exoplayer2.source.dash.DefaultDashChunkSource
import com.google.android.exoplayer2.source.dash.manifest.DashManifest
import com.google.android.exoplayer2.source.dash.manifest.DashManifestParser
import com.google.android.exoplayer2.ui.PlayerNotificationManager
import com.google.android.exoplayer2.ui.PlayerNotificationManager.Builder
import com.google.android.exoplayer2.upstream.*
import com.google.android.exoplayer2.util.Util
import com.jnesis.capacitor.brightcoveplayer.BrightcovePlayer
import com.jnesis.capacitor.brightcoveplayer.events.AudioNotificationCloseEvent
import com.jnesis.capacitor.brightcoveplayer.events.EventBus
import com.jnesis.capacitor.brightcoveplayer.exception.MissingFileIdException
import com.jnesis.capacitor.brightcoveplayer.exception.MissingSourceUrlException
import com.jnesis.capacitor.brightcoveplayer.exception.PluginException
import com.jnesis.capacitor.brightcoveplayer.manager.CatalogManager
import com.jnesis.capacitor.brightcoveplayer.model.AudioPlaybackState
import com.jnesis.capacitor.brightcoveplayer.utils.AudioNotificationOptions
import io.reactivex.Observable
import io.reactivex.subjects.BehaviorSubject
import io.reactivex.subjects.PublishSubject
import io.reactivex.subjects.Subject
import java.net.URI
import java.net.URL
import java.util.*
import java.util.concurrent.TimeUnit


class AudioService : Service() {

    val playbackState: BehaviorSubject<AudioPlaybackState> = BehaviorSubject.create<AudioPlaybackState>().apply { onNext(AudioPlaybackState()) }
    val positionState: PublishSubject<AudioPlaybackState> = PublishSubject.create<AudioPlaybackState>().apply { onNext(AudioPlaybackState()) }

    var activity: Activity? = null

    var remainingTime: Long? = null

    private var unsubscribe: Subject<Any>? = null

    private val binder = AudioServiceBinder()

    private var exoPlayer: ExoPlayer? = null
    private var playerNotificationManager: PlayerNotificationManager? = null
    private var currentMediaSource: MediaSource? = null
    private var currentMedia: Video? = null
    private var preventStop = false
    private var defaultPosterUrl: String? = null
    private var loaded: Boolean = false

    companion object {
        const val NOTIFICATION_ID = 89425
    }

    override fun onBind(intent: Intent?): IBinder {
        return binder
    }
    override fun onDestroy() = destroyPlayer()

    fun destroyPlayer(removeNotification: Boolean = true) {
        refreshNotificationToBeginning()
        unsubscribe?.onNext(Any())
        unsubscribe?.onComplete()
        playbackState.onNext(AudioPlaybackState())
        positionState.onNext(AudioPlaybackState())
        if (removeNotification) stopForeground(true)
        playerNotificationManager?.setPlayer(null)
        exoPlayer?.release()
        exoPlayer = null
        currentMediaSource = null
        currentMedia = null
        loaded = false
    }

    fun loadMedia(call: PluginCall) {
        loaded = false
        val mediaId = call.getString("fileId")!!
        this.defaultPosterUrl = call.getString("defaultPosterUrl")

        CatalogManager.checkCredentials()
        ensurePlayer()

        playbackState.onNext(AudioPlaybackState(AudioPlaybackState.State.LOADING))

        val callback = { video: Video?, local: Boolean ->
            currentMedia = video
            currentMediaSource = getMediaSourceFromVideo(video, local)
                    .also {
                        exoPlayer!!.setMediaSource(it!!)
                        exoPlayer!!.prepare()
                    }

            call.resolve()
        }

        try {
            if (call.getBoolean("local", false)!!) {
                CatalogManager.tryToLoadLocallyOrFetchRemotely(mediaId, call, callback)
            } else {
                CatalogManager.fetchRemoteMedia(mediaId, call, callback)
            }
        } catch (t: Throwable) {
            call.reject(t.localizedMessage, PluginException.ErrorCode.TECHNICAL_ERROR.name, Exception(t))
        }
    }

    private fun buildDataSourceFactory(httpDatasourceFactory: HttpDataSource.Factory): DataSource.Factory {
        return MultiDataSource.Factory(this@AudioService, httpDatasourceFactory, null)
    }

    private fun getMediaSourceFromVideo(video: Video?, local: Boolean): MediaSource? {
        return if (local) {
            getLocalMediaSource(video)
        } else {
            getRemoteMediaSource(video)
        }
    }

    private fun getLocalMediaSource(video: Video?): MediaSource? {
        if (video == null) {
            return null
        }
        val videoSource: MediaSource
        val httpDataSourceFactory: HttpDataSource.Factory = DefaultHttpDataSource.Factory().setUserAgent(Util.getUserAgent(this@AudioService, "Capacitor Brightcove Plugin"))
        val dataSourceFactory = this.buildDataSourceFactory(httpDataSourceFactory)

        var manifestParser: ParsingLoadable.Parser<out DashManifest?> = BrightcoveDashManifestParser()
        manifestParser = OfflineDashManifestParser(manifestParser as DashManifestParser, this@AudioService)

        val mediaItem: MediaItem = MediaItem.Builder()
            .setUri(getVideoUrl(video))
            .setTag(MediaTags(
                title = video.properties["name"].toString(),
                description = video.properties["description"].toString(),
                imageUri = this.getPoster(video)
            )).build()

        videoSource = DashMediaSource.Factory(
                DefaultDashChunkSource.Factory(dataSourceFactory),
                this.buildDataSourceFactory(httpDataSourceFactory)
        )
                .setManifestParser(manifestParser)
                .setLoadErrorHandlingPolicy(DefaultLoadErrorHandlingPolicy())
                .setFallbackTargetLiveOffsetMs(30000L)

                .createMediaSource(mediaItem)

        val captionPairs = video.properties["captionSources"] as MutableList<*>?
        captionPairs?.clear()
        return videoSource
    }

    private fun getRemoteMediaSource(video: Video?): MediaSource? {
        if (video == null) {
            return null
        }

        val httpDataSourceFactory: HttpDataSource.Factory = DefaultHttpDataSource.Factory().setUserAgent(Util.getUserAgent(this@AudioService, "Capacitor Brightcove Plugin"))
        val dataSourceFactory = this.buildDataSourceFactory(httpDataSourceFactory)

        val description = video.properties["description"]?.toString() ?: ""
        val mediaItem: MediaItem = MediaItem.Builder()
            .setUri(getVideoUrl(video))
            .setTag(MediaTags(
            title = video.properties["name"].toString(),
            description = description,
            imageUri = this.getPoster(video)
        )).build()

        return DashMediaSource
                .Factory(dataSourceFactory)
                .createMediaSource(mediaItem)
    }

    private fun getPoster(video: Video): URI? {
        return if (this.defaultPosterUrl !== null) {
            URI.create(this.defaultPosterUrl)
        } else {
            video.properties["stillImageUri"] as URI?
        }
    }

    private fun getVideoUrl(video: Video?): String {
        return ExoPlayerSourceSelector().selectSource(video!!).url ?: throw MissingSourceUrlException()
    }

    fun play() {
        checkFile()
        exoPlayer!!.play()
        preventStop = false
    }

    fun pause() {
        checkFile()
        exoPlayer!!.pause()
    }

    fun stop() {
        playbackState.onNext(AudioPlaybackState(AudioPlaybackState.State.STOPPED))
        positionState.onNext(AudioPlaybackState(
                currentMillis = 0,
                totalMillis = 0,
                remainingTime = remainingTime
        ))
        refreshNotificationToBeginning()
    }

    fun onAudioEnd() {

        if (preventStop || exoPlayer == null) return
        preventStop = true

        playbackState.onNext(AudioPlaybackState(AudioPlaybackState.State.ENDED))
        positionState.onNext(AudioPlaybackState(
                currentMillis = 0,
                totalMillis = 0,
                remainingTime = remainingTime
        ))
        pause()

        refreshNotificationToBeginning()
    }

    private fun refreshNotificationToBeginning() {
        if(currentMediaSource !== null) {
            pause()
            seekTo(0)
            playerNotificationManager!!.invalidate()
        }

    }

    fun seekTo(millis: Long) {

        checkFile()

        var position = millis
        if (millis < 0) position = 0
        if (millis > (exoPlayer!!.duration - 10)) position = exoPlayer!!.duration - 10

        exoPlayer!!.seekTo(position)
        positionState.onNext(AudioPlaybackState(
                currentMillis = exoPlayer!!.currentPosition,
                totalMillis = exoPlayer!!.duration,
                remainingTime = remainingTime
        ))
    }

    fun backward(millis: Long) {
        checkFile()
        seekTo(exoPlayer!!.currentPosition - millis)
    }

    fun forward(millis: Long) {
        checkFile()
        seekTo(exoPlayer!!.currentPosition + millis)
    }

    fun toggleLooping(enabled: Boolean) {
        ensurePlayer()
        playerNotificationManager?.setUseChronometer(!enabled)
        activity!!.runOnUiThread {
            if (enabled) {
                exoPlayer!!.repeatMode = Player.REPEAT_MODE_ONE
            } else {
                this.remainingTime = null
                exoPlayer!!.repeatMode = Player.REPEAT_MODE_OFF
            }
        }
    }

    fun isLooping(): Boolean {
        ensurePlayer()
        return exoPlayer!!.repeatMode == Player.REPEAT_MODE_ONE
    }

    fun getPlayerState(): AudioPlaybackState {
        ensurePlayer()

        return AudioPlaybackState(
                playbackState.value.state,
                if (playbackState.value.state == AudioPlaybackState.State.STOPPED) 0 else exoPlayer!!.currentPosition,
                exoPlayer!!.contentDuration,
                playbackState.value.error
        )
    }

    private fun ensurePlayer() {
        if (exoPlayer == null) {
        exoPlayer = ExoPlayer
            .Builder(this)
            .setSeekBackIncrementMs(AudioNotificationOptions.audioNotificationRewindIncrementMs)
            .setSeekForwardIncrementMs(AudioNotificationOptions.audioNotificationForwardIncrementMs)
            .build()
            .also {
                it.addListener(object : Player.Listener {

                    override fun onPlayerError(error: PlaybackException) {
                        playbackState.onNext(AudioPlaybackState(
                            state = AudioPlaybackState.State.ERROR,
                            error = error.toString()
                        ))
                    }

                    override fun onIsPlayingChanged(isPlaying: Boolean) {
                        playbackState.onNext(AudioPlaybackState(if (isPlaying) AudioPlaybackState.State.RUNNING else AudioPlaybackState.State.PAUSED))
                    }

                    override fun onPlaybackStateChanged(state: Int) {
                        when (state) {
                            Player.STATE_ENDED -> {
                                onAudioEnd()
                            }

                            Player.STATE_READY -> {
                                if(!loaded) {
                                    loaded = true
                                    playbackState.onNext(AudioPlaybackState(AudioPlaybackState.State.LOADED))
                                }
                            }
                        }
                    }
            })
            }

            unsubscribe = PublishSubject.create()

            initRemainingLoopTimeInterval()

            initPositionInterval()

            createNotification()
        }
    }

    private fun initRemainingLoopTimeInterval() {
        Observable
                .interval(50, TimeUnit.MILLISECONDS)
                .takeUntil(unsubscribe)
                .filter {
                    playbackState.value.state == AudioPlaybackState.State.RUNNING
                }
                .subscribe {
                    activity!!.runOnUiThread {
                        if (!isLooping()) return@runOnUiThread

                        if (remainingTime != null) {
                            remainingTime = remainingTime?.minus(50)
                            if (remainingTime!! <= 0) {
                                this.remainingTime = null
                                    this.stop()
                                    this.toggleLooping(false)
                            }
                        }
                    }
                }
    }

    private fun initPositionInterval() {
        Observable
                .interval(1, TimeUnit.SECONDS)
                .takeUntil(unsubscribe)
                .filter { playbackState.value.state == AudioPlaybackState.State.RUNNING }
                .subscribe {
                    activity!!.runOnUiThread {
                        positionState.onNext(AudioPlaybackState(
                                state = playbackState.value.state,
                                currentMillis = exoPlayer!!.currentPosition,
                                totalMillis = exoPlayer!!.duration,
                                remainingTime = remainingTime
                        ))
                    }
                }
    }

    private fun createNotification() {
        playerNotificationManager = Builder(this, NOTIFICATION_ID,BrightcovePlayer.NOTIFICATION_CHANNEL_ID).setMediaDescriptionAdapter(AudioMediaDescriptionAdapter()).build().apply {
            this.setUseStopAction(true)
            setPlayer(exoPlayer)
        }
    }

    private fun checkFile() = currentMediaSource ?: throw MissingFileIdException()

    inner class AudioServiceBinder : Binder() {
        fun getService(): AudioService = this@AudioService
    }

    private inner class AudioMediaDescriptionAdapter : PlayerNotificationManager.MediaDescriptionAdapter {

        override fun getCurrentContentTitle(player: Player): String {
            return getTags(player)?.title ?: ""
        }

        override fun createCurrentContentIntent(player: Player): PendingIntent? {

            val intent = Intent(activity, activity!!.javaClass).apply {
                action = Intent.ACTION_MAIN
                addCategory(Intent.CATEGORY_LAUNCHER)
            }

            var intentFlagType = PendingIntent.FLAG_ONE_SHOT
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                intentFlagType =
                    PendingIntent.FLAG_IMMUTABLE // or only use FLAG_MUTABLE >> if it needs to be used with inline replies or bubbles.
            }

            return PendingIntent.getActivity(activity, 0, intent, intentFlagType)
        }

        override fun getCurrentContentText(player: Player): String {
            return getTags(player)?.description ?: ""
        }

        override fun getCurrentLargeIcon(player: Player, callback: PlayerNotificationManager.BitmapCallback): Bitmap? {
            val url = getTags(player)?.imageUri?.toURL()
            @Suppress("DEPRECATION")
            callback.onBitmap(BitmapRetriever().execute(url).get())
            return null
        }

        private fun getTags(player: Player): MediaTags? {
            return player.currentMediaItem!!.localConfiguration!!.tag as MediaTags?
        }
    }

    private inner class AudioNotificationListener : PlayerNotificationManager.NotificationListener {
        override fun onNotificationPosted(notificationId: Int, notification: Notification, ongoing: Boolean) {
            this@AudioService.startForeground(notificationId, notification)
        }
    }

    private inner class AudioActionReceiver : PlayerNotificationManager.CustomActionReceiver {

        override fun createCustomActions(
            context: Context,
            instanceId: Int
        ): MutableMap<String, NotificationCompat.Action> {

            val intent: Intent = Intent("close").setPackage(context.packageName)
            val pendingIntent = PendingIntent.getBroadcast(context, instanceId, intent, PendingIntent.FLAG_CANCEL_CURRENT)
            val closeAction: NotificationCompat.Action = NotificationCompat.Action(
                    android.R.drawable.ic_notification_clear_all, "close", pendingIntent
            )

            return mutableMapOf("close" to closeAction)
        }

        override fun getCustomActions(player: Player): MutableList<String> = mutableListOf("close")

        override fun onCustomAction(player: Player, action: String, intent: Intent) {
            when (action) {
                "close" -> {
                    destroyPlayer()
                    EventBus.publish(AudioNotificationCloseEvent())
                }
            }
        }
    }

    private data class MediaTags(val title: String, val description: String, val imageUri: URI?)

    @Suppress("DEPRECATION")
    private class BitmapRetriever : AsyncTask<URL, Boolean, Bitmap>() {

        companion object {
            val cache = mutableMapOf<String, Bitmap>()
        }

        override fun doInBackground(vararg urls: URL?): Bitmap? {
            if (urls.isEmpty() || urls[0] == null) return null
            return try {

                var bitmap = cache[urls[0].toString()]
                if (bitmap == null) {
                    bitmap = BitmapFactory.decodeStream(urls[0]!!.openStream())
                    cache[urls[0].toString()] = bitmap
                }

                bitmap

            } catch (error: Exception) {
                System.err.println("Unable to retrieve media image")
                null
            }
        }
    }
}
