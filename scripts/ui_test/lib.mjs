import { chromium } from 'playwright-core';
import fs from 'node:fs';
import path from 'node:path';

export const SHOTS = path.resolve(path.dirname(new URL(import.meta.url).pathname), 'shots');
fs.mkdirSync(SHOTS, { recursive: true });

export async function launch({ width = 390, height = 844 } = {}) {
  const exe = process.env.CHROME_PATH || fs.readdirSync('/opt/pw-browsers').filter((d) => d.startsWith('chromium-')).map((d) => `/opt/pw-browsers/${d}/chrome-linux/chrome`)[0];
  const browser = await chromium.launch({ executablePath: exe, args: ['--no-sandbox', '--disable-gpu', '--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  const context = await browser.newContext({ viewport: { width, height }, deviceScaleFactor: 1, isMobile: true, hasTouch: true });
  const page = await context.newPage();
  const problems = [];
  page.on('console', (m) => { if (['error', 'warning'].includes(m.type())) problems.push(`[console.${m.type()}] ${m.text()}`); });
  page.on('pageerror', (e) => problems.push(`[pageerror] ${e.message}`));
  page.on('requestfailed', (r) => problems.push(`[requestfailed] ${r.url()} ${r.failure()?.errorText}`));
  return { browser, context, page, problems };
}

export async function open(page, url = 'http://localhost:8080/') {
  await page.goto(url);
  // Flutter draws to a canvas; its accessibility tree is what we can query.
  await page.waitForSelector('flt-semantics-placeholder', { state: 'attached', timeout: 60000 });
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  await page.waitForTimeout(1500);
}

export const shot = (page, name) => page.screenshot({ path: path.join(SHOTS, name + '.png') });

export const tree = (page) => page.evaluate(() => [...document.querySelectorAll('flt-semantics')]
  .map((e) => { const r = e.getAttribute('role'); const t = (e.getAttribute('aria-label') || e.textContent || '').trim().replace(/\s+/g, ' '); return t ? `${r || '-'}: ${t.slice(0, 600)}` : null; })
  .filter(Boolean).filter((v, i, a) => a.indexOf(v) === i));

export async function login(page, email = 'rina@example.com', password = 'rina-pass-123') {
  await page.getByRole('button', { name: 'Get Started' }).click();
  await page.waitForTimeout(800);
  await page.getByRole('textbox').nth(0).click(); await page.waitForTimeout(400);
  await page.keyboard.type(email);
  await page.getByRole('textbox').nth(1).click(); await page.waitForTimeout(400);
  await page.keyboard.type(password);
  await page.getByRole('button', { name: /^Sign in/ }).first().click();
  await page.waitForTimeout(2500);
}
