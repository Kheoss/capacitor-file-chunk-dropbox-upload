import Capacitor
import Foundation

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
    
    func updateDoneUpload(success: Bool, metadata:String) {
        let progressData: [String: Any] = ["success": success, "response": metadata ]
        self.notifyListeners("uploadComplete", data: progressData)
    }
    
    func startUploadSession(accessToken: String,firstChunk: Data, completion: @escaping (String?) -> Void) {
        let url = URL(string: "https://content.dropboxapi.com/2/files/upload_session/start")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer " + accessToken, forHTTPHeaderField: "Authorization")
        request.addValue("{\"close\":false}", forHTTPHeaderField: "Dropbox-API-Arg")
        request.addValue("application/octet-stream", forHTTPHeaderField: "Content-Type")

        let task = URLSession.shared.uploadTask(with: request, from: firstChunk) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            if let responseDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let sessionId = responseDict["session_id"] as? String {
                
 //               completion(String(sessionId.split(separator: ":")[1]))
                completion(sessionId)
            } else {
                completion(nil)
            }
        }
        task.resume()
    }
    func appendToUploadSession(accessToken: String,sessionId: String, chunk: Data, offset: Int, completion: @escaping (Bool) -> Void) {
        let url = URL(string: "https://content.dropboxapi.com/2/files/upload_session/append_v2")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer " + accessToken, forHTTPHeaderField: "Authorization")
        request.addValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.addValue("{\"cursor\": {\"session_id\": \"\(sessionId)\", \"offset\": \(offset)}}", forHTTPHeaderField: "Dropbox-API-Arg")

        let task = URLSession.shared.uploadTask(with: request, from: chunk) { _, _, error in
            completion(error == nil)
        }
        task.resume()
    }
    
    func finishUploadSession(accessToken: String, sessionId: String, finalChunk: Data, filePath: String, offset: Int, completion: @escaping (Bool, String?) -> Void) {
        let url = URL(string: "https://content.dropboxapi.com/2/files/upload_session/finish")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer " + accessToken, forHTTPHeaderField: "Authorization")
        request.addValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        
        request.addValue("{\"cursor\": {\"session_id\": \"\(sessionId)\", \"offset\": \(offset)}," +
                         "\"commit\": {\"path\": \"\(filePath)\", \"mode\": \"add\", \"autorename\": true, \"mute\": false,\"strict_conflict\": false}}",
                         forHTTPHeaderField: "Dropbox-API-Arg")

        let task = URLSession.shared.uploadTask(with: request, from: finalChunk) { data, response, error in
               guard let data = data, error == nil else {
                   completion(false, nil)
                   return
               }
                
               if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                   
                   if let responseString = String(data: data, encoding: .utf8) {
                       completion(true, responseString)
                   } else {
                       completion(false, nil)
                   }
               } else {
                   completion(false, nil)
               }
           }
           task.resume()
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
        
          
        Task.detached(priority: .userInitiated) {
            if let fileData = try? Data(contentsOf: url) {
                let CHUNK_SIZE = 8 * 1024 * 1024
                var offset = 0
                
                let chunkEnd = min(offset + CHUNK_SIZE, fileSize)
                let chunk = fileData.subdata(in: offset..<chunkEnd)
                
                
                // start the upload session
                self.startUploadSession(accessToken: accessToken, firstChunk: chunk) { sessionId in
                    guard let sessionId = sessionId else {
                        print("Failed to start upload session")
                        return
                    }
                    offset += CHUNK_SIZE
                    
                    func handleNextChunk(accessToken: String,offset: Int, targetPath: String) {
                        let chunkEnd = min(offset + CHUNK_SIZE, fileSize)
                     
                        let CHUNK_SIZE = 8 * 1024 * 1024
                        
                        if offset + CHUNK_SIZE < fileSize{
                            let chunk = fileData.subdata(in: offset..<chunkEnd)
                            self.updateProgress(progress: Float(offset) / Float(fileSize))
                            self.appendToUploadSession(accessToken: accessToken, sessionId: sessionId, chunk: chunk, offset: offset) { success in
                                              if success {
                                                  handleNextChunk(accessToken: accessToken, offset: offset + CHUNK_SIZE, targetPath:targetPath)
                                              } else {
                                                  self.updateDoneUpload(success: false, metadata: "")
                                                  call.reject("Failed")
                                              }
                                          }
                        }
                        else{
                            self.finishUploadSession(accessToken: accessToken,sessionId: sessionId, finalChunk: chunk, filePath: targetPath, offset: offset) { success, metadata in
                                               if success {
                                                   self.updateDoneUpload(success: true, metadata: metadata ?? "")
                                                   call.resolve([
                                                       "success": true,
                                                       "message": "File uploaded successfully",
                                                       "metadata": metadata ?? ""
                                                   ])
                                               } else {
                                                   self.updateDoneUpload(success: false, metadata:"")
                                                   call.reject("Failed")
                                               }
                                           }
                        }
                    }
                    
                    handleNextChunk(accessToken:accessToken,offset: offset,targetPath:targetPath)
                
                }
                
                
            }
        }
        
    }
    
    @objc func uploadFile(_ call: CAPPluginCall) {
        guard let fileUri = call.getString("uri"),
              let accessToken = call.getString("accessToken"),
              let targetPath = call.getString("targetPath"),
              let url = URL(string: fileUri) else {
            call.reject("Invalid arguments")
            return
        }
        
        guard let fileData = try? Data(contentsOf: url) else {
            call.reject("Cannot load file data")
            return
        }
        
        // start upload session
        let req_url = URL(string: "https://content.dropboxapi.com/2/files/upload")!
        var request = URLRequest(url: req_url)
        request.httpMethod = "POST"
        request.addValue("Bearer " + accessToken, forHTTPHeaderField: "Authorization")
        request.addValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.addValue("{\"path\": \"\(targetPath)\",\"mode\": \"add\",\"autorename\": true,\"mute\": false,\"strict_conflict\": false}", forHTTPHeaderField: "Dropbox-API-Arg")
 
        
        let task = URLSession.shared.uploadTask(with: request, from: fileData) { data, response, error in
                    if let error = error {
                        call.reject("Upload failed: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode == 200 else {
                        call.reject("Upload failed with status: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                        return
                    }
                    
                    if let data = data, let result = String(data: data, encoding: .utf8) {
                        self.updateDoneUpload(success: true, metadata: result)
                        call.resolve([
                            "success": true,
                            "message": "File uploaded successfully",
                            "metadata": result
                        ])
                    } else {
                        self.updateDoneUpload(success: false, metadata: "")
                        call.reject("No response data")
                    }
                }
                
                task.resume()
    }
    
}
