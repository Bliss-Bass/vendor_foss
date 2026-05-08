# vendor_foss

A unified toolkit for packaging and injecting core FOSS applications—primarily **microG**, **F-Droid**, and related services—into Android devices. 

Originally designed as a set of FOSS applications to include directly in AOSP builds, this project has evolved into a powerful, automated tool for generating **unified systemless flashable zips** compatible with Magisk, KernelSU, and TWRP Recovery, alongside its traditional AOSP vendor/foss module support.

## Features

- **Unified Flashable Zips:** Automatically generates a single `.zip` file per architecture that can be flashed natively as a systemless module via **Magisk** or **KernelSU**, or flashed directly to the system partition via **TWRP Recovery**.
- **Automated Downloads:** Fetches the latest APKs directly from F-Droid (with fallback mirrors) and the microG repositories.
- **Multi-Architecture Support:** Builds modules tailored for `arm64-v8a`, `armeabi-v7a`, `x86_64`, and `x86` architectures.
- **Native Library Extraction:** Automatically extracts and places `.so` files from downloaded APKs into the correct lib directories for system injection.
- **AOSP Integration:** Generates `foss-permissions.xml` and `Android.mk` for seamless inclusion into custom ROM builds.

## Usage: Building the Zips

The `update.sh` script is the main entry point. It downloads the apps, generates the makefiles and permissions, and builds the unified flashable zips.

```bash
# Interactive mode (prompts for architecture)
$ bash update.sh

# Headless mode (specify architecture directly)
$ bash update.sh x86_64
$ bash update.sh 1

# Clean mode (cleans build directories before building)
$ bash update.sh -c arm64-v8a
```

### Command Line Arguments

The `update.sh` script accepts the following optional arguments:

- `--clean` or `-c`: Cleans up the `bin`, `tmp`, `tmp_libs`, `permissions`, `apps.mk`, `Android.mk`, and `output` directories before running. *(Note: If passed alone without an architecture, it only cleans and then exits).*
- **Architecture Selection**: You can bypass the interactive prompt by passing the architecture name or its corresponding number:
  - `1` or `x86_64`
  - `2` or `arm64-v8a`
  - `3` or `x86`
  - `4` or `armeabi-v7a`

Once the script completes, the unified flashable zip will be available in the `output/` directory (e.g., `output/vendor_foss-arm64-v8a.zip`).

### Flashing Instructions

- **Magisk / KernelSU:** Open your root manager app, go to the Modules tab, select "Install from storage", and choose the generated zip. The `#MAGISK` tag handles systemless installation automatically.
- **TWRP / Recovery:** Boot into recovery and flash the zip. The fallback `update-binary` will attempt to install the apps directly to `/system/priv-app/`. *(Note: This requires a writable system partition; dynamic/EROFS partitions are not supported in this mode).*

## AOSP Build Instructions

To include the FOSS apps directly into your device-specific AOSP builds, clone this repo into `vendor/foss`:

```bash
$ git clone https://github.com/supremegamers/vendor_foss vendor/foss
```

Run `bash update.sh [arch]` to download the assets, then add this inherit to your device tree (`device.mk`):

```makefile
# foss apps
$(call inherit-product-if-exists, vendor/foss/foss.mk)
```

## Included Core Apps

#### From MicroG Repo:
- MicroG GMS Core - `com.google.android.gms`
- MicroG Services Framework Proxy - `com.google.android.gsf`
- FakeStore (Play Store stub) - `com.android.vending`
- DroidGuard Proxy - `org.microg.gms.droidguard`

#### From F-Droid Repo:
- F-Droid Privileged Extension
- Aurora Store - `com.aurora.store`
- Location Backends (e.g., LocalGsmNlpBackend)
- Other FOSS essentials

### Important Notes

- **Signature Spoofing:** For microG to function correctly, your ROM **must** support Signature Spoofing. If your ROM doesn't include it natively, you must patch it or use a framework module.
- **Privileged Permissions:** The generated zip and AOSP modules automatically place microG and FakeStore in `/system/priv-app/` and inject the necessary `privapp-permissions` XML files to ensure they run with elevated privileges.
