#!/usr/bin/env node
// Drive the Google Colab tabs of a browser started by launch-browser.sh, over the DevTools protocol.
//
//   node colab.cjs status                     one line per Colab tab: runtime connected or not, a cell running or
//                                              not, and the last line the notebook printed
//   node colab.cjs outputs TAB [CHARS]         the tail of every output area of one tab (outputs live in iframes)
//   node colab.cjs stop TAB                    interrupt the running cell, then disconnect and delete the runtime,
//                                              and check that it is gone
//   node colab.cjs watch [--only TAB,...] [--ignore TAB,...] [--idle-min 10] [--quiet-min 15] [--poll-s 120]
//                                              poll the Colab tabs; print ONE event line and exit (run it in the
//                                              background and re-arm it after each event):
//                                                IDLE_STOPPED   a runtime sat connected with no cell running: it was stopped
//                                                STOP_FAILED    stopping an idle runtime failed: stop it by hand now
//                                                QUIET_RUNNING  a cell has run with no new output for --quiet-min minutes
//                                                RUNTIME_LOST   a runtime that was running a cell disconnected
//                                                IDLE_UNMANAGED an idle runtime in a tab this watch may not stop
//                                              It stops only --only tabs or, without --only, the notebooks named in
//                                              the permissions file; other tabs are only reported, --ignore ones skipped.
//                                              status takes --only and --ignore too.
//   node colab.cjs allowed KIND NOTEBOOK [--account EMAIL]
//                                              is there a standing grant from the user for this consent screen?
//                                              prints ALLOWED (exit 0) or NOT ALLOWED (exit 3); needs no browser
//   node colab.cjs logclick KIND NOTEBOOK [NOTE]
//                                              append a timestamped line to the clicks log
//   node colab.cjs consent TAB KIND [--dry-run]
//                                              click a granted consent screen for that tab's notebook, only if
//                                              it is on screen and matches exactly, and log the click; for
//                                              drive-desktop-oauth, go on through each screen of the sign-in window
//   node colab.cjs popups [--close]            the Google sign-in windows open, with the tab that opened each;
//                                              --close closes them all, but only while no tab is mounting Drive
//   node colab.cjs cli-signin [--dry-run]      sign the Colab CLI in: open its sign-in link in this browser, click
//                                              through the screens a colab-cli-signin grant covers, paste the code
//   node colab.cjs cli-drivemount SESSION [PATH] [--dry-run]
//                                              mount Google Drive on a CLI session: click the Drive-for-desktop
//                                              consent on the page this mount opened (drive-desktop-oauth grant
//                                              for colab-cli), then check the CLI printed "Mounted at"
//
// TAB is a substring of the tab title (e.g. the notebook's file name) that must match exactly one Colab tab.
// KIND is drive-mount, drive-desktop-oauth (Google's Drive-for-desktop sign-in window), or colab-secret:NAME.
// Environment: COLAB_CDP_PORT (default 9222); PLAYWRIGHT_CORE (path to a playwright-core install, optional);
// COLAB_PERMISSIONS (default ~/.config/colab-browser/permissions.json); COLAB_CLICKS_LOG (default: clicks.log
// next to it).
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

