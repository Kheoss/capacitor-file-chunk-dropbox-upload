import { WebPlugin } from '@capacitor/core';

import type { FileChunkReaderPlugin } from './definitions';

export class FileChunkReaderWeb extends WebPlugin implements FileChunkReaderPlugin {
  async echo(options: { value: string }): Promise<{ value: string }> {
    console.log('ECHO', options);
    return options;
  }
}
