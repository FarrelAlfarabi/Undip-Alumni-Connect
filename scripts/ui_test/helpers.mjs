import { tree, shot } from './lib.mjs';

export const API = 'http://localhost:54321';
export const results = [];
export const state = async () => (await fetch(API + '/__state')).json();
export const wait = (ms) => new Promise((r) => setTimeout(r, ms));

export async function step(name, fn) {
  try { await fn(); results.push(['PASS', name]); console.log('PASS', name); }
  catch (e) { results.push(['FAIL', name, String(e.message).split('\n')[0]]); console.log('FAIL', name, '-', String(e.message).split('\n')[0]); }
}
export const has = async (page, re, ms = 6000) => {
  const end = Date.now() + ms;
  while (Date.now() < end) { if ((await tree(page)).some((t) => re.test(t))) return; await page.waitForTimeout(250); }
  throw new Error('not on screen: ' + re + '\n' + (await tree(page)).slice(0, 25).join(' | '));
};
export const gone = async (page, re, ms = 4000) => {
  const end = Date.now() + ms;
  while (Date.now() < end) { if (!(await tree(page)).some((t) => re.test(t))) return; await page.waitForTimeout(250); }
  throw new Error('still on screen: ' + re);
};
// Click by role first; if the control has another role (chips, menu items),
// fall back to whatever accessibility node carries that label.
export const tap = async (page, name, opts = {}) => {
  const byRole = page.getByRole(opts.role || 'button', { name, exact: opts.exact ?? false }).first();
  try { await byRole.click({ timeout: 3000 }); }
  catch {
    const src = name instanceof RegExp ? name.source : String(name);
    const flags = name instanceof RegExp ? name.flags : '';
    const box = await page.evaluate(([src, flags]) => {
      const re = new RegExp(src, flags);
      const el = [...document.querySelectorAll('flt-semantics')].find((e) => re.test((e.getAttribute('aria-label') || e.textContent || '').trim()));
      if (!el) return null; const r = el.getBoundingClientRect(); return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
    }, [src, flags]);
    if (!box) throw new Error('nothing to tap: ' + name);
    await page.mouse.click(box.x, box.y);
  }
  await page.waitForTimeout(opts.wait ?? 900);
};
export const type = async (page, nth, text) => { const f = page.getByRole('textbox').nth(nth); await f.click(); await page.waitForTimeout(400); await page.keyboard.press('Control+A'); await page.keyboard.type(text); };

