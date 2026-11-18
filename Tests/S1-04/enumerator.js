/**
 * S1-04 插件文件枚举 — 离线校验枚举模块（测试 harness）。
 *
 * 规则对齐 Spec/Stage-1/S1-04-Plugin-Enumeration.md。
 * 本模块为 Stage 1 离线验证用最小实现，非 App 运行时；后续迁移 Core/Adapters。
 * 虚拟文件系统以信号注入模拟，不访问真实设备文件系统。
 *
 * 口径：scandir 单层非递归；扩展名大小写敏感（对齐 injector.c strcmp）；
 * 软链记录自身、不跟随目标；单条目异常不中断整轮；不产出配对/解析/加载结论。
 */

function extensionOf(name) {
  if (typeof name !== 'string') return null;
  const dot = name.lastIndexOf('.');
  if (dot <= 0) return null; // 点开头隐藏文件且无第二段点号 → 无扩展名
  return name.slice(dot + 1);
}

function classify(entry) {
  if (entry.type === 'directory') return 'directory';
  if (entry.isSymlink) return 'symlink';
  const ext = extensionOf(entry.name);
  if (ext === 'dylib') return 'dylib';
  if (ext === 'plist') return 'plist';
  return 'other';
}

function joinPath(dir, name) {
  if (!dir) return null;
  return dir.endsWith('/') ? dir + name : dir + '/' + name;
}

function enumerate(env) {
  const upstream = (env && env.upstream) || {};
  const fs = (env && env.fs) || {};
  const route = upstream.route || 'unknown';
  const sourceDirectory = upstream.sourceDirectory ?? null;
  const warnings = [];

  let status;
  let items = [];

  if (sourceDirectory === null) {
    status = 'unresolved';
    warnings.push('directory_unresolved');
  } else if (fs.enumerable === false) {
    status = 'enumeration_failed';
    warnings.push('enumeration_failed');
  } else {
    const rawEntries = Array.isArray(fs.entries) ? fs.entries : [];
    // 非递归：嵌套条目不进入清单
    const topLevel = rawEntries.filter((e) => e.nested !== true);

    items = topLevel.map((entry) => {
      const kind = classify(entry);
      return {
        path: joinPath(sourceDirectory, entry.name),
        name: entry.name,
        extension: extensionOf(entry.name),
        kind,
        exists: Boolean(entry.exists),
        readable: Boolean(entry.readable),
        isSymlink: Boolean(entry.isSymlink),
        symlinkTarget: entry.symlinkTarget ?? null,
        symlinkState: entry.symlinkState ?? null,
        realpath: entry.realpath ?? null,
        size: entry.size ?? null,
        hash: entry.hash ?? null,
        hidden: Boolean(entry.hidden),
        entryStatus: entry.entryStatus || 'ok',
      };
    });

    // alphasort：按文件名字母序，保证清单确定性（大小写敏感）
    items.sort((a, b) => (a.name < b.name ? -1 : a.name > b.name ? 1 : 0));

    const partial = items.some((i) => i.entryStatus !== 'ok');
    status = partial ? 'partial' : 'enumerated';
    if (partial) warnings.push('partial_enumeration');
  }

  const counts = { dylib: 0, plist: 0, directory: 0, symlink: 0, other: 0 };
  for (const i of items) counts[i.kind] += 1;

  const unknownItems = items
    .filter((i) => i.kind !== 'dylib' && i.kind !== 'plist')
    .map((i) => ({ path: i.path, name: i.name, reason: i.kind }));

  return {
    route,
    sourceDirectory,
    enumeration: { recursive: false, status, warnings },
    items,
    unknownItems,
    counts,
    warnings,
  };
}

module.exports = { enumerate, extensionOf, classify, joinPath };
