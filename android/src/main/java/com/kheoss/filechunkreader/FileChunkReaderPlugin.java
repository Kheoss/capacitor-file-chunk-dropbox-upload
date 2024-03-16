package com.kheoss.filechunkreader;

import android.content.Context;
import android.net.Uri;
import com.dropbox.core.DbxRequestConfig;
import com.dropbox.core.v2.DbxClientV2;
import com.dropbox.core.v2.files.CommitInfo;
import com.dropbox.core.v2.files.FileMetadata;
import com.dropbox.core.v2.files.UploadSessionCursor;
import com.dropbox.core.v2.files.UploadSessionFinishArg;
import com.dropbox.core.v2.files.UploadSessionStartResult;
import com.dropbox.core.v2.files.WriteMode;
import com.getcapacitor.JSObject;
import com.getcapacitor.NativePlugin;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStream;
import java.util.Date;

@CapacitorPlugin(name = "FileChunkReader")
public class FileChunkReaderPlugin extends Plugin {

    @PluginMethod
    public void readChunk(PluginCall call) {
        String fileUri = call.getString("uri");
        int offset = call.getInt("offset");
        int length = call.getInt("length");

        Context context = getContext();
        Uri uri = Uri.parse(fileUri);
        byte[] buffer = new byte[length];

        try (InputStream inputStream = context.getContentResolver().openInputStream(uri)) {
            if (inputStream != null) {
                long skipped = inputStream.skip(offset);
                if (skipped < offset) {
                    call.reject("Unable to skip to offset");
                    return;
                }
                int bytesRead = inputStream.read(buffer, 0, length);
                String result = android.util.Base64.encodeToString(buffer, 0, bytesRead, android.util.Base64.NO_WRAP);
                JSObject ret = new JSObject();
                ret.put("data", result);
                call.resolve(ret);
            } else {
                call.reject("File not found");
            }
        } catch (Exception e) {
            call.reject("Error reading file chunk", e);
        }
    }

    public byte[] readChunkLocal(String fileUri, int offset, int length) {
        Context context = getContext();
        Uri uri = Uri.parse(fileUri);
        byte[] buffer = new byte[length];

        try (InputStream inputStream = context.getContentResolver().openInputStream(uri)) {
            if (inputStream != null) {
                long skipped = inputStream.skip(offset);
                if (skipped < offset) {
                    return null;
                }
                int bytesRead = inputStream.read(buffer, 0, length);
                return buffer;
            } else {
                return null;
            }
        } catch (Exception e) {
            return null;
        }
    }

    @PluginMethod
    public void uploadFileChunk(PluginCall call) {
        String fileUri = call.getString("uri");
        String accessToken = call.getString("accessToken");
        String targetPath = call.getString("targetPath");
        int fileSize = call.getInt("fileSize");


                try {

                    DbxRequestConfig config = DbxRequestConfig.newBuilder("eqapp/videoBuilder").build();
                    DbxClientV2 client = new DbxClientV2(config, accessToken);

                    // Split the file URI, read chunks and upload
                    int offset = 0;
                    String sessionId = null;
                    final int CHUNK_SIZE = 8 * 1024 * 1024; // 8 MB

                    while (offset < fileSize) {
                        // Read a chunk of the file
                        byte[] chunkData = readChunkLocal(fileUri, offset, CHUNK_SIZE); // Your method to read a file chunk into byte array
                        if (sessionId == null) {
                            // Start the upload session
                            UploadSessionStartResult result = client
                                .files()
                                .uploadSessionStart()
                                .uploadAndFinish(new ByteArrayInputStream(chunkData));
                            sessionId = result.getSessionId();
                        }
                        else {
                            UploadSessionCursor cursor = new UploadSessionCursor(sessionId, offset);
                            if (offset + CHUNK_SIZE < fileSize) {
                                // Append to the session
                                client.files().uploadSessionAppendV2(cursor).uploadAndFinish(new ByteArrayInputStream(chunkData));
                                JSObject progressData = new JSObject();
                                progressData.put("progress", ((float)offset / fileSize));
                                notifyListeners("uploadProgress", progressData);
                            } else {
                                CommitInfo commitInfo = CommitInfo
                                    .newBuilder(targetPath)
                                    .withMode(WriteMode.ADD)
                                    .withClientModified(new Date())
                                    .withMute(false)
                                    .build();

                                FileMetadata metadata = client
                                    .files()
                                    .uploadSessionFinish(cursor, commitInfo)
                                    .uploadAndFinish(new ByteArrayInputStream(chunkData));

                                JSObject finishData = new JSObject();
                                finishData.put("success", true);
                                finishData.put("response", metadata);
                                notifyListeners("uploadComplete", finishData);
                            }
                        }


                        offset += CHUNK_SIZE;
                    }
                } catch (Exception e) {
                    JSObject finishData = new JSObject();
                    finishData.put("success", false);
                    notifyListeners("uploadComplete", finishData);
                    e.printStackTrace();
                    // Handle exceptions
                }
    }

    @PluginMethod
    public void uploadFile(PluginCall call) {
        String fileUri = call.getString("uri");
        String accessToken = call.getString("accessToken");
        String dropboxPath = call.getString("targetPath");

        // Initialize Dropbox client
        DbxRequestConfig config = DbxRequestConfig.newBuilder("eqapp/wholeFileUploader").build();
        DbxClientV2 client = new DbxClientV2(config, accessToken);

        new Thread(() -> {
            InputStream fileInputStream = null;
            try {
                // Convert fileUri to InputStream
                fileInputStream = getContext().getContentResolver().openInputStream(Uri.parse(fileUri));

                if (fileInputStream != null) {
                    // Upload the file
                    FileMetadata metadata = client.files().uploadBuilder(dropboxPath)
                            .uploadAndFinish(fileInputStream);

                    // Prepare and return the metadata
                    JSObject ret = new JSObject();
                    ret.put("success", true);

                    JSObject finishData = new JSObject();
                    finishData.put("success", true);
                    finishData.put("response", metadata);
                    notifyListeners("uploadComplete", finishData);

                    call.resolve(ret);
                } else {
                    call.reject("Unable to open file input stream");
                }
            } catch (Exception e) {
                call.reject("Upload failed: " + e.getMessage());
            } finally {
                if (fileInputStream != null) {
                    try {
                        fileInputStream.close();
                    } catch (IOException e) {
                        e.printStackTrace();
                    }
                }
            }
        }).start();
    }
}
