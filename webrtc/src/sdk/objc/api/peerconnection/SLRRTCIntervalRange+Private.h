/*
 *  Copyright 2017 The WebRTC project authors. All Rights Reserved.
 *
 *  Use of this source code is governed by a BSD-style license
 *  that can be found in the LICENSE file in the root of the source
 *  tree. An additional intellectual property rights grant can be found
 *  in the file PATENTS.  All contributing project authors may
 *  be found in the AUTHORS file in the root of the source tree.
 */

#import "SLRRTCIntervalRange.h"

#include "rtc_base/time_utils.h"

NS_ASSUME_NONNULL_BEGIN

@interface SLRRTCIntervalRange ()

@property(nonatomic, readonly) std::unique_ptr<rtc::IntervalRange> nativeIntervalRange;

- (instancetype)initWithNativeIntervalRange:(const rtc::IntervalRange &)config;

@end

NS_ASSUME_NONNULL_END