// ---- standing consent grants ------------------------------------------------------------------------------
// A grant is written only when the user asks, in their own words, and lives on this machine, never in a repo:
//   {"grants": [{"kinds": ["drive-mount"], "notebooks": ["train"], "account": "...", "granted": "2026-01-31",
//                "user_words": ["..."]}]}
// "notebooks" lists notebook names (with or without .ipynb), or "*" for any.
function permissionsPath() {
  return process.env.COLAB_PERMISSIONS || path.join(os.homedir(), '.config', 'colab-browser', 'permissions.json');
}
function clicksLogPath() {
  return process.env.COLAB_CLICKS_LOG || path.join(path.dirname(permissionsPath()), 'clicks.log');
}
const bareName = (n) => String(n || '').trim().replace(/\.ipynb$/i, '');
function readPermissions() {
  try { return JSON.parse(fs.readFileSync(permissionsPath(), 'utf8')); } catch (e) { return null; }
}
function findGrant(perms, kind, notebook, account) {
  for (const g of (perms && perms.grants) || []) {
    if (!(g.kinds || []).includes(kind)) continue;
    const nbs = (g.notebooks || []).map(bareName);
    if (!(nbs.includes('*') || nbs.includes(bareName(notebook)))) continue;
    if (account && g.account && g.account.toLowerCase() !== String(account).toLowerCase()) continue;
    return g;
  }
  return null;
}
function logClick(kind, notebook, note) {
  const line = `${new Date().toISOString()} ${kind} ${bareName(notebook)}${note ? ' ' + note : ''}`;
  fs.mkdirSync(path.dirname(clicksLogPath()), { recursive: true });
  fs.appendFileSync(clicksLogPath(), line + '\n');
  return line;
}

// The screens a grant can cover. A screen matches when all its `needs` texts are on it, none of the NEVER texts
// are, no box on it is left unticked, and exactly one button has its label. Sign-in, account choosers, 2-step
// verification and licences are never covered, whatever a grant says.
const NEVER = [/choose an account/i, /enter your password/i, /2-step verification/i, /verify it.?s you/i, /agree and access/i];
const SCREENS = {
  'drive-mount': { where: 'tab', needs: [/access your Google Drive files/i], button: 'Connect to Google Drive' },
  // Google's Drive-for-desktop window shows one or both of these screens, each with Continue: "You're signing
  // back in to Google Drive for desktop", then "Google Drive for desktop wants access to your Google Account".
  'drive-desktop-oauth': {
    where: 'popup',
    needs: [/Google Drive for desktop/i, /signing back in|wants access to your Google Account/i],
    button: 'Continue',
  },
};
function screenFor(kind) {
  if (SCREENS[kind]) return SCREENS[kind];
  const m = /^colab-secret:([A-Za-z0-9_]+)$/.exec(kind || '');
  return m ? { where: 'tab', needs: [new RegExp('\\b' + m[1] + '\\b'), /secret/i], button: 'Grant access' } : null;
}
function matchConsent(kind, screen, account) {
  const spec = screenFor(kind);
  if (!spec) return { ok: false, reason: `unknown kind ${kind}` };
  const text = screen.text || '';
  for (const r of NEVER) if (r.test(text)) return { ok: false, reason: `a screen no grant covers (${r.source})` };
  for (const r of spec.needs) if (!r.test(text)) return { ok: false, reason: `not the ${kind} screen (no ${r.source})` };
  if (screen.unchecked) return { ok: false, reason: `the screen asks which access to give (${screen.unchecked} unticked boxes)` };
  const emails = (text.match(/[\w.+-]+@[\w-]+(\.[\w-]+)+/g) || []).map((e) => e.toLowerCase());
  if (account && emails.length && !emails.includes(account.toLowerCase())) {
    return { ok: false, reason: 'the screen shows a different account than the grant' };
  }
  if (screen.count !== 1) return { ok: false, reason: `expected one "${spec.button}" button, found ${screen.count}` };
  return { ok: true, button: spec.button, where: spec.where };
}

