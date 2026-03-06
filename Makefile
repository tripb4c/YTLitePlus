# ===== Theos / Target toolchain =====
# NOTE: The workflow will patch TARGET/SDK_VER with sed.
export TARGET      = iphone:clang:18.6:14.0
export SDK_PATH    = $(THEOS)/sdks/iPhoneOS18.6.sdk/
export SYSROOT     = $(SDK_PATH)
export ARCHS       = arm64

# Some embedded libs/frameworks have their own ARCH flags
export libcolorpicker_ARCHS = $(ARCHS)
export libFLEX_ARCHS        = $(ARCHS)

# Alderis build flags for jailed packaging
export Alderis_XCODEOPTS  = LD_DYLIB_INSTALL_NAME=@rpath/Alderis.framework/Alderis
export Alderis_XCODEFLAGS = DYLIB_INSTALL_NAME_BASE=/Library/Frameworks BUILD_LIBRARY_FOR_DISTRIBUTION=YES ARCHS="$(ARCHS)"
export libcolorpicker_LDFLAGS = -F$(TARGET_PRIVATE_FRAMEWORK_PATH) -install_name @rpath/libcolorpicker.dylib

# Additional headers (RemoteLog / Tweaks)
export ADDITIONAL_CFLAGS = -I$(THEOS_PROJECT_DIR)/Tweaks/RemoteLog -I$(THEOS_PROJECT_DIR)/Tweaks

# ===== Project meta (patched by the workflow) =====
# The workflow uses sed to set these from inputs:
#   BUNDLE_ID, DISPLAY_NAME, PACKAGE_VERSION, TARGET/SDK_PATH
PACKAGE_NAME     = YTLitePlus
PACKAGE_VERSION  = X.X.X-X.X     # workflow overwrites to: ${YT_VERSION}-${YTLITE_VERSION}
DISPLAY_NAME     = YouTube       # workflow overwrites
BUNDLE_ID        = com.google.ios.youtube  # workflow overwrites

INSTALL_TARGET_PROCESSES = YouTube

# ===== Tweak target =====
TWEAK_NAME = YTLitePlus

# Sources:
# - Your main tweak is at repo root (YTLitePlus.xm)
# - Add all .xm/.x/.m under /Source
YTLitePlus_FILES = \
  YTLitePlus.xm \
  $(shell find Source -name '*.xm' -o -name '*.x' -o -name '*.m')

# Use ARC, relax a few warnings, and embed tweak version string
YTLitePlus_CFLAGS = -fobjc-arc \
  -Wno-deprecated-declarations \
  -Wno-unsupported-availability-guard \
  -Wno-unused-but-set-variable \
  -DTWEAK_VERSION=$(PACKAGE_VERSION) \
  $(EXTRA_CFLAGS)

# Base frameworks
YTLitePlus_FRAMEWORKS = UIKit Security

# ===== Inject additional dylibs (built by subprojects or preprovided) =====
# Theos-jailed will place these into the app and set up loading for jailed packaging.
# You already have these submodules under /Tweaks.
YTLitePlus_INJECT_DYLIBS = \
  Tweaks/YTLite/var/jb/Library/MobileSubstrate/DynamicLibraries/YTLite.dylib \
  .theos/obj/libFLEX.dylib \
  .theos/obj/YTUHD.dylib \
  .theos/obj/YouPiP.dylib \
  .theos/obj/YouTubeDislikesReturn.dylib \
  .theos/obj/YTABConfig.dylib \
  .theos/obj/DontEatMyContent.dylib \
  .theos/obj/YTVideoOverlay.dylib \
  .theos/obj/YouTimeStamp.dylib \
  .theos/obj/YouGroupSettings.dylib

