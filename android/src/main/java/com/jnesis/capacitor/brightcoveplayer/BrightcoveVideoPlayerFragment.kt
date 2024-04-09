package com.jnesis.capacitor.brightcoveplayer

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageButton
import android.widget.LinearLayout
import com.brightcove.player.appcompat.BrightcovePlayerFragment
import com.brightcove.player.event.Event
import com.brightcove.player.event.EventType
import com.brightcove.player.mediacontroller.BrightcoveMediaController
import com.brightcove.player.mediacontroller.ShowHideController
import com.brightcove.player.model.Video
import com.brightcove.player.view.BrightcoveExoPlayerVideoView
import com.brightcove.player.captioning.BrightcoveCaptionFormat
import com.getcapacitor.JSObject
import com.getcapacitor.PluginCall
import com.google.gson.Gson
import com.jnesis.capacitor.brightcoveplayer.capacitorbrightcoveplayer.R
import com.jnesis.capacitor.brightcoveplayer.events.EventBus
import com.jnesis.capacitor.brightcoveplayer.events.VideoPlayerCloseEvent
import com.jnesis.capacitor.brightcoveplayer.events.VideoPlayerProgressEvent
import com.jnesis.capacitor.brightcoveplayer.exception.PluginException
import com.jnesis.capacitor.brightcoveplayer.manager.CatalogManager
import com.jnesis.capacitor.brightcoveplayer.model.VideoPlaybackState
import com.jnesis.capacitor.brightcoveplayer.utils.OnSwipeTouchListener
import io.reactivex.Observable
import io.reactivex.subjects.PublishSubject
import java.util.concurrent.TimeUnit

class BrightcoveVideoPlayerFragment() : BrightcovePlayerFragment() {

    private var unsubscribe: PublishSubject<Any> = PublishSubject.create()
    var videoId: String? = null
    var selectedSubtitle: String = ""
    lateinit var pluginCall: PluginCall;

    constructor(pluginCall: PluginCall) : this() {
        this.pluginCall = pluginCall;
    }

    companion object {
        val DEFAULT_SEEK_TIME = TimeUnit.SECONDS.toMillis(15).toInt()
    }

    //private val FONT_AWESOME = "fontawesome-webfont.ttf" //This TTF font is included in the Brightcove SDK.

    override fun onCreateView(
            inflater: LayoutInflater,
            container: ViewGroup?,
            savedInstanceState: Bundle?
    ): View? {
        val fragmentView = inflater.inflate(R.layout.fragment_brightcove_video_player, container, false)

        addTouchListenerOnLayout(fragmentView)

        baseVideoView = fragmentView.findViewById<BrightcoveExoPlayerVideoView>(R.id.brightcove_video_view)

        this.initMediaController()

        super.onCreateView(inflater, container, savedInstanceState)

        if (CatalogManager.brightcoveCatalog == null) {
            return fragmentView
        }

        this.videoId = pluginCall.getString("fileId")!!

        val callback = { video: Video?, _: Boolean ->
            try {
                playVideo(video)
                pluginCall.resolve(JSObject()
                        .put("name", video?.name)
                        .put("duration", video?.durationLong)
                )
            } catch (t: Throwable) {
                pluginCall.reject(t.localizedMessage, PluginException.ErrorCode.TECHNICAL_ERROR.name , Exception(t))
            }
        }

        try {
            if (pluginCall.getBoolean("local", false)!!) {
                CatalogManager.tryToLoadLocallyOrFetchRemotely(this.videoId!!, pluginCall, callback)
            } else {
                CatalogManager.fetchRemoteMedia(this.videoId!!, pluginCall, callback)
            }

        } catch (t: Throwable) {
            pluginCall.reject(t.localizedMessage, PluginException.ErrorCode.TECHNICAL_ERROR.name , Exception(t))
        }

        return fragmentView
    }