// The Colab CLI's own sign-in (kind colab-cli-signin), seen in the automation browser: an account chooser,
// "You're signing back in to Google Auth Library", "Google Auth Library wants access to your Google Account",
// then Google's page with the code to paste into the CLI. The chooser is covered here only, and only when it
// offers exactly one account (the grant's, if it names one). Password and 2-step pages are never covered.
const CLI_CODE_PAGE = 'https://sdk.cloud.google.com/applicationdefaultauthcode.html';
const CLI_APP = /Google Auth Library/;
function matchCliSignin(screen, account) {
  const text = screen.text || '';
  if (String(screen.url || '').startsWith(CLI_CODE_PAGE)) {
    const m = /\b4\/0[A-Za-z0-9_-]{20,}/.exec(text);
    return m ? { ok: true, action: 'code', code: m[0] } : { ok: false, reason: 'the code page shows no code' };
  }
  for (const r of NEVER.filter((x) => !/choose/.test(x.source))) if (r.test(text)) return { ok: false, reason: `a screen no grant covers (${r.source})` };
  if (!CLI_APP.test(text)) return { ok: false, reason: 'not the Colab CLI sign-in (no "Google Auth Library")' };
  if (/choose an account/i.test(text)) {
    const ids = (screen.tiles || []).map((t) => String(t).toLowerCase());
    if (ids.length !== 1) return { ok: false, reason: `the chooser offers ${ids.length} accounts, not exactly one` };
    if (account && ids[0] !== account.toLowerCase()) return { ok: false, reason: 'the chooser offers a different account than the grant' };
    return { ok: true, action: 'tile' };
  }
  if (!/signing back in to Google Auth Library|Google Auth Library wants access to your Google Account/.test(text)) {
    return { ok: false, reason: 'an unknown screen of the sign-in' };
  }
  if (screen.unchecked) return { ok: false, reason: `the screen asks which access to give (${screen.unchecked} unticked boxes)` };
  const emails = (text.match(/[\w.+-]+@[\w-]+(\.[\w-]+)+/g) || []).map((e) => e.toLowerCase());
  if (account && emails.length && !emails.includes(account.toLowerCase())) {
    return { ok: false, reason: 'the screen shows a different account than the grant' };
  }
  if (screen.count !== 1) return { ok: false, reason: `expected one "Continue" button, found ${screen.count}` };
  return { ok: true, action: 'button', button: 'Continue' };
}

// Sign the Colab CLI in: run `colab sessions`, open the link it prints in the automation browser (never the
// user's own browser), click through the screens matchCliSignin allows, and paste the code into the CLI.
async function cliSignin(dry) {
  const grant = findGrant(readPermissions(), 'colab-cli-signin', 'colab-cli');
  if (!grant) { console.log('NOT ALLOWED colab-cli-signin: no standing grant; ask the user to sign the CLI in'); return 3; }
  const { spawn } = require('child_process');
  const child = spawn(process.env.COLAB_BIN || 'colab', ['sessions'], { env: { ...process.env, BROWSER: 'true' } });
  let out = '';
  child.stdout.on('data', (d) => { out += d; });
  child.stderr.on('data', (d) => { out += d; });
  const exited = new Promise((r) => child.on('close', r));
  const url = await new Promise((resolve) => {
    const t = setInterval(() => {
      const m = /https:\/\/accounts\.google\.com\/o\/oauth2\/auth\S+/.exec(out);
      if (m) { clearInterval(t); resolve(m[0]); }
    }, 300);
    exited.then(() => { clearInterval(t); resolve(null); });
    setTimeout(() => { clearInterval(t); resolve(null); }, 60000);
  });
  if (!url) {
    if (child.exitCode === 0) { console.log('already signed in: colab sessions ran without asking'); return 0; }
    child.kill();
    console.log('NOT DONE: the CLI printed no sign-in link; its output:\n' + out.slice(-500));
    return 4;
  }
  const browser = await connect();
  const page = await browser.contexts()[0].newPage();
  const giveUp = async (why) => {
    child.kill();
    console.log(`NOT DONE: ${why}. The sign-in page is left open in the automation browser; ask the user to finish`
      + ' it there and paste the code, or to run  colab sessions  in their own terminal');
    await browser.close();
    return 4;
  };
  await page.goto(url);
  for (let step = 0; step < 6; step++) {
    await page.waitForTimeout(3000);
    const screen = await readScreen(page, 'Continue');
    screen.url = page.url();
    screen.tiles = await page.evaluate(() => [...document.querySelectorAll('[data-identifier]')]
      .map((e) => e.getAttribute('data-identifier')));
    screen.unchecked = await uncheckedBoxes(page);
    const m = matchCliSignin(screen, grant.account);
    if (!m.ok) return giveUp(m.reason);
    if (dry) {
      console.log(`would ${m.action === 'tile' ? 'choose the one account offered' : m.action === 'code' ? 'paste the code' : 'click "Continue"'}`);
      child.kill();
      await page.close();
      await browser.close();
      return 0;
    }
    if (m.action === 'code') {
      child.stdin.write(m.code + '\n');
      await page.close();
      const rc = await Promise.race([exited, new Promise((r) => setTimeout(() => r('timeout'), 60000))]);
      await browser.close();
      if (rc !== 0) { child.kill(); console.log(`NOT DONE: the CLI did not accept the code (exit ${rc}):\n${out.slice(-300)}`); return 4; }
      console.log(logClick('colab-cli-signin', 'colab-cli', `signed in (grant of ${grant.granted || 'unknown date'})`));
      return 0;
    }
    if (m.action === 'tile') await page.locator('[data-identifier]').first().click();
    else await page.getByRole('button', { name: 'Continue', exact: true }).click();
    console.log(logClick('colab-cli-signin', 'colab-cli', m.action === 'tile' ? 'chose the one account offered' : 'clicked "Continue"'));
  }
  return giveUp('still not at the code page after 6 screens');
}

