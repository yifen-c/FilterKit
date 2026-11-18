#!/usr/bin/env node
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const required = [
  'Makefile','control','entitlements.plist','FilterKit-Info.plist','README.md',
  'Sources/App/main.m','Sources/App/FKAppDelegate.m',
  'Sources/Core/FKScanner.m','Sources/Core/FKScanner.h','Sources/Core/FKDPKGAnalyzer.m',
  'Sources/Core/FKDPKGAnalyzer.h','Sources/Models/FKModels.m','Sources/Models/FKModels.h',
  'Sources/Models/FKManageModels.h','Sources/Models/FKManageModels.m',
  'Sources/Managers/FKPluginManager.h','Sources/Managers/FKPluginManager.m',
  'Sources/Managers/FKAppManager.h','Sources/Managers/FKAppManager.m',
  'Sources/Backup/FKBackupManager.h','Sources/Backup/FKBackupManager.m',
  'Sources/Backup/FKBackupManifest.h','Sources/Backup/FKBackupManifest.m',
  'Sources/Backup/FKBackupValidator.h','Sources/Backup/FKBackupValidator.m',
  'Sources/Backup/FKFileHasher.h','Sources/Backup/FKFileHasher.m',
  'Sources/Backup/FKBackupResult.h','Sources/Backup/FKBackupResult.m',
  'Sources/Backup/FKBackupOperation.h','Sources/Backup/FKBackupOperation.m',
  'Sources/Backup/FKConfigurationBackup.h','Sources/Backup/FKConfigurationBackup.m',
  'Sources/Models/FKOperationModels.h','Sources/Models/FKOperationModels.m',
  'Sources/Models/FKAppPluginAssociation.h','Sources/Models/FKAppPluginAssociation.m',
  'Sources/Models/FKInjectionPreview.h','Sources/Models/FKInjectionPreview.m',
  'Sources/Models/FKPluginCompatibility.h','Sources/Models/FKPluginCompatibility.m',
  'Sources/Helper/FKHelperProtocol.h','Sources/Helper/FKHelperProtocol.m',
  'Sources/Helper/FKHelperValidator.h','Sources/Helper/FKHelperValidator.m',
  'Sources/Helper/FKHelperClient.h','Sources/Helper/FKHelperClient.m',
  'Sources/Helper/FKHelperTrust.h','Sources/Helper/FKHelperTrust.m',
  'Sources/Helper/FKHelperIdentityVerifier.h','Sources/Helper/FKHelperIdentityVerifier.m',
  'Sources/Helper/FKHelperSignatureVerifier.h','Sources/Helper/FKHelperSignatureVerifier.m',
  'Sources/Helper/FKHelperPermissionVerifier.h','Sources/Helper/FKHelperPermissionVerifier.m',
  'Sources/Helper/FKHelperTrustVerifier.h','Sources/Helper/FKHelperTrustVerifier.m',
  'Sources/Helper/FKHelperEvidence.h','Sources/Helper/FKHelperEvidence.m',
  'Sources/Helper/FKHelperTrustStore.h','Sources/Helper/FKHelperTrustStore.m',
  'Sources/Helper/FKHelperTrustEvaluator.h','Sources/Helper/FKHelperTrustEvaluator.m',
  'Sources/Helper/FKIPCRequest.h','Sources/Helper/FKIPCRequest.m',
  'Sources/Helper/FKIPCResponse.h','Sources/Helper/FKIPCResponse.m',
  'Sources/Helper/FKHelperConnection.h','Sources/Helper/FKHelperConnection.m',
  'Sources/Helper/FKHelperMetadata.h','Sources/Helper/FKHelperMetadata.m',
  'Sources/Helper/FKHelperDiscovery.h','Sources/Helper/FKHelperDiscovery.m',
  'Sources/Helper/FKHelperIntegrityVerifier.h','Sources/Helper/FKHelperIntegrityVerifier.m',
  'Sources/Helper/FKHelperIPCError.h','Sources/Helper/FKHelperIPCError.m',
  'Sources/Helper/FKHelperIPCHandshake.h','Sources/Helper/FKHelperIPCHandshake.m',
  'Sources/Helper/FKHelperIPCCapabilities.h','Sources/Helper/FKHelperIPCCapabilities.m',
  'Sources/Helper/FKHelperCapabilityManager.h','Sources/Helper/FKHelperCapabilityManager.m',
  'Sources/Helper/FKOperationPermissionEvaluator.h','Sources/Helper/FKOperationPermissionEvaluator.m',
  'Sources/Helper/FKHelperIdentity.h','Sources/Helper/FKHelperIdentity.m',
  'Sources/Helper/FKHelperReleaseMetadata.h','Sources/Helper/FKHelperReleaseMetadata.m',
  'Sources/Helper/FKHelperBuildInfo.h','Sources/Helper/FKHelperBuildInfo.m',
  'Sources/Helper/FKHelperTrustManifest.h','Sources/Helper/FKHelperTrustManifest.m',
  'Sources/Helper/FKHelperManifestVerifier.h','Sources/Helper/FKHelperManifestVerifier.m',
  'Sources/Helper/FKHelperMessage.h','Sources/Helper/FKHelperMessage.m',
  'Sources/Helper/FKHelperMessageError.h','Sources/Helper/FKHelperMessageError.m',
  'Sources/Helper/FKHelperCapabilities.h','Sources/Helper/FKHelperCapabilities.m',
  'Sources/Helper/FKHelperHandshake.h','Sources/Helper/FKHelperHandshake.m',
  'Sources/Helper/FKHelperTransport.h','Sources/Helper/FKHelperTransportState.h','Sources/Helper/FKHelperTransportState.m',
  'Sources/Helper/FKHelperTestTransport.h','Sources/Helper/FKHelperTestTransport.m',
  'Sources/Helper/FKHelperReadOnlyClient.h','Sources/Helper/FKHelperReadOnlyClient.m',
  'Sources/Helper/FKMockHelperClient.h','Sources/Helper/FKMockHelperClient.m',
  'Sources/Helper/FKHelperServiceInfo.h','Sources/Helper/FKHelperServiceInfo.m',
  'Sources/Helper/FKHelperServiceEndpoint.h','Sources/Helper/FKHelperServiceEndpoint.m',
  'Sources/Helper/FKHelperServiceDiscovery.h','Sources/Helper/FKHelperServiceDiscovery.m',
  'Sources/Helper/FKHelperConnectionStatus.h','Sources/Helper/FKHelperConnectionStatus.m',
  'Sources/Helper/FKHelperPeerVerifier.h','Sources/Helper/FKHelperPeerVerifier.m',
  'Sources/Helper/FKHelperSession.h','Sources/Helper/FKHelperSession.m',
  'Sources/Helper/FKHelperHandshakeValidator.h','Sources/Helper/FKHelperHandshakeValidator.m',
  'Sources/Helper/FKHelperRequestRouter.h','Sources/Helper/FKHelperRequestRouter.m',
  'Sources/Helper/FKHelperPluginInfo.h','Sources/Helper/FKHelperPluginInfo.m',
  'Sources/Helper/FKHelperConfigurationSnapshot.h','Sources/Helper/FKHelperConfigurationSnapshot.m',
  'Sources/Helper/FKHelperIPCAuditEvent.h','Sources/Helper/FKHelperIPCAuditEvent.m',
  'Sources/Helper/FKHelperReadOnlyProvider.h',
  'Sources/Helper/FKHelperDeploymentAssessment.h','Sources/Helper/FKHelperDeploymentAssessment.m',
  'Sources/Helper/FKHelperMessageAuthenticator.h','Sources/Helper/FKHelperMessageAuthenticator.m',
  'Sources/Helper/FKHelperReplayProtector.h','Sources/Helper/FKHelperReplayProtector.m',
  'Sources/Helper/FKHelperFrameCodec.h','Sources/Helper/FKHelperFrameCodec.m',
  'Sources/Helper/FKHelperTransportAssessment.h','Sources/Helper/FKHelperTransportAssessment.m',
  'Sources/Tests/FKHelperDeploymentTests.h','Sources/Tests/FKHelperDeploymentTests.m',
  'Sources/Tests/FKHelperAuthenticationTests.h','Sources/Tests/FKHelperAuthenticationTests.m',
  'Sources/Tests/FKHelperReplayTests.h','Sources/Tests/FKHelperReplayTests.m',
  'Sources/Tests/FKHelperFrameTests.h','Sources/Tests/FKHelperFrameTests.m',
  'Sources/Tests/FKHelperTransportAssessmentTests.h','Sources/Tests/FKHelperTransportAssessmentTests.m',
  'Sources/Operation/FKOperationGate.h','Sources/Operation/FKOperationGate.m',
  'Sources/Operation/FKOperationRequirement.h','Sources/Operation/FKOperationRequirement.m',
  'Sources/Operation/FKOperationPolicy.h','Sources/Operation/FKOperationPolicy.m',
  'Sources/Operation/FKOperationEligibility.h','Sources/Operation/FKOperationEligibility.m',
  'Sources/Operation/FKOperationStateMachine.h','Sources/Operation/FKOperationStateMachine.m',
  'Sources/Operation/FKOperationTransaction.h','Sources/Operation/FKOperationTransaction.m',
  'Sources/Operation/FKOperationVerifier.h','Sources/Operation/FKOperationVerifier.m',
  'Sources/Operation/FKOperationRollback.h','Sources/Operation/FKOperationRollback.m',
  'Sources/Managers/FKAuditManager.h','Sources/Managers/FKAuditManager.m',
  'Sources/Managers/FKAssociationManager.h','Sources/Managers/FKAssociationManager.m',
  'Sources/Managers/FKInjectionPreviewManager.h','Sources/Managers/FKInjectionPreviewManager.m',
  'Sources/Managers/FKCompatibilityManager.h','Sources/Managers/FKCompatibilityManager.m',
  'Sources/Managers/FKStateManager.h','Sources/Managers/FKStateManager.m',
  'Sources/Operation/FKOperationManager.h','Sources/Operation/FKOperationManager.m',
  'Sources/Views/Main/FKMainViewController.h','Sources/Views/Main/FKMainViewController.m',
  'Sources/Views/Home/FKHomeViewController.h','Sources/Views/Home/FKHomeViewController.m',
  'Sources/Views/Helper/FKHelperDetailsViewController.h','Sources/Views/Helper/FKHelperDetailsViewController.m',
  'Sources/Views/Apps/FKAddPluginViewController.h','Sources/Views/Apps/FKAddPluginViewController.m',
  'Sources/Views/Apps/FKInjectionPreviewViewController.h','Sources/Views/Apps/FKInjectionPreviewViewController.m',
  'Sources/Views/List/FKDataListController.h','Sources/Views/List/FKDataListController.m',
  'Sources/Views/Detail/FKDetailController.h','Sources/Views/Detail/FKDetailController.m',
  'Sources/Views/Import/FKImportController.h','Sources/Views/Import/FKImportController.m',
  'Sources/Views/Settings/FKSettingsController.h','Sources/Views/Settings/FKSettingsController.m',
  'Sources/Views/Operation/FKOperationConfirmController.h','Sources/Views/Operation/FKOperationConfirmController.m',
  'Sources/Views/Operation/FKHistoryController.h','Sources/Views/Operation/FKHistoryController.m',
  'Sources/Views/Backup/FKBackupListController.h','Sources/Views/Backup/FKBackupListController.m',
  'Sources/Views/Backup/FKBackupDetailController.h','Sources/Views/Backup/FKBackupDetailController.m',
  'Sources/Environment/FKEnvironmentCompatibility.h','Sources/Environment/FKEnvironmentCompatibility.m',
  'Sources/Environment/FKEnvironmentEvidence.h','Sources/Environment/FKEnvironmentEvidence.m',
  'Sources/Environment/FKEnvironmentModel.h','Sources/Environment/FKEnvironmentModel.m',
  'Sources/Environment/FKEnvironmentValidator.h','Sources/Environment/FKEnvironmentValidator.m',
  'Sources/Environment/FKEnvironmentDetector.h','Sources/Environment/FKEnvironmentDetector.m',
  'Sources/Injector/FKInjectorProfile.h','Sources/Injector/FKInjectorProfile.m',
  'Sources/Injector/FKInjectorModel.h','Sources/Injector/FKInjectorModel.m',
  'Sources/Injector/FKInjectorCompatibility.h','Sources/Injector/FKInjectorCompatibility.m',
  'Sources/Injector/FKInjectorRegistry.h','Sources/Injector/FKInjectorRegistry.m',
  'Sources/Injector/FKInjectorDetector.h','Sources/Injector/FKInjectorDetector.m',
  'Sources/Security/FKSecurityEvent.h','Sources/Security/FKSecurityEvent.m',
  'Sources/Security/FKSecurityEvidenceStore.h','Sources/Security/FKSecurityEvidenceStore.m',
  'Sources/Security/FKSecurityReport.h','Sources/Security/FKSecurityReport.m',
  'Sources/Security/FKSecurityAuditManager.h','Sources/Security/FKSecurityAuditManager.m',
  'Sources/Tests/FKTestRunner.h','Sources/Tests/FKTestRunner.m',
  'Sources/Tests/FKModelTests.m','Sources/Tests/FKBackupTests.m','Sources/Tests/FKJSONTests.m','Sources/Tests/FKOperationTests.m',
  'Sources/Tests/FKHelperTrustTests.h','Sources/Tests/FKHelperTrustTests.m',
  'Sources/Tests/FKHelperIdentityTests.h','Sources/Tests/FKHelperIdentityTests.m',
  'Sources/Tests/FKHelperMetadataTests.h','Sources/Tests/FKHelperMetadataTests.m',
  'Sources/Tests/FKHelperManifestTests.h','Sources/Tests/FKHelperManifestTests.m',
  'Sources/Tests/FKHelperIntegrityTests.h','Sources/Tests/FKHelperIntegrityTests.m',
  'Sources/Tests/FKHelperProtocolTests.h','Sources/Tests/FKHelperProtocolTests.m',
  'Sources/Tests/FKHelperTransportTests.h','Sources/Tests/FKHelperTransportTests.m',
  'Sources/Tests/FKHelperReportTests.h','Sources/Tests/FKHelperReportTests.m',
  'Sources/Tests/FKHelperCapabilityTests.h','Sources/Tests/FKHelperCapabilityTests.m',
  'Sources/Tests/FKHelperGateTests.h','Sources/Tests/FKHelperGateTests.m',
  'Sources/Tests/FKHelperDiscoveryTests.h','Sources/Tests/FKHelperDiscoveryTests.m',
  'Sources/Tests/FKHelperPeerTests.h','Sources/Tests/FKHelperPeerTests.m',
  'Sources/Tests/FKHelperHandshakeTests.h','Sources/Tests/FKHelperHandshakeTests.m',
  'Sources/Tests/FKHelperRouterTests.h','Sources/Tests/FKHelperRouterTests.m',
  'Sources/Tests/FKHelperPluginTests.h','Sources/Tests/FKHelperPluginTests.m',
  'Sources/Tests/FKHelperConfigurationTests.h','Sources/Tests/FKHelperConfigurationTests.m',
  'Sources/Tests/FKHelperAuditTests.h','Sources/Tests/FKHelperAuditTests.m',
  'Sources/Tests/FKHelperBoundaryTests.h','Sources/Tests/FKHelperBoundaryTests.m',
  'Sources/Security/FKCapabilityEvaluator.h','Sources/Security/FKCapabilityEvaluator.m',
  'Resources/Helper/helper-release-manifest.json','Resources/Helper/helper-release-manifest.sig',
  'Resources/Helper/helper-deployment-profile.json','Resources/Helper/helper-readiness-profile.json',
  '.github/workflows/build.yml'
];
const missing = required.filter(f => !fs.existsSync(path.resolve(f)));
if (missing.length) { console.error(`项目文件缺失：\n${missing.join('\n')}`); process.exit(1); }
const read = f => fs.readFileSync(f,'utf8');
const readDir = dir => fs.readdirSync(dir).filter(n=>/\.(m|h)$/.test(n)).map(n=>read(path.join(dir,n))).join('\n');
const scanner=read('Sources/Core/FKScanner.m');
const ui = ['Main','Home','Apps','List','Detail','Import','Settings','Operation','Backup']
  .map(sub => readDir(`Sources/Views/${sub}`)).join('\n');
