# Builds SLRWebRTC.framework: WebRTC for iOS with the Objective-C API renamed
# from RTC* to SLRRTC*. See README.md.
#
# Run from the repository root (the path must not contain spaces) with the
# make that comes with macOS:
#   make BRANCH=m76 build

# Tools that `build` checks for below.
RENAME:= $(shell command -v rename 2> /dev/null)
# Looks for `rename` again instead of `perl`. Harmless: perl comes with macOS.
PERL  := $(shell command -v rename 2> /dev/null)
# depot_tools (cloned by `build`) provides fetch and gclient. Every recipe line
# runs through `env PATH=... bash` so that they are found: make would run
# simple commands with its original PATH. PATH is passed to env unquoted, so
# neither the repository path nor any folder in PATH may contain spaces.
PATH  := $(PATH):$(PWD)/depot_tools/
SHELL := env PATH=$(PATH) /bin/bash
# Folder of this Makefile. Not used.
THIS_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# GNU Make 3.81 (the one in macOS) ignores .ONESHELL, so every recipe line runs
# in its own shell and `cd ./src` below affects only its own line. GNU Make 3.82
# and later run the whole recipe in one shell: the `cd` then carries over to
# the next lines and the build fails.
.ONESHELL:
build:
# make evaluates these checks while it reads this file, so a missing tool stops
# every target, `clean` included.
ifndef RENAME
    $(error "Rename is not available please install rename (brew install rename)")
endif
ifndef PERL
    $(error "Perl is not available please install rename (brew install perl)")
endif
# 1. Get depot_tools, Chromium's tools for downloading and building WebRTC.
#    Fails if ./depot_tools already exists: each build needs a clean folder.
	git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
# 2. Download the WebRTC source into ./src. Hooks run later, in step 3.
	fetch --nohooks webrtc
# 3. Switch to the release branch, download its dependencies and run the hooks.
#    The commands are joined with ";": if the checkout fails (BRANCH missing or
#    misspelled), the build goes on with WebRTC's default branch.
	cd ./src; git checkout branch-heads/${BRANCH}; gclient sync
# 4. Rename WebRTC to SLRWebRTC in ./src (see renamer_script.sh).
	sh ./renamer_script.sh
# 5. Build the framework (release; arm64, armv7, x86_64, i386) into
#    src/out_ios_libs/.
	sh ./src/tools_webrtc/ios/build_ios_libs.sh 

# WARNING: deletes everything in this folder except Makefile and
# renamer_script.sh, including .git and README.md. To remove only what `build`
# created: rm -rf depot_tools src .gclient*
clean:
	find . ! -name 'Makefile' ! -name 'renamer_script*' -exec rm -Rf {} +