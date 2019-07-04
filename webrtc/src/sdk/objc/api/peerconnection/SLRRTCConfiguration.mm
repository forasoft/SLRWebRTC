/*
 *  Copyright 2015 The WebRTC project authors. All Rights Reserved.
 *
 *  Use of this source code is governed by a BSD-style license
 *  that can be found in the LICENSE file in the root of the source
 *  tree. An additional intellectual property rights grant can be found
 *  in the file PATENTS.  All contributing project authors may
 *  be found in the AUTHORS file in the root of the source tree.
 */

#import "SLRRTCConfiguration+Private.h"

#include <memory>

#import "SLRRTCCertificate.h"
#import "SLRRTCConfiguration+Native.h"
#import "SLRRTCIceServer+Private.h"
#import "SLRRTCIntervalRange+Private.h"
#import "base/SLRRTCLogging.h"

#include "rtc_base/rtc_certificate_generator.h"
#include "rtc_base/ssl_identity.h"

@implementation SLRRTCConfiguration

@synthesize iceServers = _iceServers;
@synthesize certificate = _certificate;
@synthesize iceTransportPolicy = _iceTransportPolicy;
@synthesize bundlePolicy = _bundlePolicy;
@synthesize rtcpMuxPolicy = _rtcpMuxPolicy;
@synthesize tcpCandidatePolicy = _tcpCandidatePolicy;
@synthesize candidateNetworkPolicy = _candidateNetworkPolicy;
@synthesize continualGatheringPolicy = _continualGatheringPolicy;
@synthesize disableIPV6 = _disableIPV6;
@synthesize disableIPV6OnWiFi = _disableIPV6OnWiFi;
@synthesize maxIPv6Networks = _maxIPv6Networks;
@synthesize disableLinkLocalNetworks = _disableLinkLocalNetworks;
@synthesize audioJitterBufferMaxPackets = _audioJitterBufferMaxPackets;
@synthesize audioJitterBufferFastAccelerate = _audioJitterBufferFastAccelerate;
@synthesize iceConnectionReceivingTimeout = _iceConnectionReceivingTimeout;
@synthesize iceBackupCandidatePairPingInterval =
    _iceBackupCandidatePairPingInterval;
@synthesize keyType = _keyType;
@synthesize iceCandidatePoolSize = _iceCandidatePoolSize;
@synthesize shouldPruneTurnPorts = _shouldPruneTurnPorts;
@synthesize shouldPresumeWritableWhenFullyRelayed =
    _shouldPresumeWritableWhenFullyRelayed;
@synthesize iceCheckMinInterval = _iceCheckMinInterval;
@synthesize iceRegatherIntervalRange = _iceRegatherIntervalRange;
@synthesize sdpSemantics = _sdpSemantics;
@synthesize turnCustomizer = _turnCustomizer;
@synthesize activeResetSrtpParams = _activeResetSrtpParams;
@synthesize useMediaTransport = _useMediaTransport;
@synthesize useMediaTransportForDataChannels = _useMediaTransportForDataChannels;
@synthesize cryptoOptions = _cryptoOptions;
@synthesize rtcpAudioReportIntervalMs = _rtcpAudioReportIntervalMs;
@synthesize rtcpVideoReportIntervalMs = _rtcpVideoReportIntervalMs;

- (instancetype)init {
  // Copy defaults.
  webrtc::PeerConnectionInterface::RTCConfiguration config;
  return [self initWithNativeConfiguration:config];
}

