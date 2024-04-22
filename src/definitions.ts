import { PluginListenerHandle } from '@capacitor/core';

export interface VideoPlayerPositionState {
  currentMillis: number,
  totalMillis: number
}

export interface ClosedVideoPlayerState extends VideoPlayerPositionState {
  completed: boolean,
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

export interface AudioPlayerState {
  state: AudioPlayerStatus,
  currentMillis?: number,
  totalMillis?: number,
  error?: string, // Only used if state = AudioPlayerStatus.ERROR
  remainingTime?: number // Only used if setLooping() is used
}

export interface AudioNotificationOptions {
  forwardIncrementMs?: number;
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

export interface DownloadStateMediaInfo {
  mediaId: string
  status: DownloadStatus,
  estimatedSize?: number,
  maxSize?: number,
  downloadedBytes?: number,
  progress?: number,
  reason?: string,
  title?: string,
}

export interface MediaMetaData {
  mediaId: string,
  title: string,
  totalMillis: number,
  thumbnail: string,
  posterUrl: string,
  downloaded: boolean,
  fileSize: number // in bytes
  subtitles: Array<Subtitle>
}

export interface Subtitle {
  language: string;
  src: string;
}

export interface BrightcovePlayerPlugin {

  addListener(eventName: string, listenerFunc: (...args: any) => void): Promise<PluginListenerHandle> & PluginListenerHandle;
  removeAllListeners(): Promise<void>;

  // Brightcove account
  updateBrightcoveAccount(options: { accountId: string, policyKey: string }): Promise<void>;

  // Video & Audio
  getMetadata(options: { fileId: string }) : Promise<{ metadata: MediaMetaData }>

  // Video - Return nothing if video resume
  playVideo(options: { fileId?: string, position?: number, local?: boolean, subtitle?: string }): Promise<{ name?: string, duration?: number }>;

  pauseVideo(): Promise<void>;
  closeVideo(): Promise<void>;

  setSubtitleLanguage(options: { language: string }): Promise<void>;

  // Audio
  loadAudio(options: { fileId: string, local?: boolean, defaultPosterUrl?: string }): Promise<{ name?: string, duration?: number }>;
  stopAudio():  Promise<void>;
  pauseAudio():  Promise<void>;
  playAudio(): Promise<void>;
  backwardAudio(options: { amount?: number }): Promise<void>;
  forwardAudio(options: { amount?: number }): Promise<void>;
  seekToAudio(options: { position: number }): Promise<void>;
  enableAudioLooping(options?: { time: number }): Promise<void>;
  disableAudioLooping(): Promise<void>;
  isAudioLooping(): Promise<{ value: boolean }>
  getAudioPlayerState(): Promise<AudioPlayerState>
  destroyAudioPlayer(): Promise<void>;
  setAudioNotificationOptions(options: AudioNotificationOptions): Promise<void>;

  // Offline files
  setDownloadNotifications(options: { enabled: boolean }): Promise<void>;
  isMediaAvailableLocally(options: { fileId: string }): Promise<{value: boolean}>;
  downloadMedia(options: { fileId: string }): Promise<void>;
  getDownloadedMediasState(): Promise<{medias: Array<DownloadStateMediaInfo>}>;
  deleteDownloadedMedia(options: { fileId: string}): Promise<void>;

  // Workaround for Android : better solution ?
  notifyBackButtonPressed(): Promise<void>;

  playInternalAudio(options: {file: string}): Promise<void>;

  // iOS only as for 0.0.20
  deleteAllDownloadedMedias(): Promise<void>
}
