package com.jnesis.capacitor.brightcoveplayer

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.Build
import android.util.Log
import android.os.IBinder
import androidx.annotation.RequiresApi
import androidx.fragment.app.FragmentTransaction
import com.getcapacitor.*
import com.getcapacitor.annotation.CapacitorPlugin
import com.google.gson.Gson
import com.jnesis.capacitor.brightcoveplayer.capacitorbrightcoveplayer.R
import com.jnesis.capacitor.brightcoveplayer.events.*
import com.jnesis.capacitor.brightcoveplayer.exception.PluginException
import com.jnesis.capacitor.brightcoveplayer.manager.CatalogManager
import com.jnesis.capacitor.brightcoveplayer.service.AudioService
import com.jnesis.capacitor.brightcoveplayer.utils.AudioNotificationOptions
import io.reactivex.subjects.PublishSubject
import io.reactivex.subjects.Subject
import kotlinx.serialization.ExperimentalSerializationApi

@CapacitorPlugin
class BrightcovePlayer : Plugin() {

    private var brightcoveVideoPlayerFragment: BrightcoveVideoPlayerFragment? = null

    private var audioService: AudioService? = null
    private val audioServiceConnection = AudioServiceConnection()
    
    companion object {
        lateinit var NOTIFICATION_CHANNEL_ID: String
    }

