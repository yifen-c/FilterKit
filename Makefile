TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES :=

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = FilterKit
FilterKit_BUNDLE_IDENTIFIER = com.filterkit.manager
FilterKit_FILES = Sources/main.m Sources/FKAppDelegate.m Sources/FKMainViewController.m Sources/FKScanner.m Sources/FKModels.m
FilterKit_CFLAGS = -fobjc-arc -Wall -Wextra -Werror=return-type
FilterKit_FRAMEWORKS = UIKit Foundation CoreServices
FilterKit_PRIVATE_FRAMEWORKS =
FilterKit_INSTALL_PATH = /Applications
FilterKit_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/application.mk

# roothide fork 的 Theos 不会自动把 Info.plist 复制进 App bundle，
# 这里在 stage 阶段手动覆盖复制并做 plutil 语法校验。
after-stage::
	@echo "[FilterKit] Validating App bundle..."
	@test -d "$(THEOS_STAGING_DIR)$(FilterKit_INSTALL_PATH)/$(APPLICATION_NAME).app" || \
		(echo "[FilterKit] ERROR: App bundle not found" && exit 1)
	@test -f "FilterKit-Info.plist" || \
		(echo "[FilterKit] ERROR: FilterKit-Info.plist source missing" && exit 1)
	@cp "FilterKit-Info.plist" \
		"$(THEOS_STAGING_DIR)$(FilterKit_INSTALL_PATH)/$(APPLICATION_NAME).app/Info.plist"
	@plutil -lint \
		"$(THEOS_STAGING_DIR)$(FilterKit_INSTALL_PATH)/$(APPLICATION_NAME).app/Info.plist" > /dev/null || \
		(echo "[FilterKit] ERROR: Invalid Info.plist" && exit 1)
	@echo "[FilterKit] Info.plist installed and validated successfully"

.PHONY: package-roothide package-rootless clean-packages

package-roothide:
	$(MAKE) package THEOS_PACKAGE_SCHEME=roothide ARCHS=arm64e FINALPACKAGE=1

package-rootless:
	$(MAKE) package THEOS_PACKAGE_SCHEME=rootless ARCHS=arm64 FINALPACKAGE=1

clean-packages:
	rm -rf packages .theos
