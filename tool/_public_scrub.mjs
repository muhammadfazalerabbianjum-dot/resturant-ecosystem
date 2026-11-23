// Public-release scrubber.
//
// Replaces live Firebase/Cloudinary identifiers with same-shaped placeholders,
// and removes anything that names a person or a machine, so the published tree
// cannot point at a real project, a real owner or a real disk layout. It
// rewrites data, never logic.
//
// Three details that are easy to get wrong, and are handled here:
//   * the placeholder is itself key-shaped, so the checker must not count its
//     own output as a live value (a scrubber that always reports DIRTY teaches
//     people to ignore it);
//   * a key is replaced as a whole token, not a fixed number of characters, so
//     no tail of a real key survives the substitution;
//   * longer paths are replaced first, so "/resturant-cline-1" is not eaten by
//     the "/resturant" rule and left as "<repo>-cline-1".
//
// No regular expressions on purpose: the patterns are plain strings assembled
// from fragments (so this file is safe to publish) and matching is by index.
//
// Usage:
//   node tool/_public_scrub.mjs          replace in every tracked text file
//   node tool/_public_scrub.mjs --check  exit 1 if any live value remains

import fs from 'node:fs';
import cp from 'node:child_process';

const KEY_PREFIX = 'AIza';
const KEY_MIN_LENGTH = 30;
const KEY_PLACEHOLDER = 'AIzaSyDEMO-PLACEHOLDER-NOT-A-KEY';
const NUL = String.fromCharCode(0);

// Live project identifiers.
const LITERALS = [
  ['restaur' + 'ants-8547d', 'demo-restaurant'],
  ['halal-boys' + '-c1604', 'demo-tenant'],
  ['835546' + '454041', '000000000000'],
  ['697' + '007956550', '000000000000'],
  ['dx4tr' + 'bmt', 'demo-cloudinary'],
];

// Person-shaped values: the owner's mailbox. Split into fragments so this file
// does not itself publish the address it removes, or any readable part of it.
const EMAIL = 'kni' + 'ghtoff' + 'icialboosted@' + 'gm' + 'ail.com';
const EMAIL_2 = 'faz' + 'driftt@' + 'gm' + 'ail.com';
const EMAIL_SAFE = 'owner@example.com';

// Windows profile folder name, split for the same reason.
const PROFILE = 'kni' + 'gh';

// Machine paths. The public tree should read as a project, not as somebody's
// disk. Longest needle first at match time.
const DRIVES = ['A', 'a', 'E', 'e'];
const PATHS = [
  ['<repo>-worktree', '<repo>-worktree'],
  ['<repo>-worktree', '<repo>-worktree'],
  ['<repo>-worktree', '<repo>-worktree'],
  ['<snapshot>', '<snapshot>'],
  ['<snapshot>', '<snapshot>'],
  ['<snapshot>', '<snapshot>'],
  ['<other-project>', '<other-project>'],
  ['<other-project>', '<other-project>'],
  ['<other-project>', '<other-project>'],
  ['<audit-folder>', '<audit-folder>'],
  ['<audit-folder>', '<audit-folder>'],
  ['<audit-folder>', '<audit-folder>'],
  ['C:/Users/' + PROFILE, 'C:/Users/user'],
  ['c:/Users/' + PROFILE, 'C:/Users/user'],
  ['C:\\Users\\' + PROFILE, 'C:\\Users\\user'],
  ['c:\\Users\\' + PROFILE, 'C:\\Users\\user'],
  ...DRIVES.flatMap((drive) => [
    [drive + ':/resturant', '<repo>'],
    [drive + ':\\resturant', '<repo>'],
  ]),
]
  // JSON and escaped text carry the same paths with doubled backslashes.
  .flatMap((pair) => [pair, [pair[0].split('\\').join('\\\\'), pair[1]]])
  .sort((a, b) => b[0].length - a[0].length);

// The publishing document is instructions to run on this machine, so its paths
// are the point of the file. It is still key/identity scrubbed, just not path
// scrubbed. It names folder names and a drive letter, never a user profile.
const PATH_EXEMPT = new Set(['docs/PUBLISHING.md']);

// Files that are machine output, not project content.
const PRUNE = [
  'core_app/emulators_log.txt',
  'core_app/docs/archive/stdout.txt',
  'core_app/.agents',
  // 2.1 MB mixed UTF-16/UTF-8 dump (9,091 NUL bytes) that pastes a real client
  // config. It cannot be scrubbed as text, and it is an internal handover
  // record, not project content.
  'archive/HANDOVER_AUDIT.md',
  // 1.1 MB native Isar 3.1.0 binary. Nothing references it any more: the test
  // helpers resolve the lockfile-pinned core through package_config.json
  // (core_app/DEFERRED.md D-P34-1). A binary is not portfolio content.
  'isar.dll',
  // The real CI runs in the private repository. In a scrubbed snapshot it has
  // no working credentials or project ids, so it would paint every push red.
  '.github/workflows/carnama_ci.yml',
];

