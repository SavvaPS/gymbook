// Copies the web app into www/, which Capacitor bundles into the iPhone and Android apps.
// The web version on GitHub Pages is served straight from the repo root, so it doesn't need this.
import { cpSync, rmSync, mkdirSync } from 'node:fs';
const out = 'www';
rmSync(out, { recursive: true, force: true });
mkdirSync(out);
for (const f of ['index.html', 'privacy.html', 'manifest.webmanifest']) cpSync(f, `${out}/${f}`);
for (const d of ['icons', 'fonts']) cpSync(d, `${out}/${d}`, { recursive: true });
console.log('Copied the web app into www/');
