import { WebPlugin } from '@capacitor/core';
import type {
  BrightcovePlayerPlugin,
  AudioPlayerState,
  AudioNotificationOptions,
  DownloadStateMediaInfo, MediaMetaData
} from './definitions';

export class BrightcovePlayerWeb extends WebPlugin implements BrightcovePlayerPlugin {
  constructor() {

    super({
      name: 'BrightcovePlayer',
      platforms: ['web'],
    });

    window.addEventListener('backButton', () => this.notifyBackButtonPressed());
  }

  // Brightcove account
  async updateBrightcoveAccount(options: { accountId: string, policyKey: string }): Promise<void> {
    console.log('updateBrightcoveAccount', options);
    throw this.unimplemented('Not implemented on web.');
  }

  // Video & Audio
  getMetadata(options: { fileId: string }): Promise<{ metadata: MediaMetaData }> {
    console.log('getMetadata', options);
    throw this.unimplemented('Not implemented on web.');
  }

  // Video
  async playVideo(options: { fileId: string, position?: number, local?: boolean }): Promise<{ name: string, duration: number }> {
    console.log('playVideo', options);
    throw this.unimplemented('Not implemented on web.');
  }

  pauseVideo(): Promise<void> {
    throw this.unimplemented('Not implemented on web.');
  }

  closeVideo(): Promise<void> {
    throw this.unimplemented('Not implemented on web.');
  }

  // Android only
  async setDownloadNotifications(options: { enabled: boolean}): Promise<void> {
    console.log('setDownloadNotifications', options);
    throw this.unimplemented('Not implemented on web.');
  }

  async setSubtitleLanguage(options: { language: string }): Promise<void> {
    console.log('setSubtitleLanguage', options);
    throw this.unimplemented('Not implemented on web.');
  }

  // Audio
  async loadAudio(options: { fileId: string, local?: boolean, defaultPosterUrl?: string }): Promise<{ name?: string, duration?: number }> {
    console.log('loadAudio', options);
    throw this.unimplemented('Not implemented on web.');
  }
  async backwardAudio(options: { amount: number }): Promise<void> {
    console.log('backwardAudio', options);
    throw this.unimplemented('Not implemented on web.');
  }
  async forwardAudio(options: { amount: number }): Promise<void> {
    console.log('forwardAudio', options);
    throw this.unimplemented('Not implemented on web.');
  }
  async seekToAudio(options: { position: number }): Promise<void> {
    console.log('seekTo', options);
    throw this.unimplemented('Not implemented on web.');
  }
  async enableAudioLooping(options?: { time: number }): Promise<void> {
    console.log('enable looping', options);
    throw this.unimplemented('Not implemented on web.');
  }
  async disableAudioLooping(): Promise<void> {
    console.log('disable looping');
    throw this.unimplemented('Not implemented on web.');
  }
  async isAudioLooping(): Promise<{ value: boolean }> {
    console.log('is looping');
    throw this.unimplemented('Not implemented on web.');
  }
  async stopAudio(): Promise<void> {
    console.log('stopAudio');
    throw this.unimplemented('Not implemented on web.');
  }
  async pauseAudio(): Promise<void> {
    console.log('pauseAudio');
    throw this.unimplemented('Not implemented on web.');
  }
  async playAudio(): Promise<void> {
    console.log('playAudio');
    throw this.unimplemented('Not implemented on web.');
  }

  async getAudioPlayerState(): Promise<AudioPlayerState> {
    console.log('getAudioPlayerState');
    throw this.unimplemented('Not implemented on web.');
  }

  async destroyAudioPlayer(): Promise<void> {
    throw this.unimplemented('Not implemented on web.');
  }

  async setAudioNotificationOptions(options: AudioNotificationOptions): Promise<void> {
    console.log('Set audio notification options', options);
    throw this.unimplemented('Not implemented on web.');
  }


  // Offline files
  async isMediaAvailableLocally(options: { fileId: string }): Promise<{value: boolean}> {
    console.log('Is Media Available Locally', options);
    throw this.unimplemented('Not implemented on web.');
  }

  async downloadMedia(options: { fileId: string, showNotification?: boolean }): Promise<void> {
    console.log('Download Media', options);
    throw this.unimplemented('Not implemented on web.');
  }

  async getDownloadedMediasState(): Promise<{ medias: Array<DownloadStateMediaInfo>}> {
    console.log("get Downloaded medias");
    throw this.unimplemented('Not implemented on web.');
  }

  async deleteDownloadedMedia(options: { fileId: string }): Promise<void> {
    console.log("Delete downloaded file", options);
    throw this.unimplemented('Not implemented on web.');
  }

  // Workaround for Android : better solution ?
  async notifyBackButtonPressed(): Promise<void> {
    console.log('Not implemented');
    throw this.unimplemented('Not implemented on web.');
  }

  async playInternalAudio(options: {file: string}): Promise<void> {
    console.log('Local internal not implemented ', options);
    throw this.unimplemented('Not implemented on web.');
  }

  async deleteAllDownloadedMedias(): Promise<void> {
    console.log('Delete all downloaded medias')
    throw this.unimplemented('Not implemented on web.');
  }
}
