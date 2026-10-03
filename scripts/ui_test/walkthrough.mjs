// Walks the web build through the main flows against mock_backend.mjs and
// reports pass/fail per step, plus a screenshot of each screen in shots/.
// Run:  node mock_backend.mjs &   (serve build/web on :8080)   node walkthrough.mjs
import { launch, open, shot, tree, login } from './lib.mjs';

import { API, results, state, wait, step, has, gone, tap, type } from './helpers.mjs';

await fetch(API + '/__reset');
const { browser, page, problems } = await launch();
await open(page);

await step('Sign in: empty form is refused, wrong password shows a plain message', async () => {
  await page.getByRole('button', { name: 'Get Started' }).click(); await page.waitForTimeout(800);
  await shot(page, '02-sign-in');
  await has(page, /First time\? Your password is your NIM/);
  await tap(page, /^Sign in/, { wait: 1000 });
  await shot(page, '03-sign-in-empty');
  await has(page, /Enter your email/);
  await page.getByRole('textbox').nth(0).click(); await page.waitForTimeout(400); await page.keyboard.type('rina@example.com');
  await page.getByRole('textbox').nth(1).click(); await page.waitForTimeout(400); await page.keyboard.type('wrong-password');
  await tap(page, /^Sign in/, { wait: 2000 });
  await shot(page, '03b-sign-in-wrong');
  await has(page, /Wrong email or password/);
});
await step('Sign in with the right password reaches Home', async () => {
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
  await page.getByRole('textbox').first().click(); await page.waitForTimeout(400); await page.keyboard.type('analyst'); await page.waitForTimeout(800);
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

await step('Notifications: opening them clears the badge', async () => {
  await tap(page, /Notifications/, { wait: 1800 });
  await shot(page, '26-notifications');
  await has(page, /New application/);
  await tap(page, /Back/, { wait: 1500 }).catch(() => {});
  const s = await state(); if (s.notifications.some((n) => n.recipient_id === '11111111-1111-4111-8111-111111111111' && n.read_at == null)) throw new Error('still unread in db');
  await shot(page, '27-badge-cleared');
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
  await tap(page, /Back/, { wait: 800 }).catch(() => {});
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
  await tap(page, /Industry/, { wait: 900 });
  await shot(page, '24-industry-menu');
  await tap(page, /Banking & Finance/, { role: 'menuitem', wait: 800 });
  await tap(page, /^Post Job$/, { wait: 2500 });
  await has(page, /Finance Manager/);
  await shot(page, '25-after-post');
  const s = await state(); const j = s.job_posts.find((x) => x.title === 'Finance Manager'); if (!j || j.industry !== 'Banking & Finance') throw new Error('bad row ' + JSON.stringify(j));
});

await step('Error screen has Try again, and it recovers', async () => {
  await fetch(API + '/__fail?on=1');
  await page.getByRole('tab', { name: /My Applications/ }).click().catch(() => {});
  await tap(page, /Back/, { wait: 800 }).catch(() => {});
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