const workflow=read('.github/workflows/build.yml'), makefile=read('Makefile'), appDelegate=read('Sources/App/FKAppDelegate.m');
const plist=read('FilterKit-Info.plist'), control=read('control');
const scannerTokens=[
 'jbrootFunction("/")','jbrandFunction()','dlsym(RTLD_DEFAULT, "jbroot")','NSBundle.mainBundle.bundlePath',
 'lstat(','stat(','realpath(','access(','opendir(','CFBundleShortVersionString',
 'NSPropertyListSerialization','var/lib/dpkg/status','var/lib/dpkg/info',
 'iconDataForVariant:withOptions:','@"Classes"','FKStatusInstalled','FKInjectorTypeForPackage',
 'FKRuntimeInjectorImages','suspect_packages','framework_info_plist','global_semantics_verified',
 'FKBuildPluginAssociation','same_directory_and_case_insensitive_basename','owned_files',
 'FKDPKGAnalyzer','dpkg_analysis','dpkg_metadata','dpkg_state','dpkg_file_integrity',
 'dpkg_checksum','plugin_source','ownership_conflict','matched_bundle_ids',
 'unmatched_bundle_ids','missing_dylib','missing_plist','plugin_association'
];
for (const token of scannerTokens) if(!scanner.includes(token)){console.error(`扫描器缺少 0.0.6 基线实现：${token}`);process.exit(1);}
for (const token of ['UITabBarController','@"首页"','@"App"','@"插件"','@"设置"',
 'UISearchController','UIDocumentPickerViewController','FilterKit-0.1.18-report.json',
 '只读预览','FKDetailController','configuration_review_mismatches',
 'FKBackupListController','FKBackupDetailController','FKOperationConfirmController','trustReport']) {
 if(!ui.includes(token)){console.error(`UI 缺少必要实现：${token}`);process.exit(1);}
}
for (const token of ['workflow_dispatch:','macos-latest','node-version: latest',
 'https://github.com/roothide/theos.git','https://github.com/theos/theos.git',
 'THEOS_PACKAGE_SCHEME=roothide','THEOS_PACKAGE_SCHEME=rootless','FilterKit-0.1.18-']) {
 if(!workflow.includes(token)){console.error(`工作流缺少必要配置：${token}`);process.exit(1);}
}
if(/^\s{2}(push|pull_request|create|release):/m.test(workflow)){console.error('工作流不应自动触发构建。');process.exit(1);}
if(!makefile.includes('UniformTypeIdentifiers')||!appDelegate.includes('self.window.rootViewController = [FKMainViewController new];')){console.error('UIKit TabBar 根控制器或文件选择器 framework 配置缺失。');process.exit(1);}
if(!makefile.includes('-weak-lroothide')||!makefile.includes('@loader_path/.jbroot/usr/lib')){console.error('RootHide 链接/rpath 配置缺失。');process.exit(1);}
if(!plist.includes('<string>0.1.18</string>')||!control.includes('Version: 0.1.18')||!scanner.includes('FKVersion = @"0.1.18"')){
 console.error('应用、扫描报告和 DEB 版本不一致。');process.exit(1);
}
const ids=[...scanner.matchAll(/@"(jbroot|dynamic_paths|dylib_scan|plist_read|filter_parse|dpkg_status|dpkg_ownership|ellekit_version|app_enumeration|app_metadata|plugin_association|dpkg_metadata|dpkg_state|dpkg_file_integrity|dpkg_checksum|plugin_source|ownership_conflict|roothelper_preflight)"/g)].map(m=>m[1]);
if(new Set(ids).size!==18){console.error(`验收项应为 18 项，当前 ${new Set(ids).size}`);process.exit(1);}
const analyzer=read('Sources/Core/FKDPKGAnalyzer.m');
for (const token of ['FKDChecksumFileType','mach_o','Conffiles','checksum_analysis','by_file_type','by_path_category','by_extension','by_package','hard_failures','mutable_config','configuration_review','file_type_totals','binary_mismatch_rate','configuration_review_mismatches']) {
 if(!analyzer.includes(token)){console.error(`MD5 分类分析缺少实现：${token}`);process.exit(1);}
}
for (const token of ['checksum_hard_failures','checksum_warnings','checksumNotConfirmed','mach_o_mismatches']) {
 if(!scanner.includes(token) && !analyzer.includes(token)){console.error(`MD5 分级验收缺少实现：${token}`);process.exit(1);}
}
if(!scanner.includes('roothelper_preflight')||!scanner.includes('startup_performed')||!scanner.includes('ipc_performed')){console.error('RootHelper 只读预检缺少安全边界字段。');process.exit(1);}

