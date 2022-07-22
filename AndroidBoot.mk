#Android makefile to build bootloader as a part of Android Build
ANDROID_TOP=$(shell pwd)
CLANG_BIN := $(ANDROID_TOP)/$(LLVM_PREBUILTS_PATH)/
ABL_USE_SDLLVM := false

ifneq ($(FORCE_SDCLANG_OFF),true)
ifneq ($(wildcard $(SDCLANG_PATH)),)
  ifeq ($(shell echo $(SDCLANG_PATH) | head -c 1),/)
    CLANG_BIN := $(SDCLANG_PATH)/
  else
    CLANG_BIN := $(ANDROID_TOP)/$(SDCLANG_PATH)/
  endif

  ABL_USE_SDLLVM := true
endif
endif

# LD & make are not available in prebuilts for older Android versions
ifeq (1,$(filter 1,$(shell echo "$$(( $(PLATFORM_SDK_VERSION) > 27 ))" )))
LDOPT="-fuse-ld=$(ANDROID_TOP)/$(SOONG_LLVM_PREBUILTS_PATH)/ld.lld"
MAKEPATH=$(ANDROID_TOP)/prebuilts/build-tools/linux-x86/bin/
  ifeq (,$(wildcard $(MAKEPATH)make))
    MAKEPATH :=
  endif
endif

SECTOOLSV2_BIN=$(QCPATH)/sectools/Linux/sectools

# Use host tools from prebuilts. Partner should determine the correct host tools to use
PREBUILT_HOST_TOOLS := BUILD_CC=$(ANDROID_TOP)/$(CLANG)\ \
		       BUILD_CXX=$(ANDROID_TOP)/$(CLANG_CXX)\ \
		       LDPATH=$(LDOPT)\ \
		       BUILD_AR=$(ANDROID_TOP)/$(HOST_AR)
PREBUILT_PYTHON_PATH=$(ANDROID_TOP)/prebuilts/python/linux-x86/2.7.5/bin/python2

DISABLE_PARALLEL_DOWNLOAD_FLASH := DISABLE_PARALLEL_DOWNLOAD_FLASH=0
ifeq ($(PRODUCT_SUPPORTS_VERITY),true)
	VERIFIED_BOOT := VERIFIED_BOOT=1
else
	VERIFIED_BOOT := VERIFIED_BOOT=0
endif

ifeq ($(BOARD_BUILD_SYSTEM_ROOT_IMAGE),true)
        BUILD_SYSTEM_ROOT_IMAGE := BUILD_SYSTEM_ROOT_IMAGE=1
else
        BUILD_SYSTEM_ROOT_IMAGE := BUILD_SYSTEM_ROOT_IMAGE=0
endif

ifeq ($(BOARD_AVB_ENABLE),true)
	VERIFIED_BOOT_2 := VERIFIED_BOOT_2=1
else
	VERIFIED_BOOT_2 := VERIFIED_BOOT_2=0
endif

ifeq ($(BOARD_LEVB_ENABLE),true)
	VERIFIED_BOOT_LE := VERIFIED_BOOT_LE=1
else
	VERIFIED_BOOT_LE := VERIFIED_BOOT_LE=0
endif

ifeq ($(TARGET_AB_RETRYCOUNT_DISABLE),true)
	AB_RETRYCOUNT_DISABLE := AB_RETRYCOUNT_DISABLE=1
else
	AB_RETRYCOUNT_DISABLE := AB_RETRYCOUNT_DISABLE=0
endif

ifeq ($(TARGET_BUILD_VARIANT),user)
	USER_BUILD_VARIANT := USER_BUILD_VARIANT=1
else
	USER_BUILD_VARIANT := USER_BUILD_VARIANT=0
endif

ifneq ($(TARGET_BOOTLOADER_BOARD_NAME),)
	BOARD_BOOTLOADER_PRODUCT_NAME := $(TARGET_BOOTLOADER_BOARD_NAME)
else
	BOARD_BOOTLOADER_PRODUCT_NAME := QC_Reference_Phone
