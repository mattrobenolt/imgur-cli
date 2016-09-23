import Foundation
import AppKit

let pasteboard = NSPasteboard.general()

if !NSImage.canInit(with: pasteboard) {
    print("!! No image data found in clipboard")
    exit(1)
}

let img = NSImage.init(pasteboard: pasteboard)!
let data = NSBitmapImageRep.representationOfImageReps(in: img.representations, using: NSPNGFileType, properties: [:])!

let clientId = "664b31512623737"
let url = URL(string: "https://api.imgur.com/3/image")!
let request = NSMutableURLRequest.init(url: url)

let boundary = NSUUID().uuidString
request.httpMethod = "POST"
request.addValue("Client-ID " + clientId, forHTTPHeaderField: "Authorization")
request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

let body = NSMutableData()
body.append("--\(boundary)\r\n".data(using: .utf8)!)
body.append("Content-Disposition: form-data; name=\"image\"\r\n\r\n".data(using: .utf8)!)
body.append(data)
body.append("\r\n".data(using: .utf8)!)
body.append("--\(boundary)--\r\n".data(using: .utf8)!)

request.httpBody = body as Data

let semaphore = DispatchSemaphore.init(value: 0)
let task = URLSession.shared.dataTask(with: request as URLRequest) { data, response, error in
    guard let data = data, error == nil else {
        print("!! oops: \(error)")
        exit(1)
    }

    if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {
        print("!! unexpected response: \(response)")
        exit(1)
    }

    do {
        let json = try JSONSerialization.jsonObject(with: data)
        // lol idgaf
        let link = (((json as! [String: Any])["data"] as! [String: Any])["link"]! as! String).replacingOccurrences(of: "http://", with: "https://")
        pasteboard.clearContents()
        pasteboard.setString(link, forType: NSStringPboardType)
        print(link)
    } catch let error as NSError {
        print("!! oops: \(error)")
        exit(1)
    }

    semaphore.signal()
}
task.resume()
semaphore.wait()
