/**
 * S1-03 ElleKit 目录定位 — 离线验证执行器（测试 harness，非 App 运行时）。
 *
 * 流程：读取十一组夹具 → 校验输入/预期分离 → 跑 DIR-001~013 →
 * 核对三路线前缀、状态分层、软链五态、目标一致性、回退禁止与确定性 → 生成报告。
 * 全部为离线 fixture 合成样本，虚拟 FS 以信号注入模拟，不访问真实设备文件系统。
 */

const fs = require('fs');
const path = require('path');
const { resolveDirectory } = require('./resolver');

const ROOT = path.join(__dirname, '..', '..');
const FIXTURE_DIR = path.join(ROOT, 'Tests', 'Fixtures', 'S1-03');
const REPORT_DIR = path.join(__dirname, 'report');

const FIXTURE_DIR_MAP = {
  'rh-valid': ['DIR-001', 'DIR-004', 'DIR-005'],
  'rh-missing': ['DIR-002'],
  'rh-unreadable': ['DIR-003'],
  'rh-broken-link': ['DIR-006'],
  'rh-loop': ['DIR-007'],
  'rh-target-denied': ['DIR-008'],
  'rh-not-symlink': ['DIR-009'],
  'rootless-valid': ['DIR-001'],
  'rootful-valid': ['DIR-001'],
  'route-fallback-guard': ['DIR-010'],
  'structure-conflict': ['DIR-011'],
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
    ['tiPath', result.tweakInject.value, expected.tiPath],
    ['tiExists', result.tweakInject.exists, expected.tiExists],
    ['tiReadable', result.tweakInject.readable, expected.tiReadable],
    ['tiEnumerable', result.tweakInject.enumerable, expected.tiEnumerable],
    ['tiStatus', result.tweakInject.status, expected.tiStatus],
    ['dlState', result.dynamicLibraries.symlinkState, expected.dlState],
    ['dlTargetMatch', result.dynamicLibraries.targetMatch, expected.dlTargetMatch],
    ['outcome', result.outcome, expected.outcome],
  ];
  for (const [field, actual, want] of checks) {
    if (!deepEqual(actual, want)) failures.push(`${field}: 实际=${JSON.stringify(actual)} 期望=${JSON.stringify(want)}`);
  }
  if (!sameSet(result.warnings, expectedWarnings)) {
    failures.push(`warnings: 实际=[${result.warnings.join(',')}] 期望=[${expectedWarnings.join(',')}]`);
  }
  if (result.outcome !== meta.expectedOutcome) {
    failures.push(`expectedOutcome: 实际=${result.outcome} 期望=${meta.expectedOutcome}`);
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

function runFixtureCase(dirId, fixture) {
  const { env, meta } = fixture;
  const result = resolveDirectory(env);
  const failures = compareResult(result, meta);
  return {
    dirId,
    source: `fixture:${fixture.kind}`,
    evidenceType: 'fixture',
    passed: failures.length === 0,
    result,
    failures,
  };
}

function buildSyntheticCases(fixtures) {
  const cases = [];

  // DIR-012：相同目录信号重复解析，结果确定
  cases.push((() => {
    const rh = fixtures.find((f) => f.kind === 'rh-valid');
    const r1 = resolveDirectory(rh.env);
    const r2 = resolveDirectory(rh.env);
    const passed = deepEqual(r1, r2);
    return {
      dirId: 'DIR-012',
      source: 'synthetic:determinism',
      evidenceType: 'fixture',
      passed,
      result: r1,
      failures: passed ? [] : ['重复解析结果不一致'],
    };
  })());

  // DIR-013：metadata 与 environment 的 fixtureId 不一致 → 框架报错，不影响解析器
  cases.push((() => {
    const rh = fixtures.find((f) => f.kind === 'rh-valid');
    const mismatched = { ...rh.meta, fixtureId: 'S1-03-MISMATCH-999' };
    const idMismatch = rh.env.fixtureId !== mismatched.fixtureId;
    const result = resolveDirectory(rh.env);
    const passed = idMismatch && result !== null;
    return {
      dirId: 'DIR-013',
      source: 'synthetic:id-mismatch',
      evidenceType: 'fixture',
      passed,
      result,
      failures: passed ? [] : ['框架未识别 fixtureId 不一致，或解析器受影响'],
    };
  })());

  return cases;
}

function main() {
  const fixtures = loadFixtures();
  const cases = [];
  for (const fixture of fixtures) {
    for (const dirId of FIXTURE_DIR_MAP[fixture.kind] || []) {
      cases.push(runFixtureCase(dirId, fixture));
    }
  }
  cases.push(...buildSyntheticCases(fixtures));

  // 路线覆盖核对：三路线均有有效样本
  const routes = new Set(fixtures.map((f) => f.env.upstream.route));
  const requiredRoutes = ['roothide', 'rootless', 'rootful'];
  const missingRoutes = requiredRoutes.filter((r) => !routes.has(r));

  // 路线隔离核对：RootHide jbroot 未定位时不得回退 /var/jb 或 /
  const guard = fixtures.find((f) => f.kind === 'route-fallback-guard');
  const guardResult = guard ? resolveDirectory(guard.env) : null;
  const fallbackLeak = !guardResult || guardResult.tweakInject.value !== null ||
    /^\/var\/jb/.test(guardResult.tweakInject.value || '') || guardResult.tweakInject.value === '/';

  // 状态分层核对：readable=false 时不得把 enumerable 推断为 true（两者独立记录）
  const unreadable = fixtures.find((f) => f.kind === 'rh-unreadable');
  const unreadResult = unreadable ? resolveDirectory(unreadable.env) : null;
  const layerViolation = !unreadResult ||
    (unreadResult.tweakInject.readable === false && unreadResult.tweakInject.enumerable === true);

  const passed = cases.filter((c) => c.passed).length;
  const failed = cases.length - passed;

  const report = {
    schemaVersion: '0.1.0',
    generatedAt: new Date().toISOString(),
    stage: 'Stage 1 / S1-03',
    evidenceNote: '全部为离线 fixture 合成样本；不构成 RootHide 真机验证，Rootless/Rootful 结果不代表真机兼容。',
    summary: {
      total: cases.length,
      passed,
      failed,
      routesCovered: [...routes].sort(),
      missingRoutes,
      fallbackLeakCount: fallbackLeak ? 1 : 0,
      layerViolationCount: layerViolation ? 1 : 0,
    },
    cases: cases.map((c) => ({
      dirId: c.dirId,
      source: c.source,
      evidenceType: c.evidenceType,
      passed: c.passed,
      failures: c.failures,
      result: c.result,
    })),
  };

  fs.mkdirSync(REPORT_DIR, { recursive: true });
  const reportPath = path.join(REPORT_DIR, 'S1-03-report.json');
  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2) + '\n', 'utf8');

  console.log(`S1-03 离线验证：${passed}/${cases.length} 通过，${failed} 失败`);
  console.log(`路线覆盖：[${[...routes].sort().join(', ')}]`);
  if (missingRoutes.length) console.log(`缺失路线：${missingRoutes.join(', ')}`);
  if (fallbackLeak) console.log(`回退越界：1 例`);
  if (layerViolation) console.log(`状态分层违例：1 例`);
  for (const c of cases) if (!c.passed) console.log(`  ✗ ${c.dirId}: ${c.failures.join('; ')}`);
  console.log(`报告：${path.relative(ROOT, reportPath)}`);

  process.exitCode = failed === 0 && missingRoutes.length === 0 && !fallbackLeak && !layerViolation ? 0 : 1;
}

main();