- (instancetype)initWithNativeConfiguration:
    (const webrtc::PeerConnectionInterface::RTCConfiguration &)config {
  if (self = [super init]) {
    NSMutableArray *iceServers = [NSMutableArray array];
    for (const webrtc::PeerConnectionInterface::IceServer& server : config.servers) {
      SLRRTCIceServer *iceServer = [[SLRRTCIceServer alloc] initWithNativeServer:server];
      [iceServers addObject:iceServer];
    }
    _iceServers = iceServers;
    if (!config.certificates.empty()) {
      rtc::scoped_refptr<rtc::RTCCertificate> native_cert;
      native_cert = config.certificates[0];
      rtc::RTCCertificatePEM native_pem = native_cert->ToPEM();
      _certificate =
          [[SLRRTCCertificate alloc] initWithPrivateKey:@(native_pem.private_key().c_str())
                                         certificate:@(native_pem.certificate().c_str())];
    }
    _iceTransportPolicy =
        [[self class] transportPolicyForTransportsType:config.type];
    _bundlePolicy =
        [[self class] bundlePolicyForNativePolicy:config.bundle_policy];
    _rtcpMuxPolicy =
        [[self class] rtcpMuxPolicyForNativePolicy:config.rtcp_mux_policy];
    _tcpCandidatePolicy = [[self class] tcpCandidatePolicyForNativePolicy:
        config.tcp_candidate_policy];
    _candidateNetworkPolicy = [[self class]
        candidateNetworkPolicyForNativePolicy:config.candidate_network_policy];
    webrtc::PeerConnectionInterface::ContinualGatheringPolicy nativePolicy =
    config.continual_gathering_policy;
    _continualGatheringPolicy =
        [[self class] continualGatheringPolicyForNativePolicy:nativePolicy];
    _disableIPV6 = config.disable_ipv6;
    _disableIPV6OnWiFi = config.disable_ipv6_on_wifi;
    _maxIPv6Networks = config.max_ipv6_networks;
    _disableLinkLocalNetworks = config.disable_link_local_networks;
    _audioJitterBufferMaxPackets = config.audio_jitter_buffer_max_packets;
    _audioJitterBufferFastAccelerate = config.audio_jitter_buffer_fast_accelerate;
    _iceConnectionReceivingTimeout = config.ice_connection_receiving_timeout;
    _iceBackupCandidatePairPingInterval =
        config.ice_backup_candidate_pair_ping_interval;
    _useMediaTransport = config.use_media_transport;
    _useMediaTransportForDataChannels = config.use_media_transport_for_data_channels;
    _keyType = SLRRTCEncryptionKeyTypeECDSA;
    _iceCandidatePoolSize = config.ice_candidate_pool_size;
    _shouldPruneTurnPorts = config.prune_turn_ports;
    _shouldPresumeWritableWhenFullyRelayed =
        config.presume_writable_when_fully_relayed;
    if (config.ice_check_min_interval) {
      _iceCheckMinInterval =
          [NSNumber numberWithInt:*config.ice_check_min_interval];
    }
    if (config.ice_regather_interval_range) {
      const rtc::IntervalRange &nativeIntervalRange = config.ice_regather_interval_range.value();
      _iceRegatherIntervalRange =
          [[SLRRTCIntervalRange alloc] initWithNativeIntervalRange:nativeIntervalRange];
    }
    _sdpSemantics = [[self class] sdpSemanticsForNativeSdpSemantics:config.sdp_semantics];
    _turnCustomizer = config.turn_customizer;
    _activeResetSrtpParams = config.active_reset_srtp_params;
    if (config.crypto_options) {
      _cryptoOptions = [[SLRRTCCryptoOptions alloc]
               initWithSrtpEnableGcmCryptoSuites:config.crypto_options->srtp
                                                     .enable_gcm_crypto_suites
             srtpEnableAes128Sha1_32CryptoCipher:config.crypto_options->srtp
                                                     .enable_aes128_sha1_32_crypto_cipher
          srtpEnableEncryptedRtpHeaderExtensions:config.crypto_options->srtp
                                                     .enable_encrypted_rtp_header_extensions
                    sframeRequireFrameEncryption:config.crypto_options->sframe
                                                     .require_frame_encryption];
    }
    _rtcpAudioReportIntervalMs = config.audio_rtcp_report_interval_ms();
    _rtcpVideoReportIntervalMs = config.video_rtcp_report_interval_ms();
  }
  return self;
}

- (NSString *)description {
  static NSString *formatString = @"SLRRTCConfiguration: "
                                  @"{\n%@\n%@\n%@\n%@\n%@\n%@\n%@\n%@\n%d\n%d\n%d\n%d\n%d\n%d\n"
                                  @"%d\n%@\n%@\n%d\n%d\n%d\n%d\n%d\n%@\n}\n";

  return [NSString
      stringWithFormat:formatString,
                       _iceServers,
                       [[self class] stringForTransportPolicy:_iceTransportPolicy],
                       [[self class] stringForBundlePolicy:_bundlePolicy],
                       [[self class] stringForRtcpMuxPolicy:_rtcpMuxPolicy],
                       [[self class] stringForTcpCandidatePolicy:_tcpCandidatePolicy],
                       [[self class] stringForCandidateNetworkPolicy:_candidateNetworkPolicy],
                       [[self class] stringForContinualGatheringPolicy:_continualGatheringPolicy],
                       [[self class] stringForSdpSemantics:_sdpSemantics],
                       _audioJitterBufferMaxPackets,
                       _audioJitterBufferFastAccelerate,
                       _iceConnectionReceivingTimeout,
                       _iceBackupCandidatePairPingInterval,
                       _iceCandidatePoolSize,
                       _shouldPruneTurnPorts,
                       _shouldPresumeWritableWhenFullyRelayed,
                       _iceCheckMinInterval,
                       _iceRegatherIntervalRange,
                       _disableLinkLocalNetworks,
                       _disableIPV6,
                       _disableIPV6OnWiFi,
                       _maxIPv6Networks,
                       _activeResetSrtpParams,
                       _useMediaTransport];
}