// Mount Google Drive on a CLI session: run `colab drivemount`, open the consent link it prints in a new page of
// the automation browser, click through the Drive-for-desktop screens on THAT page only (never another
// notebook's window), then tell the CLI to go on. drivemount exits 0 even when the mount fails, so success is
// "Mounted at" in its output. Needs a drive-desktop-oauth grant for the notebook name colab-cli.
async function cliDrivemount(name, mountPath, dry) {
  const grant = findGrant(readPermissions(), 'drive-desktop-oauth', 'colab-cli');
  if (!grant) { console.log('NOT ALLOWED drive-desktop-oauth colab-cli: no standing grant; ask the user'); return 3; }
  const { spawn } = require('child_process');
  // detached: no controlling terminal, so the CLI reads the go-ahead from stdin instead of /dev/tty.
  const child = spawn(process.env.COLAB_BIN || 'colab', ['drivemount', '-s', name, ...(mountPath ? [mountPath] : [])],
    { env: { ...process.env, BROWSER: 'true' }, detached: true });
  let out = '';
  child.stdout.on('data', (d) => { out += d; });
  child.stderr.on('data', (d) => { out += d; });
  const exited = new Promise((r) => child.on('close', r));
  const mounted = () => /Mounted at \S+/.test(out);
  const url = await new Promise((resolve) => {
    const t = setInterval(() => {
      const m = /https:\/\/accounts\.google\.com\/o\/oauth2\/v2\/auth\S+/.exec(out);
      if (m) { clearInterval(t); resolve(m[0]); }
    }, 300);
    exited.then(() => { clearInterval(t); resolve(null); });
    setTimeout(() => { clearInterval(t); resolve(null); }, 120000);
  });
  if (!url) {
    child.kill();
    if (mounted()) { console.log(`MOUNTED: ${/Mounted at \S+/.exec(out)[0]} (no consent was needed)`); return 0; }
    console.log('NOT MOUNTED: the CLI printed no consent link; its output:\n' + out.slice(-600));
    return 4;
  }
  const browser = await connect();
  const page = await browser.contexts()[0].newPage();
  await page.goto(url);
  let clicks = 0;
  for (let step = 0; step < 4; step++) {
    await page.waitForTimeout(4000);
    if (page.isClosed() || !page.url().startsWith('https://accounts.google.com/')) break;  // consent done
    const screen = await readScreen(page, 'Continue');
    screen.unchecked = await uncheckedBoxes(page);
    const m = matchConsent('drive-desktop-oauth', screen, grant.account);
    if (!m.ok) {
      child.kill();
      console.log(`NOT MOUNTED: ${m.reason}. The consent page is left open in the automation browser for the user`);
      await browser.close();
      return 4;
    }
    if (dry) {
      console.log('would click "Continue" on the Drive consent page this mount opened');
      child.kill(); await page.close(); await browser.close();
      return 0;
    }
    await scrollToEnd(page);
    await page.getByRole('button', { name: 'Continue', exact: true }).click({ timeout: 15000 }).catch((e) => {
      if (!page.isClosed()) throw e;
    });
    clicks++;
    console.log(logClick('drive-desktop-oauth', 'colab-cli', `clicked "Continue" for session ${name}${clicks > 1 ? ` on screen ${clicks}` : ''} (grant of ${grant.granted || 'unknown date'})`));
  }
  if (!page.isClosed()) await page.close();
  await browser.close();
  child.stdin.write('\n');
  await Promise.race([exited, new Promise((r) => setTimeout(r, 180000))]);
  if (mounted()) { console.log(`MOUNTED: ${/Mounted at \S+/.exec(out)[0]}`); return 0; }
  child.kill();
  console.log('NOT MOUNTED: ' + out.replace(/https:\S+/g, '<link>').slice(-600));
  return 4;
}

