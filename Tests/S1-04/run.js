/**
 * S1-04 插件枚举 — 离线验证执行器（测试 harness，非 App 运行时）。
 *
 * 流程：读取十三组夹具 → 校验输入/预期分离 → 跑 ENUM-001~015 →
 * 核对非递归、分类、软链身份、部分失败、排序确定性与路线隔离 → 生成报告。
 * 全部为离线 fixture 合成样本，虚拟 FS 以信号注入模拟，不访问真实设备文件系统。
 */

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const { enumerate, joinPath } = require('./enumerator');

const ROOT = path.join(__dirname, '..', '..');
const FIXTURE_DIR = path.join(ROOT, 'Tests', 'Fixtures', 'S1-04');
const REPORT_DIR = path.join(__dirname, 'report');

const FIXTURE_ENUM_MAP = {
  'rh-mixed': ['ENUM-001', 'ENUM-002', 'ENUM-004', 'ENUM-009', 'ENUM-010'],
  'rh-orphan-plist': ['ENUM-002'],
  'rh-orphan-dylib': ['ENUM-001'],
  'rh-dir-entry': ['ENUM-003', 'ENUM-006'],
  'rh-symlink-valid': ['ENUM-007'],
  'rh-symlink-broken': ['ENUM-007'],
  'rh-hidden-file': ['ENUM-005'],
  'rh-other-extension': ['ENUM-003'],
  'rh-bad-permission': ['ENUM-008', 'ENUM-012'],
  'rh-metadata-missing': ['ENUM-009', 'ENUM-010'],
  'rh-enum-failed': ['ENUM-008'],
  'rootless-mixed': ['ENUM-013'],
  'route-guard': ['ENUM-013'],
};

function readJson(file) { return JSON.parse(fs.readFileSync(file, 'utf8')); }
function normalize(v) { return v === undefined ? null : v; }

function deepEqual(a, b) {
  if (normalize(a) === normalize(b)) return true;
  if (typeof a !== typeof b) return false;
  if (Array.isArray(a) || Array.isArray(b)) {
    if (!Array.isArray(a) || !Array.isArray(b) || a.length !== b.length) return false;
    return a.every((x, i) => deepEqual(x, b[i]));
  }
  if (a && b && typeof a === 'object') {
    const ka = Object.keys(a), kb = Object.keys(b);
    if (ka.length !== kb.length) return false;
    return ka.every((k) => deepEqual(a[k], b[k]));
  }
  return false;
}

function sameSet(a, b) {
  return deepEqual([...(a || [])].sort(), [...(b || [])].sort());
}

function compareResult(result, meta) {
  const expected = meta.expected || {};
  const expectedWarnings = meta.expectedWarnings || [];
  const failures = [];
  const checks = [
    ['route', result.route, expected.route],
    ['sourceDirectory', result.sourceDirectory, expected.sourceDirectory],
    ['status', result.enumeration.status, expected.status],
    ['counts', result.counts, expected.counts],
    ['itemCount', result.items.length, expected.itemCount],
    ['unknownCount', result.unknownItems.length, expected.unknownCount],
    ['names', result.items.map((i) => i.name), expected.names],
  ];
  for (const [field, actual, want] of checks) {
    if (!deepEqual(actual, want)) failures.push(`${field}: 实际=${JSON.stringify(actual)} 期望=${JSON.stringify(want)}`);
  }
  if (!sameSet(result.warnings, expectedWarnings)) {
    failures.push(`warnings: 实际=[${result.warnings.join(',')}] 期望=[${expectedWarnings.join(',')}]`);
  }
  if (result.enumeration.status !== meta.expectedStatus) {
    failures.push(`expectedStatus: 实际=${result.enumeration.status} 期望=${meta.expectedStatus}`);
  }
  return failures;
}

function loadFixtures() {
  const kinds = fs.readdirSync(FIXTURE_DIR, { withFileTypes: true })
    .filter((d) => d.isDirectory()).map((d) => d.name);
  return kinds.map((kind) => ({
    kind,
    env: readJson(path.join(FIXTURE_DIR, kind, 'environment.json')),
    meta: readJson(path.join(FIXTURE_DIR, kind, 'metadata.json')),
  }));
}

function runFixtureCase(enumId, fixture) {
  const { env, meta } = fixture;
  const result = enumerate(env);
  const failures = compareResult(result, meta);
  return {
    enumId,
    source: `fixture:${fixture.kind}`,
    evidenceType: 'fixture',
    passed: failures.length === 0,
    result,
    failures,
  };
}