#pragma mark - Private

- (webrtc::PeerConnectionInterface::RTCConfiguration *)
    createNativeConfiguration {
  std::unique_ptr<webrtc::PeerConnectionInterface::RTCConfiguration>
      nativeConfig(new webrtc::PeerConnectionInterface::RTCConfiguration(
          webrtc::PeerConnectionInterface::RTCConfigurationType::kAggressive));

  for (SLRRTCIceServer *iceServer in _iceServers) {
    nativeConfig->servers.push_back(iceServer.nativeServer);
  }
  nativeConfig->type =
      [[self class] nativeTransportsTypeForTransportPolicy:_iceTransportPolicy];
  nativeConfig->bundle_policy =
      [[self class] nativeBundlePolicyForPolicy:_bundlePolicy];
  nativeConfig->rtcp_mux_policy =
      [[self class] nativeRtcpMuxPolicyForPolicy:_rtcpMuxPolicy];
  nativeConfig->tcp_candidate_policy =
      [[self class] nativeTcpCandidatePolicyForPolicy:_tcpCandidatePolicy];
  nativeConfig->candidate_network_policy = [[self class]
      nativeCandidateNetworkPolicyForPolicy:_candidateNetworkPolicy];
  nativeConfig->continual_gathering_policy = [[self class]
      nativeContinualGatheringPolicyForPolicy:_continualGatheringPolicy];
  nativeConfig->disable_ipv6 = _disableIPV6;
  nativeConfig->disable_ipv6_on_wifi = _disableIPV6OnWiFi;
  nativeConfig->max_ipv6_networks = _maxIPv6Networks;
  nativeConfig->disable_link_local_networks = _disableLinkLocalNetworks;
  nativeConfig->audio_jitter_buffer_max_packets = _audioJitterBufferMaxPackets;
  nativeConfig->audio_jitter_buffer_fast_accelerate =
      _audioJitterBufferFastAccelerate  ? true : false;
  nativeConfig->ice_connection_receiving_timeout =
      _iceConnectionReceivingTimeout;
  nativeConfig->ice_backup_candidate_pair_ping_interval =
      _iceBackupCandidatePairPingInterval;
  nativeConfig->use_media_transport = _useMediaTransport;
  nativeConfig->use_media_transport_for_data_channels = _useMediaTransportForDataChannels;
  rtc::KeyType keyType =
      [[self class] nativeEncryptionKeyTypeForKeyType:_keyType];
  if (_certificate != nullptr) {
    // if offered a pemcert use it...
    RTC_LOG(LS_INFO) << "Have configured cert - using it.";
    std::string pem_private_key = [[_certificate private_key] UTF8String];
    std::string pem_certificate = [[_certificate certificate] UTF8String];
    rtc::RTCCertificatePEM pem = rtc::RTCCertificatePEM(pem_private_key, pem_certificate);
    rtc::scoped_refptr<rtc::RTCCertificate> certificate = rtc::RTCCertificate::FromPEM(pem);
    RTC_LOG(LS_INFO) << "Created cert from PEM strings.";
    if (!certificate) {
      RTC_LOG(LS_ERROR) << "Failed to generate certificate from PEM.";
      return nullptr;
    }
    nativeConfig->certificates.push_back(certificate);
  } else {
    RTC_LOG(LS_INFO) << "Don't have configured cert.";
    // Generate non-default certificate.
    if (keyType != rtc::KT_DEFAULT) {
      rtc::scoped_refptr<rtc::RTCCertificate> certificate =
          rtc::RTCCertificateGenerator::GenerateCertificate(rtc::KeyParams(keyType),
                                                            absl::optional<uint64_t>());
      if (!certificate) {
        SLRRTCLogError(@"Failed to generate certificate.");
        return nullptr;
      }
      nativeConfig->certificates.push_back(certificate);
    }
  }
  nativeConfig->ice_candidate_pool_size = _iceCandidatePoolSize;
  nativeConfig->prune_turn_ports = _shouldPruneTurnPorts ? true : false;
  nativeConfig->presume_writable_when_fully_relayed =
      _shouldPresumeWritableWhenFullyRelayed ? true : false;
  if (_iceCheckMinInterval != nil) {
    nativeConfig->ice_check_min_interval = absl::optional<int>(_iceCheckMinInterval.intValue);
  }
  if (_iceRegatherIntervalRange != nil) {
    std::unique_ptr<rtc::IntervalRange> nativeIntervalRange(
        _iceRegatherIntervalRange.nativeIntervalRange);
    nativeConfig->ice_regather_interval_range =
        absl::optional<rtc::IntervalRange>(*nativeIntervalRange);
  }
  nativeConfig->sdp_semantics = [[self class] nativeSdpSemanticsForSdpSemantics:_sdpSemantics];
  if (_turnCustomizer) {
    nativeConfig->turn_customizer = _turnCustomizer;
  }
  nativeConfig->active_reset_srtp_params = _activeResetSrtpParams ? true : false;
  if (_cryptoOptions) {
    webrtc::CryptoOptions nativeCryptoOptions;
    nativeCryptoOptions.srtp.enable_gcm_crypto_suites =
        _cryptoOptions.srtpEnableGcmCryptoSuites ? true : false;
    nativeCryptoOptions.srtp.enable_aes128_sha1_32_crypto_cipher =
        _cryptoOptions.srtpEnableAes128Sha1_32CryptoCipher ? true : false;
    nativeCryptoOptions.srtp.enable_encrypted_rtp_header_extensions =
        _cryptoOptions.srtpEnableEncryptedRtpHeaderExtensions ? true : false;
    nativeCryptoOptions.sframe.require_frame_encryption =
        _cryptoOptions.sframeRequireFrameEncryption ? true : false;
    nativeConfig->crypto_options = absl::optional<webrtc::CryptoOptions>(nativeCryptoOptions);
  }
  nativeConfig->set_audio_rtcp_report_interval_ms(_rtcpAudioReportIntervalMs);
  nativeConfig->set_video_rtcp_report_interval_ms(_rtcpVideoReportIntervalMs);
  return nativeConfig.release();
}