async function readScreen(page, button) {
  // All text, including inside open shadow roots, where Colab's dialogs live.
  const text = await page.evaluate(() => {
    let out = '';
    const walk = (n) => {
      if (n.shadowRoot) walk(n.shadowRoot);
      for (const c of n.childNodes) {
        if (c.nodeType === 3) out += c.textContent + ' ';
        else if (c.nodeType === 1 && !['SCRIPT', 'STYLE'].includes(c.tagName)) walk(c);
      }
    };
    if (document.body) walk(document.body);
    return out.replace(/\s+/g, ' ');
  });
  const count = await page.getByRole('button', { name: button, exact: true }).count();
  return { text, count };
}

async function cdpTargetId(page) {
  const s = await page.context().newCDPSession(page);
  try { return (await s.send('Target.getTargetInfo')).targetInfo.targetId; } finally { await s.detach().catch(() => {}); }
}

// Every Google sign-in window, with the tab that opened it. Chrome records the opener itself
// (Target.getTargets); Playwright's opener() misses it when it attached the window before its opener.
async function signInWindows(browser) {
  const s = await browser.newBrowserCDPSession();
  const { targetInfos } = await s.send('Target.getTargets');
  await s.detach().catch(() => {});
  const openerOf = new Map(targetInfos.map((t) => [t.targetId, t.openerId || '']));
  const wins = [];
  for (const ctx of browser.contexts()) for (const p of ctx.pages()) {
    if (!p.url().startsWith('https://accounts.google.com/')) continue;
    const id = await cdpTargetId(p).catch(() => '');
    const pw = await p.opener().catch(() => null);
    const born = await p.evaluate(() => performance.timeOrigin).catch(() => 0);
    wins.push({ page: p, openerId: openerOf.get(id) || '', openerUrl: pw ? pw.url().split('#')[0] : '', born });
  }
  return wins;
}