// 0.1.0 基础插件管理版：模型层、管理器层与备份只读校验关键接口。
const models=read('Sources/Models/FKManageModels.m'), pluginMgr=read('Sources/Managers/FKPluginManager.m'),
      appMgr=read('Sources/Managers/FKAppManager.m'), backupMgr=read('Sources/Backup/FKBackupManager.m');
for (const token of ['FKPluginModel','FKAppModel','FKFilterModel','FKPackageModel','associationType','integrityStatus']) {
 if(!models.includes(token)){console.error(`模型层缺少实现：${token}`);process.exit(1);}
}
for (const token of ['pluginsWithFilter','globalPlugins','unmatchedPlugins','associatedPlugins','pluginsForBundleID']) {
 if(!pluginMgr.includes(token)){console.error(`插件管理器缺少实现：${token}`);process.exit(1);}
}
for (const token of ['pluginsForApp','injectionSummaryForApp','runtime_injection_verified']) {
 if(!appMgr.includes(token)){console.error(`App 管理器缺少实现：${token}`);process.exit(1);}
}
for (const token of ['createPluginBackup','validateBackupAtURL','block_sha256','CC_SHA256','exportBackupToURL','FKBackupDidFinishNotification','FKBackupProgressNotification','activeBackupResults','updateActiveResult']) {
 if(!backupMgr.includes(token)){console.error(`备份管理器缺少实现：${token}`);process.exit(1);}
}
// 安全边界：只读管理器与备份层不得出现安装/卸载/启停/写配置等特权调用入口。
for (const forbidden of ['installPackage','uninstallPackage','writeToFile:Filter','launchctl']) {
 if(pluginMgr.includes(forbidden)||appMgr.includes(forbidden)||backupMgr.includes(forbidden)){
   console.error(`0.1.1 只读层不应包含写操作入口：${forbidden}`);process.exit(1);
 }
}

// 0.1.1 状态管理与安全操作版：模型、Helper 骨架、状态/操作/审计管理器关键接口。
const opModels=read('Sources/Models/FKOperationModels.m'), helperProto=read('Sources/Helper/FKHelperProtocol.m'),
      helperValidator=read('Sources/Helper/FKHelperValidator.m'), helperClient=read('Sources/Helper/FKHelperClient.m'),
      auditMgr=read('Sources/Managers/FKAuditManager.m'), stateMgr=read('Sources/Managers/FKStateManager.m'),
      opMgr=read('Sources/Operation/FKOperationManager.m');
for (const token of ['FKPluginStatus','FKOperationRequest','FKOperationResult','FKOperationRecord']) {
 if(!opModels.includes(token)){console.error(`操作模型层缺少实现：${token}`);process.exit(1);}
}
for (const token of ['FKHelperErrorDomain','FKHelperOperationIsAllowed','FKHelperOperationName']) {
 if(!helperProto.includes(token)){console.error(`Helper 协议缺少实现：${token}`);process.exit(1);}
}
for (const token of ['validateRequest','validateTargetPath','identityVerified']) {
 if(!helperValidator.includes(token)){console.error(`Helper 校验器缺少实现：${token}`);process.exit(1);}
}
for (const token of ['available','performOperation','helper_unavailable']) {
 if(!helperClient.includes(token)){console.error(`Helper 客户端缺少实现：${token}`);process.exit(1);}
}
for (const token of ['appendRecord','recordsForPluginID','recordsForOperation']) {
 if(!auditMgr.includes(token)){console.error(`审计管理器缺少实现：${token}`);process.exit(1);}
}
for (const token of ['stateForPluginID','allStates','unsupportedReason']) {
 if(!stateMgr.includes(token)){console.error(`状态管理器缺少实现：${token}`);process.exit(1);}
}
for (const token of ['previewForPluginID','validatePlugin','enablePlugin','disablePlugin','restoreOperation']) {
 if(!opMgr.includes(token)){console.error(`操作管理器缺少实现：${token}`);process.exit(1);}
}
for (const token of ['createOperationBackupForRequest','validateOperationBackup','operationBackupWithID']) {
 if(!backupMgr.includes(token)){console.error(`操作备份缺少实现：${token}`);process.exit(1);}
}
// 安全边界：不得提供任意命令执行器；Helper 客户端只接受白名单操作枚举。
for (const forbidden of ['executeCommand','system(','popen(','NSTask','posix_spawn']) {
 if(helperClient.includes(forbidden)||opMgr.includes(forbidden)){
   console.error(`0.1.1 不应包含任意命令执行入口：${forbidden}`);process.exit(1);
 }
}
// 0.1.2 安全管理与操作预演版：哈希/清单/校验、Helper 信任层、准入闸门关键接口。
const hasher=read('Sources/Backup/FKFileHasher.m'), manifest=read('Sources/Backup/FKBackupManifest.m'),
      validator=read('Sources/Backup/FKBackupValidator.m'), trust=read('Sources/Helper/FKHelperTrust.m'),
      idVer=read('Sources/Helper/FKHelperIdentityVerifier.m'), sigVer=read('Sources/Helper/FKHelperSignatureVerifier.m'),
      permVer=read('Sources/Helper/FKHelperPermissionVerifier.m'), trustVer=read('Sources/Helper/FKHelperTrustVerifier.m'),
      gate=read('Sources/Operation/FKOperationGate.m');
for (const token of ['MD5ForFileAtURL','SHA256ForFileAtURL','hashForFileAtURL']) {
 if(!hasher.includes(token)){console.error(`哈希模块缺少实现：${token}`);process.exit(1);}
}
for (const token of ['original_path','backup_rel_path','sha256','entryFromDictionary','manifestFromDictionary']) {
 if(!manifest.includes(token)){console.error(`备份清单缺少实现：${token}`);process.exit(1);}
}
for (const token of ['validateBackupAtDirectory','restorePreviewForManifest','TARGET_MODIFIED','BACKUP_CORRUPTED']) {
 if(!validator.includes(token)){console.error(`备份校验器缺少实现：${token}`);process.exit(1);}
}
for (const ver of [[idVer,'verifyIdentityWithPath'],[sigVer,'verifySignatureWithPath'],[permVer,'verifyPermissionForOperationName'],[trustVer,'evaluateCandidates']]) {
 if(!ver[0].includes(ver[1])){console.error(`Helper 信任层缺少实现：${ver[1]}`);process.exit(1);}
}
for (const token of ['checksForPlugin','gateForChecks','isOperationEligible','gateText','helper_trust']) {
 if(!gate.includes(token)){console.error(`准入闸门缺少实现：${token}`);process.exit(1);}
}
// 安全边界：0.1.2 新增备份/信任/校验层同样不得出现特权写、命令执行或覆盖越狱文件入口。
for (const forbidden of ['installPackage','uninstallPackage','launchctl','system(','popen(','NSTask','posix_spawn','executeCommand']) {
 if([hasher,manifest,validator,trust,idVer,sigVer,permVer,trustVer,gate].some(f=>f.includes(forbidden))){
   console.error(`0.1.2 只读/信任层不应包含特权入口：${forbidden}`);process.exit(1);
 }
}

// 0.1.3 稳定性与模块化：异步备份、历史新字段、环境兼容性结论关键接口。
const backupResult=read('Sources/Backup/FKBackupResult.m'),
      backupOp=read('Sources/Backup/FKBackupOperation.m');
for (const token of ['FKBackupStatusCompleted','FKBackupStatusCancelled','JSONDictionary']) {
 if(!backupResult.includes(token)){console.error(`备份结果模型缺少实现：${token}`);process.exit(1);}
}
for (const token of ['backupPluginAsync','runBackupForPluginID','backupQueue']) {
 if(!backupMgr.includes(token)){console.error(`备份管理器异步接口缺少实现：${token}`);process.exit(1);}
}
for (const token of ['FKBackupOperation','isCancelled','completionHandler']) {
 if(!backupOp.includes(token)){console.error(`备份任务类缺少实现：${token}`);process.exit(1);}
}
for (const token of ['@"mode"','@"reasons"','@"helper_status"','@"checks"']) {
 if(!opModels.includes(token)){console.error(`操作历史新字段缺少实现：${token}`);process.exit(1);}
}
for (const token of ['jailbreak_type','jbroot_detected','compatibility']) {
 if(!scanner.includes(token)){console.error(`环境兼容性结论缺少实现：${token}`);process.exit(1);}
}
// 安全边界：0.1.3 拆分出的控制器与异步备份任务同样不得出现特权写或命令执行入口。
for (const forbidden of ['installPackage','uninstallPackage','launchctl','system(','popen(','NSTask','posix_spawn','executeCommand']) {
 if([ui,backupOp].some(f=>f.includes(forbidden))){
   console.error(`0.1.3 控制器/异步备份层不应包含特权入口：${forbidden}`);process.exit(1);
 }
}

