# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [6.0.2] - 2024-03-11
### Changed
- [Android]  Upgrade brightcove SDK from 8.0.1 to 8.4.1
- [iOS]  Upgrade brightcove SDK from 6.12.0 to 6.12.7

## [6.0.1] - 2023-09-19
### Fixed
- [iOS] Force disable subtitles on videos if empty param 

## [6.0.0] - 2023-08-30
### Changed
- [iOS & Android] Update to Capacitor 5

## [5.2.1] - 2023-04-28
### Changed
- [Android] Update android sdk from 32 to 33

## [5.2.0] - 2023-04-12
### Changed
- [Android]  Upgrade brightcove SDK from 7.1.3 to 8.0.1
- [iOS]  Upgrade brightcove SDK from 6.11.0 to 6.12.0
### Fixed
- [Android] Fix inability to load 2 audios without calling the destroy method

## [5.1.2] - 2023-03-21
### Fixed
- [Android] Prevent an audio file from being paused when it is played directly after another audio file

## [5.1.1] - 2023-03-14
### Fixed
- [Android] Fix LOADED event sent multiple times for the same audio

## [5.1.0] - 2023-03-14
### Added
- [iOS] Added unit tests 
- [iOS] Remove DispatchGroup.wait from the plugin
- [iOS] Play videos using DispatchQueue.main.async

## [5.0.1] - 2023-03-06
### Fixed
- [iOS] Force close the video player if the video is fully viewed

### Changed
- [iOS] Send full error stack instead of the localized description

## [5.0.0] - 2023-02-27
### Changed
- [iOS & Android] Returns the SDK error key instead of TECHNICAL_ERROR if available.
- [iOS] Replace usage of DispatchGroup() and wait() when loading audio file

## [5.0.0-beta.2] - 2023-02-17
### Fixed
- [iOS] The video player does not close when it reaches the end of the track

## [5.0.0-beta.1] - 2023-02-14
### Added
- [iOS & Android] Refactored player events & interfaces

## [5.0.0-beta.0] - 2023-01-31
### Added
- [iOS & Android] Added LOADED & PAUSED events & removed READY_TO_PLAY on the audio player

## [4.3.0] - 2023-01-17
### Fixed
- [iOS] Throw TECHNICAL_ERROR error if playVideo with a wrong brightcove file id

## [4.2.9] - 2022-12-16
### Fixed
- [iOS] Add missing references in project.pbxproj

### Changed
- [iOS] Improve download stability
- [iOS] Improve audio player stability

## [4.2.7 & 4.2.8] - 2022-12-09
### Changed
- [iOS] Improve video player stability

## [4.2.6] - 2022-11-30
### Fixed
- [Android] Added empty constructor in BrightcoveVideoPlayerFragment

## [4.2.5] - 2022-11-17
### Fixed
- [Android] Added missing com.brightcove.player:android-sdk implementation
- [iOS] Send complete error message

## [4.2.4] - 2022-11-14
### Fixed
- [iOS] Fix Brightcove-Player-Core-Static dependency version

## [4.2.3] - 2022-11-08
### Fixed
- [iOS] Prevent play downloaded audio/video if the media is not fully downloaded

## [4.2.2] - 2022-11-04
### Changed
- [Android] Upgrade brightcove SDK from 7.1.2 to 7.1.3
- [iOS] Upgrade brightcove SDK from 6.10.6 to 6.11.0

## [4.2.1] - 2022-10-20
### Fixed
- [Android] Fixed crash if the audio player is destroyed just after the end of the audio

## [4.2.0] - 2022-10-18
### Changed
- [Android]  Upgrade dependencies to the latest available version.

## [4.1.0] - 2022-10-13
### Added
- [iOS & Android] Added `ENDED` event on `AudioPlayerState`
### Fixed
- [iOS] Prevent random app crashes when calling `deleteAllDownloadedMedias` 


## [4.0.0] - 2022-10-10
### Changed
- [iOS & Android] Upgrade from Capacitor 3 to Capacitor 4
- [Android] Upgrade brightcove SDK from 6.16.1 to 7.1.2
- [Android] setting `setDownloadNotifications` to false completely hide notifications after Android O (SDK 26)

## [3.1.5] - 2022-10-06
### Fixed
- [iOS] Fix default subtitles override issue in `kBCOVPlaybackSessionLifecycleEventReady` handler

## [3.1.3] - 2022-09-22
### Fixed
- [iOS] A video can't be opened twice if you use the `position` parameter of `playVideo()`
- [iOS] Fix `kBCOVPlaybackSessionErrorDomain` if more than 30 videos is opened/closed

### Changed
- [iOS & Android] Added `subtitle` to `closeVideo` event

## [3.1.2] - 2022-09-08
### Fixed
- [Android] Fix `closeVideo()` method

## [3.1.1] - 2022-09-06
### Fixed
- [iOS] Prevent app crash if play a video without subtitles

## [3.1.0] - 2022-08-23
### Changed
- [iOS] Update brightcove SDK from 6.9.1 to 6.10.6

## [3.0.1] - 2022-08-18
### Fixed
- [Android] Prevent app crash if play an audio without thumbnail

## [3.0.0] - 2022-08-03
### Added
- [iOS & Android] Add subtitle source link in metadata `subtitles` property

## [2.3.3] - 2022-08-02
### Fixed
- [iOS] Prevent app crash if no thumbnail in getMedatadata method

## [2.3.2] - 2022-07-22
### Fixed
- [iOS] Prevent MISSING_FILE_ID issue when calling isLooping method

## [2.3.0] - 2022-06-17
### Added
- [Android] Add `setDownloadNotifications` method

## [2.2.1] - 2022-05-19
### Fixed
- [Android] Fix conflict with `@sentry/capacitor` package

