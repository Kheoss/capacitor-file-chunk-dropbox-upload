import { WebPlugin } from '@capacitor/core';
import { FileChunkReaderPlugin } from './definitions';

export class FileChunkReaderWeb
  extends WebPlugin
  implements FileChunkReaderPlugin
{
  async readChunk(): Promise<{ data: string }> {
    console.warn('FileChunkReader does not have a web implementation yet');
    return Promise.resolve({ data: '' });
  }
  uploadFileChunk(): void {
    console.warn('FileChunkReader does not have a web implementation yet');
  }
  uploadFile(): void {
    console.warn('FileChunkReader does not have a web implementation yet');
  }
}