// 0.1.4 兼容性与安全验证：环境 / 注入器 / Helper / 闸门 / 协议 / 安全审计 / 测试关键接口。
const envDir=readDir('Sources/Environment'), injectorDir=readDir('Sources/Injector'),
      secDir=readDir('Sources/Security'), testsDir=readDir('Sources/Tests');
const evidence=read('Sources/Helper/FKHelperEvidence.m'), trustStore=read('Sources/Helper/FKHelperTrustStore.m'),
      evaluator=read('Sources/Helper/FKHelperTrustEvaluator.m'),
      ipcReq=read('Sources/Helper/FKIPCRequest.m'), ipcResp=read('Sources/Helper/FKIPCResponse.m'),
      requirement=read('Sources/Operation/FKOperationRequirement.m'), policy=read('Sources/Operation/FKOperationPolicy.m'),
      eligibility=read('Sources/Operation/FKOperationEligibility.m'), gateNew=read('Sources/Operation/FKOperationGate.m');
for (const token of ['FKCompatibilityStatus','FKEnvironmentEvidence','FKEnvironmentModel','FKEnvironmentValidator','FKEnvironmentDetector','confidence','jbroot']) {
 if(!envDir.includes(token)){console.error(`环境模块缺少实现：${token}`);process.exit(1);}
}
for (const token of ['FKInjectorProfile','FKInjectorModel','FKInjectorRegistry','profileForInjector','compatibilityForPlugin','managementVerified']) {
 if(!injectorDir.includes(token)){console.error(`注入器模块缺少实现：${token}`);process.exit(1);}
}
for (const token of ['trust_chain_source','signer_subject','file_digest']) {
 if(!evidence.includes(token)){console.error(`Helper 证据模型缺少实现：${token}`);process.exit(1);}
}
for (const token of ['hasTrustedAnchorForPackageID','anchorSourceForPackageID','policyVersion']) {
 if(!trustStore.includes(token)){console.error(`Helper 可信策略缺少实现：${token}`);process.exit(1);}
}
for (const token of ['evaluateCandidates','FKHelperEvidence','trustChainSource']) {
 if(!evaluator.includes(token)){console.error(`Helper 评估器缺少实现：${token}`);process.exit(1);}
}
for (const token of ['nonce','request_id','protocol_version','authorization']) {
 if(!ipcReq.includes(token)){console.error(`IPC 请求模型缺少字段：${token}`);process.exit(1);}
}
for (const token of ['status','result','error']) {
 if(!ipcResp.includes(token)){console.error(`IPC 响应模型缺少字段：${token}`);process.exit(1);}
}
for (const token of ['preview_only','allowsRealOperation','requiredRequirementIDs']) {
 if(!policy.includes(token)){console.error(`操作策略缺少实现：${token}`);process.exit(1);}
}
for (const token of ['eligible','blockReasons','status']) {
 if(!eligibility.includes(token)){console.error(`准入结论模型缺少实现：${token}`);process.exit(1);}
}
for (const token of ['eligibilityForPlugin','environmentOK','userAuthorized','injectorCompatible']) {
 if(!gateNew.includes(token)){console.error(`准入闸门缺少高层评估接口：${token}`);process.exit(1);}
}
for (const token of ['FKSecurityEvent','FKSecurityEvidenceStore','FKSecurityReport','FKSecurityAuditManager','gate_rejection']) {
 if(!secDir.includes(token)){console.error(`安全审计模块缺少实现：${token}`);process.exit(1);}
}
for (const token of ['FKTestRunner','runAllChecks','FKModelTests','FKBackupTests','FKJSONTests','FKOperationTests']) {
 if(!testsDir.includes(token)){console.error(`最小测试骨架缺少实现：${token}`);process.exit(1);}
}

// 0.1.5 主流程接线：新评估段进入报告 JSON，主控制器接入评估器 / 测试 / 备份审计与导出事件。
const mainVC=read('Sources/Views/Main/FKMainViewController.m'),
      confirmVC=read('Sources/Views/Operation/FKOperationConfirmController.m'),
      runner=read('Sources/Tests/FKTestRunner.m');
for (const token of ['environment_assessment','injector_assessment','helper_trust','security_report','test_summary']) {
 if(!scanner.includes(token)){console.error(`报告 JSON 缺少 0.1.5 接线段：${token}`);process.exit(1);}
}
for (const token of ['evaluateCandidates','runSummary','FKSecurityEventTypeReportExport','FKSecurityEventTypeBackup','backupManager.auditManager']) {
 if(!mainVC.includes(token)){console.error(`主控制器缺少 0.1.5 接线：${token}`);process.exit(1);}
}
for (const token of ['evaluateOperationForPlugin','FKOperationEligibility']) {
 if(!confirmVC.includes(token)){console.error(`预演确认页缺少新准入闸门接线：${token}`);process.exit(1);}
}
for (const token of ['runSummary','checkCount','suites']) {
 if(!runner.includes(token)){console.error(`测试汇总缺少 0.1.5 实现：${token}`);process.exit(1);}
}
for (const token of ['recordBackupAuditWithResult','auditManager']) {
 if(!backupMgr.includes(token)){console.error(`备份管理器缺少审计回写接线：${token}`);process.exit(1);}
}
for (const token of ['recordBackupWithPluginID','persistenceStatus','schema_version']) {
 if(!auditMgr.includes(token)){console.error(`审计持久化缺少实现：${token}`);process.exit(1);}
}
// 安全边界：0.1.4 新增环境 / 注入器 / 安全 / 协议 / 闸门层同样不得出现特权写或命令执行入口。
for (const forbidden of ['installPackage','uninstallPackage','launchctl','system(','popen(','NSTask','posix_spawn','executeCommand']) {
 if([envDir,injectorDir,secDir,evidence,trustStore,evaluator,ipcReq,ipcResp,requirement,policy,eligibility,gateNew].some(f=>f.includes(forbidden))){
   console.error(`0.1.4 安全/环境/协议层不应包含特权入口：${forbidden}`);process.exit(1);
 }
}
// 0.1.6 插件管理框架：关联/预览/兼容模型、管理器、流程控制器、审计事件与持久化。
const assocModel=read('Sources/Models/FKAppPluginAssociation.m'),
      previewModel=read('Sources/Models/FKInjectionPreview.m'),
      compatModel=read('Sources/Models/FKPluginCompatibility.m'),
      assocMgr=read('Sources/Managers/FKAssociationManager.m'),
      previewMgr=read('Sources/Managers/FKInjectionPreviewManager.m'),
      compatMgr=read('Sources/Managers/FKCompatibilityManager.m'),
      homeVC=read('Sources/Views/Home/FKHomeViewController.m'),
      addVC=read('Sources/Views/Apps/FKAddPluginViewController.m'),
      previewVC=read('Sources/Views/Apps/FKInjectionPreviewViewController.m'),
      secEvent=read('Sources/Security/FKSecurityEvent.m'),
      detailVC=read('Sources/Views/Detail/FKDetailController.m');
for (const token of ['FKAppPluginAssociation','associationFromDictionary','app_bundle_id','plugin_id']) {
 if(!assocModel.includes(token)){console.error(`关联模型缺少实现：${token}`);process.exit(1);}
}
for (const token of ['FKInjectionPreview','previewFromDictionary','preview_only','system_modified','checks','warnings']) {
 if(!previewModel.includes(token)){console.error(`预览模型缺少实现：${token}`);process.exit(1);}
}
for (const token of ['FKCompatibilityStatusCompatible','FKCompatibilityStatusPartiallyCompatible','FKCompatibilityStatusIncompatible','FKCompatibilityStatusUnsupported','statusText']) {
 if(!compatModel.includes(token)){console.error(`兼容模型缺少实现：${token}`);process.exit(1);}
}
for (const token of ['addAssociationForApp','hasAssociationForApp','removeAssociationForApp','toggleFavoriteApp','recordRecentApp','associations.json','favorites.json','recent_apps.json','schema_version']) {
 if(!assocMgr.includes(token)){console.error(`关联管理器缺少实现：${token}`);process.exit(1);}
}
for (const token of ['buildPreviewForApp','savePreview','previews.json','previewOnly','systemModified']) {
 if(!previewMgr.includes(token)){console.error(`预览管理器缺少实现：${token}`);process.exit(1);}
}
for (const token of ['evaluatePlugin','detectConflictsAmongPlugins','duplicate_dylib','shared_filter_target']) {
 if(!compatMgr.includes(token)){console.error(`兼容管理器缺少实现：${token}`);process.exit(1);}
}
for (const token of ['FKHomeViewController','扫描统计','Helper 安全状态']) {
 if(!homeVC.includes(token)){console.error(`首页控制器缺少实现：${token}`);process.exit(1);}
}
for (const token of ['FKAddPluginViewController','FKSecurityEventTypePluginSelected','FKInjectionPreviewViewController']) {
 if(!addVC.includes(token)){console.error(`添加插件流程缺少实现：${token}`);process.exit(1);}
}
for (const token of ['FKSecurityEventTypeInjectionPreviewCreated','FKSecurityEventTypeCompatibilityChecked','FKSecurityEventTypeAssociationCreated','FKSecurityEventTypeOperationDenied','FKPreviewResultBlocked']) {
 if(!previewVC.includes(token)){console.error(`配置预览页缺少实现：${token}`);process.exit(1);}
}
for (const token of ['app_opened','app_searched','plugin_selected','association_previewed','association_created','association_removed','injection_preview_created','compatibility_checked','operation_denied']) {
 if(!secEvent.includes(token)){console.error(`安全审计缺少 0.1.6 事件：${token}`);process.exit(1);}
}
for (const token of ['已关联 Associated','已配置 Configured','已生效 Active']) {
 if(!detailVC.includes(token)){console.error(`详情页缺少三态区分：${token}`);process.exit(1);}
}
// 安全边界：0.1.6 新增管理/预览/兼容层与流程控制器仍不得出现特权写或命令执行入口。
for (const forbidden of ['installPackage','uninstallPackage','launchctl','system(','popen(','NSTask','posix_spawn','executeCommand']) {
 if([assocMgr,previewMgr,compatMgr,homeVC,addVC,previewVC,detailVC].some(f=>f.includes(forbidden))){
   console.error(`0.1.6 管理/预览层不应包含特权入口：${forbidden}`);process.exit(1);
 }
}
// 不允许记录 plugin_enabled；保存管理关系只能记 association_created。
if(previewVC.includes('plugin_enabled')){console.error('0.1.6 不得记录 plugin_enabled 事件。');process.exit(1);}

