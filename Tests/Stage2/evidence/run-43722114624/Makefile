# FilterKit Makefile（Theos 应用模板 — Stage 2.1 草稿，未编译验证）
#
# 基线依据：Spec/Dev-Preparation-0.1.md §4。下列方案/架构口径来自冻结基线；
# 但 Swift 在 Theos 下的工具链配置（vendor/swift-support）、Deployment Target、
# Bundle ID 仍为待确认项（Stage-2.1 子规格 §14 B1/B2/B3/B5），本文件占位，
# 须在 macOS runner 构建时固化，不得视为已可构建。

TARGET := iphone:clang:latest:15.0
INSTALL_PATH := /Applications

# 架构：RootHide arm64e arm64；Rootless arm64。CI 按路线矩阵分别构建。
ARCHS := arm64e arm64

# 路线方案（基线）：
#   RootHide : THEOS_PACKAGE_SCHEME=roothide，定义 THEOS_PACKAGE_SCHEME_ROOTHIDE=1，
#              iphone 目标跳过 -lroot；Theos 源 roothide/theos @ 958fea4。
#   Rootless : THEOS_PACKAGE_SCHEME=rootless，arm64；Theos 源上游 theos/theos（版本待固定）。
# 共用 SDK：theos/sdks @ 0222fd54（patched iPhoneOS 9.3~16.5，无 17.x SDK）。

# 待 2.1 工程创建阶段定值：
#   - Bundle ID（B3）
#   - MinimumOSVersion / Deployment Target（B2，取设备/框架/SDK 兼容交集）
#   - Swift 工具链链接与 rpath（参照旧 PoC：@loader_path/.jbroot/usr/lib，旧工程不作新基线）

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME := FilterKit

FilterKit_FILES := $(shell find App Core Adapters Models -name '*.swift')
FilterKit_PRIVATE_FRAMEWORKS :=
FilterKit_CFLAGS :=
FilterKit_LDFLAGS :=

include $(THEOS)/makefiles/application.mk
