import Capacitor
import Foundation
import SwiftyDropbox // Ensure you have SwiftyDropbox installed

@objc(FileChunkReaderPlugin)
public class FileChunkReaderPlugin: CAPPlugin {
    
  @objc func readChunk(_ call: CAPPluginCall) {
    guard let fileUri = call.getString("uri"),
          let offset = call.getInt("offset"),
          let length = call.getInt("length"),
          let url = URL(string: fileUri) else {
        call.reject("Invalid arguments")
        return
    }

    do {
        let fileData = try Data(contentsOf: url)
        let chunk = fileData.subdata(in: offset..<min(offset + length, fileData.count))
        let base64String = chunk.base64EncodedString()
        
        var ret = JSObject()
        ret["data"] = base64String
        call.resolve(ret)
    } catch {
        call.reject("Failed to read chunk: \(error)")
    }
}


    func updateProgress(progress: Float) {
        let progressData: [String: Any] = ["progress": progress]
        self.notifyListeners("uploadProgress", data: progressData)
    }

    func updateDoneUpload(success: Bool) {
        let progressData: [String: Any] = ["success": success]
        self.notifyListeners("uploadComplete", data: progressData)
    }
 
  @objc func uploadFileChunk(_ call: CAPPluginCall) {
    guard let fileUri = call.getString("uri"),
          let accessToken = call.getString("accessToken"),
          let targetPath = call.getString("targetPath"),
          let fileSize = call.getInt("fileSize"),
          let url = URL(string: fileUri) else {
        call.reject("Invalid arguments")
        return
    }

    let client = getClient(accessToken)
    
    DispatchQueue.global(qos: .background).async {
        do {
            let fileData = try Data(contentsOf: url)
            var CHUNK_SIZE = 8 * 1024 * 1024
            var offset = 0
            var sessionId: String? = nil
            
            while offset < fileSize {
                let chunkEnd = min(offset + CHUNK_SIZE, fileSize)
                let chunk = fileData.subdata(in: offset..<chunkEnd)
                
                if sessionId == nil {
                    let result = try client.files.uploadSessionStart(close: false, input: chunk).response.wait()
                    sessionId = result.sessionId
                } else if chunkEnd < fileSize {
                    try client.files.uploadSessionAppendV2(cursor: UploadSessionCursor(sessionId: sessionId!, offset: UInt64(offset)), close: false, input: chunk).response.wait()
                    self.updateProgress(progress: progress)
                } else {
                    let cursor = UploadSessionCursor(sessionId: sessionId!, offset: UInt64(offset))
                    let commitInfo = CommitInfo(path: targetPath, mode: .add, autorename: true, clientModified: nil, mute: false)
                    _ = try client.files.uploadSessionFinish(cursor: cursor, commit: commitInfo, input: chunk).response.wait()
                    self.updateDoneUpload(success: true)
                }
                
                offset += CHUNK_SIZE
            }
            
            DispatchQueue.main.async {
                call.resolve()
            }
        } catch {
            DispatchQueue.main.async {
                 updateDoneUpload(success: false)
                call.reject("Upload failed: \(error)")
            }
        }
    }
}

}
