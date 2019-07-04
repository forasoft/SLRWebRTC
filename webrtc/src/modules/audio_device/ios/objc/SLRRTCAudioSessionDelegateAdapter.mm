/*
 *  Copyright 2016 The WebRTC Project Authors. All rights reserved.
 *
 *  Use of this source code is governed by a BSD-style license
 *  that can be found in the LICENSE file in the root of the source
 *  tree. An additional intellectual property rights grant can be found
 *  in the file PATENTS.  All contributing project authors may
 *  be found in the AUTHORS file in the root of the source tree.
 */

#import "modules/audio_device/ios/objc/SLRRTCAudioSessionDelegateAdapter.h"

#include "modules/audio_device/ios/audio_session_observer.h"

#import "sdk/objc/base/SLRRTCLogging.h"

@implementation SLRRTCAudioSessionDelegateAdapter {
  webrtc::AudioSessionObserver *_observer;
}

- (instancetype)initWithObserver:(webrtc::AudioSessionObserver *)observer {
  NSParameterAssert(observer);
  if (self = [super init]) {
    _observer = observer;
  }
  return self;
}

#pragma mark - SLRRTCAudioSessionDelegate

- (void)audioSessionDidBeginInterruption:(SLRRTCAudioSession *)session {
  _observer->OnInterruptionBegin();
}

- (void)audioSessionDidEndInterruption:(SLRRTCAudioSession *)session
                   shouldResumeSession:(BOOL)shouldResumeSession {
  _observer->OnInterruptionEnd();
}

- (void)audioSessionDidChangeRoute:(SLRRTCAudioSession *)session
           reason:(AVAudioSessionRouteChangeReason)reason
    previousRoute:(AVAudioSessionRouteDescription *)previousRoute {
  switch (reason) {
    case AVAudioSessionRouteChangeReasonUnknown:
    case AVAudioSessionRouteChangeReasonNewDeviceAvailable:
    case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
    case AVAudioSessionRouteChangeReasonCategoryChange:
      // It turns out that we see a category change (at least in iOS 9.2)
      // when making a switch from a BT device to e.g. Speaker using the
      // iOS Control Center and that we therefore must check if the sample
      // rate has changed. And if so is the case, restart the audio unit.
    case AVAudioSessionRouteChangeReasonOverride:
    case AVAudioSessionRouteChangeReasonWakeFromSleep:
    case AVAudioSessionRouteChangeReasonNoSuitableRouteForCategory:
      _observer->OnValidRouteChange();
      break;
    case AVAudioSessionRouteChangeReasonRouteConfigurationChange:
      // The set of input and output ports has not changed, but their
      // configuration has, e.g., a port’s selected data source has
      // changed. Ignore this type of route change since we are focusing
      // on detecting headset changes.
      SLRRTCLog(@"Ignoring RouteConfigurationChange");
      break;
  }
}

- (void)audioSessionMediaServerTerminated:(SLRRTCAudioSession *)session {
}

- (void)audioSessionMediaServerReset:(SLRRTCAudioSession *)session {
}

- (void)audioSession:(SLRRTCAudioSession *)session
    didChangeCanPlayOrRecord:(BOOL)canPlayOrRecord {
  _observer->OnCanPlayOrRecordChange(canPlayOrRecord);
}

- (void)audioSessionDidStartPlayOrRecord:(SLRRTCAudioSession *)session {
}

- (void)audioSessionDidStopPlayOrRecord:(SLRRTCAudioSession *)session {
}

- (void)audioSession:(SLRRTCAudioSession *)audioSession
    didChangeOutputVolume:(float)outputVolume {
  _observer->OnChangedOutputVolume();
}

@end
