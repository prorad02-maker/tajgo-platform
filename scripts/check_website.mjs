import {readFileSync, existsSync, readdirSync} from 'node:fs';
import {resolve, extname} from 'node:path';
import {createHash} from 'node:crypto';

const root = resolve(import.meta.dirname, '../public');
let checked = 0;
for (const file of readdirSync(root).filter(name => name.endsWith('.html'))) {
  const html = readFileSync(resolve(root, file), 'utf8');
  for (const required of ['<title>', 'name="viewport"', 'rel="canonical"', '<h1']) {
    if (!html.includes(required)) throw new Error(`${file}: missing ${required}`);
  }
  for (const [, url] of html.matchAll(/(?:href|src)="([^"]+)"/g)) {
    if (/^(https?:|mailto:)/.test(url)) continue;
    const path = url.split('#')[0].split('?')[0];
    const target = path === '' ? file : path === '/' ? 'index.html' : path.replace(/^\//, '');
    const local = extname(target) ? target : `${target}.html`;
    if (!existsSync(resolve(root, local))) throw new Error(`${file}: missing ${url}`);
    if (['styles.css', 'landing.js'].includes(local)) {
      const expectedVersion = createHash('sha256').update(readFileSync(resolve(root, local))).digest('hex').slice(0, 12);
      const actualVersion = new URL(url, 'https://tajgo.ru').searchParams.get('v');
      if (actualVersion !== expectedVersion) throw new Error(`${file}: stale asset version for ${local}; run node scripts/version_website_assets.mjs`);
    }
    const anchor = url.split('#')[1];
    if (anchor && local.endsWith('.html')) {
      const linkedHtml = readFileSync(resolve(root, local), 'utf8');
      if (!linkedHtml.includes(`id="${decodeURIComponent(anchor)}"`)) throw new Error(`${file}: missing anchor ${url}`);
    }
    checked++;
  }
  const canonical = html.match(/rel="canonical" href="([^"]+)"/);
  if (!canonical?.[1].startsWith('https://tajgo.ru/')) throw new Error(`${file}: wrong canonical`);
  for (const [tag] of html.matchAll(/<svg\b[^>]*>/g)) {
    const classes = tag.match(/class="([^"]*)"/)?.[1].split(/\s+/) ?? [];
    if (classes.includes('icon') && (!/\bwidth="\d+"/.test(tag) || !/\bheight="\d+"/.test(tag) || !/\bfill="none"/.test(tag))) {
      throw new Error(`${file}: icon missing intrinsic size or fill`);
    }
    if (classes.includes('icon-library') && (!/\bwidth="0"/.test(tag) || !/\bheight="0"/.test(tag))) throw new Error(`${file}: icon library must not take up page space`);
  }
}
for (const [, asset] of readFileSync(resolve(root, 'styles.css'), 'utf8').matchAll(/url\(['"]?(\/[\w.\/-]+)['"]?\)/g)) {
  if (!existsSync(resolve(root, asset.slice(1)))) throw new Error(`styles.css: missing ${asset}`);
  checked++;
}
console.log(`Website checks passed: ${checked} local asset/link references.`);