// 0.1.9 真实插件管理框架：事务状态机、配置备份、结果验证、回滚计划、Helper 连接抽象与统一门禁。
const stateMachine=read('Sources/Operation/FKOperationStateMachine.m'),
      transaction=read('Sources/Operation/FKOperationTransaction.m'),
      verifier=read('Sources/Operation/FKOperationVerifier.m'),
      rollback=read('Sources/Operation/FKOperationRollback.m'),
      configBackup=read('Sources/Backup/FKConfigurationBackup.m'),
      helperConn=read('Sources/Helper/FKHelperConnection.m');
for (const token of ['FKOperationStateMachine','transitionTo:','canTransitionFrom:','FKOperationTransactionStateCreated','FKOperationTransactionStateCompleted','FKOperationTransactionStateRecoveryRequired']) {
 if(!stateMachine.includes(token)){console.error(`0.1.9 状态机缺少实现：${token}`);process.exit(1);}
}
for (const token of ['FKOperationTransaction','transactionWithRequest:','advanceTo:','decision','beforeState','afterState','verificationResult','rollbackResult']) {
 if(!transaction.includes(token)){console.error(`0.1.9 事务模型缺少实现：${token}`);process.exit(1);}
}
for (const token of ['FKOperationVerifier','verifyTargetState:','verifyTransaction:','FKVerificationStatusPassed']) {
 if(!verifier.includes(token)){console.error(`0.1.9 结果验证器缺少实现：${token}`);process.exit(1);}
}
for (const token of ['FKOperationRollback','planForTransaction:','FKRollbackStatusReady','FKRollbackStatusBackupMissing']) {
 if(!rollback.includes(token)){console.error(`0.1.9 回滚计划缺少实现：${token}`);process.exit(1);}
}
for (const token of ['FKConfigurationBackup','backupWithPluginID:','originalConfiguration','configurationHash','targetAppBundleID']) {
 if(!configBackup.includes(token)){console.error(`0.1.9 配置备份模型缺少实现：${token}`);process.exit(1);}
}
for (const token of ['FKHelperConnection','verifyConnectionWithCompletion:','applyAuthorizedOperation:','available']) {
 if(!helperConn.includes(token)){console.error(`0.1.9 Helper 连接抽象缺少实现：${token}`);process.exit(1);}
}
for (const token of ['evaluateOperationForPlugin','reasonCodes','decision']) {
 if(!gateNew.includes(token)){console.error(`0.1.9 统一门禁入口缺少实现：${token}`);process.exit(1);}
}
for (const token of ['before_state','target_state','after_state','verification_result','rollback_result','helper_identity']) {
 if(!opModels.includes(token)){console.error(`0.1.9 审计记录字段缺少实现：${token}`);process.exit(1);}
}
for (const token of ['recordsForResult','recordsWithRollback','recordsForOperation:']) {
 if(!auditMgr.includes(token)){console.error(`0.1.9 审计筛选方法缺少实现：${token}`);process.exit(1);}
}
for (const token of ['evaluateOperationForPlugin','FKOperationDecisionAllowed','decision']) {
 if(!confirmVC.includes(token)){console.error(`0.1.9 确认页未经统一门禁：${token}`);process.exit(1);}
}
for (const token of ['configurationStatus','Helper 未验证']) {
 if(!detailVC.includes(token)){console.error(`0.1.9 详情页门禁状态展示缺少实现：${token}`);process.exit(1);}
}
// 安全边界：0.1.9 事务/验证/回滚/备份/连接骨架仍为只读预演，不得出现特权写或命令执行入口。
for (const forbidden of ['installPackage','uninstallPackage','launchctl','system(','popen(','NSTask','posix_spawn','executeCommand']) {
 if([stateMachine,transaction,verifier,rollback,configBackup,helperConn].some(f=>f.includes(forbidden))){
   console.error(`0.1.9 事务骨架不应包含特权入口：${forbidden}`);process.exit(1);
 }
}
// Helper 连接抽象必须默认不可用，不得在无可信端点时建立真实 IPC 连接。
if(!helperConn.includes('FKHelperConnectionErrorUnavailable')){console.error('0.1.9 Helper 连接未定义不可用错误。');process.exit(1);}

// 0.1.9 Helper Foundation Commit01：身份 / 发布元数据 / 构建信息模型。
const fkIdentity=read('Sources/Helper/FKHelperIdentity.m'),
      fkReleaseMeta=read('Sources/Helper/FKHelperReleaseMetadata.m'),
      fkBuildInfo=read('Sources/Helper/FKHelperBuildInfo.m'),
      fkRunner=read('Sources/Tests/FKTestRunner.m');
for (const token of ['FKHelperIdentity','expectedIdentity','isStructurallyValid','matchesIdentity','supportsSecureCoding']) {
 if(!fkIdentity.includes(token)){console.error(`0.1.9 身份模型缺少实现：${token}`);process.exit(1);}
}
for (const token of ['FKHelperReleaseMetadata','metadataFromDictionary','isComplete']) {
 if(!fkReleaseMeta.includes(token)){console.error(`0.1.9 发布元数据缺少实现：${token}`);process.exit(1);}
}
for (const token of ['FKHelperBuildInfo','buildInfoFromDictionary','architectures']) {
 if(!fkBuildInfo.includes(token)){console.error(`0.1.9 构建信息缺少实现：${token}`);process.exit(1);}
}
for (const token of ['FKHelperIdentityTests','FKHelperMetadataTests','@"identity"','@"metadata"']) {
 if(!fkRunner.includes(token)){console.error(`0.1.9 新测试套件未注册：${token}`);process.exit(1);}
}
// 身份固定口径：Helper ID / 产品 / 组件 / 版本 / 构建 ID / 协议 1.0。
for (const token of ['com.filterkit.helper','@"FilterKit"','@"FilterKitHelper"','@"0.1.18"','@"FKH-0118"']) {
 if(!fkIdentity.includes(token)){console.error(`0.1.9 预期身份口径缺失：${token}`);process.exit(1);}
}
// 安全边界：0.1.9 模型层不得出现特权写或命令执行入口。
for (const forbidden of ['installPackage','uninstallPackage','launchctl','system(','popen(','NSTask','posix_spawn','executeCommand']) {
 if([fkIdentity,fkReleaseMeta,fkBuildInfo].some(f=>f.includes(forbidden))){
   console.error(`0.1.9 模型层不应包含特权入口：${forbidden}`);process.exit(1);
 }
}

// 0.1.9 Helper Foundation Commit02：可信发布清单与清单验证接口。
const fkManifest=read('Sources/Helper/FKHelperTrustManifest.m'),
      fkManifestVerifier=read('Sources/Helper/FKHelperManifestVerifier.m');
for (const token of ['FKHelperTrustManifest','FKHelperArtifact','manifestFromDictionary','hasTrustedArtifacts','isDevelopmentRelease','isValidSHA256Hex']) {
 if(!fkManifest.includes(token)){console.error(`0.1.9 清单模型缺少实现：${token}`);process.exit(1);}
}
for (const token of ['FKHelperManifestVerifying','FKHelperManifestVerificationResult','verifyManifest','allowsTrustedRelease','FKHelperManifestStatusVerified','FKHelperManifestErrorDomain']) {
 if(!fkManifestVerifier.includes(token)){console.error(`0.1.9 清单验证器缺少实现：${token}`);process.exit(1);}
}
for (const token of ['FKHelperManifestTests','@"manifest"']) {
 if(!fkRunner.includes(token)){console.error(`0.1.9 清单测试套件未注册：${token}`);process.exit(1);}
}
// 清单不得把本地计算摘要自动存为可信锚点；0.1.9 默认验证器不得产生 Verified 放行。
if(!fkManifestVerifier.includes('no_trusted_anchor')){console.error('0.1.9 清单验证器缺少无可信锚点保守结论。');process.exit(1);}
for (const forbidden of ['installPackage','uninstallPackage','launchctl','system(','popen(','NSTask','posix_spawn','executeCommand']) {
 if([fkManifest,fkManifestVerifier].some(f=>f.includes(forbidden))){
   console.error(`0.1.9 清单层不应包含特权入口：${forbidden}`);process.exit(1);
 }
}

