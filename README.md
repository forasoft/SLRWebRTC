# SLRWebRTC

Builds **SLRWebRTC.framework**: Google's [WebRTC](https://webrtc.googlesource.com/src/) for iOS with its Objective-C API renamed, so that it can be used in an app that already contains another copy of WebRTC.

|                   | WebRTC                      | SLRWebRTC                         |
| ----------------- | --------------------------- | --------------------------------- |
| Framework         | `WebRTC.framework`          | `SLRWebRTC.framework`             |
| Umbrella header   | `#import <WebRTC/WebRTC.h>` | `#import <SLRWebRTC/SLRWebRTC.h>` |
| Classes and types | `RTCPeerConnection`         | `SLRRTCPeerConnection`            |
| Header files      | `RTCPeerConnection.h`       | `SLRRTCPeerConnection.h`          |
| Bundle identifier | `org.webrtc.WebRTC`         | `org.webrtc.SLRWebRTC`            |

The repository contains no WebRTC code, only the build scripts: `make build` downloads WebRTC, renames it and builds the framework.

## Why

All Objective-C classes in an app share one global namespace. If an app contains two copies of WebRTC (for example, its own WebRTC build and a third-party SDK that bundles another one), both define `RTCPeerConnection`, `RTCVideoTrack` and the rest. The Objective-C runtime then warns that each of these classes is implemented in both frameworks and uses only one of the two implementations, so code from one copy can end up working with classes from the other. The result is crashes and bugs that are hard to trace.

With its own class, file and framework names, SLRWebRTC can live in the same app as another WebRTC.

## Requirements

