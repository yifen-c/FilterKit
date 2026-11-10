'use strict';

const fs = require('node:fs');
const path = require('node:path');

const required = [
  'Makefile',
  'control',
  'entitlements.plist',
  'FilterKit-Info.plist',
  'Sources/main.m',
  'Sources/FKAppDelegate.m',
  'Sources/FKMainViewController.m',
  'Sources/FKScanner.m',
  'Sources/FKModels.m',
  '.github/workflows/build.yml'
];

const missing = required.filter((file) => !fs.existsSync(path.resolve(file)));
if (missing.length) {
  console.error(`项目文件缺失：\n${missing.map((item) => `- ${item}`).join('\n')}`);
  process.exit(1);
}

const workflow = fs.readFileSync('.github/workflows/build.yml', 'utf8');
for (const token of ['workflow_dispatch:', 'macos-latest', 'node-version: latest',
  'https://github.com/roothide/theos.git', 'THEOS_PACKAGE_SCHEME=roothide',
  'THEOS_PACKAGE_SCHEME=rootless']) {
  if (!workflow.includes(token)) {
    console.error(`工作流缺少必要配置：${token}`);
    process.exit(1);
  }
}

console.log('FilterKit 0.0.1 项目结构检查通过。');
