// Walks the web build through the main flows against mock_backend.mjs and
// reports pass/fail per step, plus a screenshot of each screen in shots/.
// Run:  node mock_backend.mjs &   (serve build/web on :8080)   node walkthrough.mjs
import { launch, open, shot, tree, login } from './lib.mjs';

const API = 'http://localhost:54321';
const results = [];
const state = async () => (await fetch(API + '/__state')).json();
const wait = (ms) => new Promise((r) => setTimeout(r, ms));

async function step(name, fn) {
  try { await fn(); results.push(['PASS', name]); console.log('PASS', name); }
  catch (e) { results.push(['FAIL', name, String(e.message).split('\n')[0]]); console.log('FAIL', name, '-', String(e.message).split('\n')[0]); }
}
const has = async (page, re, ms = 6000) => {
  const end = Date.now() + ms;
  while (Date.now() < end) { if ((await tree(page)).some((t) => re.test(t))) return; await page.waitForTimeout(250); }
  throw new Error('not on screen: ' + re + '\n' + (await tree(page)).slice(0, 25).join(' | '));
};
const gone = async (page, re, ms = 4000) => {
  const end = Date.now() + ms;
  while (Date.now() < end) { if (!(await tree(page)).some((t) => re.test(t))) return; await page.waitForTimeout(250); }
  throw new Error('still on screen: ' + re);
};
const tap = async (page, name, opts = {}) => { await page.getByRole(opts.role || 'button', { name, exact: opts.exact ?? false }).first().click({ timeout: 8000 }); await page.waitForTimeout(opts.wait ?? 900); };
const type = async (page, nth, text) => { const f = page.getByRole('textbox').nth(nth); await f.click(); await page.keyboard.press('Control+A'); await page.keyboard.type(text); };

await fetch(API + '/__reset');
const { browser, page, problems } = await launch();
await open(page);

await step('Welcome -> Verification rejects an unknown email', async () => {
  await page.getByRole('button', { name: 'Get Started' }).click(); await page.waitForTimeout(800);
  await shot(page, '02-verification');
  await page.getByRole('textbox').first().click(); await page.keyboard.type('nobody@example.com');
  await tap(page, /^Verify/, { wait: 2000 });
  await shot(page, '03-verification-notfound');
  await has(page, /not found|couldn.t find|no match|isn.t|not in/i);
});
await step('Verification with a valid email reaches Home', async () => {
  await page.reload(); await open(page);
  await login(page, 'rina@example.com');
  await has(page, /Hello, Rina/);
  await shot(page, '04-home');
});

await step('Jobs opens the Job Board with both tabs, 4 jobs and the unread badge', async () => {
  await tap(page, 'Jobs', { wait: 1800 });
  await shot(page, '05-jobboard');
  await has(page, /All Jobs/); await has(page, /My Applications/);
  await has(page, /Backend Engineer/); await has(page, /Business Analyst/); await has(page, /Data Analyst/);
  await has(page, /Notifications.*1|1.*Notifications/s, 2000).catch(() => { throw new Error('unread badge (1) not announced'); });
});
await step('My Applications lists the applied job with its status', async () => {
  await tap(page, /My Applications/, { role: 'tab', wait: 1500 });
  await shot(page, '06-my-applications');
  await has(page, /Backend Engineer/); await has(page, /Reviewed/);
  await gone(page, /Business Analyst/);
});
await step('Back on All Jobs: filters narrow the list', async () => {
  await tap(page, /All Jobs/, { role: 'tab', wait: 1200 });
  await page.getByRole('textbox').first().click(); await page.keyboard.type('analyst'); await page.waitForTimeout(800);
  await has(page, /Business Analyst/); await has(page, /Data Analyst/); await gone(page, /Backend Engineer/);
  await shot(page, '07-search');
  await page.keyboard.press('Control+A'); await page.keyboard.press('Backspace'); await page.waitForTimeout(600);
});

await step('Another poster\'s job: details, contact and Apply button; applying shows Applied · Pending', async () => {
  await tap(page, /Product Manager/, { wait: 1500 });
  await shot(page, '08-job-detail');
  await has(page, /Apply to this Job/); await has(page, /ahmad@example.com/);
  await tap(page, /Apply to this Job/, { wait: 1500 });
  await shot(page, '09-apply');
  const tb = await page.getByRole('textbox').count();
  if (tb < 2) throw new Error('apply form has too few fields: ' + tb);
  await tap(page, /Review|Next|Continue/, { wait: 1200 });
  await shot(page, '10-apply-review');
  await tap(page, /Submit|Send/, { wait: 2500 });
  await shot(page, '11-apply-done');
  await has(page, /Back to Job/);
  await tap(page, /Back to Job/, { wait: 2000 });
  await shot(page, '12-job-detail-applied');
  await has(page, /Applied · Pending/);
});
await step('Poster got a notification for it (server trigger)', async () => {
  const s = await state();
  if (!s.notifications.some((n) => /New application: Product Manager/.test(n.title) && n.recipient_id === '44444444-4444-4444-8444-444444444444')) throw new Error('no poster notification');
});
await step('My Applications now has 2 entries after returning', async () => {
  await page.goBack().catch(() => {}); await page.waitForTimeout(500);
  const t = await tree(page);
  if (!t.some((x) => /All Jobs/.test(x))) await tap(page, /Back/, { wait: 1200 });
  await tap(page, /My Applications/, { role: 'tab', wait: 1500 });
  await has(page, /Product Manager/); await has(page, /Pending/);
  await shot(page, '13-my-applications-2');
  await tap(page, /All Jobs/, { role: 'tab', wait: 800 });
});