# Embed libs/frameworks that need to ship inside the app
YTLitePlus_EMBED_LIBRARIES  = $(THEOS_OBJ_DIR)/libcolorpicker.dylib
YTLitePlus_EMBED_FRAMEWORKS = $(_THEOS_LOCAL_DATA_DIR)/$(_THEOS_OBJ_DIR_NAME)/install_Alderis.xcarchive/Products/var/jb/Library/Frameworks/Alderis.framework
YTLitePlus_EMBED_BUNDLES    = $(wildcard Bundles/*.bundle)
YTLitePlus_EMBED_EXTENSIONS = $(wildcard Extensions/*.appex)

# Tell theos where the unpacked .app is
YTLitePlus_IPA = ./tmp/Payload/YouTube.app

# No fishhook macro usage here
YTLitePlus_USE_FISHHOOK = 0

include $(THEOS)/makefiles/common.mk

# ===== Jailed build: also build subprojects (these generate the .theos/obj/*.dylib listed above) =====
ifneq ($(JAILBROKEN),1)
SUBPROJECTS += \
  Tweaks/Alderis \
  Tweaks/FLEXing/libflex \
  Tweaks/YTUHD \
  Tweaks/YouPiP \
  Tweaks/Return-YouTube-Dislikes \
  Tweaks/YTABConfig \
  Tweaks/DontEatMyContent \
  Tweaks/YTVideoOverlay \
  Tweaks/YouTimeStamp \
  Tweaks/YouGroupSettings

include $(THEOS_MAKE_PATH)/aggregate.mk
endif

include $(THEOS_MAKE_PATH)/tweak.mk

# ===== Packaging knobs =====
FINALPACKAGE   = 1
REMOVE_EXTENSIONS = 1
CODESIGN_IPA   = 0

# ===== YTLite predownload / extraction =====
# The workflow now downloads a verified .deb into Tweaks/YTLite/YTLite.deb (or similar).
# Prefer any local .deb; fall back to fetching from GitHub only if nothing exists.
YTLITE_PATH    := Tweaks/YTLite
YTLITE_VERSION ?= $(shell curl -s https://api.github.com/repos/dayanch96/YTLite/releases/latest | grep '"tag_name"' | sed 's/.*"v\(...\)".*/\1/')
YTLITE_DEB     := $(firstword $(wildcard $(YTLITE_PATH)/*.deb))
ifeq ($(YTLITE_DEB),)
  YTLITE_DEB := $(YTLITE_PATH)/com.dvntm.ytlite_$(YTLITE_VERSION)_iphoneos-arm64.deb
endif
YTLITE_DYLIB  := $(YTLITE_PATH)/var/jb/Library/MobileSubstrate/DynamicLibraries/YTLite.dylib
YTLITE_BUNDLE := $(YTLITE_PATH)/var/jb/Library/Application\ Support/YTLite.bundle

internal-clean::
    @rm -rf $(YTLITE_PATH)/*

ifneq ($(JAILBROKEN),1)
before-all::
    @mkdir -p $(YTLITE_PATH); \
    if [[ ! -f "$(YTLITE_DEB)" ]]; then \
        echo "==> Downloading YTLite $(YTLITE_VERSION) (no local .deb found)"; \
        curl -s -L "https://github.com/dayanch96/YTLite/releases/download/v$(YTLITE_VERSION)/com.dvntm.ytlite_$(YTLITE_VERSION)_iphoneos-arm64.deb" -o "$(YTLITE_PATH)/com.dvntm.ytlite_$(YTLITE_VERSION)_iphoneos-arm64.deb"; \
        YTLITE_DEB="$(YTLITE_PATH)/com.dvntm.ytlite_$(YTLITE_VERSION)_iphoneos-arm64.deb"; \
    fi; \
    if [[ ! -f "$(YTLITE_DYLIB)" || ! -d "$(YTLITE_BUNDLE)" ]]; then \
        tar -xf "$(YTLITE_DEB)" -C "$(YTLITE_PATH)"; \
        tar -xf "$(YTLITE_PATH)/data.tar"* -C "$(YTLITE_PATH)"; \
        if [[ ! -f "$(YTLITE_DYLIB)" || ! -d "$(YTLITE_BUNDLE)" ]]; then \
            echo "==> Error: Failed to extract YTLite"; exit 1; \
        fi; \
    fi
endif

# ===== Optional: CORE_LITE mode (safer) =====
# Excludes early/fragile hooks while preserving login fixes.
# Enable from CI by adding CORE_LITE=1 to "make package …".
ifeq ($(CORE_LITE),1)
  YTLitePlus_FILES := $(filter-out \
    Source/Themes.xm \
    Source/VersionSpooferLite.xm \
  ,$(YTLitePlus_FILES))
  $(info Building CORE_LITE: skipping Themes.xm and VersionSpooferLite.xm)
endif

# ===== Optional: disable a set of dylibs at package time via regex =====
# (The CI sets DISABLE_DYLIBS_REGEX="YTUHD|YouPiP|...".)
# We remove matching built dylibs before packaging to keep loader clean.
ifneq ($(DISABLE_DYLIBS_REGEX),)
before-package::
    @echo "==> Disabling dylibs matching regex: $(DISABLE_DYLIBS_REGEX)"; \
    find .theos -type f -name "*.dylib" | \
    awk 'BEGIN{rc=0} \
         { if ($$0 ~ /($(DISABLE_DYLIBS_REGEX))/) { print "  - removing " $$0; system("rm -f \"" $$0 "\""); } } \
         END{exit rc}'
endif
