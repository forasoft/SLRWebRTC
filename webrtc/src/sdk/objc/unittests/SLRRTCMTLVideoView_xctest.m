/*
 *  Copyright 2017 The WebRTC project authors. All Rights Reserved.
 *
 *  Use of this source code is governed by a BSD-style license
 *  that can be found in the LICENSE file in the root of the source
 *  tree. An additional intellectual property rights grant can be found
 *  in the file PATENTS.  All contributing project authors may
 *  be found in the AUTHORS file in the root of the source tree.
 */

#import <XCTest/XCTest.h>

#import <Foundation/Foundation.h>
#import <MetalKit/MetalKit.h>
#import <OCMock/OCMock.h>

#import "components/renderer/metal/SLRRTCMTLVideoView.h"

#import "api/video_frame_buffer/SLRRTCNativeI420Buffer.h"
#import "base/SLRRTCVideoFrameBuffer.h"
#import "components/renderer/metal/SLRRTCMTLNV12Renderer.h"
#import "components/video_frame_buffer/SLRRTCCVPixelBuffer.h"

// Extension of SLRRTCMTLVideoView for testing purposes.
@interface SLRRTCMTLVideoView (Testing)

+ (BOOL)isMetalAvailable;
+ (UIView *)createMetalView:(CGRect)frame;
+ (id<SLRRTCMTLRenderer>)createNV12Renderer;
+ (id<SLRRTCMTLRenderer>)createI420Renderer;
- (void)drawInMTKView:(id)view;
@end

@interface SLRRTCMTLVideoViewTests : XCTestCase
@property(nonatomic, strong) id classMock;
@property(nonatomic, strong) id rendererNV12Mock;
@property(nonatomic, strong) id rendererI420Mock;
@property(nonatomic, strong) id frameMock;
@end

@implementation SLRRTCMTLVideoViewTests

@synthesize classMock = _classMock;
@synthesize rendererNV12Mock = _rendererNV12Mock;
@synthesize rendererI420Mock = _rendererI420Mock;
@synthesize frameMock = _frameMock;

- (void)setUp {
  self.classMock = OCMClassMock([SLRRTCMTLVideoView class]);
  [self startMockingNilView];
}

- (void)tearDown {
  [self.classMock stopMocking];
  [self.rendererI420Mock stopMocking];
  [self.rendererNV12Mock stopMocking];
  [self.frameMock stopMocking];
  self.classMock = nil;
  self.rendererI420Mock = nil;
  self.rendererNV12Mock = nil;
  self.frameMock = nil;
}

- (id)frameMockWithCVPixelBuffer:(BOOL)hasCVPixelBuffer {
  id frameMock = OCMClassMock([SLRRTCVideoFrame class]);
  if (hasCVPixelBuffer) {
    CVPixelBufferRef pixelBufferRef;
    CVPixelBufferCreate(
        kCFAllocatorDefault, 200, 200, kCVPixelFormatType_420YpCbCr8Planar, nil, &pixelBufferRef);
    OCMStub([frameMock buffer])
        .andReturn([[SLRRTCCVPixelBuffer alloc] initWithPixelBuffer:pixelBufferRef]);
  } else {
    OCMStub([frameMock buffer]).andReturn([[SLRRTCI420Buffer alloc] initWithWidth:200 height:200]);
  }
  OCMStub([frameMock timeStampNs]).andReturn(arc4random_uniform(INT_MAX));
  return frameMock;
}

- (id)rendererMockWithSuccessfulSetup:(BOOL)success {
  id rendererMock = OCMClassMock([SLRRTCMTLRenderer class]);
  OCMStub([rendererMock addRenderingDestination:[OCMArg any]]).andReturn(success);
  return rendererMock;
}

- (void)startMockingNilView {
  // Use OCMock 2 syntax here until OCMock is upgraded to 3.4
  [[[self.classMock stub] andReturn:nil] createMetalView:CGRectZero];
}

#pragma mark - Test cases

- (void)testInitAssertsIfMetalUnavailabe {
  // given
  OCMStub([self.classMock isMetalAvailable]).andReturn(NO);

  // when
  BOOL asserts = NO;
  @try {
    SLRRTCMTLVideoView *realView = [[SLRRTCMTLVideoView alloc] initWithFrame:CGRectZero];
    (void)realView;
  } @catch (NSException *ex) {
    asserts = YES;
  }

  XCTAssertTrue(asserts);
}

- (void)testRTCVideoRenderNilFrameCallback {
  // given
  OCMStub([self.classMock isMetalAvailable]).andReturn(YES);

  SLRRTCMTLVideoView *realView = [[SLRRTCMTLVideoView alloc] init];
  self.frameMock = OCMClassMock([SLRRTCVideoFrame class]);

  [[self.frameMock reject] buffer];
  [[self.classMock reject] createNV12Renderer];
  [[self.classMock reject] createI420Renderer];

  // when
  [realView renderFrame:nil];
  [realView drawInMTKView:nil];

  // then
  [self.frameMock verify];
  [self.classMock verify];
}

- (void)testRTCVideoRenderFrameCallbackI420 {
  // given
  OCMStub([self.classMock isMetalAvailable]).andReturn(YES);
  self.rendererI420Mock = [self rendererMockWithSuccessfulSetup:YES];
  self.frameMock = [self frameMockWithCVPixelBuffer:NO];

  OCMExpect([self.rendererI420Mock drawFrame:self.frameMock]);
  OCMExpect([self.classMock createI420Renderer]).andReturn(self.rendererI420Mock);
  [[self.classMock reject] createNV12Renderer];

  SLRRTCMTLVideoView *realView = [[SLRRTCMTLVideoView alloc] init];

  // when
  [realView renderFrame:self.frameMock];
  [realView drawInMTKView:nil];

  // then
  [self.rendererI420Mock verify];
  [self.classMock verify];
}