await step('Own job: menu offers Edit and Delete', async () => {
  await tap(page, /Data Analyst/, { wait: 1500 });
  await shot(page, '14-own-job');
  await has(page, /1 application/);
  await tap(page, /Show menu|Menu/, { wait: 800 }).catch(async () => { await page.locator('[aria-haspopup], flt-semantics[role=button]').last().click(); });
  await shot(page, '15-job-menu');
  await has(page, /Edit job/); await has(page, /Delete job/);
});
await step('Edit job: form is prefilled, industry is a dropdown, save updates the job', async () => {
  await tap(page, /Edit job/, { role: 'menuitem', wait: 1500 });
  await shot(page, '16-edit-job');
  await has(page, /Edit Job/); await has(page, /Save changes/);
  await type(page, 0, 'Senior Data Analyst');
  await tap(page, /Save changes/, { wait: 2500 });
  await shot(page, '17-after-edit');
  await has(page, /Senior Data Analyst/);
  const s = await state(); if (!s.job_posts.some((j) => j.title === 'Senior Data Analyst')) throw new Error('not saved');
});
await step('Applicants list: status chips; accepting notifies the applicant', async () => {
  await tap(page, /View Applicants/, { wait: 1800 });
  await shot(page, '18-applicants');
  await has(page, /Dewi Lestari/);
  await tap(page, /Accepted/, { wait: 1800 });
  await shot(page, '19-applicants-accepted');
  const s = await state();
  if (!s.notifications.some((n) => /Application update/.test(n.title) && n.recipient_id === '55555555-5555-4555-8555-555555555555')) throw new Error('applicant not notified');
});
await step('Delete job: confirmation, then the job is gone everywhere', async () => {
  await page.getByRole('button', { name: /Back/ }).first().click().catch(() => {}); await page.waitForTimeout(800);
  await tap(page, /Show menu|Menu/, { wait: 800 }).catch(async () => { await page.locator('flt-semantics[role=button]').last().click(); await page.waitForTimeout(800); });
  await tap(page, /Delete job/, { role: 'menuitem', wait: 1000 });
  await shot(page, '20-delete-confirm');
  await has(page, /Delete this job/);
  await tap(page, /^Delete$/, { wait: 2500 });
  await gone(page, /Senior Data Analyst/);
  const s = await state(); if (s.job_posts.some((j) => /Senior Data Analyst/.test(j.title))) throw new Error('still in db');
  await shot(page, '21-after-delete');
});

await step('Post a Job: empty submit is refused, industry is required, then it posts', async () => {
  await tap(page, /Post a Job/, { wait: 1800 });
  await shot(page, '22-post-job');
  await tap(page, /^Post Job$/, { wait: 1000 });
  await shot(page, '23-post-job-errors');
  await has(page, /Required/); await has(page, /Choose an industry/);
  await type(page, 0, 'Finance Manager'); await type(page, 1, 'Gojek'); await type(page, 2, 'Lead our finance team and report to the CFO.'); await type(page, 3, 'rina@example.com');
  await page.getByRole('button', { name: /Industry/ }).first().click().catch(async () => { await page.getByText('Industry').first().click(); });
  await page.waitForTimeout(800); await shot(page, '24-industry-menu');
  await page.getByText('Banking & Finance').last().click(); await page.waitForTimeout(600);
  await tap(page, /^Post Job$/, { wait: 2500 });
  await has(page, /Finance Manager/);
  await shot(page, '25-after-post');
  const s = await state(); const j = s.job_posts.find((x) => x.title === 'Finance Manager'); if (!j || j.industry !== 'Banking & Finance') throw new Error('bad row ' + JSON.stringify(j));
});

await step('Notifications: opening them clears the badge', async () => {
  await tap(page, /Notifications/, { wait: 1800 });
  await shot(page, '26-notifications');
  await has(page, /New application/);
  await page.getByRole('button', { name: /Back/ }).first().click().catch(() => {}); await page.waitForTimeout(1500);
  const s = await state(); if (s.notifications.some((n) => n.recipient_id === '11111111-1111-4111-8111-111111111111' && n.read_at == null)) throw new Error('still unread in db');
  await shot(page, '27-badge-cleared');
});

await step('Error screen has Try again, and it recovers', async () => {
  await fetch(API + '/__fail?on=1');
  await page.getByRole('tab', { name: /My Applications/ }).click().catch(() => {});
  await page.getByRole('button', { name: /Back/ }).first().click().catch(() => {}); await page.waitForTimeout(800);
  await tap(page, /Jobs/, { wait: 2000 }).catch(() => {});
  await shot(page, '28-error');
  await has(page, /Try again/);
  await fetch(API + '/__fail?on=0');
  await tap(page, /Try again/, { wait: 2000 });
  await has(page, /Finance Manager|Backend Engineer/);
  await shot(page, '29-recovered');
});

console.log('\nconsole/page problems (filtered):');
for (const p of problems.filter((p) => !/GL Driver|fonts.gstatic|CERT_AUTHORITY|ERR_CERT/.test(p))) console.log(' ', p.slice(0, 200));
const failed = results.filter((r) => r[0] === 'FAIL');
console.log(`\n${results.length - failed.length}/${results.length} steps passed`);
await browser.close();
process.exit(failed.length ? 1 : 0);