    override fun load() {
        Log.v("Brightcove plugin", "Load capacitor brightcove plugin")

        NOTIFICATION_CHANNEL_ID = activity.resources.getString(R.string.notification_channel_id)

        // Create and retrieve audio service instance.
        Intent(activity, AudioService::class.java).also {
            activity.bindService(it, audioServiceConnection, Context.BIND_AUTO_CREATE)
        }

        listenToDownloadEvents()
        listenToAudioEvents()
        listenToVideoEvents()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            initNotificationChannel()
        }
    }

    private fun listenToAudioEvents() {
        EventBus.listen(AudioNotificationCloseEvent::class.java).subscribe {
            notifyListeners("audioNotificationClose", it.data)
        }
    }

    private fun listenToVideoEvents() {
        EventBus.listen(VideoPlayerProgressEvent::class.java).subscribe {
            notifyListeners("videoPositionChange", it.data)
        }

        EventBus.listen(VideoPlayerCloseEvent::class.java).subscribe {
            notifyListeners("closeVideo", it.data)
        }
    }

    private fun listenToDownloadEvents() {
        EventBus.listen(DownloadStateChangeEvent::class.java).subscribe {
            notifyListeners("downloadStateChange", it.data)
        }
    }

    override fun handleOnDestroy() = activity.unbindService(audioServiceConnection)

    @PluginMethod
    fun setAudioNotificationOptions(call: PluginCall) {
        Log.v("Brightcove plugin", "setAudioNotificationOptions")
        try {
            val options: JSObject = call.data
            AudioNotificationOptions.audioNotificationForwardIncrementMs = options.getLong("forwardIncrementMs")
            AudioNotificationOptions.audioNotificationRewindIncrementMs = options.getLong("rewindIncrementMs")
            call.resolve()
        } catch (t: Throwable) {
            call.reject(t.localizedMessage, PluginException.ErrorCode.TECHNICAL_ERROR.name, Exception(t))
        }
    }

    @PluginMethod
    fun loadAudio(call: PluginCall) {
        Log.v("Brightcove plugin", "loadAudio")
        activity.runOnUiThread {
            try {
                audioService!!.loadMedia(call)
            } catch (t: Throwable) {
                call.reject(t.localizedMessage, PluginException.ErrorCode.TECHNICAL_ERROR.name, Exception(t))
            }
        }
    }

    @PluginMethod
    fun destroyAudioPlayer(call: PluginCall) {
        Log.v("Brightcove plugin", "destroyAudioPlayer")
        activity.runOnUiThread {
            try {
                if (audioService != null) audioService!!.destroyPlayer()
                call.resolve()
            } catch (t: Throwable) {
                call.reject(t.localizedMessage, PluginException.ErrorCode.TECHNICAL_ERROR.name, Exception(t))
            }
        }
    }

    @PluginMethod
    fun playAudio(call: PluginCall) {
        Log.v("Brightcove plugin", "playAudio")
        activity.runOnUiThread {
            try {
                audioService!!.play()
                call.resolve()
            } catch (t: Throwable) {
                call.reject(t.localizedMessage, PluginException.ErrorCode.TECHNICAL_ERROR.name, Exception(t))
            }
        }
    }

    @PluginMethod
    fun pauseAudio(call: PluginCall) {
        Log.v("Brightcove plugin", "pauseAudio")
        activity.runOnUiThread {
            try {
                audioService!!.pause()
                call.resolve()
            } catch (t: Throwable) {
                call.reject(t.localizedMessage, PluginException.ErrorCode.TECHNICAL_ERROR.name, Exception(t))
            }
        }
    }

    @PluginMethod
    fun stopAudio(call: PluginCall) {
        Log.v("Brightcove plugin", "stopAudio")
        activity.runOnUiThread {
            try {
                audioService!!.stop()
                call.resolve()
            } catch (t: Throwable) {
                call.reject(t.localizedMessage, PluginException.ErrorCode.TECHNICAL_ERROR.name, Exception(t))
            }
        }
    }

    @PluginMethod
    fun seekToAudio(call: PluginCall) {
        Log.v("Brightcove plugin", "seekToAudio")
        activity.runOnUiThread {
            try {
                audioService!!.seekTo(call.getInt("position")!!.toLong())
                call.resolve()
            } catch (t: Throwable) {
                call.reject(t.localizedMessage, PluginException.ErrorCode.TECHNICAL_ERROR.name, Exception(t))
            }
        }
    }

    @PluginMethod
    fun backwardAudio(call: PluginCall) {
        Log.v("Brightcove plugin", "backwardAudio")
        activity.runOnUiThread {
            try {
                audioService!!.backward(call.getInt("amount")!!.toLong())
                call.resolve()
            } catch (t: Throwable) {
                call.reject(t.localizedMessage, PluginException.ErrorCode.TECHNICAL_ERROR.name, Exception(t))
            }
        }
    }

    @PluginMethod
    fun forwardAudio(call: PluginCall) {
        Log.v("Brightcove plugin", "forwardAudio")
        activity.runOnUiThread {
            try {
                audioService!!.forward(call.getInt("amount")!!.toLong())
                call.resolve()
            } catch (t: Throwable) {
                call.reject(t.localizedMessage, PluginException.ErrorCode.TECHNICAL_ERROR.name, Exception(t))
            }
        }
    }

    @PluginMethod
    fun getMetadata(call: PluginCall) {
        Log.v("Brightcove plugin", "getMetadata")
        activity.runOnUiThread {
            try {
                CatalogManager.getMetadata(call)
            } catch (t: Throwable) {
                call.reject(t.localizedMessage, PluginException.ErrorCode.TECHNICAL_ERROR.name, Exception(t))
            }
        }
    }

    @PluginMethod
    fun updateBrightcoveAccount(call: PluginCall) {
        Log.v("Brightcove plugin", "updateBrightcoveAccount")
        try {
            CatalogManager.initCatalog(activity.applicationContext, call.getString("accountId")!!, call.getString("policyKey")!!)
            call.resolve()
        } catch (t: Throwable) {
            call.reject(t.localizedMessage, PluginException.ErrorCode.TECHNICAL_ERROR.name,Exception(t))
        }
    }

    @PluginMethod
    fun enableAudioLooping(call: PluginCall) {
        Log.v("Brightcove plugin", "enableAudioLooping")
        activity!!.runOnUiThread {
            try {
                audioService!!.remainingTime = call.getInt("time")?.toLong()
                audioService!!.toggleLooping(true)
                call.resolve()
            } catch (t: Throwable) {
                call.reject(t.localizedMessage, PluginException.ErrorCode.TECHNICAL_ERROR.name, Exception(t))
            }
        }
    }

    @PluginMethod
    fun disableAudioLooping(call: PluginCall) {
        Log.v("Brightcove plugin", "disableAudioLooping")
        activity!!.runOnUiThread {
            try {
                audioService!!.toggleLooping(false)
                call.resolve()
            } catch (t: Throwable) {
                call.reject(t.localizedMessage, PluginException.ErrorCode.TECHNICAL_ERROR.name, Exception(t))
            }
        }
    }

    @PluginMethod
    fun isAudioLooping(call: PluginCall) {
        Log.v("Brightcove plugin", "isAudioLooping")
        activity.runOnUiThread {
            try {
                val looping = audioService!!.isLooping()
                call.resolve(JSObject("{\"value\": $looping}"))
            } catch (t: Throwable) {
                call.reject(t.localizedMessage, PluginException.ErrorCode.TECHNICAL_ERROR.name, Exception(t))
            }
        }
    }

    @PluginMethod
    fun getAudioPlayerState(call: PluginCall) {
        Log.v("Brightcove plugin", "getAudioPlayerState")
        activity!!.runOnUiThread {
            try {
                call.resolve(JSObject(Gson().toJson(audioService!!.getPlayerState())))
            } catch (t: Throwable) {
                call.reject(t.localizedMessage, PluginException.ErrorCode.TECHNICAL_ERROR.name, Exception(t))
            }
        }

    }

    @PluginMethod
    fun playVideo(call: PluginCall) {
        Log.v("Brightcove plugin", "playVideo")
        try {
            // Resume video
            if(call.getString("fileId") === null) {
                if(this.brightcoveVideoPlayerFragment !== null && this.brightcoveVideoPlayerFragment!!.videoId !== null) {
                    this.brightcoveVideoPlayerFragment?.baseVideoView?.start()
                }
                call.resolve()
            } else {
                this.createBrightcoveVideoPlayerFragment(call)
            }

        } catch (t: Throwable) {
            call.reject(t.localizedMessage, PluginException.ErrorCode.TECHNICAL_ERROR.name, Exception(t))
        }
    }

    @PluginMethod
    fun pauseVideo(call: PluginCall) {
        Log.v("Brightcove plugin", "pauseVideo")
        activity.runOnUiThread {
            try {
                this.brightcoveVideoPlayerFragment?.baseVideoView?.pause()
                call.resolve()
            } catch (t: Throwable) {
                call.reject(t.localizedMessage, PluginException.ErrorCode.TECHNICAL_ERROR.name, Exception(t))
            }
        }
    }

    @PluginMethod
    fun closeVideo(call: PluginCall) {
        Log.v("Brightcove plugin", "closeVideo")
        try {
            if (this.brightcoveVideoPlayerFragment != null) {
                this.brightcoveVideoPlayerFragment?.closeVideo(false)
            }
            call.resolve()
        } catch (t: Throwable) {
            call.reject(t.localizedMessage, PluginException.ErrorCode.TECHNICAL_ERROR.name, Exception(t))
        }
    }

    @PluginMethod
    fun setSubtitleLanguage(call: PluginCall) {
        Log.v("Brightcove plugin", "setSubtitleLanguage")
        try {
            CatalogManager.defaultSubtitleLanguage = call.getString("language")
            call.resolve()
        } catch (t: Throwable) {
            call.reject(t.localizedMessage, PluginException.ErrorCode.TECHNICAL_ERROR.name, Exception(t))
        }
    }

    /*
    Tried to use onBackPressedDispatcher to handle back button, but it seems to be handled only by BridgeActivity.onBackPressed function.
    Workaround is to notify back button press event through the capacitor plugin App and the ionic application :
    App.addListener('backButton', (data: any) => {
      BrightcovePlayer.notifyBackButtonPressed();
    });
     */
    @PluginMethod
    fun notifyBackButtonPressed(call: PluginCall) {
        Log.v("Brightcove plugin", "notifyBackButtonPressed")
        try {
            activity.supportFragmentManager.popBackStack()
            call.resolve()
        } catch (t: Throwable) {
            call.reject(t.localizedMessage, PluginException.ErrorCode.TECHNICAL_ERROR.name, Exception(t))
        }
    }
    
    @PluginMethod
    fun isMediaAvailableLocally(call: PluginCall) {
        Log.v("Brightcove plugin", "isMediaAvailableLocally")
        activity.runOnUiThread {
            try {
                CatalogManager.checkLocalMedia(call)
            } catch (t: Throwable) {
                call.reject(t.localizedMessage, PluginException.ErrorCode.TECHNICAL_ERROR.name, Exception(t))
            }
        }
    }

    @PluginMethod
    fun downloadMedia(call: PluginCall) {
        Log.v("Brightcove plugin", "downloadMedia")
        activity.runOnUiThread {
            try {
                CatalogManager.downloadMedia(call)
            } catch (t: Throwable) {
                call.reject(t.localizedMessage, PluginException.ErrorCode.TECHNICAL_ERROR.name, Exception(t))
            }
        }
    }

    @PluginMethod
    fun setDownloadNotifications(call: PluginCall) {
        Log.v("Brightcove plugin", "setDownloadNotifications")
        try {
            CatalogManager.setDownloadNotifications(activity.applicationContext, call.getBoolean("enabled", true)!!)

            call.resolve()
        } catch (t: Throwable) {
            call.reject(t.localizedMessage, PluginException.ErrorCode.TECHNICAL_ERROR.name, Exception(t))
        }
    }

    @PluginMethod
    fun deleteAllDownloadedMedias(call: PluginCall) {
        Log.v("Brightcove plugin", "deleteAllDownloadedMedias")
        activity.runOnUiThread {
            try {
                CatalogManager.deleteAllLocalMedia(call)
            } catch (t: Throwable) {
                call.reject(t.localizedMessage, PluginException.ErrorCode.TECHNICAL_ERROR.name, Exception(t))
            }
        }
    }

    @PluginMethod
    fun deleteDownloadedMedia(call: PluginCall) {
        Log.v("Brightcove plugin", "deleteDownloadedMedia")
        activity.runOnUiThread {
            try {
                CatalogManager.deleteLocalMedia(call)
            } catch (t: Throwable) {
                call.reject(t.localizedMessage, PluginException.ErrorCode.TECHNICAL_ERROR.name, Exception(t))
            }
        }
    }


    @ExperimentalSerializationApi
    @PluginMethod
    fun getDownloadedMediasState(call: PluginCall) {
        Log.v("Brightcove plugin", "getDownloadedMediasState")
        activity.runOnUiThread {
            try {
                CatalogManager.getDownloadedMediasState(call)
            } catch (t: Throwable) {
                call.reject(t.localizedMessage, PluginException.ErrorCode.TECHNICAL_ERROR.name, Exception(t))
            }
        }
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private fun initNotificationChannel() {
        Log.v("Brightcove plugin", "initNotificationChannel")
        val channel = NotificationChannel(NOTIFICATION_CHANNEL_ID, "Capacitor Brightcove Notification", NotificationManager.IMPORTANCE_DEFAULT)
        channel.setSound(null, null)
        channel.vibrationPattern = null
        val manager = activity.applicationContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        manager.createNotificationChannel(channel)
    }

    private fun createBrightcoveVideoPlayerFragment(pluginCall: PluginCall) {
        val brightcoveVideoPlayerFrag = BrightcoveVideoPlayerFragment(pluginCall)

        activity
                .supportFragmentManager
                .beginTransaction()
                .replace(R.id.webview, brightcoveVideoPlayerFrag, "brightCoveVideoFragment")
                .setTransition(FragmentTransaction.TRANSIT_FRAGMENT_OPEN)
                .addToBackStack(null)
                .commit()

        brightcoveVideoPlayerFragment = brightcoveVideoPlayerFrag
    }

    private inner class AudioServiceConnection : ServiceConnection {

        val unsubscribe: Subject<Any> = PublishSubject.create()

        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {

            audioService = (service as AudioService.AudioServiceBinder).getService().apply {

                activity = this@BrightcovePlayer.activity

                playbackState
                        .takeUntil(unsubscribe)
                        .subscribe {
                            playbackState -> notifyListeners("audioStateChange", JSObject(Gson().toJson(playbackState)))
                        }

                positionState
                        .takeUntil(unsubscribe)
                        .subscribe {
                            positionState -> notifyListeners("audioPositionChange", JSObject(Gson().toJson(positionState)))
                        }
            }
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            unsubscribe.onNext(Any())
            unsubscribe.onComplete()
            audioService!!.destroyPlayer()
            audioService = null
        }
    }
}