+ (webrtc::PeerConnectionInterface::IceTransportsType)
    nativeTransportsTypeForTransportPolicy:(SLRRTCIceTransportPolicy)policy {
  switch (policy) {
    case SLRRTCIceTransportPolicyNone:
      return webrtc::PeerConnectionInterface::kNone;
    case SLRRTCIceTransportPolicyRelay:
      return webrtc::PeerConnectionInterface::kRelay;
    case SLRRTCIceTransportPolicyNoHost:
      return webrtc::PeerConnectionInterface::kNoHost;
    case SLRRTCIceTransportPolicyAll:
      return webrtc::PeerConnectionInterface::kAll;
  }
}

+ (SLRRTCIceTransportPolicy)transportPolicyForTransportsType:
    (webrtc::PeerConnectionInterface::IceTransportsType)nativeType {
  switch (nativeType) {
    case webrtc::PeerConnectionInterface::kNone:
      return SLRRTCIceTransportPolicyNone;
    case webrtc::PeerConnectionInterface::kRelay:
      return SLRRTCIceTransportPolicyRelay;
    case webrtc::PeerConnectionInterface::kNoHost:
      return SLRRTCIceTransportPolicyNoHost;
    case webrtc::PeerConnectionInterface::kAll:
      return SLRRTCIceTransportPolicyAll;
  }
}

+ (NSString *)stringForTransportPolicy:(SLRRTCIceTransportPolicy)policy {
  switch (policy) {
    case SLRRTCIceTransportPolicyNone:
      return @"NONE";
    case SLRRTCIceTransportPolicyRelay:
      return @"RELAY";
    case SLRRTCIceTransportPolicyNoHost:
      return @"NO_HOST";
    case SLRRTCIceTransportPolicyAll:
      return @"ALL";
  }
}

