/*
 *  Copyright 2017 The WebRTC project authors. All Rights Reserved.
 *
 *  Use of this source code is governed by a BSD-style license
 *  that can be found in the LICENSE file in the root of the source
 *  tree. An additional intellectual property rights grant can be found
 *  in the file PATENTS.  All contributing project authors may
 *  be found in the AUTHORS file in the root of the source tree.
 */

#include "sdk/objc/native/src/objc_video_encoder_factory.h"

#include <string>

#import "base/SLRRTCVideoEncoder.h"
#import "base/SLRRTCVideoEncoderFactory.h"
#import "components/video_codec/SLRRTCCodecSpecificInfoH264+Private.h"
#import "sdk/objc/api/peerconnection/SLRRTCEncodedImage+Private.h"
#import "sdk/objc/api/peerconnection/SLRRTCRtpFragmentationHeader+Private.h"
#import "sdk/objc/api/peerconnection/SLRRTCVideoCodecInfo+Private.h"
#import "sdk/objc/api/peerconnection/SLRRTCVideoEncoderSettings+Private.h"
#import "sdk/objc/api/video_codec/SLRRTCVideoCodecConstants.h"
#import "sdk/objc/api/video_codec/SLRRTCWrappedNativeVideoEncoder.h"
#import "sdk/objc/helpers/NSString+StdString.h"

#include "api/video/video_frame.h"
#include "api/video_codecs/sdp_video_format.h"
#include "api/video_codecs/video_encoder.h"
#include "modules/include/module_common_types.h"
#include "modules/video_coding/include/video_codec_interface.h"
#include "modules/video_coding/include/video_error_codes.h"
#include "rtc_base/logging.h"
#include "sdk/objc/native/src/objc_video_frame.h"

namespace webrtc {

namespace {

class ObjCVideoEncoder : public VideoEncoder {
 public:
  ObjCVideoEncoder(id<SLRRTCVideoEncoder> encoder)
      : encoder_(encoder), implementation_name_([encoder implementationName].stdString) {}

  int32_t InitEncode(const VideoCodec *codec_settings,
                     int32_t number_of_cores,
                     size_t max_payload_size) override {
    SLRRTCVideoEncoderSettings *settings =
        [[SLRRTCVideoEncoderSettings alloc] initWithNativeVideoCodec:codec_settings];
    return [encoder_ startEncodeWithSettings:settings numberOfCores:number_of_cores];
  }

  int32_t RegisterEncodeCompleteCallback(EncodedImageCallback *callback) override {
    [encoder_ setCallback:^BOOL(SLRRTCEncodedImage *_Nonnull frame,
                                id<SLRRTCCodecSpecificInfo> _Nonnull info,
                                SLRRTCRtpFragmentationHeader *_Nonnull header) {
      EncodedImage encodedImage = [frame nativeEncodedImage];

      // Handle types that can be converted into one of CodecSpecificInfo's hard coded cases.
      CodecSpecificInfo codecSpecificInfo;
      if ([info isKindOfClass:[SLRRTCCodecSpecificInfoH264 class]]) {
        codecSpecificInfo = [(SLRRTCCodecSpecificInfoH264 *)info nativeCodecSpecificInfo];
      }

      std::unique_ptr<RTPFragmentationHeader> fragmentationHeader =
          [header createNativeFragmentationHeader];
      EncodedImageCallback::Result res =
          callback->OnEncodedImage(encodedImage, &codecSpecificInfo, fragmentationHeader.get());
      return res.error == EncodedImageCallback::Result::OK;
    }];

    return WEBRTC_VIDEO_CODEC_OK;
  }

  int32_t Release() override { return [encoder_ releaseEncoder]; }

  int32_t Encode(const VideoFrame &frame,
                 const CodecSpecificInfo *codec_specific_info,
                 const std::vector<FrameType> *frame_types) override {
    NSMutableArray<NSNumber *> *rtcFrameTypes = [NSMutableArray array];
    for (size_t i = 0; i < frame_types->size(); ++i) {
      [rtcFrameTypes addObject:@(SLRRTCFrameType(frame_types->at(i)))];
    }

    return [encoder_ encode:ToObjCVideoFrame(frame)
          codecSpecificInfo:nil
                 frameTypes:rtcFrameTypes];
  }

  int32_t SetRates(uint32_t bitrate, uint32_t framerate) override {
    return [encoder_ setBitrate:bitrate framerate:framerate];
  }

  VideoEncoder::EncoderInfo GetEncoderInfo() const override {
    EncoderInfo info;
    info.supports_native_handle = true;
    info.implementation_name = implementation_name_;

    SLRRTCVideoEncoderQpThresholds *qp_thresholds = [encoder_ scalingSettings];
    info.scaling_settings = qp_thresholds ? ScalingSettings(qp_thresholds.low, qp_thresholds.high) :
                                            ScalingSettings::kOff;

    info.is_hardware_accelerated = true;
    info.has_internal_source = false;
    return info;
  }

 private:
  id<SLRRTCVideoEncoder> encoder_;
  const std::string implementation_name_;
};
}  // namespace

ObjCVideoEncoderFactory::ObjCVideoEncoderFactory(id<SLRRTCVideoEncoderFactory> encoder_factory)
    : encoder_factory_(encoder_factory) {}

ObjCVideoEncoderFactory::~ObjCVideoEncoderFactory() {}

id<SLRRTCVideoEncoderFactory> ObjCVideoEncoderFactory::wrapped_encoder_factory() const {
  return encoder_factory_;
}

std::vector<SdpVideoFormat> ObjCVideoEncoderFactory::GetSupportedFormats() const {
  std::vector<SdpVideoFormat> supported_formats;
  for (SLRRTCVideoCodecInfo *supportedCodec in encoder_factory_.supportedCodecs) {
    SdpVideoFormat format = [supportedCodec nativeSdpVideoFormat];
    supported_formats.push_back(format);
  }

  return supported_formats;
}

VideoEncoderFactory::CodecInfo ObjCVideoEncoderFactory::QueryVideoEncoder(
    const SdpVideoFormat &format) const {
  // TODO(andersc): This is a hack until we figure out how this should be done properly.
  NSString *formatName = [NSString stringForStdString:format.name];
  NSSet *wrappedSoftwareFormats =
      [NSSet setWithObjects:kRTCVideoCodecVp8Name, kRTCVideoCodecVp9Name, nil];

  CodecInfo codec_info;
  codec_info.is_hardware_accelerated = ![wrappedSoftwareFormats containsObject:formatName];
  codec_info.has_internal_source = false;
  return codec_info;
}

std::unique_ptr<VideoEncoder> ObjCVideoEncoderFactory::CreateVideoEncoder(
    const SdpVideoFormat &format) {
  SLRRTCVideoCodecInfo *info = [[SLRRTCVideoCodecInfo alloc] initWithNativeSdpVideoFormat:format];
  id<SLRRTCVideoEncoder> encoder = [encoder_factory_ createEncoder:info];
  if ([encoder isKindOfClass:[SLRRTCWrappedNativeVideoEncoder class]]) {
    return [(SLRRTCWrappedNativeVideoEncoder *)encoder releaseWrappedEncoder];
  } else {
    return std::unique_ptr<ObjCVideoEncoder>(new ObjCVideoEncoder(encoder));
  }
}

}  // namespace webrtc
