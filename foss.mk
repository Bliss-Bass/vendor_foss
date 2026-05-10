-include vendor/foss/apps.mk
include $(wildcard $(call my-dir)/*/Android.mk)
# include $(filter-out $(call my-dir)/Android.mk,$(shell find $(call my-dir)/ -type f -name Android.mk))

$(call inherit-product-if-exists, vendor/foss/init-foss-permissions.mk)

PRODUCT_PACKAGES += \
	Provision

PRODUCT_PACKAGES += \
	FDroidPrivilegedExtension \
	IchnaeaNlpBackend \
	NominatimGeocoderBackend

ifeq ($(USE_MINIMAL_FOSS_APPS_WITH_MICROG),true)

PRODUCT_PACKAGES += \
	GmsCore \
	GsfProxy \
	FakeStore

endif

# Copy any Permissions files, overriding anything if needed
$(foreach f,$(wildcard $(LOCAL_PATH)/permissions/*.xml),\
    $(eval PRODUCT_COPY_FILES += $(f):$(TARGET_COPY_OUT_SYSTEM)/etc/permissions/$(notdir $f)))