+ (webrtc::PeerConnectionInterface::BundlePolicy)nativeBundlePolicyForPolicy:
    (SLRRTCBundlePolicy)policy {
  switch (policy) {
    case SLRRTCBundlePolicyBalanced:
      return webrtc::PeerConnectionInterface::kBundlePolicyBalanced;
    case SLRRTCBundlePolicyMaxCompat:
      return webrtc::PeerConnectionInterface::kBundlePolicyMaxCompat;
    case SLRRTCBundlePolicyMaxBundle:
      return webrtc::PeerConnectionInterface::kBundlePolicyMaxBundle;
  }
}

+ (SLRRTCBundlePolicy)bundlePolicyForNativePolicy:
    (webrtc::PeerConnectionInterface::BundlePolicy)nativePolicy {
  switch (nativePolicy) {
    case webrtc::PeerConnectionInterface::kBundlePolicyBalanced:
      return SLRRTCBundlePolicyBalanced;
    case webrtc::PeerConnectionInterface::kBundlePolicyMaxCompat:
      return SLRRTCBundlePolicyMaxCompat;
    case webrtc::PeerConnectionInterface::kBundlePolicyMaxBundle:
      return SLRRTCBundlePolicyMaxBundle;
  }
}

+ (NSString *)stringForBundlePolicy:(SLRRTCBundlePolicy)policy {
  switch (policy) {
    case SLRRTCBundlePolicyBalanced:
      return @"BALANCED";
    case SLRRTCBundlePolicyMaxCompat:
      return @"MAX_COMPAT";
    case SLRRTCBundlePolicyMaxBundle:
      return @"MAX_BUNDLE";
  }
}

+ (webrtc::PeerConnectionInterface::RtcpMuxPolicy)nativeRtcpMuxPolicyForPolicy:
    (SLRRTCRtcpMuxPolicy)policy {
  switch (policy) {
    case SLRRTCRtcpMuxPolicyNegotiate:
      return webrtc::PeerConnectionInterface::kRtcpMuxPolicyNegotiate;
    case SLRRTCRtcpMuxPolicyRequire:
      return webrtc::PeerConnectionInterface::kRtcpMuxPolicyRequire;
  }
}

+ (SLRRTCRtcpMuxPolicy)rtcpMuxPolicyForNativePolicy:
    (webrtc::PeerConnectionInterface::RtcpMuxPolicy)nativePolicy {
  switch (nativePolicy) {
    case webrtc::PeerConnectionInterface::kRtcpMuxPolicyNegotiate:
      return SLRRTCRtcpMuxPolicyNegotiate;
    case webrtc::PeerConnectionInterface::kRtcpMuxPolicyRequire:
      return SLRRTCRtcpMuxPolicyRequire;
  }
}

+ (NSString *)stringForRtcpMuxPolicy:(SLRRTCRtcpMuxPolicy)policy {
  switch (policy) {
    case SLRRTCRtcpMuxPolicyNegotiate:
      return @"NEGOTIATE";
    case SLRRTCRtcpMuxPolicyRequire:
      return @"REQUIRE";
  }
}

+ (webrtc::PeerConnectionInterface::TcpCandidatePolicy)
    nativeTcpCandidatePolicyForPolicy:(SLRRTCTcpCandidatePolicy)policy {
  switch (policy) {
    case SLRRTCTcpCandidatePolicyEnabled:
      return webrtc::PeerConnectionInterface::kTcpCandidatePolicyEnabled;
    case SLRRTCTcpCandidatePolicyDisabled:
      return webrtc::PeerConnectionInterface::kTcpCandidatePolicyDisabled;
  }
}

+ (webrtc::PeerConnectionInterface::CandidateNetworkPolicy)
    nativeCandidateNetworkPolicyForPolicy:(SLRRTCCandidateNetworkPolicy)policy {
  switch (policy) {
    case SLRRTCCandidateNetworkPolicyAll:
      return webrtc::PeerConnectionInterface::kCandidateNetworkPolicyAll;
    case SLRRTCCandidateNetworkPolicyLowCost:
      return webrtc::PeerConnectionInterface::kCandidateNetworkPolicyLowCost;
  }
}

+ (SLRRTCTcpCandidatePolicy)tcpCandidatePolicyForNativePolicy:
    (webrtc::PeerConnectionInterface::TcpCandidatePolicy)nativePolicy {
  switch (nativePolicy) {
    case webrtc::PeerConnectionInterface::kTcpCandidatePolicyEnabled:
      return SLRRTCTcpCandidatePolicyEnabled;
    case webrtc::PeerConnectionInterface::kTcpCandidatePolicyDisabled:
      return SLRRTCTcpCandidatePolicyDisabled;
  }
}

