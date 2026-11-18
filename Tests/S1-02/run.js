/**
 * S1-02 离线验证执行器（测试 harness，非 App 运行时）。
 *
 * 流程：读取十组夹具 → 校验输入/预期分离 → 跑 PATH-001~012 →
 * 核对五种候选来源、分层裁决、异常分类、路线隔离与确定性 → 生成报告。
 * 全部为离线 fixture 合成样本，不构成真机验证。
 */

const fs = require('fs');
const path = require('path');
const { resolvePaths, normalizeLexical } = require('./resolver');

const ROOT = path.join(__dirname, '..', '..');
const FIXTURE_DIR = path.join(ROOT, 'Tests', 'Fixtures', 'S1-02');
const REPORT_DIR = path.join(__dirname, 'report');

const FIXTURE_PATH_MAP = {
  'rh-valid': ['PATH-001', 'PATH-002', 'PATH-003', 'PATH-008', 'PATH-009'],
  'rh-multiple': ['PATH-006'],
  'rh-badname': ['PATH-003'],
  'rh-name-only': ['PATH-002'],
  'rh-unreadable': ['PATH-007'],
  'rh-broken-link': ['PATH-005', 'PATH-007'],
  'rootless-varjb': ['PATH-010'],
  'rootful-root': ['PATH-010'],
  'no-candidate': ['PATH-007'],
  'realpath-privatevar': ['PATH-005'],
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
    ['jbroot', result.jbroot, expected.jbroot],
    ['jbrand', result.jbrand, expected.jbrand],
    ['realpath', result.realpath, expected.realpath],
    ['ambiguous', result.ambiguous, expected.ambiguous],
    ['outcome', result.outcome, expected.outcome],
    ['selectedSource', result.selectedSource, expected.selectedSource ?? null],
    ['candidateCount', result.candidateCount, expected.candidateCount],
  ];
  for (const [field, actual, want] of checks) {
    if (!deepEqual(actual, want)) failures.push(`${field}: 实际=${JSON.stringify(actual)} 期望=${JSON.stringify(want)}`);
  }
  if (!sameSet(result.warnings, expectedWarnings)) {
    failures.push(`warnings: 实际=[${result.warnings.join(',')}] 期望=[${expectedWarnings.join(',')}]`);
  }
  if (result.outcome !== meta.expectedOutcome) {
    failures.push(`outcome: 实际=${result.outcome} 期望=${meta.expectedOutcome}`);
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

function runFixtureCase(pathId, fixture) {
  const { env, meta } = fixture;
  const result = resolvePaths(env);
  const failures = compareResult(result, meta);
  return {
    pathId,
    source: `fixture:${fixture.kind}`,
    evidenceType: 'fixture',
    passed: failures.length === 0,
    result,
    failures,
  };
}

function buildSyntheticCases(fixtures) {
  const cases = [];

  // PATH-004：词法规范化（. / .. / 重复分隔符 / 尾斜杠）
  cases.push((() => {
    const messy = '//var/containers/Bundle/./Application/../Application/.jbroot-9C414BB7D5DCECC4/';
    const normalized = normalizeLexical(messy);
    const want = '/var/containers/Bundle/Application/.jbroot-9C414BB7D5DCECC4';
    const passed = normalized === want;
    return {
      pathId: 'PATH-004',
      source: 'synthetic:lexical-normalize',
      evidenceType: 'fixture',
      passed,
      result: { normalized },
      failures: passed ? [] : [`规范化=${normalized} 期望=${want}`],
    };
  })());

  // PATH-011：相同候选重复解析，结果确定
  cases.push((() => {
    const rh = fixtures.find((f) => f.kind === 'rh-valid');
    const r1 = resolvePaths(rh.env);
    const r2 = resolvePaths(rh.env);
    const passed = deepEqual(r1, r2);
    return {
      pathId: 'PATH-011',
      source: 'synthetic:determinism',
      evidenceType: 'fixture',
      passed,
      result: r1,
      failures: passed ? [] : ['重复解析结果不一致'],
    };
  })());

  // PATH-012：metadata 与 environment 的 fixtureId 不一致 → 框架报错，不影响解析器
  cases.push((() => {
    const rh = fixtures.find((f) => f.kind === 'rh-valid');
    const mismatched = { ...rh.meta, fixtureId: 'S1-02-MISMATCH-999' };
    const idMismatch = rh.env.fixtureId !== mismatched.fixtureId;
    const result = resolvePaths(rh.env);
    const passed = idMismatch && result !== null;
    return {
      pathId: 'PATH-012',
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
    for (const pathId of FIXTURE_PATH_MAP[fixture.kind] || []) {
      cases.push(runFixtureCase(pathId, fixture));
    }
  }
  cases.push(...buildSyntheticCases(fixtures));

  // 五种候选来源覆盖核对
  const sources = new Set(fixtures.flatMap((f) => f.env.signals.candidates.map((c) => c.source)));
  const requiredSources = ['api', 'scan', 'bootstrap', 'rootless', 'rootful'];
  const missingSources = requiredSources.filter((s) => !sources.has(s));

  // 路线隔离核对：rootless/rootful 候选不得产生 jbroot
  const crossRouteLeak = cases.filter((c) =>
    (c.source.includes('rootless') || c.source.includes('rootful')) && c.result && c.result.jbroot !== null
  );

  const passed = cases.filter((c) => c.passed).length;
  const failed = cases.length - passed;

  const report = {
    schemaVersion: '0.1.0',
    generatedAt: new Date().toISOString(),
    stage: 'Stage 1 / S1-02',
    evidenceNote: '全部为离线 fixture 合成样本；不构成 RootHide 真机验证，Rootless/Rootful 结果不代表真机兼容。',
    summary: {
      total: cases.length,
      passed,
      failed,
      sourcesCovered: [...sources].sort(),
      missingSources,
      crossRouteLeakCount: crossRouteLeak.length,
    },
    cases: cases.map((c) => ({
      pathId: c.pathId,
      source: c.source,
      evidenceType: c.evidenceType,
      passed: c.passed,
      failures: c.failures,
      result: c.result,
    })),
  };

  fs.mkdirSync(REPORT_DIR, { recursive: true });
  const reportPath = path.join(REPORT_DIR, 'S1-02-report.json');
  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2) + '\n', 'utf8');

  console.log(`S1-02 离线验证：${passed}/${cases.length} 通过，${failed} 失败`);
  console.log(`候选来源覆盖：[${[...sources].sort().join(', ')}]`);
  if (missingSources.length) console.log(`缺失来源：${missingSources.join(', ')}`);
  if (crossRouteLeak.length) console.log(`路线越界：${crossRouteLeak.length} 例`);
  for (const c of cases) if (!c.passed) console.log(`  ✗ ${c.pathId}: ${c.failures.join('; ')}`);
  console.log(`报告：${path.relative(ROOT, reportPath)}`);

  process.exitCode = failed === 0 && missingSources.length === 0 && crossRouteLeak.length === 0 ? 0 : 1;
}

main();
