import { launch, open, shot } from './lib.mjs';
const { browser, page, problems } = await launch();
await open(page);
await page.waitForTimeout(2000);
await shot(page, '00-welcome');
const tree = await page.evaluate(() => [...document.querySelectorAll('flt-semantics')].map((e) => (e.getAttribute('role') || '') + ':' + (e.getAttribute('aria-label') || e.textContent || '').trim().slice(0, 60)).filter((s) => s.length > 1).slice(0, 30));
console.log(tree.join('\n'));
console.log('problems:', problems.slice(0, 10));
await browser.close();