- macOS with Xcode.
- `rename`: `brew install rename`. Perl, which the scripts also use, comes with macOS.
- The `make` that comes with macOS (`/usr/bin/make`, GNU Make 3.81). Newer versions break the build, see [Known issues](#known-issues).
- A path without spaces. If the repository path or any folder in `PATH` contains a space, every build step fails.
- Plenty of free disk space and a fast connection: the build downloads WebRTC with its dependencies and toolchains, many gigabytes in total. Keep the repository out of folders synced to the cloud, such as iCloud Drive.

## Usage

```bash
make BRANCH=m76 build
```

`BRANCH` is a WebRTC release branch: the name after `branch-heads/`. Releases M73 to M79 have branches named `m73` to `m79`; later releases are numbered. To list all of them:

```bash
git ls-remote https://webrtc.googlesource.com/src 'refs/branch-heads/*'
```

The scripts were written for `m76`; for other branches, see [Known issues](#known-issues).

The result goes to `src/out_ios_libs/`:

- `SLRWebRTC.framework`: a dynamic framework with a single binary for devices (arm64, armv7) and the simulator (x86_64, i386). Remove the simulator architectures from it before you submit an app to the App Store.
- `SLRWebRTC.dSYM`: debug symbols.

In code, use `#import <SLRWebRTC/SLRWebRTC.h>` and the `SLRRTC…` class names. For iOS, M76 doesn't generate a module map, so Swift code needs a bridging header with that import.

## How it works

`make build` runs these steps from the repository root:

1. Clones [depot_tools](https://chromium.googlesource.com/chromium/tools/depot_tools.git), Chromium's tools for downloading and building, into `depot_tools/` and adds them to `PATH`.
2. `fetch --nohooks webrtc` downloads WebRTC into `src/`.
3. In `src/`, `git checkout branch-heads/$BRANCH` switches to the release branch, and `gclient sync` downloads its dependencies and runs the hooks, which fetch the build toolchain.
4. [`renamer_script.sh`](renamer_script.sh) renames WebRTC to SLRWebRTC in `src/`.
5. WebRTC's own `src/tools_webrtc/ios/build_ios_libs.sh` builds a release framework for each architecture and merges them into one with `lipo`.

### What the renamer changes

The renamer works with plain text replacements (`perl`) and file renames (`rename`):

| Where | What changes |
| --- | --- |
| `src/tools_webrtc/ios/build_ios_libs.py` | Framework, binary and dSYM names: `WebRTC` → `SLRWebRTC` |
| `src/tools_webrtc/ios/generate_umbrella_header.py` | Umbrella header imports: `<WebRTC/…>` → `<SLRWebRTC/…>` |
| Files in `src/sdk/objc` | `RTC*.h`, `RTC*.m`, `RTC*.mm` → `SLRRTC*`; `UIDevice+RTCDevice.*` → `UIDevice+SLRRTCDevice.*`; the `Framework/Headers/WebRTC` folder → `Framework/Headers/SLRWebRTC` |
| Code in `src/sdk/objc` (`.h`, `.m`, `.mm`) | Every `RTC` → `SLRRTC`: classes, protocols, types, constants, functions and `#import` paths |
| `src/sdk/objc/Info.plist` | Bundle name, identifier and executable: `WebRTC` → `SLRWebRTC` |
| `BUILD.gn` files in `src/sdk` | Source lists and framework name (`output_name = "SLRWebRTC"`) |

Replacing every `RTC` also hits names that must not change, so the script then restores them:

- macros such as `RTC_OBJC_EXPORT`, `RTC_DCHECK`, `RTC_LOG` and `WEBRTC_IOS`;
- C++ types from the WebRTC core that the Objective-C code uses: `rtc::RTCCertificate`, `webrtc::RTCStats*`, `PeerConnectionInterface::RTCConfiguration`, `webrtc::RTCError`, `PeerConnectionInterface::RTCOfferAnswerOptions`.

Only the Objective-C layer is renamed; the C++ code inside the framework stays as it is.

### Names that keep the `RTC` prefix

The restoring replacements don't tell C++ names from Objective-C ones, so a few Objective-C names keep their original form:

- the `RTCConfiguration` and `RTCCertificate` classes;
- the `RTCStatsOutputLevel` enum.

Other WebRTC builds have these classes too, so `RTCConfiguration` and `RTCCertificate` can still clash with another WebRTC in the same app.

## Repository layout

```
Makefile             the build and clean targets
renamer_script.sh    renames WebRTC to SLRWebRTC in src/
README.md

Created by make build:
depot_tools/         Chromium's depot_tools
.gclient*            gclient configuration and state
src/                 the WebRTC checkout, changed by renamer_script.sh
src/out_ios_libs/    the built framework
```

## Cleaning up

> **Warning:** `make clean` deletes everything in the repository folder except `Makefile` and `renamer_script.sh`. That includes `.git`, with any commits you haven't pushed, and `README.md`.

To remove only what `make build` created:

```bash
rm -rf depot_tools src .gclient*
```

A build always starts from scratch and stops at once if `depot_tools/` exists, so clean up before you build again.

## Known issues

- **Made in July 2019 for WebRTC M76 and not updated since.** The replacements are tuned to the code of that time. Other branches, and M76 itself with today's tools, may need changes. For example, current Xcode versions no longer support the 32-bit architectures (armv7, i386) that `build_ios_libs` builds by default, and M76's build script runs `python`, which current macOS doesn't include.
- **The renamer can edit files outside the repository.** If `src/sdk/objc/Framework/Headers/WebRTC` doesn't exist, the script's `cd` into that folder fails and it goes on in the wrong folders. It ends up in the parent folder of the repository and edits `.h`, `.m`, `.mm` and `BUILD.gn` files of other projects there. Current WebRTC no longer has this folder, and after the first run it's gone too. Run the renamer only once, on a fresh checkout of a branch that has it (M76 does).
- **A missing or misspelled `BRANCH` doesn't stop the build.** `git checkout` fails, and the build goes on with WebRTC's default branch.
- **GNU Make 3.82 and later** (for example, `gmake` from Homebrew) apply the Makefile's `.ONESHELL`: the whole recipe runs in one shell, `cd ./src` carries over to the next steps and the build fails.
- **`make clean` deletes `.git` and `README.md`** (see [Cleaning up](#cleaning-up)). It also refuses to run without `rename` installed, because the tool checks apply to every target.
- The Makefile checks for `rename` twice instead of checking for `perl`. Harmless, since macOS includes perl.

Newer WebRTC versions support a custom class prefix out of the box: see `RTC_OBJC_TYPE_PREFIX` in `sdk/objc/base/RTCMacros.h`. If you move to a newer branch, start from that rather than from these replacements.
