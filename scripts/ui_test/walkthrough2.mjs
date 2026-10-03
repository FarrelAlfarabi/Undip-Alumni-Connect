// Second walk-through: first-time password prompt, forgot password, directory,
// chat (incl. live new messages), profile + sign out, marketplace city
// picker, nearby alumni, announcements, and small phone sizes.
import { launch, open, shot, tree, login } from './lib.mjs';
import { API, results, state, wait, step, has, gone, tap, type } from './helpers.mjs';

const REZA = '22222222-2222-4222-8222-222222222222';
const RINA = '11111111-1111-4111-8111-111111111111';
const post = (path, body) => fetch(API + path, { method: 'POST', headers: { 'Content-Type': 'application/json', Prefer: 'return=minimal' }, body: JSON.stringify(body) });

await fetch(API + '/__reset');

// ---------- A: first-time sign-in with the NIM -------------------------------
{
  const { browser, page, problems } = await launch();
  await open(page);
  await step('First sign-in with the NIM offers a new password and can be skipped', async () => {
    await login(page, 'reza.putra@example.com', 'NIM2222222222');
    await shot(page, '30-set-password');
    await has(page, /Choose your password/); await has(page, /Not now/);
    await tap(page, /Not now/, { wait: 1800 });
    await has(page, /Hello, Reza/);
    const s = await state(); if (s.alumni_profiles.find((p) => p.id === REZA).password_set) throw new Error('password_set should stay false');
  });
  await page.reload(); await open(page);
  const fillTwo = async (a, b) => {
    await page.getByRole('textbox').nth(0).click(); await page.waitForTimeout(400); await page.keyboard.type(a);
    await page.getByRole('textbox').nth(1).click(); await page.waitForTimeout(400); await page.keyboard.type(b);
    await tap(page, /Save password/, { wait: 1800 });
  };
  const toPrompt = async () => { await page.reload(); await open(page); await login(page, 'reza.putra@example.com', 'NIM2222222222'); await has(page, /Choose your password/); };
  await step('Asked again next time; a short password is refused', async () => {
    await toPrompt(); await fillTwo('short', 'short');
    await shot(page, '31-set-password-short'); await has(page, /at least 8/);
  });
  await step('A mismatched repeat is refused', async () => {
    await toPrompt(); await fillTwo('a-good-password', 'different-one');
    await has(page, /passwords don.t match/);
  });
  await step('A password equal to the NIM is refused', async () => {
    await toPrompt(); await fillTwo('NIM2222222222', 'NIM2222222222');
    await has(page, /different from your NIM/);
  });
  await step('A good new password is saved and signs them in', async () => {
    await toPrompt(); await fillTwo('a-good-password', 'a-good-password');
    await has(page, /Hello, Reza/);
    const s = await state(); if (!s.alumni_profiles.find((p) => p.id === REZA).password_set) throw new Error('password_set not saved');
  });
  await step('The old NIM password no longer works; the new one does', async () => {
    await page.reload(); await open(page);
    await login(page, 'reza.putra@example.com', 'NIM2222222222');
    await has(page, /Wrong email or password/);
    await page.getByRole('textbox').nth(1).click(); await page.keyboard.press('Control+A'); await page.keyboard.type('a-good-password');
    await tap(page, /^Sign in/, { wait: 2000 });
    await has(page, /Hello, Reza/);
    await shot(page, '32-home-reza');
  });
  await step('Profile tab shows the profile; Sign out returns to Welcome', async () => {
    await tap(page, /Profile/, { role: 'tab', wait: 1500 });
    await shot(page, '33-profile');
    await has(page, /Reza Pratama Putra/);
    await tap(page, /Sign out/, { wait: 1800 });
    await shot(page, '34-after-signout');
    await has(page, /Sign in/);
  });
  await browser.close();
}

// ---------- B: forgot password ------------------------------------------------
{
  const { browser, page } = await launch();
  await open(page);
  await step('Forgot password: code, new password, signed in', async () => {
    await page.getByRole('button', { name: 'Get Started' }).click(); await page.waitForTimeout(800);
    await tap(page, /Forgot password/, { wait: 900 });
    await shot(page, '35-forgot');
    await page.getByRole('textbox').first().click(); await page.waitForTimeout(400); await page.keyboard.type('siti@example.com');
    await tap(page, /Send code/, { wait: 1500 });
    await shot(page, '36-reset');
    await has(page, /we sent a code/i);
    await page.getByRole('textbox').nth(0).click(); await page.waitForTimeout(400); await page.keyboard.type('000000');
    await page.getByRole('textbox').nth(1).click(); await page.waitForTimeout(400); await page.keyboard.type('brand-new-pass');
    await tap(page, /Save and sign in/, { wait: 1800 });
    await has(page, /wrong or has expired/i);
    await page.getByRole('textbox').nth(0).click(); await page.keyboard.press('Control+A'); await page.keyboard.type('123456');
    await tap(page, /Save and sign in/, { wait: 2500 });
    await has(page, /Hello, Siti/);
  });
  await browser.close();
}