// 0.1.9 Helper Foundation Commit03：完整性 Result 模型与结果化验证。
const fkIntegrity=read('Sources/Helper/FKHelperIntegrityVerifier.m');
for (const token of ['FKHelperIntegrityResult','verifyFileAtPath:','expectedSHA256','reasonCode','digest_match','no_trusted_anchor','digest_mismatch']) {
 if(!fkIntegrity.includes(token)){console.error(`0.1.9 完整性结果模型缺少实现：${token}`);process.exit(1);}
}
for (const token of ['FKHelperIntegrityTests','@"integrity"']) {
 if(!fkRunner.includes(token)){console.error(`0.1.9 完整性测试套件未注册：${token}`);process.exit(1);}
}
for (const forbidden of ['installPackage','uninstallPackage','launchctl','system(','popen(','NSTask','posix_spawn','executeCommand']) {
 if(fkIntegrity.includes(forbidden)){
   console.error(`0.1.9 完整性层不应包含特权入口：${forbidden}`);process.exit(1);
 }
}

// 0.1.9 Helper Foundation Commit04：v1 协议消息、错误码、只读能力与握手模型。
const fkMessage=read('Sources/Helper/FKHelperMessage.m'),
      fkMessageError=read('Sources/Helper/FKHelperMessageError.m'),
      fkCapabilities=read('Sources/Helper/FKHelperCapabilities.m'),
      fkHandshake=read('Sources/Helper/FKHelperHandshake.m');
for (const token of ['FKHelperMessage','messageFromData:','validateWithError:','matchesResponse:','FKHelperNonceCache','FKHelperMessageMaxPayloadBytes','FKHelperMessageMaxAge']) {
 if(!fkMessage.includes(token)){console.error(`0.1.9 v1 消息模型缺少实现：${token}`);process.exit(1);}
}
for (const token of ['FKHelperMessageErrorCode','reasonCodeForCode','FKHelperMessageErrorDomain']) {
 if(!fkMessageError.includes(token)){console.error(`0.1.9 消息错误码缺少实现：${token}`);process.exit(1);}
}
for (const token of ['FKHelperCapabilities','readOnlyWhitelist','writeCapabilityBlacklist','containsOnlyReadOnlyCapabilities']) {
 if(!fkCapabilities.includes(token)){console.error(`0.1.9 只读能力模型缺少实现：${token}`);process.exit(1);}
}
for (const token of ['FKHelperHandshake','isProtocolCompatibleWithMajor']) {
 if(!fkHandshake.includes(token)){console.error(`0.1.9 握手模型缺少实现：${token}`);process.exit(1);}
}
for (const token of ['FKHelperProtocolTests','@"protocol"']) {
 if(!fkRunner.includes(token)){console.error(`0.1.9 协议测试套件未注册：${token}`);process.exit(1);}
}
for (const forbidden of ['installPackage','uninstallPackage','launchctl','system(','popen(','NSTask','posix_spawn','executeCommand']) {
 if([fkMessage,fkMessageError,fkCapabilities,fkHandshake].some(f=>f.includes(forbidden))){
   console.error(`0.1.9 协议层不应包含特权入口：${forbidden}`);process.exit(1);
 }
}

// 0.1.9 Helper Foundation Commit05：Transport 抽象、只读客户端、Mock 标注与服务端只读模型。
const fkTransportState=read('Sources/Helper/FKHelperTransportState.m'),
      fkTestTransport=read('Sources/Helper/FKHelperTestTransport.m'),
      fkReadOnlyClient=read('Sources/Helper/FKHelperReadOnlyClient.m'),
      fkMockClient=read('Sources/Helper/FKMockHelperClient.m'),
      fkServiceInfo=read('Sources/Helper/FKHelperServiceInfo.m'),
      fkProvider=read('Sources/Helper/FKHelperReadOnlyProvider.h');
for (const token of ['FKHelperTransportState','FKHelperTransportErrorDomain','FKHelperTransportStatus']) {
 if(!fkTransportState.includes(token)){console.error(`0.1.9 传输状态模型缺少实现：${token}`);process.exit(1);}
}
for (const token of ['FKHelperTestTransport','isMock','simulateTimeout']) {
 if(!fkTestTransport.includes(token)){console.error(`0.1.9 模拟传输缺少实现：${token}`);process.exit(1);}
}
for (const token of ['FKHelperReadOnlyClient','initWithTransport:','requestHelperInfo:','requestCapabilities:','requestPluginList:']) {
 if(!fkReadOnlyClient.includes(token)){console.error(`0.1.9 只读客户端缺少实现：${token}`);process.exit(1);}
}
for (const token of ['FKMockHelperClient','isMock','@"mock"']) {
 if(!fkMockClient.includes(token)){console.error(`0.1.9 Mock 客户端缺少实现：${token}`);process.exit(1);}
}
for (const token of ['FKHelperServiceInfo']) {
 if(!fkServiceInfo.includes(token)){console.error(`0.1.9 服务信息模型缺少实现：${token}`);process.exit(1);}
}
for (const token of ['FKHelperReadOnlyProvider','pluginInfoForIdentifier:','configurationSnapshot']) {
 if(!fkProvider.includes(token)){console.error(`0.1.9 只读提供者协议缺少接口：${token}`);process.exit(1);}
}
for (const token of ['FKHelperTransportTests','@"transport"']) {
 if(!fkRunner.includes(token)){console.error(`0.1.9 传输测试套件未注册：${token}`);process.exit(1);}
}
for (const token of ['FKHelperReportTests','@"report"']) {
 if(!fkRunner.includes(token)){console.error(`0.1.9 报告测试套件未注册：${token}`);process.exit(1);}
}
for (const token of ['FKHelperCapabilityTests','@"capability"']) {
 if(!fkRunner.includes(token)){console.error(`0.1.9 能力测试套件未注册：${token}`);process.exit(1);}
}
for (const token of ['FKHelperGateTests','@"gate"']) {
 if(!fkRunner.includes(token)){console.error(`0.1.9 门禁回归套件未注册：${token}`);process.exit(1);}
}
for (const token of ['FKHelperDiscoveryTests','@"discovery"']) {
 if(!fkRunner.includes(token)){console.error(`0.1.9 服务发现套件未注册：${token}`);process.exit(1);}
}
for (const token of ['FKHelperPeerTests','@"peer"']) {
 if(!fkRunner.includes(token)){console.error(`0.1.9 对端验证套件未注册：${token}`);process.exit(1);}
}
for (const token of ['FKHelperHandshakeTests','@"handshake"']) {
 if(!fkRunner.includes(token)){console.error(`0.1.9 握手会话套件未注册：${token}`);process.exit(1);}
}
for (const token of ['FKHelperRouterTests','@"router"']) {
 if(!fkRunner.includes(token)){console.error(`0.1.9 路由套件未注册：${token}`);process.exit(1);}
}
for (const token of ['FKHelperPluginTests','@"plugin"']) {
 if(!fkRunner.includes(token)){console.error(`0.1.9 插件只读套件未注册：${token}`);process.exit(1);}
}
for (const token of ['FKHelperConfigurationTests','@"configuration"']) {
 if(!fkRunner.includes(token)){console.error(`0.1.9 配置只读套件未注册：${token}`);process.exit(1);}
}
for (const token of ['FKHelperAuditTests','@"audit"']) {
 if(!fkRunner.includes(token)){console.error(`0.1.9 审计事件套件未注册：${token}`);process.exit(1);}
}
for (const forbidden of ['installPackage','uninstallPackage','launchctl','system(','popen(','NSTask','posix_spawn','executeCommand']) {
 if([fkTransportState,fkTestTransport,fkReadOnlyClient,fkMockClient,fkServiceInfo].some(f=>f.includes(forbidden))){
   console.error(`0.1.9 传输/客户端层不应包含特权入口：${forbidden}`);process.exit(1);
 }
}

function FKHelperMessageReadOnlyRequestCheck(source, method) {
  const whitelistBlock = source.match(/readOnlyWhitelist[\s\S]*?@\[([\s\S]*?)\]/);
  return whitelistBlock ? whitelistBlock[1].includes(method) : true;
}

// 0.1.10 边界加固：严格报文解析、响应关联、Mock 隔离、服务端二次校验、审计事件持久化。
const readonlyClient=read('Sources/Helper/FKHelperReadOnlyClient.m'),
      message=read('Sources/Helper/FKHelperMessage.m'),
      router=read('Sources/Helper/FKHelperRequestRouter.m'),
      peer=read('Sources/Helper/FKHelperPeerVerifier.m'),
      auditManager=read('Sources/Managers/FKAuditManager.m'),
      auditEvent=read('Sources/Helper/FKHelperIPCAuditEvent.m'),
      boundaryTests=read('Sources/Tests/FKHelperBoundaryTests.m'),
      testRunner=read('Sources/Tests/FKTestRunner.m');