endif

ifeq ($(TARGET_BOARD_TYPE),auto)
	DISPLAY_DISABLE := DISPLAY_DISABLE=1
else
	DISPLAY_DISABLE := DISPLAY_DISABLE=0
endif

ifeq ($(TARGET_BOOTLOADER_DISPLAY_DISABLE),true)
	DISPLAY_DISABLE := DISPLAY_DISABLE=1
else
	DISPLAY_DISABLE := DISPLAY_DISABLE=0
endif

ifeq ($(BOARD_ABL_SAFESTACK_DISABLE),true)
	ABL_SAFESTACK := false
else
	ABL_SAFESTACK := true
endif

ifeq ($(PRODUCT_USE_DYNAMIC_PARTITIONS),true)
        DYNAMIC_PARTITION_SUPPORT := DYNAMIC_PARTITION_SUPPORT=1
else
        DYNAMIC_PARTITION_SUPPORT := DYNAMIC_PARTITION_SUPPORT=0
endif

ifeq ($(PRODUCT_VIRTUAL_AB_OTA),true)
        VIRTUAL_AB_OTA := VIRTUAL_AB_OTA=1
else
        VIRTUAL_AB_OTA := VIRTUAL_AB_OTA=0
endif

ifneq (,$(filter true,$(BOARD_USES_RECOVERY_AS_BOOT) $(BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT)))
	BUILD_USES_RECOVERY_AS_BOOT := BUILD_USES_RECOVERY_AS_BOOT=1
else
	BUILD_USES_RECOVERY_AS_BOOT := BUILD_USES_RECOVERY_AS_BOOT=0
endif

SAFESTACK_SUPPORTED_CLANG_VERSION = 6.0

# For most platform, abl needed always be built
# in aarch64 arthitecture to run.
# Specify BOOTLOADER_ARCH if needed to built with
# other ARCHs.
ifeq ($(BOOTLOADER_ARCH),)
	BOOTLOADER_ARCH := AARCH64
endif
TARGET_ARCHITECTURE := $(BOOTLOADER_ARCH)

ifeq ($(TARGET_ARCHITECTURE),arm)
	CLANG35_PREFIX := $(ANDROID_TOP)/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-$(TARGET_GCC_VERSION)/bin/arm-linux-androideabi-
	CLANG35_GCC_TOOLCHAIN := $(ANDROID_TOP)/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-$(TARGET_GCC_VERSION)
else
	CLANG35_PREFIX := $(ANDROID_TOP)/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-$(TARGET_GCC_VERSION)/bin/aarch64-linux-android-
	CLANG35_GCC_TOOLCHAIN := $(ANDROID_TOP)/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-$(TARGET_GCC_VERSION)
endif

# Final configurations before calling edk2's make
# Always keep the following block towards the end of configurations.
ifeq ($(BOARD_ABL_SIMPLE),true)
	AB_RETRYCOUNT_DISABLE := AB_RETRYCOUNT_DISABLE=1
	VERIFIED_BOOT := VERIFIED_BOOT=0
	VERIFIED_BOOT_2 := VERIFIED_BOOT_2=0
	VERIFIED_BOOT_LE := VERIFIED_BOOT_LE=0
	DISABLE_PARALLEL_DOWNLOAD_FLASH := DISABLE_PARALLEL_DOWNLOAD_FLASH=1
endif

# ABL ELF output
TARGET_ABL := $(PRODUCT_OUT)/unsigned_abl.elf
TARGET_EMMC_BOOTLOADER := $(TARGET_ABL)
ABL_OUT := $(TARGET_OUT_INTERMEDIATES)/ABL_OBJ

$(ABL_OUT):
	mkdir -p $(ABL_OUT)

# Top level target
LOCAL_ABL_PATH := bootable/bootloader/edk2
_LOCAL_PATH := $(LOCAL_PATH)
LOCAL_PATH := $(LOCAL_ABL_PATH)
LOCAL_ABL_SRC_FILE := $(addprefix $(LOCAL_PATH)/,$(call find-subdir-files,-type f))

