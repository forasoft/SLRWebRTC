/*
 *  Copyright 2017 The WebRTC project authors. All Rights Reserved.
 *
 *  Use of this source code is governed by a BSD-style license
 *  that can be found in the LICENSE file in the root of the source
 *  tree. An additional intellectual property rights grant can be found
 *  in the file PATENTS.  All contributing project authors may
 *  be found in the AUTHORS file in the root of the source tree.
 */

#import <Foundation/Foundation.h>

#import "SLRRTCMacros.h"
#import "SLRRTCVideoDecoder.h"

RTC_OBJC_EXPORT
@interface SLRRTCVideoDecoderVP8 : NSObject

/* This returns a VP8 decoder that can be returned from a SLRRTCVideoDecoderFactory injected into
 * SLRRTCPeerConnectionFactory. Even though it implements the SLRRTCVideoDecoder protocol, it can not be
 * used independently from the SLRRTCPeerConnectionFactory.
 */
+ (id<SLRRTCVideoDecoder>)vp8Decoder;

@end
