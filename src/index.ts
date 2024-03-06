import { registerPlugin } from '@capacitor/core';

import type { FileChunkReaderPlugin } from './definitions';

const FileChunkReader = registerPlugin<FileChunkReaderPlugin>('FileChunkReader', {
  web: () => import('./web').then(m => new m.FileChunkReaderWeb()),
});

export * from './definitions';
export { FileChunkReader };