## [2.2.0] - 2022-05-13
- [iOS & Android] simplify downloadStateChange event
### Fixed
- [Android] Fix crash if no subtitle provided to playVideo method

## [2.1.0] - 2022-05-02
### Fixed
- [Android] Fix caption selection issues
### Added
- [iOS] Add defaultPosterUrl parameter to loadAudio

## [2.0.1] - 2022-04-27
### Fixed
- [iOS & Android] Fix issue with Jest after capacitor 3 upgrade

## [2.0.0] - 2022-04-27
### Added
- [iOS & Android] Add getMetadata method
- [iOS & Android] Add pauseVideo method
- [iOS & Android] Add closeVideo method
- [iOS & Android] If playVideo method is called on an open paused video, the video will resume
- [iOS & Android] Add logs
- [iOS & Android] Add totalMillis key to videoClosed event
- [iOS & Android] Add subtitle option to playVideo method
- [Web & Android] Improved error handling
- [iOS & Android] Improve error management
- [Android] Add deleteAllDownloadedMedias
-
### Fixed
- [Android] Fixed kotlin issues on the video player

## [1.0.1] - 2022-03-01
- [iOS & Android] Add an accessibility label "close" on the close button of the video


## [1.0.0] - 2021-10-12
### Changed
- [iOS & Android] Upgrade from Capacitor 2 to Capacitor 3

## [0.0.20] - 2021-09-03
- [iOS] Add deleteAllDownloadedMedias

## [0.0.19] - 2021-09-01
### Fixed
- [Android] Hide close button when media controls are hidden
- [iOS] Hide close button when media controls are hidden
- [iOS] Black screen on the video when the notification control center is displayed
### Added
- [iOS] Get the download size
- [iOS] Remove unnecessary reference to download token
- [iOS] Add playInternalAudio

## [0.0.18] - 2021-08-19
- [Android] Delete a downloaded media
- [Android] Get the status of all downloaded media

## [0.0.17] - 2021-08-11
### Added
- [iOS] Delete a downloaded media
- [iOS] Get the status of all downloaded media
- [iOS] Offline playback of downloaded media
- [iOS] Download medias
- [Android] Added close video button
- [iOS] Added close video button
### Fixed
- [iOS] Restart a download if status is in error

## [0.0.16] - 2021-04-28
- [iOS] Remove animation when user swipe to close video

## [0.0.15] - 2021-04-13
### Fixed
- [iOS] Load audio events on plugin initialization

## [0.0.14] - 2021-04-01
### Fixed
- [iOS] Fixed warnings in logs

## [0.0.13] - 2021-04-01
### Added
- [Android] added "swipe down" gesture to close video

## [0.0.12] - 2021-04-01
### Added
- [iOS] added "swipe down" gesture to close video

## [0.0.11] - 2021-04-01
### Fixed
- [iOS] Prevent glitchs on the audio player when user makes a seek to
- [iOS] Prevent app crash if file id is missing on a video

## [0.0.10] - 2021-03-31
### Added
- [iOS] videoPositionChange event
- [iOS] Play video from a specific position
- [iOS] closeVideo event sends current position and video completion information

### Fixed
- [Android] Fixed wrong thread for toggleLooping calls

## [0.0.9] - 2021-03-29
### Fixed
- [Android] set `local` param to default false on loadAudio/playVideo methods


## [0.0.8] - 2021-03-29
### Changed
- [Android] loadAudio / playVideo methods use remote by default and accept a "local" param to force local playback if available

## [0.0.7] - 2021-03-26
### Added
- [Android] videoPositionChange event
- [Android] Play video from a specific position

### Changed
- [Android] closeVideo event sends current position and video completion information

## [0.0.6] - 2021-03-26
### Added
- [Android] Download media feature (audio and video) with status and progress
- [Android] Offline playback of downloaded media
- [Android] Automatic download of secondary audio tracks and subtitles for offline playback

### Fixed
- [iOS] Fixed an issue that could lead to a crash when a video reached the end
- [iOS] Fixed an issue that caused the video to take a long time to load

## [0.0.5] - 2021-03-24
### Fixed
- [iOS] Issues on lock screen controls when switching from a video to an audio
- [iOS] Glitches on lock screen seekbar

## [0.0.4] - 2021-03-19
### Changed
- [iOS] Hide remaining time & disable progress bar when looping is enabled

## [0.0.3] - 2021-03-17

### Changed
- [Android] Hide chronometer when looping is enabled
- [Android] Set notification importance to DEFAULT

### Fixed
- [Android] Initiate notification channel for SDK > Oreo

## [0.0.2] - 2021-03-12

### Added
- Project initialization
- [Android] Handle Brightcove Account data for playback API
- [Android] Play audio files from Brightcove cloud
- [Android] Display audio player notification
- [Android] Dispose audio player resources when needed
- [Android] Audio player external controls (load/play/pause/stop/seekTo/backward/forward)
- [Android] Plugin error handling
- [Android] Looping audio files
- [Android] Setting a looping duration and stop playing when it reaches the end
- [Android] Audio position, player state and error events
  [Android] Customization of forward/rewind buttons in audio notification
  [Android] Notification close event
- [iOS] Add authentication
- [iOS] Handle Brightcove Account data for playback API
- [iOS] Open a fullscreen ViewController when playVideo is called
- [iOS] Play audio files from Brightcove cloud
- [iOS] Audio controls: load, stop, play/pause, forward, backward, seekTo
- [iOS] Looping audio files
- [iOS] Lock screen controls for audio player
- [iOS] Lock screen controls for video player
- [iOS] Audio position, player state and error events
- [iOS] Setting a looping duration and stop playing when it reaches the end
