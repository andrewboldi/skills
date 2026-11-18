#!/usr/bin/env node
// Drive the Google Colab tabs of a browser started by launch-browser.sh, over the DevTools protocol.
//
//   node colab.cjs status                     one line per Colab tab: runtime connected or not, a cell running or
//                                              not, and the last line the notebook printed
//   node colab.cjs outputs TAB [CHARS]         the tail of every output area of one tab (outputs live in iframes)
//   node colab.cjs stop TAB                    interrupt the running cell, then disconnect and delete the runtime,
//                                              and check that it is gone
//   node colab.cjs watch [--idle-min 10] [--quiet-min 15] [--poll-s 120]
//                                              poll all Colab tabs; print ONE event line and exit (run it in the
//                                              background and re-arm it after each event):
//                                                IDLE_STOPPED  a runtime sat connected with no cell running: it was stopped
//                                                STOP_FAILED   stopping an idle runtime failed: stop it by hand now
//                                                QUIET_RUNNING a cell has run with no new output for --quiet-min minutes
//                                                RUNTIME_LOST  a runtime that was running a cell disconnected
//
// TAB is a substring of the tab title (e.g. the notebook's file name) that must match exactly one Colab tab.
// Environment: COLAB_CDP_PORT (default 9222); PLAYWRIGHT_CORE (path to a playwright-core install, optional).
'use strict';
const fs = require('fs');
const os = require('os');
const path = require('path');

const PORT = process.env.COLAB_CDP_PORT || '9222';

// A Colab connect button that says "Connect" or "Reconnect" means no runtime is attached; anything else
// (the RAM and disk meters, the runtime menu) means one is.
function isDisconnected(buttonText) {
  return /\bReconnect\b|\bConnect\b(?!ed)/.test(buttonText || '');
}

function loadPlaywright() {
  const tries = [process.env.PLAYWRIGHT_CORE, path.join(__dirname, 'node_modules', 'playwright-core'), 'playwright-core'];
  for (const t of tries) {
    if (!t) continue;
    try { return require(t); } catch (e) { /* try the next one */ }
  }
  console.error('playwright-core not found: run  bash ' + path.join(__dirname, 'setup.sh') + '  once');
  process.exit(3);
}

async function connect() {
  const { chromium } = loadPlaywright();
  try {
    return await chromium.connectOverCDP('http://127.0.0.1:' + PORT);
  } catch (e) {
    console.error('no browser on DevTools port ' + PORT + ': run  bash ' + path.join(__dirname, 'launch-browser.sh'));
    process.exit(4);
  }
}

function colabPages(browser) {
  const pages = [];
  for (const ctx of browser.contexts()) for (const p of ctx.pages()) {
    if (p.url().includes('colab.research.google.com')) pages.push(p);
  }
  return pages;
}

// Plain text output is rendered in the page itself; rich (HTML) output in iframes served from
// googleusercontent.com. Colab's other iframes (reCAPTCHA, feedback, about:blank helpers) are noise.
async function outputsText(page) {
  let text = await page.evaluate(() => {
    for (const sel of ['colab-static-output-renderer', '.output-content', '.output_text']) {
      const parts = [...document.querySelectorAll(sel)].map((e) => e.innerText || '').filter((t) => t.trim());
      if (parts.length) return parts.join('\n');
    }
    return '';
  });
  for (const f of page.frames()) {
    if (f === page.mainFrame() || !f.url().includes('googleusercontent.com')) continue;
    try {
      const t = await f.evaluate(() => (document.body ? document.body.innerText : ''));
      if (t && t.trim()) text += '\n' + t.trim();
    } catch (e) { /* frame went away */ }
  }
  return text;
}

async function probe(page) {
  const s = await page.evaluate(() => {
    const cb = document.querySelector('colab-connect-button');
    let button = '';
    try { button = cb && cb.shadowRoot ? cb.shadowRoot.textContent : (cb ? cb.textContent : ''); } catch (e) { button = ''; }
    const running = !!document.querySelector('.cell.running, colab-run-button[running]');
    return { button: (button || '').replace(/\s+/g, ' ').trim(), running };
  });
  const out = await outputsText(page);
  const title = (await page.title()).replace(/ - Colab$/, '');
  return {
    title,
    url: page.url().split('#')[0],
    connected: s.button !== '' && !isDisconnected(s.button),
    running: s.running,
    lastLine: out.trim().split('\n').filter(Boolean).slice(-1)[0] || '',
    sig: out.length + ':' + out.slice(-400),
  };
}

function pickOne(pages, states, match) {
  const hits = states.map((s, i) => [s, pages[i]]).filter(([s]) => s.title.includes(match));
  if (hits.length !== 1) {
    console.error(`"${match}" matches ${hits.length} Colab tabs; give a substring that matches exactly one:`);
    for (const s of states) console.error('  ' + s.title);
    process.exit(2);
  }
  return hits[0];
}

