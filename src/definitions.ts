export interface FileChunkReaderPlugin {
  echo(options: { value: string }): Promise<{ value: string }>;
}
