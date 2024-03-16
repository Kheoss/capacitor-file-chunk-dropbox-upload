export interface FileChunkReaderPlugin {
  readChunk(options: {
    uri: string;
    offset: number;
    length: number;
  }): Promise<{ data: string }>;
  uploadFileChunk(options: {
    uri: string;
    accessToken: string;
    targetPath: string;
    fileSize: number;
  }): void;
  uploadFile(options: {
    uri: string;
    accessToken: string;
    targetPath: string;
  }): void;
}
