//
//  NSObject+MediapipeHandTracker.m
//  HandTrackingGpuFramework
//
//  Created by fuziki on 2020/03/03.
//

#import "MediapipeHandTracker.h"

#import "mediapipe/objc/MPPGraph.h"
#import "mediapipe/objc/MPPCameraInputSource.h"
#import "mediapipe/objc/MPPLayerRenderer.h"

#include "mediapipe/framework/formats/landmark.pb.h"

static NSString* const kGraphName = @"hand_tracking_mobile_gpu";

static const char* kInputStream = "input_video";
static const char* kOutputStream = "output_video";
static const char* kLandmarksOutputStream = "hand_landmarks";
//static const char* kVideoQueueLabel = "com.google.mediapipe.example.videoQueue";

@implementation MediapipeHandTrackerLandmark: NSObject
- (id)initWithX:(float)x y:(float)y z:(float)z {
    if (self = [super init])
        { self.x = x; self.y = y; self.z = z; }
    return self;
}
@end

@interface MediapipeHandTracker() <MPPGraphDelegate/*, MPPInputSourceDelegate*/>
// The MediaPipe graph currently in use. Initialized in viewDidLoad, started in viewWillAppear: and
// sent video frames on _videoQueue.
@property(nonatomic) MPPGraph* mediapipeGraph;
@property(nonatomic, nullable) MediapipeHandTrackerBlock mediapipeHandTrackerBlock;
@end

@implementation MediapipeHandTracker

#pragma mark - Cleanup methods

- (void)dealloc {
  self.mediapipeGraph.delegate = nil;
  self.mediapipeHandTrackerBlock = nil;
  [self.mediapipeGraph cancel];
  // Ignore errors since we're cleaning up.
  [self.mediapipeGraph closeAllInputStreamsWithError:nil];
  [self.mediapipeGraph waitUntilDoneWithError:nil];
}

#pragma mark - MediaPipe graph methods

+ (MPPGraph*)loadGraphFromResource:(NSString*)resource {
  // Load the graph config resource.
  NSError* configLoadError = nil;
  NSBundle* bundle = [NSBundle bundleForClass:[self class]];
  if (!resource || resource.length == 0) {
    return nil;
  }
  NSURL* graphURL = [bundle URLForResource:resource withExtension:@"binarypb"];
  NSData* data = [NSData dataWithContentsOfURL:graphURL options:0 error:&configLoadError];
  if (!data) {
    NSLog(@"Failed to load MediaPipe graph config: %@", configLoadError);
    return nil;
  }

  // Parse the graph config resource into mediapipe::CalculatorGraphConfig proto object.
  mediapipe::CalculatorGraphConfig config;
  config.ParseFromArray(data.bytes, data.length);

  // Create MediaPipe graph with mediapipe::CalculatorGraphConfig proto object.
  MPPGraph* newGraph = [[MPPGraph alloc] initWithGraphConfig:config];
  [newGraph addFrameOutputStream:kOutputStream outputPacketType:MPPPacketTypePixelBuffer];
  [newGraph addFrameOutputStream:kLandmarksOutputStream outputPacketType:MPPPacketTypeRaw];
  return newGraph;
}

- (id)init {
    if (self = [super init]) {
        self.mediapipeGraph = [[self class] loadGraphFromResource:kGraphName];
        self.mediapipeGraph.delegate = self;
        // Set maxFramesInFlight to a small value to avoid memory contention for real-time processing.
        self.mediapipeGraph.maxFramesInFlight = 2;
    }
    return self;
}

- (void)startGraph {
  // Start running self.mediapipeGraph.
  NSError* error;
  if (![self.mediapipeGraph startWithError:&error]) {
    NSLog(@"Failed to start graph: %@", error);
  }
}

- (void)sendPixelBuffer:(CVPixelBufferRef)imageBuffer {
    [self.mediapipeGraph sendPixelBuffer:imageBuffer
                              intoStream:kInputStream
                              packetType:MPPPacketTypePixelBuffer];
}

- (void)didOutputLandmark:(void (^)(NSArray<MediapipeHandTrackerLandmark *> *))block {
    self.mediapipeHandTrackerBlock = block;
}

#pragma mark - MPPGraphDelegate methods

// Receives CVPixelBufferRef from the MediaPipe graph. Invoked on a MediaPipe worker thread.
- (void)mediapipeGraph:(MPPGraph*)graph
    didOutputPixelBuffer:(CVPixelBufferRef)pixelBuffer
              fromStream:(const std::string&)streamName {
    //do nothing
    //future: add block callback
}

// Receives a raw packet from the MediaPipe graph. Invoked on a MediaPipe worker thread.
- (void)mediapipeGraph:(MPPGraph*)graph
     didOutputPacket:(const ::mediapipe::Packet&)packet
          fromStream:(const std::string&)streamName {
    if (streamName != kLandmarksOutputStream)
        return;
    if (packet.IsEmpty()) {
      NSLog(@"[TS:%lld] No hand landmarks", packet.Timestamp().Value());
      return;
    }
    const auto& landmarks = packet.Get<::mediapipe::NormalizedLandmarkList>();
    NSLog(@"[TS:%lld] Number of landmarks on hand: %d", packet.Timestamp().Value(),
          landmarks.landmark_size());
    NSMutableArray<MediapipeHandTrackerLandmark *> *resLandmarks = [NSMutableArray array];
    for (int i = 0; i < landmarks.landmark_size(); ++i) {
//        NSLog(@"\tLandmark[%d]: (%f, %f, %f)", i, landmarks.landmark(i).x(), landmarks.landmark(i).y(), landmarks.landmark(i).z());
        MediapipeHandTrackerLandmark *landmark =
            [[MediapipeHandTrackerLandmark alloc] initWithX:landmarks.landmark(i).x()
                                                          y:landmarks.landmark(i).y()
                                                          z:landmarks.landmark(i).z()];
        [resLandmarks addObject:landmark];
    }
    if (self.mediapipeHandTrackerBlock)
        self.mediapipeHandTrackerBlock(resLandmarks);
}

@end
