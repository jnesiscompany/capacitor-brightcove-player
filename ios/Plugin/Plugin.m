#import <Foundation/Foundation.h>
#import <Capacitor/Capacitor.h>

// Define the plugin using the CAP_PLUGIN Macro, and
// each method the plugin supports using the CAP_PLUGIN_METHOD macro.
CAP_PLUGIN(BrightcovePlayer, "BrightcovePlayer",
           CAP_PLUGIN_METHOD(updateBrightcoveAccount, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(getMetadata, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(playVideo, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(pauseVideo, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(closeVideo, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(setSubtitleLanguage, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(loadAudio, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(destroyAudioPlayer, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(playAudio, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(stopAudio, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(pauseAudio, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(backwardAudio, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(forwardAudio, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(seekToAudio, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(enableAudioLooping, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(disableAudioLooping, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(isAudioLooping, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(setAudioNotificationOptions, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(getDownloadedFiles, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(removeDownloadedFile, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(notifyBackButtonPressed, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(getAudioPlayerState, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(downloadMedia, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(isMediaAvailableLocally, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(playInternalAudio, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(getDownloadedMediasState, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(deleteDownloadedMedia, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(deleteAllDownloadedMedias, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(setDownloadNotifications, CAPPluginReturnPromise);
)