const SKIP_EXTENSIONS = new Set([
  'dll', 'exe', 'so', 'a', 'dylib', 'jar', 'zip', 'tar', 'gz', 'tgz',
  'png', 'jpg', 'jpeg', 'gif', 'webp', 'ico', 'ttf', 'otf', 'woff', 'woff2',
  'pdf', 'keystore', 'jks',
]);

function isKeyChar(ch) {
  return (
    (ch >= 'A' && ch <= 'Z') ||
    (ch >= 'a' && ch <= 'z') ||
    (ch >= '0' && ch <= '9') ||
    ch === '-' ||
    ch === '_'
  );
}

/** The end index of a key-shaped token starting at [at], or -1 if too short. */
function keyEnd(text, at) {
  let end = at + KEY_PREFIX.length;
  while (end < text.length && isKeyChar(text[end])) end += 1;
  return end - at >= KEY_MIN_LENGTH ? end : -1;
}

/** Replace every live key token in [text]. */
function scrubKeys(text) {
  let out = '';
  let i = 0;
  for (;;) {
    const at = text.indexOf(KEY_PREFIX, i);
    if (at === -1) return out + text.slice(i);
    if (text.startsWith(KEY_PLACEHOLDER, at)) {
      out += text.slice(i, at + KEY_PLACEHOLDER.length);
      i = at + KEY_PLACEHOLDER.length;
      continue;
    }
    const end = keyEnd(text, at);
    if (end === -1) {
      out += text.slice(i, at + KEY_PREFIX.length);
      i = at + KEY_PREFIX.length;
      continue;
    }
    out += text.slice(i, at) + KEY_PLACEHOLDER;
    i = end;
  }
}

/** Count live key tokens in [text], ignoring the placeholder. */
function countKeys(text) {
  let count = 0;
  let i = 0;
  for (;;) {
    const at = text.indexOf(KEY_PREFIX, i);
    if (at === -1) return count;
    if (text.startsWith(KEY_PLACEHOLDER, at)) {
      i = at + KEY_PLACEHOLDER.length;
      continue;
    }
    const end = keyEnd(text, at);
    if (end === -1) {
      i = at + KEY_PREFIX.length;
      continue;
    }
    count += 1;
    i = end;
  }
}

function countLiteral(text, needle) {
  return text.split(needle).length - 1;
}

const check = process.argv.includes('--check');

const files = cp
  .execSync('git ls-files', { encoding: 'utf8' })
  .split('\n')
  .map((line) => line.trim())
  .filter(Boolean)
  .filter((file) => {
    const dot = file.lastIndexOf('.');
    if (dot === -1) return true;
    return !SKIP_EXTENSIONS.has(file.slice(dot + 1).toLowerCase());
  })
  .filter((file) => fs.existsSync(file));

let changed = 0;
let live = 0;

for (const file of files) {
  let text;
  try {
    text = fs.readFileSync(file, 'utf8');
  } catch {
    continue;
  }
  if (text.indexOf(NUL) !== -1) continue;

  if (check) {
    let hits = countKeys(text);
    for (const [needle] of LITERALS) hits += countLiteral(text, needle);
    hits += countLiteral(text, EMAIL);
    hits += countLiteral(text, EMAIL_2);
    hits += countLiteral(text, 'Users/' + PROFILE);
    hits += countLiteral(text, 'Users\\' + PROFILE);
    if (hits > 0) {
      live += hits;
      console.log('LIVE  ' + file + '  (' + hits + ')');
    }
    continue;
  }

  const before = text;
  text = scrubKeys(text);
  for (const [needle, replacement] of LITERALS) {
    text = text.split(needle).join(replacement);
  }
  text = text.split(EMAIL).join(EMAIL_SAFE);
  text = text.split(EMAIL_2).join(EMAIL_SAFE);
  if (!PATH_EXEMPT.has(file)) {
    for (const [needle, replacement] of PATHS) {
      text = text.split(needle).join(replacement);
    }
  }
  if (text !== before) {
    fs.writeFileSync(file, text);
    changed += 1;
  }
}

if (check) {
  for (const target of PRUNE) {
    if (fs.existsSync(target)) {
      live += 1;
      console.log('LIVE  ' + target + '  (machine output, must be pruned)');
    }
  }
  console.log(
    live === 0
      ? 'CLEAN - no live identifier or personal path in the tracked tree'
      : 'DIRTY - ' + live + ' live identifier(s) remain',
  );
  process.exit(live === 0 ? 0 : 1);
}

for (const target of PRUNE) {
  if (fs.existsSync(target)) {
    fs.rmSync(target, { recursive: true, force: true });
    console.log('pruned  ' + target);
  }
}

console.log('scrubbed ' + changed + ' file(s)');