// ---------- C: the rest of the app as Rina -----------------------------------
{
  const { browser, page, problems } = await launch();
  await open(page);
  await login(page, 'rina@example.com', 'rina-pass-123');
  await has(page, /Hello, Rina/);

  await step('Directory tab: list, search narrows it, profile opens', async () => {
    await tap(page, /Directory/, { role: 'tab', wait: 1800 });
    await shot(page, '40-directory');
    await has(page, /Dewi Lestari/); await has(page, /Reza Pratama Putra/);
    await gone(page, /Budi Santoso/); // unverified people are not listed
    await page.getByRole('textbox').first().click(); await page.waitForTimeout(400); await page.keyboard.type('dewi'); await page.waitForTimeout(900);
    await gone(page, /Reza Pratama Putra/);
    await shot(page, '41-directory-search');
    await tap(page, /Dewi Lestari/, { wait: 1500 });
    await shot(page, '42-profile-other');
    await has(page, /Auditor/);
    await tap(page, /Back/, { wait: 800 }).catch(() => {});
  });

  await step('Chat tab: conversation list, open, send, and a new message arrives by itself', async () => {
    await tap(page, /Chat/, { role: 'tab', wait: 1800 });
    await shot(page, '43-chat-list');
    await has(page, /Reza Pratama Putra/);
    await tap(page, /Reza Pratama Putra/, { wait: 1800 });
    await shot(page, '44-chat');
    await has(page, /are you coming to the reunion/);
    await page.getByRole('textbox').first().click(); await page.waitForTimeout(400); await page.keyboard.type('See you Friday');
    await tap(page, /Send message/, { wait: 1800 });
    await has(page, /See you Friday/);
    await post('/rest/v1/messages', { conversation_id: 'cccccccc-cccc-4ccc-8ccc-ccccccccccc1', sender_id: REZA, body: 'Great, lunch is on me!' });
    await has(page, /lunch is on me/, 9000); // arrives via the 5 second poll, no refresh tap
    await shot(page, '45-chat-live');
    await tap(page, /Back/, { wait: 800 }).catch(() => {});
  });

  await step('Home: announcements open and read', async () => {
    await tap(page, /Home/, { role: 'tab', wait: 1500 });
    await tap(page, /See all announcements/, { wait: 1500 });
    await shot(page, '46-announcements');
    await has(page, /Ikafe reunion 2026/); await has(page, /Mentoring program/);
    await tap(page, /Mentoring program/, { wait: 1200 });
    await shot(page, '47-announcement-detail');
    await has(page, /preparing a mentoring program/);
    await tap(page, /Back/, { wait: 600 }).catch(() => {});
    await tap(page, /Back/, { wait: 800 }).catch(() => {});
  });

  await step('Nearby Alumni loads without an error', async () => {
    await tap(page, /Nearby Alumni/, { wait: 2500 });
    await shot(page, '48-nearby');
    await gone(page, /Couldn.t load/);
    await tap(page, /Back/, { wait: 800 }).catch(() => {});
  });

  await step('Marketplace: empty state, then the listing form with the city picker', async () => {
    await tap(page, /Marketplace/, { wait: 2000 });
    await shot(page, '49-marketplace');
    await tap(page, /Post a listing/, { wait: 1800 });
    await shot(page, '50-listing-form');
    await tap(page, /^City/, { role: 'textbox', wait: 1200 }).catch(async () => { await tap(page, /City/, { wait: 1200 }); });
    await shot(page, '51-city-picker');
    await has(page, /Banda Aceh/);
    await page.getByRole('textbox').last().click(); await page.waitForTimeout(400); await page.keyboard.type('sema'); await page.waitForTimeout(900);
    await shot(page, '52-city-search');
    await has(page, /Semarang/); await gone(page, /Surabaya/);
    await tap(page, /^Semarang$/, { role: 'button', wait: 1000 }).catch(async () => { await tap(page, /Semarang/, { wait: 1000 }); });
    await shot(page, '53-city-chosen');
  });
  const real = problems.filter((p) => !/GL Driver|fonts.gstatic|CERT_AUTHORITY|ERR_CERT|favicon|ttf|Failed to fetch|Failed to load font|ERR_ABORTED/.test(p));
  console.log('\nconsole problems:', real.length ? real.map((p) => p.slice(0, 160)) : 'none');
  await browser.close();
}

// ---------- D: small phones ---------------------------------------------------
for (const [w, h] of [[320, 568], [360, 640]]) {
  const { browser, page } = await launch({ width: w, height: h });
  await open(page);
  await step(`${w}x${h}: sign-in, job board and post-a-job screens render (see screenshots)`, async () => {
    await page.getByRole('button', { name: 'Get Started' }).click(); await page.waitForTimeout(700);
    await shot(page, `60-${w}-sign-in`);
    await page.getByRole('textbox').nth(0).click(); await page.waitForTimeout(400); await page.keyboard.type('rina@example.com');
    await page.getByRole('textbox').nth(1).click(); await page.waitForTimeout(400); await page.keyboard.type('rina-pass-123');
    await shot(page, `61-${w}-sign-in-filled`);
    await tap(page, /^Sign in/, { wait: 2500 });
    await shot(page, `62-${w}-home`);
    await tap(page, /Jobs/, { wait: 1800 });
    await shot(page, `63-${w}-jobboard`);
    await tap(page, /Post a Job/, { wait: 1500 });
    await shot(page, `64-${w}-postjob`);
  });
  await browser.close();
}

const failed = results.filter((r) => r[0] === 'FAIL');
console.log(`\n${results.length - failed.length}/${results.length} steps passed`);
process.exit(failed.length ? 1 : 0);
