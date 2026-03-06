set -euxo pipefail

# ──────────────────────────────────────────────────────────────────────────────
# Overwrite Makefile on the runner (tabs preserved) to avoid "missing separator"
# ──────────────────────────────────────────────────────────────────────────────
cat > Makefile <<'MAKE'
# ===== Theos / Target toolchain =====
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

# Headers
export ADDITIONAL_CFLAGS = -I$(THEOS_PROJECT_DIR)/Tweaks/RemoteLog -I$(THEOS_PROJECT_DIR)/Tweaks

# ===== Project identifiers (workflow patches these with sed) =====
PACKAGE_NAME     = YTLitePlus
PACKAGE_VERSION  = X.X.X-X.X
DISPLAY_NAME     = YouTube
BUNDLE_ID        = com.google.ios.youtube

INSTALL_TARGET_PROCESSES = YouTube

# ===== Tweak target =====
TWEAK_NAME = YTLitePlus

# Sources (main file at repo root + everything in /Source)
YTLitePlus_FILES = \
    YTLitePlus.xm \
    $(shell find Source -name '*.xm' -o -name '*.x' -o -name '*.m')

# Optional safe mode (Core-Lite): set SKIP_CORE_FILES as a space-separated list
YTLitePlus_FILES := $(filter-out $(SKIP_CORE_FILES),$(YTLitePlus_FILES))

# Build flags
YTLitePlus_CFLAGS = -fobjc-arc \
    -Wno-deprecated-declarations \
    -Wno-unsupported-availability-guard \
    -Wno-unused-but-set-variable \
    -DTWEAK_VERSION=$(PACKAGE_VERSION) \
    $(EXTRA_CFLAGS)

# Frameworks
YTLitePlus_FRAMEWORKS = UIKit Security

# Injected dylibs produced by subprojects
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

# App path inside unpacked IPA
YTLitePlus_IPA = ./tmp/Payload/YouTube.app

# No fishhook macro
YTLitePlus_USE_FISHHOOK = 0

include $(THEOS)/makefiles/common.mk

# Always build subprojects for jailed packaging
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

include $(THEOS_MAKE_PATH)/tweak.mk

# Packaging knobs
FINALPACKAGE      = 1
REMOVE_EXTENSIONS = 1
CODESIGN_IPA      = 0

