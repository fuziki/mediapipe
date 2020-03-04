//
//  NSObject+MediapipeHandTracker.h
//  HandTrackingGpuFramework
//
//  Created by fuziki on 2020/03/03.
//

#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>

NS_ASSUME_NONNULL_BEGIN

@interface MediapipeHandTrackerLandmark: NSObject
@property(nonatomic) float x, y, z;
- (id)initWithX:(float)x y:(float)y z:(float)z;
@end

typedef void(^MediapipeHandTrackerBlock)(NSArray<MediapipeHandTrackerLandmark *> *);
@interface MediapipeHandTracker : NSObject
- (instancetype)init;
- (void)startGraph;
- (void)sendPixelBuffer:(CVPixelBufferRef)imageBuffer;
- (void)didOutputLandmark:(void (^)(NSArray<MediapipeHandTrackerLandmark *> *))block;
@end

NS_ASSUME_NONNULL_END

