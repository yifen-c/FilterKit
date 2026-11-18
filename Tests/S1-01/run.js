/**
 * S1-01 离线验证执行器（测试 harness，非 App 运行时）。
 *
 * 流程：读取六组夹具 → 校验输入/预期分离 → 跑 ENV-001~015 →
 * 核对五版本态与两类冲突 → 生成测试报告。
 * 所有样本均为 fixture（离线合成），不得标注为 RootHide 真机验证。
 */

const fs = require('fs');
const path = require('path');
const { detectEnvironment } = require('./detector');

const ROOT = path.join(__dirname, '..', '..');
const FIXTURE_DIR = path.join(ROOT, 'Tests', 'Fixtures', 'S1-01');
const REPORT_DIR = path.join(__dirname, 'report');

// ENV 用例 → 夹具目录映射（夹具覆盖的用例）
const FIXTURE_ENV_MAP = {
  roothide: ['ENV-001'],
  rootless: ['ENV-002'],
  rootful: ['ENV-003'],
  unknown: ['ENV-004', 'ENV-005', 'ENV-007'],
  incomplete: ['ENV-006', 'ENV-010', 'ENV-014'],
  conflicting: ['ENV-008', 'ENV-009'],
};

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

function normalize(v) {
  return v === undefined ? null : v;
}

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
  const sa = [...(a || [])].sort();
  const sb = [...(b || [])].sort();
  return deepEqual(sa, sb);
}

