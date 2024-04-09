package com.jnesis.capacitor.brightcoveplayer.manager

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Context.NOTIFICATION_SERVICE
import android.net.Uri
import android.os.Build
import android.util.Log
import android.util.Pair
import androidx.annotation.RequiresApi
import com.brightcove.player.captioning.BrightcoveCaptionFormat
import com.brightcove.player.edge.CatalogError
import com.brightcove.player.edge.OfflineCallback
import com.brightcove.player.edge.OfflineCatalog
import com.brightcove.player.edge.VideoListener
import com.brightcove.player.event.EventEmitterImpl
import com.brightcove.player.model.Video
import com.brightcove.player.network.ConnectivityMonitor
import com.brightcove.player.network.DownloadManager
import com.brightcove.player.network.DownloadStatus
import com.brightcove.player.offline.MediaDownloadable
import com.brightcove.player.offline.MediaDownloadable.MediaFormatListener
import com.getcapacitor.JSObject
import com.getcapacitor.PluginCall
import com.google.gson.Gson
import com.jnesis.capacitor.brightcoveplayer.events.DownloadStateChangeEvent
import com.jnesis.capacitor.brightcoveplayer.events.EventBus
import com.jnesis.capacitor.brightcoveplayer.exception.MissingAccountIdException
import com.jnesis.capacitor.brightcoveplayer.exception.PluginException
import com.jnesis.capacitor.brightcoveplayer.model.DownloadStateMediaInfo
import com.jnesis.capacitor.brightcoveplayer.utils.BrightcoveDownloadUtil
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import org.json.JSONArray
import java.io.Serializable
import kotlin.streams.toList


object CatalogManager {

    private lateinit var connectivityMonitor: ConnectivityMonitor


    var brightcoveCatalog: OfflineCatalog? = null
    var defaultSubtitleLanguage: String? = null
    var displayDownloadNotification: Boolean? = true

    /**
     * Make sure to pass the appContext here to avoid memory leaks due to keeping the catalog as a static field
     * in the case of the context passed is an activity
     */
    fun initCatalog(context: Context, accountId: String, policyKey: String) {
        connectivityMonitor = ConnectivityMonitor.getInstance(context)

        brightcoveCatalog = OfflineCatalog
                .Builder(context, EventEmitterImpl(), accountId)
                .setPolicy(policyKey)
                .setBaseURL("https://edge.api.brightcove.com/playback/v1")
                .build()
                .apply {
                    isMobileDownloadAllowed = true
                    isRoamingDownloadAllowed = true
                    isMeteredDownloadAllowed = true
                    addDownloadEventListener(object : MediaDownloadable.DownloadEventListener {
                        override fun onDownloadRequested(video: Video) {
                            Log.v("Brightcove plugin", "Media download: onDownloadRequested")
                            cancelNotification(context)
                            updateDownloadState(DownloadStateMediaInfo(video.id, DownloadStateMediaInfo.Status.REQUESTED))
                        }

                        override fun onDownloadStarted(video: Video, estimatedSize: Long, mediaProperties: MutableMap<String, Serializable>) {
                            Log.v("Brightcove plugin", "Media download: onDownloadStarted")
                            cancelNotification(context)
                            updateDownloadState(DownloadStateMediaInfo(video.id, DownloadStateMediaInfo.Status.IN_PROGRESS, estimatedSize))
                        }

                        override fun onDownloadProgress(video: Video, status: DownloadStatus) {
                            Log.v("Brightcove plugin", "Media download: onDownloadProgress")
                            updateDownloadState(
                                    DownloadStateMediaInfo(video.id, DownloadStateMediaInfo.Status.IN_PROGRESS),
                                    status
                            )
                        }

                        override fun onDownloadPaused(video: Video, status: DownloadStatus) {
                            Log.v("Brightcove plugin", "Media download: onDownloadPaused")
                            cancelNotification(context)
                            updateDownloadState(
                                    DownloadStateMediaInfo(video.id, DownloadStateMediaInfo.Status.PAUSED),
                                    status
                            )
                        }

                        override fun onDownloadCompleted(video: Video, status: DownloadStatus) {
                            Log.v("Brightcove plugin", "Media download: onDownloadCompleted")
                            cancelNotification(context)
                            updateDownloadState(DownloadStateMediaInfo(video.id, DownloadStateMediaInfo.Status.COMPLETED), status)
                        }

                        override fun onDownloadCanceled(video: Video) {
                            Log.v("Brightcove plugin", "Media download: onDownloadCanceled")
                            cancelNotification(context)
                            updateDownloadState(DownloadStateMediaInfo(video.id, DownloadStateMediaInfo.Status.CANCELED))
                        }

                        override fun onDownloadDeleted(video: Video) {
                            Log.v("Brightcove plugin", "Media download: onDownloadDeleted")
                            cancelNotification(context)
                            updateDownloadState(DownloadStateMediaInfo(video.id, DownloadStateMediaInfo.Status.DELETED))
                        }

                        override fun onDownloadFailed(video: Video, status: DownloadStatus) {
                            Log.v("Brightcove plugin", "Media download: onDownloadFailed")
                            cancelNotification(context)
                            updateDownloadState(DownloadStateMediaInfo(video.id, DownloadStateMediaInfo.Status.FAILED), status)
                        }

                    })
                }
    }

