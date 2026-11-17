// Plays a tap sequence against the local Arcana web build and saves screenshots.
// Usage: node shot_seq.js <out_dir> '<url query>' '<steps json>'
// Only talks to http://localhost:8765 (the locally served build).
const { chromium, devices } = require('playwright');
(async () => {
  const [out, query, stepsJson] = process.argv.slice(2);
  const steps = JSON.parse(stepsJson || '[]');
  const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  const ctx = await browser.newContext({ ...devices['iPhone 13 landscape'] });
  const page = await ctx.newPage();
  page.on('console', m => { if (m.type() === 'error' || m.text().includes('ERROR')) console.log('ERR', m.text().slice(0, 300)); });
  await page.goto('http://localhost:8765/index.html' + (query || ''));
  await page.waitForTimeout(11000);  // the Godot web build needs a while to start
  let n = 0;
  for (const s of steps) {
    if (s[0] === 'tap') await page.touchscreen.tap(s[1], s[2]);
    await page.waitForTimeout(s[3] || 300);
    if (s[4]) await page.screenshot({ path: `${out}/${String(n++).padStart(2, '0')}.png` });
  }
  await browser.close();
})();
