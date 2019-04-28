#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

const char *VERSION = "0.0.3";

int usage(const char *program) {
  printf("Usage: %s [OPTIONS]\n\n", program);
  printf("  Upload image data from your clipboard to imgur.\n\n");
  printf("Options:\n");
  printf("  --help/-h  Show this message and exit.\n");
  printf("  --no-copy  Don't copy link to your clipboard.\n");
  printf("  --version  Print program version and exit.\n");
  printf("\nVersion %s\n", VERSION);
  return 0;
}

void wups(NSError *error) {
  printf("!! oops: %s\n", [[error description] UTF8String]);
  exit(1);
}

int main(int argc, const char *argv[]) {
  @autoreleasepool {
    bool noCopy = false;

    for (int i = 1; i < argc; i++) {
      if (strcmp(argv[i], "--help") == 0) {
        return usage(argv[0]);
      }
      if (strcmp(argv[i], "-h") == 0) {
        return usage(argv[0]);
      }
      if (strcmp(argv[i], "--version") == 0) {
        printf("%s\n", VERSION);
        return 0;
      }
      if (strcmp(argv[i], "--no-copy") == 0) {
        noCopy = true;
        continue;
      }
    }

    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    if (![NSImage canInitWithPasteboard:pasteboard]) {
      printf("!! No image data found in clipboard\n");
      return 1;
    }

    // Extract raw image data from our pasteboard
    NSImage *image = [[NSImage alloc] initWithPasteboard:pasteboard];
    NSData *imageData =
        [NSBitmapImageRep representationOfImageRepsInArray:image.representations
                                                 usingType:NSPNGFileType
                                                properties:@{}];

    // Construct our request to Imgur
    NSString *clientId =
        @"664b31512623737"; // This isn't super secret, so let's just bake it in
    NSURL *url = [NSURL URLWithString:@"https://api.imgur.com/3/image"];
    NSMutableURLRequest *request =
        [[NSMutableURLRequest alloc] initWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:[NSString stringWithFormat:@"Client-Id %@", clientId]
        forHTTPHeaderField:@"Authorization"];
    [request setValue:@"imgur-cli" forHTTPHeaderField:@"User-Agent"];

    // We have to hand craft our multipart form request to upload the image data
    NSString *boundary = [[NSUUID UUID] UUIDString];
    [request setValue:[NSString
                          stringWithFormat:@"multipart/form-data; boundary=%@",
                                           boundary]
        forHTTPHeaderField:@"Content-Type"];

    NSMutableData *body = [[NSMutableData alloc] init];
    [body appendBytes:"--" length:2];
    [body appendData:[boundary dataUsingEncoding:NSUTF8StringEncoding]];
    [body
        appendBytes:"\r\nContent-Disposition: form-data; name=\"image\"\r\n\r\n"
             length:50];
    [body appendData:imageData];
    [body appendBytes:"\r\n--" length:4];
    [body appendData:[boundary dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendBytes:"--\r\n" length:4];
    [request setHTTPBody:body];

    // Create a semaphore so we can wait for the asynchronous http request to
    // finish
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);

    NSTask *task = [[NSURLSession sharedSession]
        dataTaskWithRequest:request
          completionHandler:^(NSData *_Nullable data,
                              NSURLResponse *_Nullable response,
                              NSError *_Nullable error) {
            if (error != nil) {
              wups(error);
            }

            if ([(NSHTTPURLResponse *)response statusCode] != 200) {
              printf("!! unexpected response: %d\n",
                     (int)[(NSHTTPURLResponse *)response statusCode]);
              exit(1);
            }

            NSError *jsonError;
            NSDictionary *json =
                [NSJSONSerialization JSONObjectWithData:data
                                                options:0
                                                  error:&jsonError];

            if (jsonError != nil) {
              wups(jsonError);
            }

            NSString *link = [json[@"data"][@"link"]
                stringByReplacingOccurrencesOfString:@"http://"
                                          withString:@"https://"];
            printf("%s\n", [link UTF8String]);

            if (!noCopy) {
              [pasteboard clearContents];
              [pasteboard setString:link forType:NSStringPboardType];
              printf("> Copied to clipboard!\n");
            }

            dispatch_semaphore_signal(sema);
          }];

    // Start the async task and wait for completion before shutting down.
    [task resume];
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
  }
  return 0;
}
