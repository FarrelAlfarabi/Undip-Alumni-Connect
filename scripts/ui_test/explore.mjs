import { launch, open, shot, tree, login } from './lib.mjs';
const { browser, page, problems } = await launch();
await open(page);
await login(page);
await shot(page, '01-home');
console.log((await tree(page)).join('\n'));
console.log(problems.filter((p) => !/GL Driver|fonts.gstatic|CERT_AUTHORITY/.test(p)));
await browser.close();