+ (NSString *)stringForTcpCandidatePolicy:(SLRRTCTcpCandidatePolicy)policy {
  switch (policy) {
    case SLRRTCTcpCandidatePolicyEnabled:
      return @"TCP_ENABLED";
    case SLRRTCTcpCandidatePolicyDisabled:
      return @"TCP_DISABLED";
  }
}

+ (SLRRTCCandidateNetworkPolicy)candidateNetworkPolicyForNativePolicy:
    (webrtc::PeerConnectionInterface::CandidateNetworkPolicy)nativePolicy {
  switch (nativePolicy) {
    case webrtc::PeerConnectionInterface::kCandidateNetworkPolicyAll:
      return SLRRTCCandidateNetworkPolicyAll;
    case webrtc::PeerConnectionInterface::kCandidateNetworkPolicyLowCost:
      return SLRRTCCandidateNetworkPolicyLowCost;
  }
}

+ (NSString *)stringForCandidateNetworkPolicy:
    (SLRRTCCandidateNetworkPolicy)policy {
  switch (policy) {
    case SLRRTCCandidateNetworkPolicyAll:
      return @"CANDIDATE_ALL_NETWORKS";
    case SLRRTCCandidateNetworkPolicyLowCost:
      return @"CANDIDATE_LOW_COST_NETWORKS";
  }
}

+ (webrtc::PeerConnectionInterface::ContinualGatheringPolicy)
    nativeContinualGatheringPolicyForPolicy:
        (SLRRTCContinualGatheringPolicy)policy {
  switch (policy) {
    case SLRRTCContinualGatheringPolicyGatherOnce:
      return webrtc::PeerConnectionInterface::GATHER_ONCE;
    case SLRRTCContinualGatheringPolicyGatherContinually:
      return webrtc::PeerConnectionInterface::GATHER_CONTINUALLY;
  }
}

+ (SLRRTCContinualGatheringPolicy)continualGatheringPolicyForNativePolicy:
    (webrtc::PeerConnectionInterface::ContinualGatheringPolicy)nativePolicy {
  switch (nativePolicy) {
    case webrtc::PeerConnectionInterface::GATHER_ONCE:
      return SLRRTCContinualGatheringPolicyGatherOnce;
    case webrtc::PeerConnectionInterface::GATHER_CONTINUALLY:
      return SLRRTCContinualGatheringPolicyGatherContinually;
  }
}

+ (NSString *)stringForContinualGatheringPolicy:
    (SLRRTCContinualGatheringPolicy)policy {
  switch (policy) {
    case SLRRTCContinualGatheringPolicyGatherOnce:
      return @"GATHER_ONCE";
    case SLRRTCContinualGatheringPolicyGatherContinually:
      return @"GATHER_CONTINUALLY";
  }
}

+ (rtc::KeyType)nativeEncryptionKeyTypeForKeyType:
    (SLRRTCEncryptionKeyType)keyType {
  switch (keyType) {
    case SLRRTCEncryptionKeyTypeRSA:
      return rtc::KT_RSA;
    case SLRRTCEncryptionKeyTypeECDSA:
      return rtc::KT_ECDSA;
  }
}

+ (webrtc::SdpSemantics)nativeSdpSemanticsForSdpSemantics:(SLRRTCSdpSemantics)sdpSemantics {
  switch (sdpSemantics) {
    case SLRRTCSdpSemanticsPlanB:
      return webrtc::SdpSemantics::kPlanB;
    case SLRRTCSdpSemanticsUnifiedPlan:
      return webrtc::SdpSemantics::kUnifiedPlan;
  }
}

+ (SLRRTCSdpSemantics)sdpSemanticsForNativeSdpSemantics:(webrtc::SdpSemantics)sdpSemantics {
  switch (sdpSemantics) {
    case webrtc::SdpSemantics::kPlanB:
      return SLRRTCSdpSemanticsPlanB;
    case webrtc::SdpSemantics::kUnifiedPlan:
      return SLRRTCSdpSemanticsUnifiedPlan;
  }
}

+ (NSString *)stringForSdpSemantics:(SLRRTCSdpSemantics)sdpSemantics {
  switch (sdpSemantics) {
    case SLRRTCSdpSemanticsPlanB:
      return @"PLAN_B";
    case SLRRTCSdpSemanticsUnifiedPlan:
      return @"UNIFIED_PLAN";
  }
}

@end
