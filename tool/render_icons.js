// Renders the app icon PNGs from tool/icon.html. Run: node tool/render_icons.js
const { chromium } = require('playwright');
const path = require('path');
(async () => {
  const b = await chromium.launch();
  const pg = await b.newPage({ viewport: { width: 1024, height: 1024 } });
  await pg.goto('file://' + path.resolve(__dirname, 'icon.html'));
  await pg.evaluate(() => document.fonts.ready);
  await pg.waitForTimeout(800);
  console.log('font loaded:', await pg.evaluate(() => document.fonts.check("800 46px 'Bricolage Grotesque'")));
  const out = (n) => path.resolve(__dirname, '..', 'assets', n);
  // Rounded icon with transparent corners (Windows, web, in-app logo).
  await pg.screenshot({ path: out('icon.png'), omitBackground: true });
  // Square, full-bleed (iOS and legacy Android).
  await pg.evaluate(() => document.querySelector('.bg').setAttribute('rx', '0'));
  await pg.screenshot({ path: out('icon_square.png') });
  // Android adaptive foreground: art only, shrunk into the safe zone.
  await pg.evaluate(() => { document.querySelector('.bg').remove(); document.querySelector('.art').setAttribute('transform', 'translate(60 60) scale(0.62) translate(-60 -60)'); });
  await pg.screenshot({ path: out('icon_foreground.png'), omitBackground: true });
  await b.close();
})();
