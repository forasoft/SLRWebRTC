#!/bin/bash
#
# Renames WebRTC to SLRWebRTC in the WebRTC checkout in ./src before the iOS
# framework is built:
#
#   WebRTC.framework    -> SLRWebRTC.framework
#   RTCPeerConnection   -> SLRRTCPeerConnection    (classes, protocols, types)
#   RTCPeerConnection.h -> SLRRTCPeerConnection.h  (files)
#
# Only the Objective-C layer (src/sdk/objc) is renamed; the C++ code is not.
# Everything is done with plain text replacements written for WebRTC M76.
#
# `make build` runs this script from the repository root after `gclient sync`.
# Run it only once, on a fresh checkout of a branch that has the folder
# src/sdk/objc/Framework/Headers/WebRTC (M76 does, current WebRTC doesn't).
# Otherwise the `cd` into that folder fails, the script goes on in the wrong
# folders and ends up editing files outside the repository, in its parent
# folder.
#
# Needs `rename` (brew install rename) and perl.

# --- Build scripts: src/tools_webrtc/ios ---

cd ./src/tools_webrtc/ios
# Umbrella header: #import <WebRTC/...> -> #import <SLRWebRTC/...>
find . -name 'generate_umbrella_header*' | xargs perl -pi -e 's/<WebRTC/<SLRWebRTC/g'
# Framework, binary and dSYM names in build_ios_libs.py. The shell drops the
# inner quotes, so perl gets s/WebRTC/SLRWebRTC/g and replaces every "WebRTC"
# in these files; the next line restores the function name BuildWebRTC.
find . -name "build_ios_libs*" | xargs perl -pi -e 's/'WebRTC'/'SLRWebRTC'/g'
find . -name "build_ios_libs*" | xargs perl -pi -e 's/BuildSLRWebRTC/BuildWebRTC/g'

# --- File names: src/sdk/objc ---

cd ../../sdk/objc

# RTC*.h/.m/.mm -> SLRRTC*, UIDevice+RTCDevice.* -> UIDevice+SLRRTCDevice.*
# rename replaces the first "RTC" in the whole path. For files in
# Framework/Headers/WebRTC/ that is the "RTC" of "WebRTC": these renames fail
# ("Can't rename ...") and are redone below, after the folder is renamed.
find . -name "RTC*.mm" -exec rename 's|RTC|SLRRTC|' {} +
find . -name "RTC*.m" -exec rename 's|RTC|SLRRTC|' {} +
find . -name "RTC*.h" -exec rename 's|RTC|SLRRTC|' {} +
find . -name "UIDevice*" -exec rename 's|RTC|SLRRTC|' {} +

# Public headers folder: Framework/Headers/WebRTC -> Framework/Headers/SLRWebRTC.
# The `find ... |` parts have no effect (rm and mv don't read stdin), so these
# lines are a plain rm -Rf and mv. On a second run the rm deletes the already
# renamed headers.
find . -name "SLRWebRTC" -type d | rm -Rf  ./Framework/Headers/SLRWebRTC 
find . -name "WebRTC" -type d | mv ./Framework/Headers/WebRTC ./Framework/Headers/SLRWebRTC 

# Rename the headers that failed above.
cd ./Framework/Headers/SLRWebRTC/
find . -name "RTC*.h" -exec rename 's|RTC|SLRRTC|' {} +
find . -name "UIDevice*" -exec rename 's|RTC|SLRRTC|' {} +

# Back to src/sdk/objc.
cd ../../../

# --- File contents: src/sdk/objc ---

# Info.plist: bundle name, identifier and executable (WebRTC -> SLRWebRTC).
find . -name "*.plist" | xargs perl -pi -e 's/(WebRTC)/SLRWebRTC/g'
# Every "RTC" -> "SLRRTC": names of classes, protocols, types, constants and
# functions, and the #import paths of the renamed files. This also changes
# names that must stay as they are; they are restored below.
find . -name "*.h" | xargs perl -pi -e 's/(RTC)/SLRRTC/g'
find . -name "*.m" | xargs perl -pi -e 's/(RTC)/SLRRTC/g'
find . -name "*.mm" | xargs perl -pi -e 's/(RTC)/SLRRTC/g'

# The rest of the script runs in src/sdk.
cd ../

# BUILD.gn: source lists and framework name. "WebRTC" turns into "WebSLRRTC"
# here; that is fixed at the end of the script.
find . -name "BUILD.gn" | xargs perl -pi -e 's/(RTC)/SLRRTC/g'

# --- Undo replacements that went too far ---

