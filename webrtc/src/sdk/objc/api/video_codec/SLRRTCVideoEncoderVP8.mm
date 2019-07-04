/*
 *  Copyright (c) 2017 The WebRTC project authors. All Rights Reserved.
 *
 *  Use of this source code is governed by a BSD-style license
 *  that can be found in the LICENSE file in the root of the source
 *  tree. An additional intellectual property rights grant can be found
 *  in the file PATENTS.  All contributing project authors may
 *  be found in the AUTHORS file in the root of the source tree.
 *
 */

#import <Foundation/Foundation.h>

#import "SLRRTCVideoEncoderVP8.h"
#import "SLRRTCWrappedNativeVideoEncoder.h"

#include "modules/video_coding/codecs/vp8/include/vp8.h"

@implementation SLRRTCVideoEncoderVP8

+ (id<SLRRTCVideoEncoder>)vp8Encoder {
  return [[SLRRTCWrappedNativeVideoEncoder alloc]
      initWithNativeEncoder:std::unique_ptr<webrtc::VideoEncoder>(webrtc::VP8Encoder::Create())];
}

@end
