import {createHash} from 'node:crypto';
import {readFileSync, readdirSync, writeFileSync} from 'node:fs';
import {resolve} from 'node:path';

const root = resolve(import.meta.dirname, '../public');
const assets = ['styles.css', 'landing.js'];
const versions = new Map(assets.map(asset => [
  asset,
  createHash('sha256').update(readFileSync(resolve(root, asset))).digest('hex').slice(0, 12),
]));

for (const file of readdirSync(root).filter(name => name.endsWith('.html'))) {
  const path = resolve(root, file);
  const original = readFileSync(path, 'utf8');
  let html = original;
  for (const [asset, version] of versions) {
    const pattern = new RegExp(`((?:href|src)=")/${asset.replace('.', '\\.')}(?:\\?[^"<>]*)?"`, 'g');
    html = html.replace(pattern, `$1/${asset}?v=${version}"`);
  }
  if (html !== original) writeFileSync(path, html);
}

console.log(`Website asset versions: ${[...versions].map(([asset, version]) => `${asset}=${version}`).join(', ')}`);
