interface MobileOptions {
  uri: string;
  accessToken: string;
  targetPath: string;
  fileSize: number;
}
interface WebOptions {
  accessToken: string;
  file: File;
  targetPath: string;
}
export interface FileChunkReaderPlugin {
  readChunk?(options: MobileOptions): Promise<{ data: string }>;
  uploadFileChunk?(options: MobileOptions | WebOptions): void;
  uploadFile?(options: MobileOptions | WebOptions): void;
}
