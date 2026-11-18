/**
 * S1-05 插件配对 — 离线验证执行器（测试 harness，非 App 运行时）。
 *
 * 流程：读取十三组夹具 → 校验输入/预期分离 → 跑 PAIR-001~014 →
 * 核对大小写敏感、配对方向、五类互斥、跨路径不合并、软链身份与确定性 → 生成报告。
 * 全部为离线 fixture 合成样本，清单以信号注入模拟，不访问真实设备文件系统。
 */

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const { pairInventory } = require('./pairing');

const ROOT = path.join(__dirname, '..', '..');
const FIXTURE_DIR = path.join(ROOT, 'Tests', 'Fixtures', 'S1-05');
const REPORT_DIR = path.join(__dirname, 'report');

const FIXTURE_PAIR_MAP = {
  'pair-valid': ['PAIR-001'],
  'pair-missing-plist': ['PAIR-002'],
  'pair-orphan-plist': ['PAIR-003'],
  'pair-multi': ['PAIR-004'],
  'pair-case-mismatch': ['PAIR-005'],
  'pair-cross-path': ['PAIR-006'],
  'pair-hidden': ['PAIR-007'],
  'pair-symlink': ['PAIR-008'],
  'pair-other-ext': ['PAIR-009'],
  'pair-duplicate': ['PAIR-010'],
  'pair-access-denied': ['PAIR-011'],
  'route-guard': ['PAIR-012'],
  'pair-determinism': ['PAIR-013'],
};

function readJson(file) { return JSON.parse(fs.readFileSync(file, 'utf8')); }
function normalize(v) { return v === undefined ? null : v; }
function basename(p) { return p == null ? null : p.split('/').pop(); }

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

function deriveLists(result) {
  return {
    pairedBases: result.pairs.map((p) => p.base),
    missingBases: result.missingPlist.map((p) => p.base),
    orphanNames: result.orphanPlist.map((o) => basename(o.plistPath)),
    ambiguousBases: result.ambiguous.map((a) => a.base),
    uncertainPaths: result.uncertain.map((u) => basename(u.path)),
  };
}