    fun setDownloadNotifications(context: Context, downloadNotifications: Boolean) {
        this.displayDownloadNotification = downloadNotifications
        val availableSetNotificationChannel = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O

        if(!downloadNotifications && availableSetNotificationChannel) {
            val downloadManager: DownloadManager = DownloadManager.getInstance(context)
            val notificationChannel = NotificationChannel(
                "hidden",
                "hidden",
                NotificationManager.IMPORTANCE_NONE
            )

            downloadManager.setNotificationChannel(notificationChannel)
        }
    }

    private fun cancelNotification(context: Context) {
        val availableSetNotificationChannel = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O

        if(this.displayDownloadNotification != true && !availableSetNotificationChannel) {
            val notificationManager = context.getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancelAll()
        }
    }

    fun checkCredentials() = brightcoveCatalog ?: throw MissingAccountIdException()

    fun checkLocalMedia(call: PluginCall) {
        val mediaId = call.getString("fileId")!!
        checkCredentials()
        brightcoveCatalog?.getVideoDownloadStatus(mediaId, object : OfflineCallback<DownloadStatus> {
            override fun onSuccess(downloadStatus: DownloadStatus?) {
                call.resolve(JSObject("{\"value\": ${(downloadStatus?.code == DownloadStatus.STATUS_COMPLETE)} }"))
            }

            override fun onFailure(t: Throwable?) {
                call.reject(t?.localizedMessage, PluginException.ErrorCode.TECHNICAL_ERROR.name, Exception(t))
            }

        })
    }

    fun getMetadata(call: PluginCall) {
        val mediaId = call.getString("fileId")!!

        tryToLoadLocallyOrFetchRemotely(mediaId, call) { video: Video?, local: Boolean ->
            if (video == null) {
                call.reject("File not found in the brightcove catalog (fileId:$mediaId)", PluginException.ErrorCode.MEDIA_NOT_FOUND.name)
            } else {
                brightcoveCatalog?.estimateSize(video) { bytes ->
                    call.resolve(this.buildMetadataJSON(video, local, bytes));
                }
            }
        }
    }

    private fun buildMetadataJSON(video: Video?, local: Boolean, fileSize: Long?): JSObject {
        val metadata = JSObject()

        metadata.put("mediaId", video?.id)
        metadata.put("title", video?.name)
        metadata.put("totalMillis", video?.durationLong)
        metadata.put("thumbnail", video?.properties?.get("thumbnail"))
        metadata.put("posterUrl", video?.posterImage)
        metadata.put("downloaded", local)
        metadata.put("fileSize", fileSize)
        metadata.put("subtitles", JSONArray(this.getSubtitles(video)))

        return JSObject().put("metadata", metadata)
    }

    private fun getSubtitles(video: Video?): ArrayList<JSObject> {
        val subtitles = arrayListOf<JSObject>()
        val captionSources = video?.properties?.get(Video.Fields.CAPTION_SOURCES)
        @Suppress("UNCHECKED_CAST")
        for (p in captionSources as List<Pair<Uri, BrightcoveCaptionFormat>>) {
            val sub = JSObject()
            sub.put("language", p.second.language())
            sub.put("src", p.first)
            subtitles.add(sub)
        }

        return subtitles
    }

    fun deleteAllLocalMedia(call: PluginCall) {
        checkCredentials()
        brightcoveCatalog?.findAllVideoDownload(
        DownloadStatus.STATUS_COMPLETE, object: OfflineCallback<List<Video>> {
            override fun onSuccess(videos: List<Video>) {
                videos.map { brightcoveCatalog?.deleteVideo(it.id) }
                    .toTypedArray()
                    .let{ call.resolve() }
            }

            override fun onFailure(t: Throwable?) {
                call.reject(t?.localizedMessage, PluginException.ErrorCode.TECHNICAL_ERROR.name, Exception(t))
            }
        });
    }

    fun deleteLocalMedia(call: PluginCall) {
        val mediaId = call.getString("fileId")!!

        checkCredentials()
        brightcoveCatalog?.deleteVideo(mediaId, object: OfflineCallback<Boolean> {

            override fun onSuccess(result: Boolean?) {
                if (result!!)
                    call.resolve()
                else
                    call.reject("Cannot delete downloaded media (mediaId: $mediaId)", PluginException.ErrorCode.UNKNOWN_REASON.name)
            }

            override fun onFailure(t: Throwable?) {
                call.reject(t?.localizedMessage, PluginException.ErrorCode.TECHNICAL_ERROR.name, Exception(t))
            }
        })
    }

