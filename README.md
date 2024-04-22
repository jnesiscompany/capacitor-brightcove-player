# Capacitor Brightcove Player

## About this plugin

This capacitor plugin allows you to play medias from Brightcove video cloud.

- Android and iOS support.
- Play fullscreen video.
- Play audio only media in background with lockscreen controls.
- Timed audio playback looping.
- Manage offline media (download, list, remove) and play them offline

## Getting started

### Installation

```shell
npm install capacitor-brightcove-player
npx cap sync ios|android
```

### Brightcove account infos

You need to provide your Brightcove account infos to the plugin, so
it can stream your media from the cloud.

- **Account ID**  
You can find it from Brightcove Studio.


- **Policy key**  
Brightcove Studio generates automatically a policy key for each player.  
Go to "Players" page, select a player and get the policy key from JSON editor.


- **Media ID**  
The media ID you want to play. Get it from your Brightcove media library.

### Basic usage

```typescript
import { Plugins } from '@capacitor/core';
import { BrightcovePlayerWeb, PlayerState } from 'capacitor-brightcove-player';

const { App } = Plugins;
const BrightcovePlayer = Plugins.BrightcovePlayer as BrightcovePlayerWeb;

...

// Provide your Brightcove account infos.
await BrightcovePlayer.updateBrightcoveAccount({
  accountId: 'Account ID as a string',
  policyKey: 'Policy key as a string'
});

// Exit video fullscreen on back button (Android only).
App.addListener('backButton', () => BrightcovePlayer.notifyBackButtonPressed());

// Play fullscreen video.
// position param is optional, if <= 0 or >= video duration, video will start from the beginning
// local param is optional (default = false). If true and the media is available, it will force the local playback, else if will stream it remotely if network is on
// subtitle param is optional. You can get the available subtitles with the getMetadata() method. 
await BrightcovePlayer.playVideo({ fileId: 'Media ID as a string', position: 42, local: true, subtitle: string });

// Play audio only.
// local param is optional (default = false). If true and the media is available, it will force the local playback, else if will stream it remotely if network is on
await BrightcovePlayer.loadAudio({ fileId: 'Media ID as a string', local: true });
await BrightcovePlayer.playAudio();
```

## API

### Types

```typescript
// Current video player position state
interface VideoPlayerState {
  // Current playback position in millis.
  currentMillis: number
  // Total media duration in millis.
  totalMillis: number
}

// State & informations when closed video event is called
export interface ClosedVideoPlayerState extends VideoPlayerState {
    // Video fully watched
    completed: boolean,
    // Selected subtitle
    subtitle: string
}

export enum AudioPlayerStatus {
    NONE = "NONE",
    ERROR = "ERROR",
    LOADING = "LOADING",
    LOADED = "LOADED",
    RUNNING = "RUNNING",
    PAUSED = "PAUSED",
    STOPPED = "STOPPED",
    ENDED = "ENDED"
}

// Current audio player state.
interface AudioPlayerState {
    // The actual state.
    state: AudioPlayerStatus,
    // Current playback position in millis.
    currentMillis?: number
    // Total media duration in millis.
    totalMillis?: number,
    // Error message if a playback error occured.
    error?: string,
    // Remainning looping time if looping is enabled.
    remainingTime?: number
}

// Native audio notification customization options.
interface AudioNotificationOptions {
    // Forward button time amount in millis.
    forwardIncrementMs?: number;
    // Backward button time amount in millis.
    rewindIncrementMs?: number;
}

export enum DownloadStatus {
    REQUESTED = "REQUESTED",
    IN_PROGRESS = "IN_PROGRESS",
    PAUSED = "PAUSED",
    CANCELED = "CANCELED",
    COMPLETED =  "COMPLETED",
    DELETED = "DELETED",
    FAILED = "FAILED"
}

// Downloading/downloaded media info
interface DownloadStateMediaInfo {
    mediaId: string // id of the media
    status: DownloadStatus,
    estimatedSize?: number, //gotten when download starts (in bytes)
    maxSize?: number, //size of the media to download (in bytes)
    downloadedBytes?: number, //downloaded bytes of the media
    progress?: number, // download progress in percent
    reason?: string // reason code when media is paused or on error,
    title?: string, // title of the media
}

// Media main metadata
export interface MediaMetaData {
  mediaId: string,
  // title of the video
  title: string,
  // total length of the media is in millis
  totalMillis: number,
  // thumbnail of the media (low resolution image)
  thumbnail: string, // only if available
  // thumbnail of the media (high resolution image)
  posterUrl: string, // only if available
  // check if the media is already downloaded
  downloaded: boolean, 
  // display the real size of the media if downloaded, or the estimate size of the media if not
  fileSize: number // in bytes
  // return an array with all available subtitles
  subtitles: Array<Subtitle> 
}

export interface Subtitle {
    language: string;
    src: string;
}
```

### Functions