# Macros: RTC_OBJC_EXPORT, RTC_DCHECK, RTC_LOG and so on. This also restores
# WEBRTC_* macros such as WEBRTC_IOS, which had become WEBSLRRTC_*.
find . -name "*.h" | xargs perl -pi -e 's/(SLRRTC_)/RTC_/g'
find . -name "*.m" | xargs perl -pi -e 's/(SLRRTC_)/RTC_/g'
find . -name "*.mm" | xargs perl -pi -e 's/(SLRRTC_)/RTC_/g'

# C++ types from the WebRTC core that the Objective-C code uses:
# rtc::RTCCertificate, webrtc::RTCStats*,
# PeerConnectionInterface::RTCConfiguration, webrtc::RTCError.
# Side effect: the Objective-C classes RTCCertificate and RTCConfiguration and
# the RTCStatsOutputLevel enum keep their original names as well.
find . -name "*.h" | xargs perl -pi -e 's/(SLRRTCCertificate)/RTCCertificate/g'
find . -name "*.m" | xargs perl -pi -e 's/(SLRRTCCertificate)/RTCCertificate/g'
find . -name "*.mm" | xargs perl -pi -e 's/(SLRRTCCertificate)/RTCCertificate/g'

find . -name "*.h" | xargs perl -pi -e 's/(SLRRTCStats)/RTCStats/g'
find . -name "*.m" | xargs perl -pi -e 's/(SLRRTCStats)/RTCStats/g'
find . -name "*.mm" | xargs perl -pi -e 's/(SLRRTCStats)/RTCStats/g'

find . -name "*.h" | xargs perl -pi -e 's/(SLRRTCConfiguration)/RTCConfiguration/g'
find . -name "*.m" | xargs perl -pi -e 's/(SLRRTCConfiguration)/RTCConfiguration/g'
find . -name "*.mm" | xargs perl -pi -e 's/(SLRRTCConfiguration)/RTCConfiguration/g'

find . -name "*.h" | xargs perl -pi -e 's/(SLRRTCError)/RTCError/g'
find . -name "*.m" | xargs perl -pi -e 's/(SLRRTCError)/RTCError/g'
find . -name "*.mm" | xargs perl -pi -e 's/(SLRRTCError)/RTCError/g'

# The header files of those two classes were renamed: fix the #import paths.
find . -name "*.h" | xargs perl -pi -e 's/(RTCConfiguration.h)/SLRRTCConfiguration.h/g'
find . -name "*.m" | xargs perl -pi -e 's/(RTCConfiguration.h)/SLRRTCConfiguration.h/g'
find . -name "*.mm" | xargs perl -pi -e 's/(RTCConfiguration.h)/SLRRTCConfiguration.h/g'

find . -name "*.h" | xargs perl -pi -e 's/(RTCCertificate.h)/SLRRTCCertificate.h/g'
find . -name "*.m" | xargs perl -pi -e 's/(RTCCertificate.h)/SLRRTCCertificate.h/g'
find . -name "*.mm" | xargs perl -pi -e 's/(RTCCertificate.h)/SLRRTCCertificate.h/g'

# C++ type PeerConnectionInterface::RTCOfferAnswerOptions.
find . -name "*.h" | xargs perl -pi -e 's/(SLRRTCOfferAnswerOptions)/RTCOfferAnswerOptions/g'
find . -name "*.m" | xargs perl -pi -e 's/(SLRRTCOfferAnswerOptions)/RTCOfferAnswerOptions/g'
find . -name "*.mm" | xargs perl -pi -e 's/(SLRRTCOfferAnswerOptions)/RTCOfferAnswerOptions/g'

# Removes a double prefix. Does nothing on a fresh checkout.
find . -name "*.h" | xargs perl -pi -e 's/(SLRSLRRTCCertificate.h)/SLRRTCCertificate.h/g'
find . -name "*.m" | xargs perl -pi -e 's/(SLRSLRRTCCertificate.h)/SLRRTCCertificate.h/g'
find . -name "*.mm" | xargs perl -pi -e 's/(SLRSLRRTCCertificate.h)/SLRRTCCertificate.h/g'

# Imports such as "RTCConfiguration+Private.h", which the .h rule above misses.
find . -name "*.h" | xargs perl -pi -e 's/"RTCConfiguration/"SLRRTCConfiguration/g'
find . -name "*.m" | xargs perl -pi -e 's/"RTCConfiguration/"SLRRTCConfiguration/g'
find . -name "*.mm" | xargs perl -pi -e 's/"RTCConfiguration/"SLRRTCConfiguration/g'

# --- Finish BUILD.gn ---

# "WebSLRRTC" (from the BUILD.gn step above) -> "SLRWebRTC": the framework name
# and the public headers folder.
find . -name "BUILD.gn" | xargs perl -pi -e 's/(WebSLRRTC)/SLRWebRTC/g'
