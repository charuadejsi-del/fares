// يبني simulateur.html: ملف واحد مستقل (core.js + المحاكي + الأنماط) يعمل بلا خادم ولا اتصال.
// الاستعمال: node jeu-khazna/tools/build-sim.mjs
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const read = f => readFileSync(join(root, f), 'utf8');

const core = read('core.js').replace(/^export\s+/gm, '');
const css = read('style.css') + '\n' + read('sim/sim.css');
const sim = read('sim/sim-app.js');

const html = `<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="theme-color" content="#0f1115">
<title>الخزنة — محاكي التجربة</title>
<link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>🔐</text></svg>">
<style>
${css}
</style>
</head>
<body>
<main id="app" aria-live="polite"></main>
<div id="flash" aria-hidden="true"></div>
<script>
"use strict";
(() => {
${core}
${sim}
})();
</script>
</body>
</html>
`;
writeFileSync(join(root, 'simulateur.html'), html);
console.log('✓ simulateur.html', (html.length / 1024).toFixed(1), 'KB');
