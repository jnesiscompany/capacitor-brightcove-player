import { registerPlugin } from '@capacitor/core';
import type { BrightcovePlayerPlugin } from './definitions';

const BrightcovePlayer = registerPlugin<BrightcovePlayerPlugin>('BrightcovePlayer', {
  web: () => import('./web').then(m => new m.BrightcovePlayerWeb())
});

export * from './definitions'
export { BrightcovePlayer };