for (const [source, tokens, label] of [
  [readonlyClient, ['!transport.isMock','matchesResponse:response','requestPluginInfo:','requestConfigurationSnapshot:','session.isReadOnlyReady','FKCapabilityEvaluator','auditEventHandler','session_invalidated'], '只读客户端'],
  [message, ['FKHelperMessageMaxPayloadBytes','完整报文超过消息大小上限','请求缺少防重放随机值','responseStatus'], '协议报文'],
  [router, ['validateWithError:','capabilities.list','validationStatus','pluginID'], '服务端路由'],
  [peer, ['signatureVerified','integrityStatus','permissionReadOnly','matchesIdentity:'], 'Peer 验证'],
  [auditManager, ['helper_ipc_events','appendHelperIPCAuditEvent:','eventFromDictionary:'], 'IPC 审计持久化'],
  [auditEvent, ['buildID','sessionID','eventFromDictionary:','helper_info_read'], 'IPC 审计模型'],
  [boundaryTests, ['BND1001','BND1014'], '0.1.10 边界测试'],
  [testRunner, ['FKHelperBoundaryTests.class','@"boundary"'], '测试运行器']
]) {
  for (const token of tokens) {
    if (!source.includes(token)) { console.error(`${label}缺少 0.1.10 加固项：${token}`); process.exit(1); }
  }
}
if (!makefile.includes('Sources/Tests/FKHelperBoundaryTests.m')) {
  console.error('Makefile 未登记 0.1.10 边界测试源文件。'); process.exit(1);
}
if (!testRunner.includes('FKHelperBoundaryTests.class')) {
  console.error('FKTestRunner 未注册 0.1.10 边界测试。'); process.exit(1);
}
for (const forbidden of ['plugin.enable','plugin.disable','config.write','filter.modify','file.restore','process.signal']) {
  if (FKHelperMessageReadOnlyRequestCheck(message, forbidden)) {
    console.error(`0.1.10 协议请求白名单错误包含写能力：${forbidden}`); process.exit(1);
  }
}
// 0.1.12：候选路径/字段严格校验、发现证据报告、无效候选早停。
const discovery=read('Sources/Helper/FKHelperServiceDiscovery.m'),
      metadata=read('Sources/Helper/FKHelperMetadata.m'),
      trustEvaluator=read('Sources/Helper/FKHelperTrustEvaluator.m'),
      discoveryTests=read('Sources/Tests/FKHelperDiscoveryTests.m');
for (const [source, tokens, label] of [
  [metadata, ['path_not_absolute','path_contains_traversal','exists_type_invalid','candidateSchemaValid','validationIssues'], '候选元数据校验'],
  [discovery, ['discoveryReportForCandidates:','trustStatus','realIPCReady','writeOperationsAllowed','selectedCandidatePath'], '发现证据报告'],
  [trustEvaluator, ['candidateSchemaValid','pathHasTraversal','candidate_not_regular_executable'], '信任评估早停'],
  [discoveryTests, ['SRV909','SRV910','SRV911','SRV912','SRV913','SRV914','SRV915','SRV916'], '发现边界测试'],
  [scanner, ['FKHelperServiceDiscovery discovery','lstat(path.fileSystemRepresentation','file_type','discovery_report'], '扫描器发现证据接线']
]) {
  for (const token of tokens) if (!source.includes(token)) { console.error(`${label}缺少 0.1.12 实现：${token}`); process.exit(1); }
}
if (!discoveryTests.includes('discoveryReportForCandidates:') || !fkRunner.includes('FKHelperDiscoveryTests.class')) {
  console.error('0.1.12 发现报告测试未注册。'); process.exit(1);
}
if (!makefile.includes('Sources/Helper/FKHelperServiceDiscovery.m') || !makefile.includes('Sources/Helper/FKHelperMetadata.m')) {
  console.error('Makefile 未包含 0.1.12 修改的发现模块。'); process.exit(1);
}
for (const forbidden of ['launchctl','system(','popen(','NSTask','posix_spawn','executeCommand','plugin.enable','plugin.disable','config.write','filter.modify','file.restore','process.signal']) {
  if ([discovery,metadata,trustEvaluator].some(source => source.includes(forbidden))) {
    console.error(`0.1.12 发现/信任层不应包含特权执行或写入口：${forbidden}`); process.exit(1);
  }
}
// 0.1.12：部署可行性证据评估，不创建 Helper Target、Daemon 或特权启动入口。
const deployment=read('Sources/Helper/FKHelperDeploymentAssessment.m'),
      deploymentTests=read('Sources/Tests/FKHelperDeploymentTests.m');