```typescript
// Move audio playback backward by the specified amount in millis.
backwardAudio(options: {amount?: number }): Promise<void>;

// Free all native audio resources.
destroyAudioPlayer(): Promise<void>;

// Disable audio looping playback.
disableAudioLooping(): Promise<void>;

// Enable audio looping.
// Automatically disable looping and stop playback after the specified time.
// Do not specify time to enable infinite looping.
enableAudioLooping(options?: { time: number }): Promise<void>;

// Move audio playback forward by the specified amount in millis.
forwardAudio(options: { amount?: number }): Promise<void>;

// Get current audio player state. PlaybackState is described above.
getAudioPlayerState(): Promise<AudioPlayerState>;

// Returns value=true when audio looping is enabled.
isAudioLooping(): Promise<{ value: boolean }>;

// Load audio player with specified media ID.
// Returns file name and total duration.
loadAudio(options: { fileId: string }): Promise<{ name?: string, duration?: number }>;

// Notify plugin that native back button has been pressed (Android only).
notifyBackButtonPressed(): Promise<void>;

// Pause audio playback. 
pauseAudio(): Promise<void>;

// Start audio playback.
playAudio(): Promise<void>;

// Get main metadata of a file
getMetadata(options: { fileId: string }) : Promise<{metadata: MediaMetaData}>

// Load video player with specified media ID and start playing immediately
// If *position* (in milliseconds) is passed, video will start at this position
// If a non-existant subtitle is passed as a parameter, no subtitle will be displayed
// If this method is called when the player is already open, the video resumes
// Returns file name and total duration.
playVideo(options: { fileId?: string, position?: number, subtitle?: string }): Promise<{ name: string, duration: number }>;

// Pause the video from the javascript context. Can be called with a setTimeout for instance
pauseVideo(): Promise<void>;

// Close the video from the javascript context. Can be called with a setTimeout for instance
closeVideo(): Promise<void>;

// Move playback to specified position.
// Move to end or start if duration is out of bound.
seekToAudio(options: { position: number }): Promise<void>;

// Set audio native notification options. AudioNotificationOptions is described above.
setAudioNotificationOptions(options: AudioNotificationOptions): Promise<void>;

// Stop and reset audio playback for current media. If you want to pause playback use pauseAudio.
stopAudio(): Promise<void>;

// Set Brightcove account infos.
// Playing a media without providing account infos generates an error.
updateBrightcoveAccount(options: { accountId: string, policyKey: string }): Promise<void>;


// Set Brightcove android notifications : Android only
// Allows you to enable or disable notifications when downloading media with Android. 
// If false is passed, start, end and failed download notifications are no longer displayed
setDownloadNotifications(options: { enabled: boolean}): Promise<void>;

// Download a media by its id
// This will download the main track and any other secondary audio tracks and subtitles
downloadMedia(options: { fileId: string }): Promise<void>;

// Check if media is available locally
// If the download had started but was paused due to lost of connection for example
// it will automatically restart when calling this method
isMediaAvailableLocally(options: { fileId: string}): Promise<{value: boolean}>
    
// iOS only as for v0.0.16, Android is a WIP
// Plays an audio file recorded in the device
playInternalAudio(options: {file: string}): Promise<void>;

// Get the list of downloaded media and their status
getDownloadedMediasState(): Promise<{state: Array<DownloadStateMediaInfo>}>
    
// Delete a downloaded media
deleteDownloadedMedia(options: { fileId: string}): Promise<void>
    
deleteAllDownloadedMedias(): Promise<void>

```

### Events

You can listen to player plugin events using _addListener_ method.

```typescript
BrightcovePlayer.addListener('audioStateChange', (playback: AudioPlayerState) => {
  // Do something.
});
```

#### audioStateChange
Notify listeners when a player state change occurs.

_Payload_: AudioPlayerState

#### audioPositionChange
Notify listeners every second when player state is _RUNNING_.

_Payload_: AudioPlayerState

#### audioNotificationClose
Notify listeners when the user closes the player notification (**android only**)

#### videoPositionChange
Notify listeners every second **on android** and several times per second **on iOS** while the video is playing

_Payload_: VideoPlayerPositionState

#### closeVideo
Notify listeners when the fullscreen video is closed
```typescript
BrightcovePlayer.addListener('closeVideo', (state: ClosedVideoPlayerState) => {
  console.log('Video has ended : ', state.completed);
  console.log('Position when player was closed : ', state.currentMillis);
  console.log('Total length of the video : ', state.currentMillis);
  console.log('Subtitle language selected when player was closed : ', state.subtitle);
})

_Payload_: ClosedVideoPlayerState
```

#### donwloadStateChange
Fired everytime the downloading state of medias changes, and several times during the actual download to get the progress updated

See API for DownloadState and DownloadStateMediaInfo

### Error management

When plugin error occurs, promise is rejected with a object with the error desctiption and the error code (see the errors list at the end of this readme).
```typescript
try {
  await BrightcovePlayer.playAudio();
} catch (error: {message: string, code: string}) {
  alert(`Error code: ${error.code}, error message: ${error.message}`);
}
```

Here are available error codes:

|Error codes|Meaning|
|---|---|
|NOT_IMPLEMENTED|Feature is not implemented for this platform.|
|MISSING_POLICYKEY|Brightcove account policy key is not provided.|
|MISSING_ACCOUNTID|Brightcove account ID is not provided.|
|MISSING_FILEID|Media ID not provided, or no audio file loaded.|
|MISSING_SOURCE_URL|Media is found but returned URL is not valid.|
|FILE_NOT_EXIST_AND_NO_INTERNET|The file is not available locally, and no internet connection is available.|
|NO_INTERNET_CONNECTION|When calling loadAudio or playVideo without the param local=true without network
|FILE_NOT_EXIST| When calling play playInternalAudio with a non-existent audio file
|MISSING_FILE_PARAMETER| When calling play playInternalAudio, file parameter is not provided
|NO_INTERNET_CONNECTION|When calling loadAudio or playVideo without the param local=true without network.|
|VIDEO_CANT_BE_DOWNLOADED|When you try to download a brightcove media that is not downloadable (iOS only).|
|DOWNLOADED_FILE_NOT_FOUND|When you try to delete a media that is not present in the list of downloads.|
|UNKNOWN_REASON|Something failed but the native SDK didn't provide any reason.|
|TECHNICAL_ERRROR|This error is an error not captured by the others plugin errors. In this case, the error stacktrace is also returned|


