# ===== Theos / Target toolchain =====
# NOTE: the workflow patches TARGET/SDK_PATH with sed.
export TARGET      = iphone:clang:18.6:14.0
export SDK_PATH    = $(THEOS)/sdks/iPhoneOS18.6.sdk/
export SYSROOT     = $(SDK_PATH)
export ARCHS       = arm64

# Build flags for embedded libs
export libcolorpicker_ARCHS = $(ARCHS)
export libFLEX_ARCHS        = $(ARCHS)
export Alderis_XCODEOPTS    = LD_DYLIB_INSTALL_NAME=@rpath/Alderis.framework/Alderis
export Alderis_XCODEFLAGS   = DYLIB_INSTALL_NAME_BASE=/Library/Frameworks BUILD_LIBRARY_FOR_DISTRIBUTION=YES ARCHS="$(ARCHS)"
export libcolorpicker_LDFLAGS = -F$(TARGET_PRIVATE_FRAMEWORK_PATH) -install_name @rpath/libcolorpicker.dylib

# Header search path for internal tweaks
export ADDITIONAL_CFLAGS = -I$(THEOS_PROJECT_DIR)/Tweaks/RemoteLog -I$(THEOS_PROJECT_DIR)/Tweaks

# ===== Project identifiers (workflow patches these) =====
PACKAGE_NAME     = YTLitePlus
PACKAGE_VERSION  = X.X.X-X.X      # set by workflow to ${YT_VERSION}-${YTLITE_VERSION}
DISPLAY_NAME     = YouTube        # set by workflow
BUNDLE_ID        = com.google.ios.youtube  # set by workflow

INSTALL_TARGET_PROCESSES = YouTube

# ===== Tweak target =====
TWEAK_NAME = YTLitePlus

# Your main tweak is at repo root; extras live under /Source
YTLitePlus_FILES = \
    YTLitePlus.xm \
    $(shell find Source -name '*.xm' -o -name '*.x' -o -name '*.m')

# Build flags (ARC + version macro + relaxed warnings)
YTLitePlus_CFLAGS = -fobjc-arc \
    -Wno-deprecated-declarations \
    -Wno-unsupported-availability-guard \
    -Wno-unused-but-set-variable \
    -DTWEAK_VERSION=$(PACKAGE_VERSION) \
    $(EXTRA_CFLAGS)

# Base frameworks
YTLitePlus_FRAMEWORKS = UIKit Security

# ===== Injected dylibs built by subprojects (rootless jailed packaging) =====
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

# Embedded libs/frameworks/bundles/extensions
YTLitePlus_EMBED_LIBRARIES  = $(THEOS_OBJ_DIR)/libcolorpicker.dylib
YTLitePlus_EMBED_FRAMEWORKS = $(_THEOS_LOCAL_DATA_DIR)/$(_THEOS_OBJ_DIR_NAME)/install_Alderis.xcarchive/Products/var/jb/Library/Frameworks/Alderis.framework
YTLitePlus_EMBED_BUNDLES    = $(wildcard Bundles/*.bundle)
YTLitePlus_EMBED_EXTENSIONS = $(wildcard Extensions/*.appex)

# Path to the unpacked app
YTLitePlus_IPA = ./tmp/Payload/YouTube.app

# No fishhook macro here
YTLitePlus_USE_FISHHOOK = 0

include $(THEOS)/makefiles/common.mk

# Build subprojects that produce the injected dylibs
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