# ===== YTLite predownload / extraction =====
# Prefer the local .deb (downloaded by CI into Tweaks/YTLite/*.deb).
YTLITE_PATH    := Tweaks/YTLite
YTLITE_VERSION ?= $(shell curl -s https://api.github.com/repos/dayanch96/YTLite/releases/latest | grep '"tag_name"' | sed 's/.*"v\(...\)".*/\1/')
YTLITE_DEB     := $(firstword $(wildcard $(YTLITE_PATH)/*.deb))
YTLITE_DYLIB   := $(YTLITE_PATH)/var/jb/Library/MobileSubstrate/DynamicLibraries/YTLite.dylib
YTLITE_BUNDLE  := $(YTLITE_PATH)/var/jb/Library/Application\ Support/YTLite.bundle

internal-clean::
    @rm -rf "$(YTLITE_PATH)"/*

# Always run; shell decides what to do (NOTE: recipe lines begin with TAB)
before-all::
    @mkdir -p "$(YTLITE_PATH)"; \
    if [ ! -f "$(YTLITE_DEB)" ]; then \
        echo "==> Downloading YTLite $(YTLITE_VERSION) (no local .deb found)"; \
        curl -s -L "https://github.com/dayanch96/YTLite/releases/download/v$(YTLITE_VERSION)/com.dvntm.ytlite_$(YTLITE_VERSION)_iphoneos-arm64.deb" \
            -o "$(YTLITE_PATH)/com.dvntm.ytlite_$(YTLITE_VERSION)_iphoneos-arm64.deb"; \
        YTLITE_DEB="$(YTLITE_PATH)/com.dvntm.ytlite_$(YTLITE_VERSION)_iphoneos-arm64.deb"; \
    fi; \
    if [ ! -f "$(YTLITE_DYLIB)" ] || [ ! -d "$(YTLITE_BUNDLE)" ]; then \
        tar -xf "$(YTLITE_DEB)" -C "$(YTLITE_PATH)"; \
        tar -xf "$(YTLITE_PATH)/data.tar"* -C "$(YTLITE_PATH)"; \
        if [ ! -f "$(YTLITE_DYLIB)" ] || [ ! -d "$(YTLITE_BUNDLE)" ]; then \
            echo "==> Error: Failed to extract YTLite"; exit 1; \
        fi; \
    fi

# Disable selected dylibs via regex provided by CI
before-package::
    @if [ -n "$(DISABLE_DYLIBS_REGEX)" ]; then \
        echo "==> Disabling dylibs matching: $(DISABLE_DYLIBS_REGEX)"; \
        find .theos -type f -name "*.dylib" | while read f; do \
            echo "$$f" | grep -Eq "($(DISABLE_DYLIBS_REGEX))" && { echo "  - removing $$f"; rm -f "$$f"; }; \
        done; \
    fi
MAKE

# Optional: one-time debug to visualize TABs on recipe lines
# sed -n '1,140p' Makefile | sed -e $'s/\t/[TAB]\t/g' | nl

# ──────────────────────────────────────────────────────────────────────────────
# Keep your existing safety checks + sed patches
# ──────────────────────────────────────────────────────────────────────────────

# Safety: validate BUNDLE_ID looks like a bundle id, not a URL
if echo "${BUNDLE_ID}" | grep -qiE 'https?://'; then
  echo "::error::Bundle ID looks like a URL. Put the URL in decrypted_youtube_url, not bundle_id."
  exit 1
fi

# Apply chosen disable set
if [ -n "${DISABLE_REGEX:-}" ]; then
  export DISABLE_DYLIBS_REGEX="${DISABLE_REGEX}"
fi

# Patch Makefile from inputs (ok to run even after overwrite)
sed -i '' "s/^BUNDLE_ID.*$/BUNDLE_ID = ${BUNDLE_ID}/" Makefile
sed -i '' "s/^DISPLAY_NAME.*$/DISPLAY_NAME = ${APP_NAME}/" Makefile
sed -i '' "s/^PACKAGE_VERSION.*$/PACKAGE_VERSION = ${YT_VERSION}-${YTLITE_VERSION}/" Makefile
sed -i '' "s/^export TARGET.*$/export TARGET = iphone:clang:${SDK_VER}:14.0/" Makefile
sed -i '' "s|^export SDK_PATH.*$|export SDK_PATH = \$(THEOS)/sdks/iPhoneOS${SDK_VER}.sdk/|" Makefile

# ──────────────────────────────────────────────────────────────────────────────
# Build (Core-Lite ON for the first pass to avoid early fragile hooks)
# ──────────────────────────────────────────────────────────────────────────────
make package SIDELOAD=1 THEOS_PACKAGE_SCHEME=rootless FINALPACKAGE=1 \
  YTLITE_VERSION="${YTLITE_VERSION}" \
  SKIP_CORE_FILES="Source/Themes.xm Source/VersionSpooferLite.xm"

# Rename to friendly name (ignore error if already matched)
mv "packages/$(ls -t packages | head -n1)" "packages/YTLitePlus_${YT_VERSION}_${YTLITE_VERSION}.ipa" || true

# Expose final name to later steps
echo "package=$(ls -t packages | head -n1)" >> "$GITHUB_OUTPUT"

# Show hash & bundle id
echo "==> SHASUM256: $(shasum -a 256 packages/*.ipa | cut -f1 -d' ')"
echo "==> Bundle ID: ${BUNDLE_ID}"
