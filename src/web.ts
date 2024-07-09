// @ts-nocheck
import { WebPlugin } from '@capacitor/core';
import { Dropbox } from 'dropbox';
import { FileChunkReaderPlugin } from './definitions';

export class FileChunkReaderWeb
  extends WebPlugin
  implements FileChunkReaderPlugin
{
  constructor() {
    super({
      name: 'FileChunkReader', // Ensure this name matches the plugin name used in registration
      platforms: ['web'],
    });
    console.log('FileChunkReaderWeb initialized');
  }

  /**
   * Upload a file in chunks to DROPBOX API
   * @param options
   */
  async uploadFileChunk(options: {
    accessToken: string;
    file: File;
    targetPath: string;
    progressCallback: (progress: any) => void;
    doneCallback: (succes: boolean, response: any) => void;
  }): Promise<void> {
    const { accessToken, file, targetPath, progressCallback, doneCallback } =
      options;
    const CHUNK_SIZE = 8 * 1024 * 1024; // 8 MB, Dropbox's recommended chunk size
    let offset = 0;
    let sessionId: string | null = null;
    const dbx = new Dropbox({ accessToken });

    // Function to handle each chunk's upload
    const uploadChunk = async (chunk: Blob, isLastChunk: boolean) => {
      if (sessionId === null) {
        // Start a new upload session
        const startResponse = await dbx.filesUploadSessionStart({
          close: false,
          contents: chunk,
        });
        sessionId = startResponse.result.session_id;
      } else {
        // Append to existing session
        const cursor = { session_id: sessionId, offset: offset };
        if (!isLastChunk) {
          await dbx.filesUploadSessionAppendV2({
            cursor: cursor,
            close: false,
            contents: chunk,
          });
        } else {
          // Finish the upload session on the last chunk
          const commit: DropboxTypes.files.CommitInfo = {
            path: targetPath,
            mode: { '.tag': 'add' },
            autorename: true,
            mute: false,
          };
          const response = await dbx.filesUploadSessionFinish({
            cursor: cursor,
            commit: commit,
            contents: chunk,
          });
          // Notify completion
          doneCallback(true, response);
        }
      }
    };

    while (offset < file.size) {
      const isLastChunk = offset + CHUNK_SIZE >= file.size;
      const chunk = file.slice(offset, offset + CHUNK_SIZE);
      await uploadChunk(chunk, isLastChunk);
      offset += CHUNK_SIZE;

      // Notify progress (optional)
      const progress = Math.min(100, (offset / file.size) * 100);
      // this.notifyListeners('uploadProgress', { progress: progress });
      progressCallback(progress);
    }
  }
  /**
   * Upload a file using DROPBOX API
   * @param options
   */
  async uploadFile(options: {
    accessToken: string;
    file: File;
    targetPath: string;
    progressCallback: (progress: any) => void;
    doneCallback: (succes: boolean, response: any) => void;
  }): Promise<void> {
    console.log('AM ACCESAT AICI');
    const { accessToken, file, targetPath, progressCallback, doneCallback } =
      options;
    const dbx = new Dropbox({ accessToken });
    console.log(dbx);

    dbx
      .filesUpload({ path: targetPath, contents: file })
      .then(response => {
        // Notify listeners that the upload is complete, including any relevant response data
        doneCallback(true, response);
      })
      .catch(error => {
        // Handle upload errors
        console.error('Error uploading file:', error);
        doneCallback(false, null);
      });
  }

  /**
   * Upload a file in chunks using Azure File Blob Storage API
   * @param options
   */
  async uploadFileChunk(options: {
    sasToken: string;
    accountName: string;
    containerName: string;
    file: File;
    targetPath: string;
    progressCallback: (progress: any) => void;
    doneCallback: (success: boolean, response: any) => void;
  }): Promise<void> {
    const {
      sasToken,
      accountName,
      containerName,
      file,
      targetPath,
      progressCallback,
      doneCallback,
    } = options;
    const CHUNK_SIZE = 8 * 1024 * 1024; // 8 MB
    let offset = 0;
    const blockIds = [];
    const blobServiceClient = new BlobServiceClient(
      `https://${accountName}.blob.core.windows.net?${sasToken}`,
    );
    const containerClient = blobServiceClient.getContainerClient(containerName);
    const blockBlobClient = containerClient.getBlockBlobClient(targetPath);

    // Function to handle each chunk's upload
    const uploadChunk = async (chunk: Blob, blockId: string) => {
      blockIds.push(blockId);
      await blockBlobClient.stageBlock(blockId, chunk, chunk.size);
    };

    while (offset < file.size) {
      const isLastChunk = offset + CHUNK_SIZE >= file.size;
      const chunk = file.slice(offset, offset + CHUNK_SIZE);
      const blockId = btoa(String(offset).padStart(5, '0')); // block ID must be base64-encoded and unique
      await uploadChunk(chunk, blockId);
      offset += CHUNK_SIZE;

      // Notify progress
      const progress = Math.min(100, (offset / file.size) * 100);
      progressCallback(progress);
    }

    // Commit the blocks
    await blockBlobClient.commitBlockList(
      blockIds.map(id => btoa(String(id).padStart(5, '0'))),
    );
    doneCallback(true, { message: 'Upload complete' });
  }

  /**
   * Upload a file using Azure File Blob Storage API
   * @param options
   */
  async uploadFile(options: {
    sasToken: string;
    accountName: string;
    containerName: string;
    file: File;
    targetPath: string;
    progressCallback: (progress: any) => void;
    doneCallback: (success: boolean, response: any) => void;
  }): Promise<void> {
    const {
      sasToken,
      accountName,
      containerName,
      file,
      targetPath,
      progressCallback,
      doneCallback,
    } = options;
    const blobServiceClient = new BlobServiceClient(
      `https://${accountName}.blob.core.windows.net?${sasToken}`,
    );
    const containerClient = blobServiceClient.getContainerClient(containerName);
    const blockBlobClient = containerClient.getBlockBlobClient(targetPath);

    try {
      await blockBlobClient.uploadData(file, {
        onProgress: progress => {
          progressCallback(
            Math.round((progress.loadedBytes / file.size) * 100),
          );
        },
      });
      doneCallback(true, { message: 'Upload complete' });
    } catch (error) {
      console.error('Error uploading file:', error);
      doneCallback(false, error);
    }
  }
}