    fun downloadMedia(pluginCall: PluginCall) {
        val mediaId = pluginCall.getString("fileId")!!
        checkCredentials()

        tryToLoadLocallyOrFetchRemotely(mediaId, pluginCall) { video: Video?, _: Boolean ->

            // bundle has all available captions and audio tracks
            brightcoveCatalog?.getMediaFormatTracksAvailable(video!!, MediaFormatListener { mediaDownloadable, bundle ->
                BrightcoveDownloadUtil.selectMediaFormatTracksAvailable(mediaDownloadable, bundle)
                brightcoveCatalog?.downloadVideo(video, object : OfflineCallback<DownloadStatus> {
                    override fun onSuccess(status: DownloadStatus) {
                        pluginCall.resolve()
                    }

                    override fun onFailure(t: Throwable?) {
                        pluginCall.reject(t?.localizedMessage, PluginException.ErrorCode.TECHNICAL_ERROR.name, Exception(t))
                    }

                })
            })
        }
    }

    @ExperimentalSerializationApi
    fun getDownloadedMediasState(call: PluginCall) {

        brightcoveCatalog?.findAllQueuedVideoDownload(object : OfflineCallback<List<Video>> {

            @RequiresApi(Build.VERSION_CODES.N)
            override fun onSuccess(videos: List<Video>?) {
                videos!!
                    .stream()
                    .map { video ->
                        DownloadStateMediaInfo(
                            mediaId = video.id,
                            title = video.name,
                            estimatedSize = brightcoveCatalog?.estimateSize(video),
                            status = brightcoveStatusToPluginStatus(
                                brightcoveCatalog!!.getVideoDownloadStatus(video)
                            )
                        )
                    }
                    .toList()
                    .let(Json::encodeToString)
                    .also { Log.v("Downloaded medias", it) }
                    .let { JSObject().put("medias", it) }
                    .let(call::resolve)
            }

            override fun onFailure(t: Throwable?) {
                call.reject(t?.localizedMessage, PluginException.ErrorCode.TECHNICAL_ERROR.name, Exception(t));
            }
        })
    }

    fun tryToLoadLocallyOrFetchRemotely(mediaId: String, pluginCall: PluginCall, callback: ((video: Video?, local: Boolean) -> Unit)) {
        brightcoveCatalog?.findOfflineVideoById(mediaId, object : OfflineCallback<Video> {
            override fun onSuccess(video: Video?) {
                if (video == null) {
                    return fetchRemoteMedia(mediaId, pluginCall, callback)
                }

                callback.invoke(video, true)
            }

            override fun onFailure(throwable: Throwable) {
                fetchRemoteMedia(mediaId, pluginCall, callback)
            }
        })
    }

    fun fetchRemoteMedia(
        mediaId: String,
        pluginCall: PluginCall,
        callback: (video: Video?, local: Boolean) -> Unit
    ) {
        if (!connectivityMonitor.isConnected) {
            return pluginCall.reject("FetchRemoveMedia: Need internet connection to do this action", PluginException.ErrorCode.NO_INTERNET_CONNECTION.name)
        }
        brightcoveCatalog?.findVideoByID(mediaId, object : VideoListener() {

            override fun onVideo(video: Video?) {
                callback.invoke(video, false)
            }

            override fun onError(errors: MutableList<CatalogError>) {
                var errorCode = PluginException.ErrorCode.TECHNICAL_ERROR.name
                // We take the first relevant error code
                if(errors?.get(0)?.catalogErrorCode !== null){
                    errorCode = errors[0].catalogErrorCode
                }
                pluginCall.reject(errors.joinToString(
                        separator = "\n",
                        transform = { error -> error.toString() }
                ), errorCode)
            }
        })
    }

    private fun updateDownloadState(downloadStateMediaInfo: DownloadStateMediaInfo, status: DownloadStatus? = null) {
        var downloadInfo = downloadStateMediaInfo

        if (status != null) {
            downloadInfo = downloadStateMediaInfo.copy(
                    downloadStateMediaInfo.mediaId,
                    downloadStateMediaInfo.status,
                    status.estimatedSize,
                    status.maxSize,
                    status.bytesDownloaded,
                    status.progress,
                    BrightcoveDownloadUtil.toReasonMessage(status.reason)
            )
        }

        EventBus.publish(
            DownloadStateChangeEvent(
                JSObject(
                    Gson().toJson(
                    downloadInfo
                    )
                )
            )
        )
    }

    private fun brightcoveStatusToPluginStatus(status: DownloadStatus): DownloadStateMediaInfo.Status {

        return when (status.code) {

            DownloadStatus.STATUS_PAUSED
            -> DownloadStateMediaInfo.Status.PAUSED

            DownloadStatus.STATUS_DELETING
            -> DownloadStateMediaInfo.Status.DELETED

            DownloadStatus.STATUS_CANCELLING,
            -> DownloadStateMediaInfo.Status.CANCELED

            DownloadStatus.STATUS_QUEUEING,
            DownloadStatus.STATUS_NOT_QUEUED,
            -> DownloadStateMediaInfo.Status.REQUESTED

            DownloadStatus.STATUS_PENDING,
            DownloadStatus.STATUS_DOWNLOADING,
            DownloadStatus.STATUS_RETRY
            -> DownloadStateMediaInfo.Status.IN_PROGRESS

            DownloadStatus.STATUS_COMPLETE
            -> DownloadStateMediaInfo.Status.COMPLETED

            else -> DownloadStateMediaInfo.Status.FAILED
        }
    }
}