for (const token of ['FKRequiredDeploymentEvidence','FKStrictBoolean','unknownEvidenceKeys',
                     'entitlements_separated_and_reviewed','mach_service_observed',
                     'rootless_build_verified','roothide_build_verified',
                     'daemonDeploymentAllowed','privilegedLaunchAllowed','writeOperationsAllowed']) {
  if (!deployment.includes(token)) { console.error(`部署可行性评估缺少实现：${token}`); process.exit(1); }
}
for (const token of ['isValidMachServiceName:','regularExpressionWithPattern','128']) {
  if (!deployment.includes(token)) { console.error(`Mach Service 名称校验缺少实现：${token}`); process.exit(1); }
}
for (const token of ['DEP1201','DEP1202','DEP1203','DEP1204','DEP1205','DEP1206',
                     'DEP1207','DEP1208','DEP1209','DEP1210','DEP1211','DEP1212','DEP1213']) {
  if (!deploymentTests.includes(token)) { console.error(`部署边界测试缺少用例：${token}`); process.exit(1); }
}
const helperDetails=read('Sources/Views/Helper/FKHelperDetailsViewController.m');
for (const token of ['FKHelperDeploymentAssessment','deployment_evidence','部署可行性','特权启动 / 写操作']) {
  if (!helperDetails.includes(token)) { console.error(`Helper 详情页缺少部署评估展示：${token}`); process.exit(1); }
}
if (!fkRunner.includes('FKHelperDeploymentTests.class') || !fkRunner.includes('@"deployment"') ||
    !makefile.includes('Sources/Helper/FKHelperDeploymentAssessment.m') ||
    !makefile.includes('Sources/Tests/FKHelperDeploymentTests.m')) {
  console.error('部署可行性模块或测试未加入构建/测试入口。'); process.exit(1);
}
for (const forbidden of ['launchctl','NSTask','posix_spawn','system(','popen(','plugin.enable','plugin.disable','config.write','filter.modify','file.restore']) {
  if (deployment.includes(forbidden)) { console.error(`部署评估模块不得包含执行或写操作入口：${forbidden}`); process.exit(1); }
}
// 版本与测试登记一致性：42 套件、468 个静态声明断言。
const testSources = fs.readdirSync('Sources/Tests').filter(name => name.endsWith('Tests.m'));
let declaredChecks = 0;
for (const name of testSources) {
  const source = read(`Sources/Tests/${name}`);
  const match = source.match(/\+\s*\(NSUInteger\)checkCount\s*\{\s*return\s+(\d+)\s*;/);
  if (match) declaredChecks += Number(match[1]);
}
for (const required of [
  'Sources/Helper/FKHelperKeyDerivation.m',
  'Sources/Helper/FKHelperKeyLifecycle.m',
  'Sources/Helper/FKHelperProtocolNegotiator.m',
  'Sources/Helper/FKHelperHandshakeTranscript.m',
  'Sources/Tests/FKHelperKeyDerivationTests.m',
  'Sources/Tests/FKHelperKeyLifecycleTests.m',
  'Sources/Tests/FKHelperProtocolNegotiationTests.m',
  'Sources/Tests/FKHelperHandshakeTranscriptTests.m',
  'Sources/Helper/FKHelperUnixSocketTransport.m',
  'Sources/Tests/FKHelperUnixSocketTransportTests.m'
]) {
  if (!makefile.includes(required)) { console.error(`0.1.18 新增源码未加入 Makefile：${required}`); process.exit(1); }
}
if (testSources.length !== 42 || declaredChecks !== 468) {
  console.error(`0.1.18 测试登记应为 42 套件/468 项，当前 ${testSources.length} 套件/${declaredChecks} 项。`); process.exit(1);
}
const deploymentProfile = JSON.parse(read('Resources/Helper/helper-deployment-profile.json'));
if (deploymentProfile.release.version !== '0.1.18' || deploymentProfile.release.build !== 118 ||
    deploymentProfile.helper.targetPresent !== false ||
    deploymentProfile.entitlements.inheritAppEntitlements !== false ||
    deploymentProfile.safety.daemonDeploymentAllowed !== false ||
    deploymentProfile.safety.privilegedLaunchAllowed !== false ||
    deploymentProfile.safety.realIPCReady !== false ||
    deploymentProfile.safety.writeOperationsAllowed !== false ||
    deploymentProfile.transport.securityModel.keyConfirmation !== 'hmac_sha256_client_helper_role_separated_model' ||
    deploymentProfile.transport.securityModel.handshakeIntegrated !== true) {
  console.error('0.1.12 Helper 部署档案的版本或安全边界不一致。'); process.exit(1);
}
const handshakeProfile = JSON.parse(read('Resources/Helper/helper-handshake-profile.json'));
if (handshakeProfile.release.version !== '0.1.18' || handshakeProfile.release.build !== 118 ||
    handshakeProfile.sequence.length !== 7 || handshakeProfile.safety.realTransportImplemented !== false ||
    handshakeProfile.safety.realPeerCredentialsCollected !== false ||
    handshakeProfile.safety.trustedKeyProvisioningImplemented !== false ||
    handshakeProfile.safety.realIPCReady !== false || handshakeProfile.safety.writeOperationsAllowed !== false) {
  console.error('0.1.18 握手档案版本、状态序列或安全边界不一致。'); process.exit(1);
}
const releaseManifest = JSON.parse(read('Resources/Helper/helper-release-manifest.json'));
if (releaseManifest.release.version !== '0.1.18' || releaseManifest.release.buildID !== 'FKH-0118' ||
    releaseManifest.release.channel !== 'development' || releaseManifest.artifacts.length !== 0) {
  console.error('0.1.12 Helper Manifest 版本或开发态安全标记不一致。'); process.exit(1);
}
if (!plist.includes('<string>118</string>')) { console.error('CFBundleVersion 应为 118。'); process.exit(1); }
const keyConfirmation=read('Sources/Helper/FKHelperKeyConfirmation.m');
const handshakeState=read('Sources/Helper/FKHelperHandshakeStateMachine.m');
const peerBinding=read('Sources/Helper/FKHelperPeerBinding.m');
const sessionLifecycle=read('Sources/Helper/FKHelperSessionLifecycle.m');
const ipcAudit=read('Sources/Helper/FKHelperIPCAuditEvent.m');
const auditTests=read('Sources/Tests/FKHelperAuditTests.m');
for (const [source, tokens, label] of [
  [keyConfirmation, ['CCHmac(kCCHmacAlgSHA256','FilterKit.Helper.KeyConfirmation.v1','client','helper','transcriptDigest'], '双向密钥确认'],
  [handshakeState, ['peer_verified','protocol_negotiated','transcript_verified','key_derived','client_confirmation_verified','helper_confirmation_verified','CFBooleanGetTypeID'], '握手状态机'],
  [peerBinding, ['credentialDigest','transcriptDigest','matchesExpectedHelperID:','helperBuildID'], 'Peer 绑定'],
  [sessionLifecycle, ['maximumLifetime','idleTimeout','peerBindingVerified','clientConfirmationVerified','helperConfirmationVerified','session_timeout','clock_rollback'], '会话生命周期'],
  [ipcAudit, ['peer_binding','key_confirmation','handshake_state','session_expired'], '认证审计动作'],
  [auditTests, ['AUD913','AUD914','AUD915','AUD916'], '认证审计测试']
]) for (const token of tokens) if (!source.includes(token)) { console.error(`${label}缺少实现：${token}`); process.exit(1); }
for (const forbidden of ['launchctl','NSTask','posix_spawn','system(','popen(','plugin.enable','plugin.disable','config.write','filter.modify','file.restore']) {
  if ([keyConfirmation,handshakeState,peerBinding,sessionLifecycle].some(source => source.includes(forbidden))) {
    console.error(`0.1.18 握手模块不得包含特权执行或写操作入口：${forbidden}`); process.exit(1);
  }
}
for (const required of [
  'Sources/Helper/FKHelperKeyConfirmation.m','Sources/Helper/FKHelperHandshakeStateMachine.m',
  'Sources/Helper/FKHelperPeerBinding.m','Sources/Helper/FKHelperSessionLifecycle.m','Sources/Helper/FKHelperAuthenticatedSessionManager.m',
  'Sources/Tests/FKHelperKeyConfirmationTests.m','Sources/Tests/FKHelperHandshakeStateMachineTests.m',
  'Sources/Tests/FKHelperPeerBindingTests.m','Sources/Tests/FKHelperSessionLifecycleTests.m','Sources/Tests/FKHelperAuthenticatedSessionTests.m'
]) if (!makefile.includes(required)) { console.error(`0.1.18 源文件未加入 Makefile：${required}`); process.exit(1); }
for (const token of ['FKHelperKeyConfirmationTests.class','FKHelperHandshakeStateMachineTests.class','FKHelperPeerBindingTests.class','FKHelperSessionLifecycleTests.class','FKHelperAuthenticatedSessionTests.class','authenticated_session',
                     '@"key_confirmation"','@"handshake_state_machine"','@"peer_binding"','@"session_lifecycle"','@"authenticated_session"']) {
  if (!fkRunner.includes(token)) { console.error(`0.1.18 测试未注册：${token}`); process.exit(1); }
}
for (const token of ['双向密钥确认','握手状态机','Peer 绑定','会话生命周期']) {
  if (!helperDetails.includes(token)) { console.error(`Helper 详情页缺少 0.1.18 状态：${token}`); process.exit(1); }
}
const sessionCoordinator=read('Sources/Helper/FKHelperAuthenticatedSessionManager.m');
const sessionCoordinatorTests=read('Sources/Tests/FKHelperAuthenticatedSessionTests.m');
for (const token of ['FKHelperHandshakeStateMachine','FKHelperPeerBinding','FKHelperKeyConfirmation',
                     'FKHelperSessionLifecycle','revokeActiveKey','session_already_active',
                     'key_confirmation_failed','FKAuditHelperIPCDisconnect','FKAuditHelperIPCSessionExpired',
                     'NSRecursiveLock','mock','unsupported']) {
  if (!sessionCoordinator.includes(token)) { console.error(`统一认证会话协调器缺少实现：${token}`); process.exit(1); }
}
for (const token of ['并发握手竞争','ASM1913','ASM1914','transport_disconnected','real_ipc']) {
  if (!sessionCoordinatorTests.includes(token)) { console.error(`统一认证会话测试缺少场景：${token}`); process.exit(1); }
}
for (const forbidden of ['launchctl','NSTask','posix_spawn','system(','popen(','plugin.enable','plugin.disable','config.write']) {
  if (sessionCoordinator.includes(forbidden)) { console.error(`认证会话协调器不得包含特权执行或写操作入口：${forbidden}`); process.exit(1); }
}
// 0.1.18：Unix Domain Socket client/listener implementation and bounded peer-authenticated IPC.
const unixTransport = read('Sources/Helper/FKHelperUnixSocketTransport.m');
for (const token of ['getpeereid','expectedPeerUID','FKHelperFrameCodec','1024 * 1024','SO_RCVTIMEO','SO_SNDTIMEO','S_ISSOCK','S_ISLNK','allowedPeerUID']) { if (!unixTransport.includes(token)) { console.error(`Unix Socket Transport 缺少安全控制：${token}`); process.exit(1); } }
if (unixTransport.includes('launchctl') || unixTransport.includes('posix_spawn') || unixTransport.includes('system(')) { console.error('Transport 模块不得启动特权进程'); process.exit(1); }

// 0.1.18：Helper Trust & Transport Readiness；只评估证据，不创建真实端点。
const trustAnchor=read('Sources/Helper/FKHelperTrustAnchor.m');
const releaseVerifier=read('Sources/Helper/FKHelperReleaseVerifier.m');
const peerCredential=read('Sources/Helper/FKHelperPeerCredentialEvidence.m');
const transportReadiness=read('Sources/Helper/FKHelperTransportReadiness.m');
const readinessReport=read('Sources/Helper/FKHelperReadinessReport.m');
for (const [source,tokens,label] of [
  [trustAnchor,['isUsableForProduction','testOnly','provisioningSource','caller_supplied','productionAnchorForKeyID','policyVersion'], '可信锚点'],
  [releaseVerifier,['trusted_anchor_unavailable','development_channel','artifact_digest_mismatch','NSJSONWritingSortedKeys','signatureVerifier'], '发布验证'],
  [peerCredential,['mock_credential_not_trusted','self_reported_credential_not_trusted','system_peer_credential_collector_not_implemented'], 'Peer Credential'],
  [transportReadiness,['production_transport_attestation','verified_endpoint','fresh_transport_evidence','realTransportVerified'], 'Transport 就绪评估'],
  [readinessReport,['realIPCReady = NO','readOnlyOperationsAllowed = NO','writeOperationsAllowed = NO','blockingReasons'], 'Readiness 报告']
]) for (const token of tokens) if (!source.includes(token)) { console.error(`${label}缺少实现：${token}`); process.exit(1); }
for (const required of ['Sources/Helper/FKHelperTrustAnchor.m','Sources/Helper/FKHelperReleaseVerifier.m','Sources/Helper/FKHelperPeerCredentialEvidence.m','Sources/Helper/FKHelperTransportReadiness.m','Sources/Helper/FKHelperReadinessReport.m','Sources/Helper/FKHelperUnixSocketTransport.m','Sources/Tests/FKHelperUnixSocketTransportTests.m','Sources/Tests/FKHelperTrustAnchorTests.m','Sources/Tests/FKHelperReleaseVerifierTests.m','Sources/Tests/FKHelperPeerCredentialTests.m','Sources/Tests/FKHelperTransportReadinessTests.m','Sources/Tests/FKHelperReadinessReportTests.m']) {
  if (!makefile.includes(required)) { console.error(`0.1.18 新增源码未加入 Makefile：${required}`); process.exit(1); }
}
for (const token of ['FKHelperTrustAnchorTests.class','FKHelperReleaseVerifierTests.class','FKHelperPeerCredentialTests.class','FKHelperTransportReadinessTests.class','FKHelperReadinessReportTests.class','@"trust_anchor"','@"release_verifier"','@"peer_credential"','@"transport_readiness"','@"readiness_report"']) {
  if (!fkRunner.includes(token)) { console.error(`0.1.18 测试未注册：${token}`); process.exit(1); }
}
const readinessProfile = JSON.parse(read('Resources/Helper/helper-readiness-profile.json'));
if (readinessProfile.release.version !== '0.1.18' || readinessProfile.release.build !== 118 || readinessProfile.trust.productionAnchorsConfigured !== false || readinessProfile.peerCredential.systemCollectorImplemented !== false || readinessProfile.transport.realTransportImplemented !== false || readinessProfile.readiness.realIPCReady !== false || readinessProfile.readiness.writeOperationsAllowed !== false) {
  console.error('0.1.18 Readiness Profile 版本或安全边界不一致。'); process.exit(1);
}
for (const forbidden of ['launchctl','NSTask','posix_spawn','system(','popen(','plugin.enable','plugin.disable','config.write','filter.modify','file.restore']) {
  if ([trustAnchor,releaseVerifier,peerCredential,transportReadiness,readinessReport].some(source => source.includes(forbidden))) { console.error(`0.1.18 Trust/Transport 层不得包含特权执行或写操作入口：${forbidden}`); process.exit(1); }
}
console.log('FilterKit 0.1.18：Unix Domain Socket IPC client/listener、Peer UID 校验、长度前缀帧及既有信任边界静态检查通过。42 个测试套件登记 468 项断言；Helper Target/Daemon 尚未创建，未开放插件启停、配置写入或其他写操作。本脚本仅做静态核对。');