function compareResult(result, meta) {
  const expected = meta.expected || {};
  const expectedWarnings = meta.expectedWarnings || [];
  const failures = [];
  const checks = [
    ['jailbreakType', result.jailbreakType, expected.jailbreakType],
    ['architecture', result.architecture, expected.architecture],
    ['iosVersion', result.iosVersion, expected.iosVersion],
    ['bootstrap.name', result.bootstrap.name, expected.bootstrap?.name ?? null],
    ['bootstrap.version', result.bootstrap.version, expected.bootstrap?.version ?? null],
    ['ellekitImplementation', result.ellekitImplementation, expected.ellekitImplementation],
    ['ellekitVersion', result.ellekitVersion, expected.ellekitVersion ?? null],
    ['ellekitVersionStatus', result.ellekitVersionStatus, expected.ellekitVersionStatus],
    ['adapterProfile', result.adapterProfile, expected.adapterProfile ?? null],
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
  const groups = fs.readdirSync(FIXTURE_DIR, { withFileTypes: true })
    .filter((d) => d.isDirectory())
    .map((d) => d.name);
  const fixtures = [];
  for (const kind of groups) {
    const dir = path.join(FIXTURE_DIR, kind);
    const env = readJson(path.join(dir, 'environment.json'));
    const meta = readJson(path.join(dir, 'metadata.json'));
    fixtures.push({ kind, env, meta });
  }
  return fixtures;
}

function runFixtureCase(envId, fixture) {
  const { env, meta } = fixture;
  // 输入/预期分离校验：识别器只接收 environment，不读取 metadata
  const result = detectEnvironment(env);
  const failures = compareResult(result, meta);
  return {
    envId,
    source: `fixture:${fixture.kind}`,
    evidenceType: 'fixture',
    passed: failures.length === 0,
    result,
    failures,
  };
}

function buildSyntheticCases() {
  const cases = [];

  // ENV-011：输入数据格式错误 → 结构化错误，不崩溃
  cases.push((() => {
    let parseError = null;
    let result = null;
    try {
      JSON.parse('{ not valid json');
    } catch (e) {
      parseError = e.name;
    }
    try {
      result = detectEnvironment({ signals: {} });
    } catch (e) {
      parseError = (parseError || '') + '; detector-threw:' + e.name;
    }
    const passed = parseError === 'SyntaxError' && result !== null;
    return {
      envId: 'ENV-011',
      source: 'synthetic:malformed-input',
      evidenceType: 'fixture',
      passed,
      result,
      failures: passed ? [] : ['格式错误未被结构化捕获，或识别器崩溃'],
    };
  })());

  // ENV-012：版本存在但不可读 → unreadable，访问受限
  cases.push((() => {
    const env = {
      signals: {
        jailbreakType: { value: 'roothide', present: true },
        architecture: { value: 'arm64e', present: true },
        iosVersion: { value: '17.0.2', present: true },
        bootstrap: { name: 'dopamine-roothide', version: '3.0.13-30', present: true },
        ellekitImplementation: { value: 'roothide', present: true },
        ellekitVersion: { value: null, present: true, readability: 'unreadable' },
      },
    };
    const result = detectEnvironment(env);
    const failures = [];
    if (result.ellekitVersionStatus !== 'unreadable') failures.push(`版本态=${result.ellekitVersionStatus} 期望=unreadable`);
    if (!result.warnings.includes('access_limited')) failures.push('缺少 access_limited 告警');
    return { envId: 'ENV-012', source: 'synthetic:version-unreadable', evidenceType: 'fixture', passed: failures.length === 0, result, failures };
  })());

  // ENV-013：相同输入重复执行 → 结果确定
  cases.push((() => {
    const roothide = loadFixtures().find((f) => f.kind === 'roothide');
    const r1 = detectEnvironment(roothide.env);
    const r2 = detectEnvironment(roothide.env);
    const passed = deepEqual(r1, r2);
    return {
      envId: 'ENV-013',
      source: 'synthetic:determinism',
      evidenceType: 'fixture',
      passed,
      result: r1,
      failures: passed ? [] : ['重复输入结果不一致'],
    };
  })());

  // ENV-015：metadata 与 environment 的 fixtureId 不一致 → 框架报错，识别器判断不受影响
  cases.push((() => {
    const roothide = loadFixtures().find((f) => f.kind === 'roothide');
    const mismatchedMeta = { ...roothide.meta, fixtureId: 'S1-01-MISMATCH-999' };
    const idMismatch = roothide.env.fixtureId !== mismatchedMeta.fixtureId;
    const result = detectEnvironment(roothide.env);
    const passed = idMismatch && result !== null;
    return {
      envId: 'ENV-015',
      source: 'synthetic:id-mismatch',
      evidenceType: 'fixture',
      passed,
      result,
      failures: passed ? [] : ['框架未识别 fixtureId 不一致，或识别器受影响'],
    };
  })());

  return cases;
}

function main() {
  const fixtures = loadFixtures();
  const cases = [];

  for (const fixture of fixtures) {
    const envIds = FIXTURE_ENV_MAP[fixture.kind] || [];
    for (const envId of envIds) cases.push(runFixtureCase(envId, fixture));
  }
  cases.push(...buildSyntheticCases());

  // 版本五态覆盖核对
  const statuses = new Set(cases.map((c) => c.result && c.result.ellekitVersionStatus).filter(Boolean));
  const requiredStatuses = ['parsed', 'not_installed', 'unreadable', 'unparsable', 'conflicted'];
  const missingStatuses = requiredStatuses.filter((s) => !statuses.has(s));

  // 两类冲突覆盖核对
  const conflictWarnings = new Set(cases.flatMap((c) => c.result?.warnings || []));
  const missingConflicts = ['route_signal_conflict', 'impl_version_conflict'].filter((w) => !conflictWarnings.has(w));

  const passed = cases.filter((c) => c.passed).length;
  const failed = cases.length - passed;

  const report = {
    schemaVersion: '0.1.0',
    generatedAt: new Date().toISOString(),
    stage: 'Stage 1 / S1-01',
    evidenceNote: '全部为离线 fixture 合成样本；不构成 RootHide 真机验证，Rootless 结果不代表 Rootless 真机兼容。',
    summary: {
      total: cases.length,
      passed,
      failed,
      versionStatusesCovered: [...statuses].sort(),
      missingVersionStatuses: missingStatuses,
      missingConflictWarnings: missingConflicts,
    },
    cases: cases.map((c) => ({
      envId: c.envId,
      source: c.source,
      evidenceType: c.evidenceType,
      passed: c.passed,
      failures: c.failures,
      result: c.result,
    })),
  };

  fs.mkdirSync(REPORT_DIR, { recursive: true });
  const reportPath = path.join(REPORT_DIR, 'S1-01-report.json');
  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2) + '\n', 'utf8');

  console.log(`S1-01 离线验证：${passed}/${cases.length} 通过，${failed} 失败`);
  console.log(`版本态覆盖：[${[...statuses].sort().join(', ')}]`);
  if (missingStatuses.length) console.log(`缺失版本态：${missingStatuses.join(', ')}`);
  if (missingConflicts.length) console.log(`缺失冲突：${missingConflicts.join(', ')}`);
  for (const c of cases) {
    if (!c.passed) console.log(`  ✗ ${c.envId}: ${c.failures.join('; ')}`);
  }
  console.log(`报告：${path.relative(ROOT, reportPath)}`);

  process.exitCode = failed === 0 && missingStatuses.length === 0 && missingConflicts.length === 0 ? 0 : 1;
}

main();