async function stop(page) {
  await page.bringToFront();
  let s = await probe(page);
  if (s.running) {
    // Interrupt first: the cell's try/finally then copies results and releases the runtime itself.
    await page.keyboard.press('ControlOrMeta+M');   // Colab's two-key shortcut for Interrupt execution: Ctrl+M, then i
    await page.keyboard.press('i');
    for (let i = 0; i < 12 && s.running; i++) { await page.waitForTimeout(5000); s = await probe(page); }
  }
  for (let i = 0; i < 6 && s.connected; i++) { await page.waitForTimeout(5000); s = await probe(page); }
  if (s.connected) {
    await page.keyboard.press('ControlOrMeta+Shift+P');
    await page.waitForTimeout(800);
    await page.keyboard.type('Disconnect and delete runtime');
    await page.waitForTimeout(800);
    await page.keyboard.press('Enter');
    await page.waitForTimeout(1500);
    const yes = page.getByRole('button', { name: /^(Yes|Disconnect|Delete)$/i });
    if (await yes.count()) await yes.first().click();
    for (let i = 0; i < 6 && s.connected; i++) { await page.waitForTimeout(5000); s = await probe(page); }
  }
  if (s.connected) throw new Error('still connected: ask the user to click Runtime > Disconnect and delete runtime');
  return s;
}

function parseFlags(argv) {
  const f = { idleMin: 10, quietMin: 15, pollS: 120 };
  for (let i = 0; i < argv.length; i += 2) {
    const v = Number(argv[i + 1]);
    if (argv[i] === '--idle-min') f.idleMin = v;
    else if (argv[i] === '--quiet-min') f.quietMin = v;
    else if (argv[i] === '--poll-s') f.pollS = v;
    else { console.error('unknown flag: ' + argv[i]); process.exit(2); }
  }
  return f;
}

async function watch(flags) {
  const stateFile = path.join(os.tmpdir(), `colab-browser-watch-${PORT}.json`);
  let state = {};
  try { state = JSON.parse(fs.readFileSync(stateFile, 'utf8')); } catch (e) { state = {}; }
  for (;;) {
    const now = Date.now();
    const browser = await connect();
    for (const page of colabPages(browser)) {
      let s;
      try { s = await probe(page); } catch (e) { continue; }
      const prev = state[s.url] || { sig: s.sig, sigAt: now, idleSince: null, wasRunning: false };
      if (s.sig !== prev.sig) { prev.sig = s.sig; prev.sigAt = now; }
      prev.idleSince = s.connected && !s.running ? (prev.idleSince || now) : null;
      const quietMin = (now - prev.sigAt) / 60000;
      const idleMin = prev.idleSince ? (now - prev.idleSince) / 60000 : 0;
      let event = null;
      if (prev.wasRunning && !s.connected) event = `RUNTIME_LOST ${s.title} (was running a cell, now disconnected)`;
      else if (s.connected && !s.running && idleMin > flags.idleMin) {
        try { await stop(page); event = `IDLE_STOPPED ${s.title} idle=${idleMin.toFixed(0)}min`; }
        catch (e) { event = `STOP_FAILED ${s.title} ${String(e.message || e).slice(0, 160)}`; }
      } else if (s.connected && s.running && quietMin > flags.quietMin && !prev.alerted) {
        prev.alerted = true;
        event = `QUIET_RUNNING ${s.title} quiet=${quietMin.toFixed(0)}min; check the job's own log before stopping it`;
      }
      if (quietMin <= flags.quietMin) prev.alerted = false;
      prev.wasRunning = s.connected && s.running;
      state[s.url] = prev;
      if (event) {
        fs.writeFileSync(stateFile, JSON.stringify(state));
        console.log(event);
        await browser.close();
        return;
      }
    }
    fs.writeFileSync(stateFile, JSON.stringify(state));
    await browser.close();
    await new Promise((r) => setTimeout(r, flags.pollS * 1000));
  }
}

async function main() {
  const [cmd, ...args] = process.argv.slice(2);
  if (!cmd || cmd === 'help' || cmd === '--help' || cmd === '-h') {
    const head = fs.readFileSync(__filename, 'utf8').split('\n').slice(1, 20).join('\n');
    console.log(head.replace(/^\/\/ ?/gm, ''));
    return;
  }
  if (cmd === 'watch') return watch(parseFlags(args));
  const browser = await connect();
  const pages = colabPages(browser);
  const states = [];
  for (const p of pages) states.push(await probe(p));
  if (cmd === 'status') {
    if (!states.length) console.log('no Colab tabs open');
    for (const s of states) {
      const rt = s.connected ? (s.running ? 'RUNNING' : 'CONNECTED, nothing running') : 'no runtime';
      console.log(`${s.title} | ${rt} | last output: ${s.lastLine.slice(0, 140)}`);
    }
  } else if (cmd === 'outputs') {
    const [, page] = pickOne(pages, states, args[0] || '');
    const text = await outputsText(page);
    console.log(text.slice(-Number(args[1] || 3000)));
  } else if (cmd === 'stop') {
    const [, page] = pickOne(pages, states, args[0] || '');
    try { const s = await stop(page); console.log(`stopped: ${s.title}`); }
    catch (e) { console.error(String(e.message || e)); await browser.close(); process.exit(1); }
  } else {
    console.error('unknown command: ' + cmd + ' (try: node colab.cjs help)');
    await browser.close();
    process.exit(2);
  }
  await browser.close();
}

if (require.main === module) main().catch((e) => { console.error(e); process.exit(1); });
module.exports = { isDisconnected, parseFlags };
