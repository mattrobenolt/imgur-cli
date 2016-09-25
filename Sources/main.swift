import Foundation
import AppKit

func usage(_ code: Int32) {
    print("Usage: \(CommandLine.arguments[0]) [OPTIONS]\n")
    print("  Upload image data from your clipboard to imgur.\n")
    print("Options:")
    print("  --help/-h  Show this message and exit.")
    print("  --no-copy  Don't copy link to your clipboard.")
    exit(code)
}

var noCopy = false

for argument in CommandLine.arguments[1..<CommandLine.arguments.count] {
    switch argument {
    case "--help", "-h":
        usage(0)
    case "--no-copy":
        noCopy = true
    default:
        usage(1)
    }
}

let pasteboard = NSPasteboard.general()
if !NSImage.canInit(with: pasteboard) {
    print("!! No image data found in clipboard")
    exit(1)
}

// Extract raw image data from our pasteboard
let img = NSImage.init(pasteboard: pasteboard)!
let data = NSBitmapImageRep.representationOfImageReps(in: img.representations, using: NSPNGFileType, properties: [:])!

// Construct our request to Imgur
let clientId = "664b31512623737"  // This isn't super secret, so let's just bake it in
let url = URL(string: "https://api.imgur.com/3/image")!
let request = NSMutableURLRequest.init(url: url)
request.httpMethod = "POST"
request.addValue("Client-ID " + clientId, forHTTPHeaderField: "Authorization")

// We have to hand craft our multipart form request to upload the image data
let boundary = NSUUID().uuidString
request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

let body = NSMutableData()
body.append("--\(boundary)\r\n".data(using: .utf8)!)
body.append("Content-Disposition: form-data; name=\"image\"\r\n\r\n".data(using: .utf8)!)
body.append(data)
body.append("\r\n".data(using: .utf8)!)
body.append("--\(boundary)--\r\n".data(using: .utf8)!)
request.httpBody = body as Data

// Create a semaphore so we can wait for the asynchronous http request to finish
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

        print(link)

        if !noCopy {
            pasteboard.clearContents()
            pasteboard.setString(link, forType: NSStringPboardType)
            print("> Copied to clipboard!")
        }
    } catch let error as NSError {
        print("!! oops: \(error)")
        exit(1)
    }

    semaphore.signal()
}

// Start the async task and wait for completion before shutting down.
task.resume()
semaphore.wait()