LOCAL_PATH := $(CLANG_BIN)
CLANG_FILES := $(addprefix $(LOCAL_PATH)/,$(call find-subdir-files,-type f))

LOCAL_PATH := $(CLANG35_GCC_TOOLCHAIN)
GCC_FILES := $(addprefix $(LOCAL_PATH)/,$(call find-subdir-files,-type f))

# Reset LOCAL_PATH to not confuse android build system later
LOCAL_PATH := $(_LOCAL_PATH)

LOCAL_ABL_TOOLS := \
		$(PREBUILT_PYTHON_PATH) \
		$(MAKEPATH)make \
		$(ANDROID_TOP)/$(CLANG) \
		$(ANDROID_TOP)/$(CLANG_CXX) \
		$(ANDROID_TOP)/$(HOST_AR) \
		$(ANDROID_TOP)/$(SOONG_LLVM_PREBUILTS_PATH)/ld.lld \
		$(CLANG_FILES) \
		$(GCC_FILES) \
		$(SECTOOLSV2_BIN)

$(TARGET_ABL): $(LOCAL_ABL_SRC_FILE) $(LOCAL_ABL_TOOLS) | $(ABL_OUT) $(INSTALLED_KEYSTOREIMAGE_TARGET)
	$(MAKEPATH)make -C bootable/bootloader/edk2 \
		BOOTLOADER_OUT=../../../$(ABL_OUT) \
		all \
		PREBUILT_HOST_TOOLS=$(PREBUILT_HOST_TOOLS) \
		PREBUILT_PYTHON_PATH=$(PREBUILT_PYTHON_PATH) \
		MAKEPATH=$(MAKEPATH) \
		$(BUILD_SYSTEM_ROOT_IMAGE) \
		$(VERIFIED_BOOT) \
		$(VERIFIED_BOOT_2) \
		$(VERIFIED_BOOT_LE) \
		$(USER_BUILD_VARIANT) \
		$(DISABLE_PARALLEL_DOWNLOAD_FLASH) \
		$(AB_RETRYCOUNT_DISABLE) \
		$(DYNAMIC_PARTITION_SUPPORT) \
		$(VIRTUAL_AB_OTA) \
		$(DISPLAY_DISABLE) \
		$(BUILD_USES_RECOVERY_AS_BOOT) \
		CLANG_BIN=$(CLANG_BIN) \
		CLANG_PREFIX=$(CLANG35_PREFIX)\
		ABL_USE_SDLLVM=$(ABL_USE_SDLLVM) \
		ABL_SAFESTACK=$(ABL_SAFESTACK) \
		SAFESTACK_SUPPORTED_CLANG_VERSION=$(SAFESTACK_SUPPORTED_CLANG_VERSION) \
		CLANG_GCC_TOOLCHAIN=$(CLANG35_GCC_TOOLCHAIN)\
		TARGET_ARCHITECTURE=$(TARGET_ARCHITECTURE) \
		BOARD_BOOTLOADER_PRODUCT_NAME=$(BOARD_BOOTLOADER_PRODUCT_NAME)


define sec-image-generate
	@echo "Generating signed appsbl using secimagev2 tool"
	@rm -rf $(PRODUCT_OUT)/temp_signed_abl
	( $(SECTOOLSV2_BIN) secure-image $(TARGET_EMMC_BOOTLOADER) \
		--outfile $(PRODUCT_OUT)/abl.elf \
		--image-id ABL \
		--security-profile $(SECTOOLS_SECURITY_PROFILE) \
		--sign \
		--signing-mode TEST \
		> $(PRODUCT_OUT)/secimage.log 2>&1 )
	@echo "Completed secimagev2 signed appsbl (ABL) (logs in $(PRODUCT_OUT)/secimage.log)"
endef


SIGN_ABL := $(PRODUCT_OUT)/temp_signed_abl
$(SIGN_ABL): $(TARGET_EMMC_BOOTLOADER)
	$(call sec-image-generate)
