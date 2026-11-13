// Essai du build web dans Chromium (Playwright), sans carte graphique.
// Sert build/web, attend le marqueur « [91350] prêt », capture l'écran, maintient
// la touche D une seconde et capture à nouveau : le joueur doit avoir bougé.
//
//   tools/check.sh web && node tools/web_smoke.cjs
//
// Vérification locale (Node + Playwright, préinstallés dans les sessions cloud).
const fs = require('node:fs');
const http = require('node:http');
const path = require('node:path');
const { chromium } = require('playwright');

const WEB_DIR = path.resolve(__dirname, '..', 'build', 'web');
const SHOT_DIR = path.resolve(__dirname, '..', 'build', 'screenshots');
const READY_MARKER = '[91350] prêt';
const READY_TIMEOUT_MS = 60000;
const MIME_TYPES = {
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.wasm': 'application/wasm',
  '.pck': 'application/octet-stream',
  '.png': 'image/png',
};

function serve() {
  const server = http.createServer((request, response) => {
    const name = decodeURIComponent(request.url.split('?')[0]).replace(/^\/+/, '') || 'index.html';
    const file = path.join(WEB_DIR, name);
    if (!file.startsWith(WEB_DIR) || !fs.existsSync(file)) {
      response.writeHead(204).end();
      return;
    }
    response.writeHead(200, { 'Content-Type': MIME_TYPES[path.extname(file)] || 'application/octet-stream' });
    fs.createReadStream(file).pipe(response);
  });
  return new Promise((resolve) => server.listen(0, '127.0.0.1', () => resolve(server)));
}

async function main() {
  if (!fs.existsSync(path.join(WEB_DIR, 'index.html'))) {
    throw new Error('build/web/index.html manquant : lancer « tools/check.sh web » d\'abord.');
  }
  fs.mkdirSync(SHOT_DIR, { recursive: true });
  const server = await serve();
  const browser = await chromium.launch({
    args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'],
  });
  try {
    const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
    const errors = [];
    let markReady;
    const ready = new Promise((resolve) => { markReady = resolve; });
    page.on('console', (message) => {
      if (message.text().includes(READY_MARKER)) markReady(true);
      if (message.type() === 'error') errors.push(message.text());
    });
    page.on('pageerror', (error) => errors.push(String(error)));

    await page.goto(`http://127.0.0.1:${server.address().port}/index.html`);
    const timeout = new Promise((resolve) => setTimeout(resolve, READY_TIMEOUT_MS, false));
    if (!(await Promise.race([ready, timeout]))) {
      throw new Error(`le marqueur « ${READY_MARKER} » n'est pas apparu en ${READY_TIMEOUT_MS / 1000} s`);
    }
    await page.click('canvas');
    await page.waitForTimeout(500);
    await page.screenshot({ path: path.join(SHOT_DIR, 'web_0_titre.png') });
    // L'écran titre donne le focus à « Nouvelle partie » : Entrée lance la partie.
    await page.keyboard.press('Enter');
    await page.waitForTimeout(2500);
    await page.screenshot({ path: path.join(SHOT_DIR, 'web_1.png') });
    // Le monde bouge tout seul (horloge, respiration) : on compare une zone que seul le
    // panneau du sac recouvre, loin d'Akan (au centre) et de l'horloge (en haut à droite).
    const view = page.viewportSize();
    const clip = {
      x: Math.round(view.width * 0.3), y: Math.round(view.height * 0.4),
      width: Math.round(view.width * 0.1), height: Math.round(view.height * 0.1),
    };
    const before = await page.screenshot({ clip });
    await page.keyboard.press('Tab');
    await page.waitForTimeout(500);
    const after = await page.screenshot({ clip });
    await page.screenshot({ path: path.join(SHOT_DIR, 'web_2.png') });

    if (errors.length > 0) throw new Error(`erreurs dans la console :\n  ${errors.join('\n  ')}`);
    if (before.equals(after)) throw new Error('la touche Tab n\'a pas ouvert le sac');
    console.log('OK : le build web démarre, s\'affiche et répond au clavier.');
  } finally {
    await browser.close();
    server.close();
  }
}

main().catch((error) => {
  console.error(`Échec de l'essai web : ${error.message}`);
  process.exit(1);
});