    private fun initMediaController() {
        baseVideoView.setMediaController(BrightcoveMediaController(baseVideoView, R.layout.default_media_controller))

        // Configure rewind and fast-forward buttons
        val properties: MutableMap<String, Any> = HashMap()

        properties[Event.SEEK_DEFAULT_LONG] = DEFAULT_SEEK_TIME
        properties[Event.SEEK_RELATIVE_ENABLED] = false
        baseVideoView.eventEmitter.emit(EventType.SEEK_CONTROLLER_CONFIGURATION, properties)

        // Fullscreen auto
        baseVideoView.eventEmitter.emit(EventType.ENTER_FULL_SCREEN)
        baseVideoView.eventEmitter.on(EventType.EXIT_FULL_SCREEN) {
            closeVideo(false)
        }

        // Close button
        baseVideoView.findViewById<ImageButton>(R.id.button_close).apply {

            setOnClickListener { closeVideo(false) }
            visibility = View.INVISIBLE

            baseVideoView.eventEmitter.on(ShowHideController.DID_SHOW_MEDIA_CONTROLS) {
                visibility = View.VISIBLE
            }

            baseVideoView.eventEmitter.on(ShowHideController.DID_HIDE_MEDIA_CONTROLS) {
                visibility = View.INVISIBLE
            }
        }
    }

    private fun playVideo(video: Video?) {
        val subtitle = pluginCall.getString("subtitle","")!!

        if(subtitle.isNotEmpty()) {
            baseVideoView.eventEmitter.once(EventType.CAPTIONS_LANGUAGES) {
                baseVideoView.setClosedCaptioningEnabled(true)
                baseVideoView.setSubtitleLocale(subtitle)
                this.selectedSubtitle = subtitle
            }
        }

        baseVideoView.add(video)
        baseVideoView.start()

        baseVideoView.eventEmitter.on(EventType.VIDEO_DURATION_CHANGED) {

            val duration = video?.durationLong
            val ret = JSObject()
            ret.put("name", video?.name)
            ret.put("duration", duration)

            val position = pluginCall.getInt("position", -1)!!

            if (position in 1 until duration!!) {
                baseVideoView.seekTo(position.toLong())
            }

            pluginCall.resolve(ret)
        }

        baseVideoView.eventEmitter.on(EventType.PLAY) {
            initPositionTimer()
        }

        baseVideoView.eventEmitter.on(EventType.COMPLETED) {
            closeVideo(true)
        }

        baseVideoView.eventEmitter.on(EventType.SELECT_CLOSED_CAPTION_TRACK) { e ->
            val captionFormat = e.properties[Event.CAPTION_FORMAT] as BrightcoveCaptionFormat?
            if (captionFormat != null) {
              this.selectedSubtitle = captionFormat.language() as String
            }
        }

        baseVideoView.eventEmitter.on(EventType.TOGGLE_CLOSED_CAPTIONS) { e ->
            val captionsToggledOn = e.properties[Event.BOOLEAN] as Boolean
            if (!captionsToggledOn) {
                this.selectedSubtitle = ""
            }
        }
    }

    private fun initPositionTimer() {
        Observable
                .interval(1000, TimeUnit.MILLISECONDS)
                .takeUntil(unsubscribe)
                .filter { baseVideoView.isPlaying }
                .subscribe {
                    emitPositionEvent()
                }
    }

    private fun emitPositionEvent() {
        EventBus.publish(
                VideoPlayerProgressEvent(
                        JSObject(Gson().toJson(
                                VideoPlaybackState(baseVideoView.currentPositionLong, baseVideoView.durationLong))
                        )
                )
        )
    }

    fun closeVideo(completed: Boolean) {
        this.videoId = null
        val position = baseVideoView.currentPositionLong
        val subtitle = this.selectedSubtitle
        emitPositionEvent()
        unsubscribe.onNext(Any())
        unsubscribe.onComplete()
        requireActivity().supportFragmentManager.popBackStack()
        EventBus.publish(VideoPlayerCloseEvent(JSObject(Gson().toJson(mapOf("completed" to completed, "currentMillis" to position, "subtitle" to subtitle)))))
    }

    private fun addTouchListenerOnLayout(fragmentView: View) {
        val fragmentLayout = fragmentView.findViewById<LinearLayout>(R.id.player_fragment_layout)

        fragmentLayout.setOnTouchListener(object : OnSwipeTouchListener(requireActivity().applicationContext) {
            override fun onSwipeDown() {
                closeVideo(false)
            }
        })
    }
}