const mountingNow = (page) => page.evaluate(() => {
  const c = document.querySelector('.cell.running');
  return !!c && /drive\.mount\(/.test(c.innerText);
}).catch(() => false);

const uncheckedBoxes = (page) => page.evaluate(() => [...document.querySelectorAll('input[type=checkbox], [role=checkbox]')]
  .filter((e) => e.offsetParent !== null && (e.type === 'checkbox' ? !e.checked : e.getAttribute('aria-checked') !== 'true')).length);

async function scrollToEnd(page) {
  await page.evaluate(() => {
    for (const el of [document.scrollingElement, ...document.querySelectorAll('*')]) {
      if (el && el.scrollHeight > el.clientHeight + 4) el.scrollTop = el.scrollHeight;
    }
  }).catch(() => {});
  await page.waitForTimeout(500);
}

// After a click in a sign-in window: 'closed', 'changed' (a new screen, the same in two reads a second
// apart), or 'unchanged' after ms.
async function nextScreen(page, before, button, ms) {
  let last = null;
  for (const end = Date.now() + ms; Date.now() < end;) {
    await new Promise((r) => setTimeout(r, 1000));
    if (page.isClosed()) return 'closed';
    const t = await readScreen(page, button).then((s) => s.text).catch(() => null);
    if (t !== null && t !== before && t === last) return 'changed';
    last = t;
  }
  return page.isClosed() ? 'closed' : 'unchanged';
}

async function consent(browser, page, notebook, kind, dry) {
  const grant = findGrant(readPermissions(), kind, notebook);
  if (!grant) { console.log(`NOT ALLOWED ${kind} ${notebook}: no standing grant; ask the user`); return 3; }
  const spec = screenFor(kind);
  const st = await probe(page);       // consent screens appear while a cell runs on an attached runtime
  if (!st.connected) { console.log('NOT CLICKED: this tab has no runtime'); return 4; }
  if (!st.running) { console.log('NOT CLICKED: no cell is running in this tab, so nothing is waiting on a consent screen'); return 4; }
  let target = page;
  if (spec.where === 'popup') {
    // The sign-in window must belong to this tab, and this tab must be mounting Drive right now: another
    // notebook's window, or one left over from an earlier attempt, is not covered by this tab's grant.
    if (!(await mountingNow(page))) { console.log('NOT CLICKED: this tab is not running a drive.mount cell now; the window is stale'); return 4; }
    const tabId = await cdpTargetId(page);
    const tabUrl = page.url().split('#')[0];
    const wins = await signInWindows(browser);
    let mine = wins.filter((w) => w.openerId === tabId || w.openerUrl === tabUrl);
    if (!mine.length && wins.length === 1 && !wins[0].openerId && !wins[0].openerUrl) {
      // Chrome kept no opener for the only sign-in window. It is this tab's if no other tab is mounting Drive.
      let others = 0;
      for (const p of colabPages(browser)) if (p !== page && await mountingNow(p)) others++;
      if (!others) { mine = wins; console.log('note: the only sign-in window has no recorded opener, and only this tab is mounting Drive'); }
    }
    if (!mine.length) {
      console.log(`NOT CLICKED: no Google sign-in window from this tab yet (${wins.length} open in all); try again in a few seconds`);
      return 4;
    }
    mine.sort((a, b) => b.born - a.born);
    if (mine.length > 1) console.log(`note: using the newest of ${mine.length} sign-in windows from this tab; close the rest with  colab.cjs popups --close  once no mount is running`);
    target = mine[0].page;
  }
  for (let clicks = 0; ;) {
    const screen = await readScreen(target, spec.button);
    if (spec.where === 'popup') screen.unchecked = await uncheckedBoxes(target);
    const m = matchConsent(kind, screen, grant.account);
    if (!m.ok && clicks) {
      // Not one of this kind's screens any more, after our clicks: say what is there and let the caller check the cell.
      console.log(`clicked ${clicks} screen(s); the window now shows: ${screen.text.trim().slice(0, 160)}`);
      console.log('check that the drive.mount cell printed "Mounted at"; if not, ask the user to look at the window');
      return 0;
    }
    if (!m.ok) { console.log(`NOT CLICKED: ${m.reason}`); return 4; }
    if (dry) { console.log(`would click "${m.button}" for ${kind} in ${notebook}`); return 0; }
    if (spec.where === 'popup') await scrollToEnd(target);
    try {
      await target.getByRole('button', { name: m.button, exact: true }).click({ timeout: 15000 });
    } catch (e) {
      if (!target.isClosed()) throw e;   // the window closed as it was clicked: the click went through
    }
    clicks++;
    console.log(logClick(kind, notebook, `clicked "${m.button}"${clicks > 1 ? ` on screen ${clicks}` : ''} (grant of ${grant.granted || 'unknown date'})`));
    if (spec.where !== 'popup') return 0;
    // Google can ask again in the same window ("... wants access to your Google Account"): go on through it.
    const next = await nextScreen(target, screen.text, spec.button, 20000);
    if (next === 'closed') { console.log('the sign-in window closed: sign-in done'); return 0; }
    if (next === 'unchanged') { console.log('NOT DONE: the window shows the same screen 20 s after the click; ask the user to look'); return 4; }
    if (clicks >= 3) { console.log('NOT DONE: the window is still open after 3 screens; ask the user to look'); return 4; }
  }
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

const splitList = (v) => String(v || '').split(',').map((t) => t.trim()).filter(Boolean);

function parseFlags(argv) {
  const f = { idleMin: 10, quietMin: 15, pollS: 120, only: [], ignore: [] };
  for (let i = 0; i < argv.length; i += 2) {
    const k = argv[i], v = argv[i + 1];
    if (k === '--idle-min') f.idleMin = Number(v);
    else if (k === '--quiet-min') f.quietMin = Number(v);
    else if (k === '--poll-s') f.pollS = Number(v);
    else if (k === '--only') f.only = splitList(v);
    else if (k === '--ignore') f.ignore = splitList(v);
    else { console.error('unknown flag: ' + k); process.exit(2); }
  }
  return f;
}

// The browser may hold other projects' notebooks. 'manage': the watch may stop the tab's idle runtime;
// 'warn': report it, never stop it; 'ignore': skip the tab. Without --only, the notebooks named in the
// permissions file (not "*") are this project's.
function tabPolicy(title, flags, perms) {
  const name = bareName(title);
  const hit = (list) => list.some((t) => name.includes(bareName(t)));
  if (flags.ignore.length && hit(flags.ignore)) return 'ignore';
  if (flags.only.length) return hit(flags.only) ? 'manage' : 'ignore';
  const mine = new Set(((perms && perms.grants) || []).flatMap((g) => (g.notebooks || []).map(bareName)));
  mine.delete('*');
  return mine.has(name) ? 'manage' : 'warn';
}

async function watch(flags) {
  const stateFile = path.join(os.tmpdir(), `colab-browser-watch-${PORT}.json`);
  let state = {};
  try { state = JSON.parse(fs.readFileSync(stateFile, 'utf8')); } catch (e) { state = {}; }
  for (;;) {
    const now = Date.now();
    const browser = await connect();
    const perms = readPermissions();
    for (const page of colabPages(browser)) {
      let s;
      try { s = await probe(page); } catch (e) { continue; }
      const policy = tabPolicy(s.title, flags, perms);
      if (policy === 'ignore') continue;
      const prev = state[s.url] || { sig: s.sig, sigAt: now, idleSince: null, wasRunning: false };
      if (s.sig !== prev.sig) { prev.sig = s.sig; prev.sigAt = now; }
      prev.idleSince = s.connected && !s.running ? (prev.idleSince || now) : null;
      const quietMin = (now - prev.sigAt) / 60000;
      const idleMin = prev.idleSince ? (now - prev.idleSince) / 60000 : 0;
      let event = null;
      if (!(s.connected && !s.running)) prev.warned = false;
      if (policy === 'warn') {
        if (s.connected && !s.running && idleMin > flags.idleMin && !prev.warned) {
          prev.warned = true;
          event = `IDLE_UNMANAGED ${s.title} idle=${idleMin.toFixed(0)}min (not stopped: not one of this watch's notebooks)`;
        }
      } else if (prev.wasRunning && !s.connected) event = `RUNTIME_LOST ${s.title} (was running a cell, now disconnected)`;
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
    const lines = fs.readFileSync(__filename, 'utf8').split('\n').slice(1);
    const head = lines.slice(0, lines.findIndex((l) => !l.startsWith('//')));
    console.log(head.map((l) => l.replace(/^\/\/ ?/, '')).join('\n'));
    return;
  }
  if (cmd === 'watch') return watch(parseFlags(args));
  if (cmd === 'allowed') {
    const [kind, notebook, flag, account] = args;
    if (!kind || !notebook) { console.error('usage: node colab.cjs allowed KIND NOTEBOOK [--account EMAIL]'); process.exit(2); }
    const g = findGrant(readPermissions(), kind, notebook, flag === '--account' ? account : undefined);
    if (g) { console.log(`ALLOWED ${kind} ${bareName(notebook)} (granted ${g.granted || 'unknown date'})`); return; }
    console.log(`NOT ALLOWED ${kind} ${bareName(notebook)}: no standing grant in ${permissionsPath()}; ask the user`);
    process.exit(3);
  }
  if (cmd === 'logclick') {
    const [kind, notebook, ...note] = args;
    if (!kind || !notebook) { console.error('usage: node colab.cjs logclick KIND NOTEBOOK [NOTE]'); process.exit(2); }
    console.log(logClick(kind, notebook, note.join(' ')));
    return;
  }
  if (cmd === 'cli-signin') process.exit(await cliSignin(args[0] === '--dry-run'));
  if (cmd === 'cli-drivemount') {
    const pos = args.filter((a) => a !== '--dry-run');
    if (!pos[0]) { console.error('usage: node colab.cjs cli-drivemount SESSION [PATH] [--dry-run]'); process.exit(2); }
    process.exit(await cliDrivemount(pos[0], pos[1], args.includes('--dry-run')));
  }
  const browser = await connect();
  const pages = colabPages(browser);
  const states = [];
  for (const p of pages) states.push(await probe(p));
  if (cmd === 'status') {
    const flags = parseFlags(args);
    const shown = states.filter((s) => tabPolicy(s.title, flags, readPermissions()) !== 'ignore' || !flags.only.length && !flags.ignore.length);
    if (!shown.length) console.log('no Colab tabs open');
    for (const s of shown) {
      const rt = s.connected ? (s.running ? 'RUNNING' : 'CONNECTED, nothing running') : 'no runtime';
      console.log(`${s.title} | ${rt} | last output: ${s.lastLine.slice(0, 140)}`);
    }
  } else if (cmd === 'outputs') {
    const [, page] = pickOne(pages, states, args[0] || '');
    const text = await outputsText(page);
    console.log(text.slice(-Number(args[1] || 3000)));
  } else if (cmd === 'consent') {
    const [match, kind, flag] = args;
    if (!match || !kind || !screenFor(kind)) {
      console.error('usage: node colab.cjs consent TAB KIND [--dry-run]   (KIND: drive-mount, drive-desktop-oauth, colab-secret:NAME)');
      await browser.close();
      process.exit(2);
    }
    const [st, page] = pickOne(pages, states, match);
    const rc = await consent(browser, page, bareName(st.title), kind, flag === '--dry-run');
    await browser.close();
    process.exit(rc);
  } else if (cmd === 'popups') {
    const wins = await signInWindows(browser);
    const tabOf = new Map();
    for (const p of pages) tabOf.set(await cdpTargetId(p).catch(() => ''), p);
    if (!wins.length) console.log('no Google sign-in windows open');
    for (const w of wins) {
      const opener = tabOf.get(w.openerId) || pages.find((p) => p.url().split('#')[0] === w.openerUrl);
      const text = await readScreen(w.page, 'Continue').then((s) => s.text.trim()).catch(() => '');
      console.log(`${opener ? (await opener.title()).replace(/ - Colab$/, '') : 'opener unknown'} | ${text.slice(0, 120)}`);
    }
    if (args[0] === '--close' && wins.length) {
      let mounting = 0;
      for (const p of pages) if (await mountingNow(p)) mounting++;
      if (mounting) console.log(`NOT CLOSED: ${mounting} tab(s) are mounting Drive now; close them once no mount is running`);
      else {
        for (const w of wins) await w.page.close().catch(() => {});
        console.log(`closed ${wins.length} sign-in window(s)`);
      }
    }
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
module.exports = { isDisconnected, parseFlags, findGrant, matchConsent, matchCliSignin, screenFor, bareName, tabPolicy };