- (void)testRTCVideoRenderFrameCallbackNV12 {
  // given
  OCMStub([self.classMock isMetalAvailable]).andReturn(YES);
  self.rendererNV12Mock = [self rendererMockWithSuccessfulSetup:YES];
  self.frameMock = [self frameMockWithCVPixelBuffer:YES];

  OCMExpect([self.rendererNV12Mock drawFrame:self.frameMock]);
  OCMExpect([self.classMock createNV12Renderer]).andReturn(self.rendererNV12Mock);
  [[self.classMock reject] createI420Renderer];

  SLRRTCMTLVideoView *realView = [[SLRRTCMTLVideoView alloc] init];

  // when
  [realView renderFrame:self.frameMock];
  [realView drawInMTKView:nil];

  // then
  [self.rendererNV12Mock verify];
  [self.classMock verify];
}

- (void)testRTCVideoRenderWorksAfterReconstruction {
  OCMStub([self.classMock isMetalAvailable]).andReturn(YES);
  self.rendererNV12Mock = [self rendererMockWithSuccessfulSetup:YES];
  self.frameMock = [self frameMockWithCVPixelBuffer:YES];

  OCMExpect([self.rendererNV12Mock drawFrame:self.frameMock]);
  OCMExpect([self.classMock createNV12Renderer]).andReturn(self.rendererNV12Mock);
  [[self.classMock reject] createI420Renderer];

  SLRRTCMTLVideoView *realView = [[SLRRTCMTLVideoView alloc] init];

  [realView renderFrame:self.frameMock];
  [realView drawInMTKView:nil];
  [self.rendererNV12Mock verify];
  [self.classMock verify];

  // Recreate view.
  realView = [[SLRRTCMTLVideoView alloc] init];
  OCMExpect([self.rendererNV12Mock drawFrame:self.frameMock]);
  // View hould reinit renderer.
  OCMExpect([self.classMock createNV12Renderer]).andReturn(self.rendererNV12Mock);

  [realView renderFrame:self.frameMock];
  [realView drawInMTKView:nil];
  [self.rendererNV12Mock verify];
  [self.classMock verify];
}

- (void)testDontRedrawOldFrame {
  OCMStub([self.classMock isMetalAvailable]).andReturn(YES);
  self.rendererNV12Mock = [self rendererMockWithSuccessfulSetup:YES];
  self.frameMock = [self frameMockWithCVPixelBuffer:YES];

  OCMExpect([self.rendererNV12Mock drawFrame:self.frameMock]);
  OCMExpect([self.classMock createNV12Renderer]).andReturn(self.rendererNV12Mock);
  [[self.classMock reject] createI420Renderer];

  SLRRTCMTLVideoView *realView = [[SLRRTCMTLVideoView alloc] init];
  [realView renderFrame:self.frameMock];
  [realView drawInMTKView:nil];

  [self.rendererNV12Mock verify];
  [self.classMock verify];

  [[self.rendererNV12Mock reject] drawFrame:[OCMArg any]];

  [realView renderFrame:self.frameMock];
  [realView drawInMTKView:nil];

  [self.rendererNV12Mock verify];
}

- (void)testDoDrawNewFrame {
  OCMStub([self.classMock isMetalAvailable]).andReturn(YES);
  self.rendererNV12Mock = [self rendererMockWithSuccessfulSetup:YES];
  self.frameMock = [self frameMockWithCVPixelBuffer:YES];

  OCMExpect([self.rendererNV12Mock drawFrame:self.frameMock]);
  OCMExpect([self.classMock createNV12Renderer]).andReturn(self.rendererNV12Mock);
  [[self.classMock reject] createI420Renderer];

  SLRRTCMTLVideoView *realView = [[SLRRTCMTLVideoView alloc] init];
  [realView renderFrame:self.frameMock];
  [realView drawInMTKView:nil];

  [self.rendererNV12Mock verify];
  [self.classMock verify];

  // Get new frame.
  self.frameMock = [self frameMockWithCVPixelBuffer:YES];
  OCMExpect([self.rendererNV12Mock drawFrame:self.frameMock]);

  [realView renderFrame:self.frameMock];
  [realView drawInMTKView:nil];

  [self.rendererNV12Mock verify];
}

- (void)testReportsSizeChangesToDelegate {
  OCMStub([self.classMock isMetalAvailable]).andReturn(YES);

  id delegateMock = OCMProtocolMock(@protocol(SLRRTCVideoViewDelegate));
  CGSize size = CGSizeMake(640, 480);
  OCMExpect([delegateMock videoView:[OCMArg any] didChangeVideoSize:size]);

  SLRRTCMTLVideoView *realView = [[SLRRTCMTLVideoView alloc] init];
  realView.delegate = delegateMock;
  [realView setSize:size];

  // Delegate method is invoked with a dispatch_async.
  OCMVerifyAllWithDelay(delegateMock, 1);
}

- (void)testSetContentMode {
  OCMStub([self.classMock isMetalAvailable]).andReturn(YES);
  id metalKitView = OCMClassMock([MTKView class]);
  [[[[self.classMock stub] ignoringNonObjectArgs] andReturn:metalKitView]
      createMetalView:CGRectZero];
  OCMExpect([metalKitView setContentMode:UIViewContentModeScaleAspectFill]);

  SLRRTCMTLVideoView *realView = [[SLRRTCMTLVideoView alloc] init];
  [realView setVideoContentMode:UIViewContentModeScaleAspectFill];

  OCMVerify(metalKitView);
}

@end
