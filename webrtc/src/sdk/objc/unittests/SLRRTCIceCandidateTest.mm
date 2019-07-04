/*
 *  Copyright 2015 The WebRTC project authors. All Rights Reserved.
 *
 *  Use of this source code is governed by a BSD-style license
 *  that can be found in the LICENSE file in the root of the source
 *  tree. An additional intellectual property rights grant can be found
 *  in the file PATENTS.  All contributing project authors may
 *  be found in the AUTHORS file in the root of the source tree.
 */

#import <Foundation/Foundation.h>

#include <memory>

#include "rtc_base/gunit.h"

#import "api/peerconnection/SLRRTCIceCandidate+Private.h"
#import "api/peerconnection/SLRRTCIceCandidate.h"
#import "helpers/NSString+StdString.h"

@interface SLRRTCIceCandidateTest : NSObject
- (void)testCandidate;
- (void)testInitFromNativeCandidate;
@end

@implementation SLRRTCIceCandidateTest

- (void)testCandidate {
  NSString *sdp = @"candidate:4025901590 1 udp 2122265343 "
                   "fdff:2642:12a6:fe38:c001:beda:fcf9:51aa "
                   "59052 typ host generation 0";

  SLRRTCIceCandidate *candidate = [[SLRRTCIceCandidate alloc] initWithSdp:sdp
                                                      sdpMLineIndex:0
                                                             sdpMid:@"audio"];

  std::unique_ptr<webrtc::IceCandidateInterface> nativeCandidate =
      candidate.nativeCandidate;
  EXPECT_EQ("audio", nativeCandidate->sdp_mid());
  EXPECT_EQ(0, nativeCandidate->sdp_mline_index());

  std::string sdpString;
  nativeCandidate->ToString(&sdpString);
  EXPECT_EQ(sdp.stdString, sdpString);
}

- (void)testInitFromNativeCandidate {
  std::string sdp("candidate:4025901590 1 udp 2122265343 "
                  "fdff:2642:12a6:fe38:c001:beda:fcf9:51aa "
                  "59052 typ host generation 0");
  webrtc::IceCandidateInterface *nativeCandidate =
      webrtc::CreateIceCandidate("audio", 0, sdp, nullptr);

  SLRRTCIceCandidate *iceCandidate =
      [[SLRRTCIceCandidate alloc] initWithNativeCandidate:nativeCandidate];
  EXPECT_TRUE([@"audio" isEqualToString:iceCandidate.sdpMid]);
  EXPECT_EQ(0, iceCandidate.sdpMLineIndex);

  EXPECT_EQ(sdp, iceCandidate.sdp.stdString);
}

@end

TEST(SLRRTCIceCandidateTest, CandidateTest) {
  @autoreleasepool {
    SLRRTCIceCandidateTest *test = [[SLRRTCIceCandidateTest alloc] init];
    [test testCandidate];
  }
}

TEST(SLRRTCIceCandidateTest, InitFromCandidateTest) {
  @autoreleasepool {
    SLRRTCIceCandidateTest *test = [[SLRRTCIceCandidateTest alloc] init];
    [test testInitFromNativeCandidate];
  }
}