function buildSyntheticCases(fixtures) {
  const cases = [];

  // ENUM-011：同名条目不同路径，按完整路径保留，不按基名合并
  cases.push((() => {
    const envA = {
      upstream: { route: 'roothide', sourceDirectory: '/root/A/usr/lib/TweakInject/' },
      fs: { enumerable: true, entries: [{ name: 'Same.dylib', type: 'file', exists: true, readable: true, entryStatus: 'ok' }] },
    };
    const envB = {
      upstream: { route: 'roothide', sourceDirectory: '/root/B/usr/lib/TweakInject/' },
      fs: { enumerable: true, entries: [{ name: 'Same.dylib', type: 'file', exists: true, readable: true, entryStatus: 'ok' }] },
    };
    const ra = enumerate(envA);
    const rb = enumerate(envB);
    const paths = [ra.items[0].path, rb.items[0].path];
    const passed = ra.items.length === 1 && rb.items.length === 1 && paths[0] !== paths[1];
    return {
      enumId: 'ENUM-011',
      source: 'synthetic:path-identity',
      evidenceType: 'fixture',
      passed,
      result: { paths },
      failures: passed ? [] : ['同名条目被按基名合并，或路径未保留'],
    };
  })());

  // ENUM-014：相同目录信号重复枚举，清单/顺序/计数确定
  cases.push((() => {
    const mixed = fixtures.find((f) => f.kind === 'rh-mixed');
    const r1 = enumerate(mixed.env);
    const r2 = enumerate(mixed.env);
    const passed = deepEqual(r1, r2);
    return {
      enumId: 'ENUM-014',
      source: 'synthetic:determinism',
      evidenceType: 'fixture',
      passed,
      result: r1,
      failures: passed ? [] : ['重复枚举结果不一致'],
    };
  })());

  // ENUM-013 补充：RootHide 结果不得出现 /var/jb 回退路径
  cases.push((() => {
    const guard = fixtures.find((f) => f.kind === 'route-guard');
    const r = enumerate(guard.env);
    const leak = r.items.some((i) => /^\/var\/jb/.test(i.path || ''));
    const passed = r.sourceDirectory === null && !leak;
    return {
      enumId: 'ENUM-013',
      source: 'synthetic:route-isolation',
      evidenceType: 'fixture',
      passed,
      result: { sourceDirectory: r.sourceDirectory, itemCount: r.items.length },
      failures: passed ? [] : ['RootHide 回退扫描了 /var/jb 路径'],
    };
  })());

  return cases;
}

function runPriorRegression() {
  const stages = ['S1-01', 'S1-02', 'S1-03'];
  const regression = {};
  for (const stage of stages) {
    const script = path.join(ROOT, 'Tests', stage, 'run.js');
    try {
      execFileSync(process.execPath, [script], { stdio: 'pipe' });
      regression[stage] = 'passed';
    } catch (e) {
      regression[stage] = `failed (exit ${e.status})`;
    }
  }
  return regression;
}

function main() {
  const fixtures = loadFixtures();
  const cases = [];
  for (const fixture of fixtures) {
    for (const enumId of FIXTURE_ENUM_MAP[fixture.kind] || []) {
      cases.push(runFixtureCase(enumId, fixture));
    }
  }
  cases.push(...buildSyntheticCases(fixtures));

  // 路线覆盖核对
  const routes = new Set(fixtures.map((f) => f.env.upstream.route));
  const requiredRoutes = ['roothide', 'rootless'];
  const missingRoutes = requiredRoutes.filter((r) => !routes.has(r));

  // 非递归核对：rh-dir-entry 嵌套条目不得进入清单
  const dirEntry = fixtures.find((f) => f.kind === 'rh-dir-entry');
  const dirResult = dirEntry ? enumerate(dirEntry.env) : null;
  const nestedLeak = !dirResult || dirResult.items.some((i) => i.name.includes('/'));

  // 前序回归（ENUM-015）
  const regression = runPriorRegression();
  const regressionFailed = Object.values(regression).some((v) => v !== 'passed');

  const passed = cases.filter((c) => c.passed).length;
  const failed = cases.length - passed;

  const report = {
    schemaVersion: '0.1.0',
    generatedAt: new Date().toISOString(),
    stage: 'Stage 1 / S1-04',
    evidenceNote: '全部为离线 fixture 合成样本；不构成 RootHide 真机验证，Rootless 结果不代表真机兼容。',
    summary: {
      total: cases.length,
      passed,
      failed,
      routesCovered: [...routes].sort(),
      missingRoutes,
      nestedLeakCount: nestedLeak ? 1 : 0,
      regression,
    },
    cases: cases.map((c) => ({
      enumId: c.enumId,
      source: c.source,
      evidenceType: c.evidenceType,
      passed: c.passed,
      failures: c.failures,
      result: c.result,
    })),
  };

  fs.mkdirSync(REPORT_DIR, { recursive: true });
  const reportPath = path.join(REPORT_DIR, 'S1-04-report.json');
  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2) + '\n', 'utf8');

  console.log(`S1-04 离线验证：${passed}/${cases.length} 通过，${failed} 失败`);
  console.log(`路线覆盖：[${[...routes].sort().join(', ')}]`);
  console.log(`前序回归：${JSON.stringify(regression)}`);
  if (missingRoutes.length) console.log(`缺失路线：${missingRoutes.join(', ')}`);
  if (nestedLeak) console.log(`非递归违例：1 例`);
  for (const c of cases) if (!c.passed) console.log(`  ✗ ${c.enumId}: ${c.failures.join('; ')}`);
  console.log(`报告：${path.relative(ROOT, reportPath)}`);

  process.exitCode = failed === 0 && missingRoutes.length === 0 && !nestedLeak && !regressionFailed ? 0 : 1;
}

main();