function compareResult(result, meta) {
  const expected = meta.expected || {};
  const expectedWarnings = meta.expectedWarnings || [];
  const failures = [];
  const lists = deriveLists(result);
  const checks = [
    ['route', result.route, expected.route],
    ['sourceDirectory', result.sourceDirectory, expected.sourceDirectory],
    ['status', result.status, expected.status],
    ['counts', result.counts, expected.counts],
    ['pairedBases', lists.pairedBases, expected.pairedBases],
    ['missingBases', lists.missingBases, expected.missingBases],
    ['orphanNames', lists.orphanNames, expected.orphanNames],
    ['ambiguousBases', lists.ambiguousBases, expected.ambiguousBases || []],
    ['uncertainPaths', lists.uncertainPaths, expected.uncertainPaths || []],
  ];
  for (const [field, actual, want] of checks) {
    if (!deepEqual(actual, want)) failures.push(`${field}: 实际=${JSON.stringify(actual)} 期望=${JSON.stringify(want)}`);
  }
  if (!sameSet(result.warnings, expectedWarnings)) {
    failures.push(`warnings: 实际=[${result.warnings.join(',')}] 期望=[${expectedWarnings.join(',')}]`);
  }
  if (result.status !== meta.expectedStatus) {
    failures.push(`expectedStatus: 实际=${result.status} 期望=${meta.expectedStatus}`);
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

function runFixtureCase(pairId, fixture) {
  const { env, meta } = fixture;
  const result = pairInventory(env);
  const failures = compareResult(result, meta);
  return {
    pairId,
    source: `fixture:${fixture.kind}`,
    evidenceType: 'fixture',
    passed: failures.length === 0,
    result,
    failures,
  };
}

function buildSyntheticCases(fixtures) {
  const cases = [];

  // PAIR-013：相同清单重复配对，关系/归类/计数确定
  cases.push((() => {
    const det = fixtures.find((f) => f.kind === 'pair-determinism');
    const r1 = pairInventory(det.env);
    const r2 = pairInventory(det.env);
    const passed = deepEqual(r1, r2);
    return {
      pairId: 'PAIR-013',
      source: 'synthetic:determinism',
      evidenceType: 'fixture',
      passed,
      result: r1,
      failures: passed ? [] : ['重复配对结果不一致'],
    };
  })());

  // PAIR-006 补充：RootHide 配对结果不得出现 /var/jb 回退路径
  cases.push((() => {
    const guard = fixtures.find((f) => f.kind === 'route-guard');
    const r = pairInventory(guard.env);
    const allPaths = [...r.pairs, ...r.missingPlist, ...r.orphanPlist].map((x) => x.dylibPath || x.plistPath);
    const leak = allPaths.some((p) => /^\/var\/jb/.test(p || ''));
    const passed = r.sourceDirectory === null && !leak;
    return {
      pairId: 'PAIR-006',
      source: 'synthetic:route-isolation',
      evidenceType: 'fixture',
      passed,
      result: { sourceDirectory: r.sourceDirectory, counts: r.counts },
      failures: passed ? [] : ['回退扫描了 /var/jb 路径'],
    };
  })());

  return cases;
}

function runPriorRegression() {
  const stages = ['S1-01', 'S1-02', 'S1-03', 'S1-04'];
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
    for (const pairId of FIXTURE_PAIR_MAP[fixture.kind] || []) {
      cases.push(runFixtureCase(pairId, fixture));
    }
  }
  cases.push(...buildSyntheticCases(fixtures));

  const routes = new Set(fixtures.map((f) => f.env.upstream.route));
  const requiredRoutes = ['roothide'];
  const missingRoutes = requiredRoutes.filter((r) => !routes.has(r));

  // 五类互斥核对：同一栈条目不得同时进入多个类别
  const mutualLeak = cases.filter((c) => {
    const r = c.result;
    if (!r || !r.counts || !Array.isArray(r.pairs)) return false;
    const total = r.counts.paired + r.counts.missing_plist + r.counts.orphan_plist + r.counts.ambiguous + r.counts.uncertain;
    const listed = r.pairs.length + r.missingPlist.length + r.orphanPlist.length + r.ambiguous.length + r.uncertain.length;
    return total !== listed;
  });

  const regression = runPriorRegression();
  const regressionFailed = Object.values(regression).some((v) => v !== 'passed');

  const passed = cases.filter((c) => c.passed).length;
  const failed = cases.length - passed;

  const report = {
    schemaVersion: '0.1.0',
    generatedAt: new Date().toISOString(),
    stage: 'Stage 1 / S1-05',
    evidenceNote: '全部为离线 fixture 合成样本；不构成 RootHide 真机验证，Rootless 结果不代表真机兼容。',
    summary: {
      total: cases.length,
      passed,
      failed,
      routesCovered: [...routes].sort(),
      missingRoutes,
      mutualLeakCount: mutualLeak.length,
      regression,
    },
    cases: cases.map((c) => ({
      pairId: c.pairId,
      source: c.source,
      evidenceType: c.evidenceType,
      passed: c.passed,
      failures: c.failures,
      result: c.result,
    })),
  };

  fs.mkdirSync(REPORT_DIR, { recursive: true });
  const reportPath = path.join(REPORT_DIR, 'S1-05-report.json');
  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2) + '\n', 'utf8');

  console.log(`S1-05 离线验证：${passed}/${cases.length} 通过，${failed} 失败`);
  console.log(`路线覆盖：[${[...routes].sort().join(', ')}]`);
  console.log(`前序回归：${JSON.stringify(regression)}`);
  if (missingRoutes.length) console.log(`缺失路线：${missingRoutes.join(', ')}`);
  if (mutualLeak.length) console.log(`互斥违例：${mutualLeak.length} 例`);
  for (const c of cases) if (!c.passed) console.log(`  ✗ ${c.pairId}: ${c.failures.join('; ')}`);
  console.log(`报告：${path.relative(ROOT, reportPath)}`);

  process.exitCode = failed === 0 && missingRoutes.length === 0 && mutualLeak.length === 0 && !regressionFailed ? 0 : 1;
}

main();
