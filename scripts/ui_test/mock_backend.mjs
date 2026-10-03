// A small in-memory stand-in for the Supabase REST API (PostgREST), with
// seed data and the database triggers/functions the app relies on. It exists
// so the Flutter web build can be walked through in a browser without the
// real project. It understands only what this app sends: eq/neq/is/in/or
// filters, order, limit, embedded selects (alias:table(cols)), single-row
// responses, inserts, updates, deletes and a few rpc functions.
//
// Usage: node mock_backend.mjs [port]   (default 54321)
import http from 'node:http';
import { randomUUID } from 'node:crypto';

const PORT = Number(process.argv[2] || 54321);
const now = () => new Date().toISOString();
const ago = (mins) => new Date(Date.now() - mins * 60000).toISOString();

const P = {
  rina: '11111111-1111-4111-8111-111111111111',
  reza: '22222222-2222-4222-8222-222222222222',
  siti: '33333333-3333-4333-8333-333333333333',
  ahmad: '44444444-4444-4444-8444-444444444444',
  dewi: '55555555-5555-4555-8555-555555555555',
  budi: '66666666-6666-4666-8666-666666666666',
};
const J = {
  backend: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
  analyst: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',
  pm: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3',
  mine: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4',
};

const profile = (id, name, email, major, year, role, employer, industry, city, extra = {}) => ({
  id, user_id: null, nim: 'N' + id.slice(0, 6), name, email, faculty: 'Ekonomika dan Bisnis',
  major, graduation_year: year, current_employer: employer, current_role: role,
  industry, company: employer, city, verification_status: 'verified',
  subscription_status: 'free', created_at: ago(9000), updated_at: ago(9000), ...extra,
});

function seed() {
  return {
    alumni_profiles: [
      profile(P.rina, 'Rina Test', 'rina@example.com', 'Manajemen', 2018, 'Product Lead', 'Gojek', 'Technology', 'Jakarta', { subscription_status: 'subscribed' }),
      profile(P.reza, 'Reza Pratama Putra', 'reza.putra@example.com', 'Akuntansi', 2016, 'Engineering Manager', 'Tokopedia', 'Technology', 'Jakarta'),
      profile(P.siti, 'Siti Nur Azizah', 'siti@example.com', 'Manajemen', 2019, 'Business Analyst', 'Bank Mandiri', 'Banking & Finance', 'Semarang'),
      profile(P.ahmad, 'Ahmad Fauzan Ramadhan', 'ahmad@example.com', 'Ilmu Ekonomi', 2014, 'Product Manager', 'Gojek', 'Technology', 'Bandung'),
      profile(P.dewi, 'Dewi Lestari', 'dewi@example.com', 'Akuntansi', 2020, 'Auditor', 'KPMG', 'Accounting & Audit', 'Surabaya'),
      profile(P.budi, 'Budi Santoso', 'budi@example.com', 'Manajemen', 2012, null, null, null, null, { verification_status: 'unverified' }),
    ],
    job_posts: [
      { id: J.backend, posted_by: P.reza, title: 'Backend Engineer', company: 'Tokopedia', industry: 'Technology', description: 'Backend Engineer for our logistics platform team. Go or Java experience a plus.', contact_info: 'reza.putra@example.com', notify_on_apply: true, require_cv: false, require_linkedin: false, require_portfolio: false, require_cover_note: false, created_at: ago(300) },
      { id: J.analyst, posted_by: P.siti, title: 'Business Analyst', company: 'Bank Mandiri', industry: 'Banking & Finance', description: 'Entry to mid-level Business Analyst role in our digital banking division. Fresh grads welcome.', contact_info: 'siti@example.com', notify_on_apply: true, require_cv: true, require_linkedin: true, require_portfolio: false, require_cover_note: true, created_at: ago(200) },
      { id: J.pm, posted_by: P.ahmad, title: 'Product Manager', company: 'Gojek', industry: 'Technology', description: 'Looking for a Product Manager to lead our merchant tools team. UNDIP alumni preferred, reach out directly.', contact_info: 'ahmad@example.com', notify_on_apply: true, require_cv: false, require_linkedin: false, require_portfolio: false, require_cover_note: false, created_at: ago(100) },
      { id: J.mine, posted_by: P.rina, title: 'Data Analyst', company: 'Gojek', industry: 'Technology', description: 'Analyse marketplace data and present findings to leadership.', contact_info: 'rina@example.com', notify_on_apply: true, require_cv: false, require_linkedin: false, require_portfolio: false, require_cover_note: false, created_at: ago(50) },
    ],
    job_applications: [
      { id: randomUUID(), job_post_id: J.backend, applicant_id: P.rina, full_name: 'Rina Test', email: 'rina@example.com', phone: '', linkedin_url: null, portfolio_url: null, cover_note: 'Interested!', cv_path: null, status: 'reviewed', created_at: ago(120) },
      { id: randomUUID(), job_post_id: J.mine, applicant_id: P.dewi, full_name: 'Dewi Lestari', email: 'dewi@example.com', phone: '0812', linkedin_url: 'https://linkedin.com/in/dewi', portfolio_url: null, cover_note: 'I love data.', cv_path: null, status: 'pending', created_at: ago(30) },
    ],
    notifications: [
      { id: randomUUID(), recipient_id: P.rina, job_post_id: J.mine, title: 'New application: Data Analyst', body: 'Dewi Lestari applied to your "Data Analyst" posting.', read_at: null, created_at: ago(29) },
    ],
    announcements: [
      { id: randomUUID(), title: 'Ikafe reunion 2026', body: 'Save the date for the annual alumni reunion in Semarang.', posted_by: null, created_at: ago(1000) },
      { id: randomUUID(), title: 'Mentoring program opens soon', body: 'We are preparing a mentoring program for fresh graduates.', posted_by: null, created_at: ago(2000) },
    ],
    conversations: [
      { id: 'cccccccc-cccc-4ccc-8ccc-ccccccccccc1', participant_one: P.rina, participant_two: P.reza, created_at: ago(500) },
    ],
    messages: [
      { id: randomUUID(), conversation_id: 'cccccccc-cccc-4ccc-8ccc-ccccccccccc1', sender_id: P.reza, body: 'Hi Rina, are you coming to the reunion?', created_at: ago(400) },
      { id: randomUUID(), conversation_id: 'cccccccc-cccc-4ccc-8ccc-ccccccccccc1', sender_id: P.rina, body: 'Yes, see you there!', created_at: ago(390) },
    ],
    city_chat_messages: [
      { id: randomUUID(), city: 'Jakarta', sender_id: P.reza, body: 'Anyone up for lunch on Friday?', created_at: ago(60) },
    ],
    email_log: [],
    marketplace_listings: [],
    marketplace_reports: [],
    marketplace_admins: [],
  };
}
let db = seed();
let failing = false; // /__fail?on=1 makes every REST call return 500, to test error screens

// Which column links a table to the table named in an embedded select.
const FK = {
  job_posts: { alumni_profiles: 'posted_by' },
  job_applications: { job_posts: 'job_post_id', alumni_profiles: 'applicant_id' },
  messages: { alumni_profiles: 'sender_id' },
  city_chat_messages: { alumni_profiles: 'sender_id' },
  announcements: { alumni_profiles: 'posted_by' },
};

function splitTop(s) {
  const out = []; let depth = 0, cur = '';
  for (const c of s) {
    if (c === '(') depth++;
    if (c === ')') depth--;
    if (c === ',' && depth === 0) { out.push(cur.trim()); cur = ''; } else cur += c;
  }
  if (cur.trim()) out.push(cur.trim());
  return out;
}

function project(table, row, select) {
  if (!select || select === '*') return { ...row };
  const out = {};
  for (const item of splitTop(select)) {
    if (item === '*') { Object.assign(out, row); continue; }
    const m = item.match(/^(?:(\w+):)?(\w+)(?:!(\w+))?\((.*)\)$/s);
    if (m) {
      const [, alias, target, hint, inner] = m;
      let col = FK[table]?.[target];
      if (hint?.includes('participant_one')) col = 'participant_one';
      if (hint?.includes('participant_two')) col = 'participant_two';
      const found = col ? (db[target] || []).find((r) => r.id === row[col]) : null;
      out[alias || target] = found ? project(target, found, inner) : null;
    } else {
      out[item] = row[item];
    }
  }
  return out;
}

function matches(row, key, expr) {
  if (key === 'or') {
    const inner = expr.replace(/^\(|\)$/g, '');
    return splitTop(inner).some((c) => {
      const [col, op, ...rest] = c.split('.');
      return test(row[col], op, rest.join('.'));
    });
  }
  const dot = expr.indexOf('.');
  return test(row[key], expr.slice(0, dot), expr.slice(dot + 1));
}
function test(v, op, arg) {
  switch (op) {
    case 'eq': return String(v) === arg;
    case 'neq': return String(v) !== arg;
    case 'is': return arg === 'null' ? v == null : String(v) === arg;
    case 'in': return arg.replace(/^\(|\)$/g, '').split(',').includes(String(v));
    case 'ilike': return String(v ?? '').toLowerCase().includes(arg.replace(/%/g, '').toLowerCase());
    default: return true;
  }
}
const RESERVED = new Set(['select', 'order', 'limit', 'offset', 'columns', 'on_conflict']);

function query(table, params) {
  let rows = [...(db[table] || [])];
  for (const [k, v] of params) if (!RESERVED.has(k)) rows = rows.filter((r) => matches(r, k, v));
  const order = params.get('order');
  if (order) {
    for (const spec of order.split(',').reverse()) {
      const [col, dir] = spec.split('.');
      rows.sort((a, b) => (a[col] > b[col] ? 1 : a[col] < b[col] ? -1 : 0) * (dir === 'desc' ? -1 : 1));
    }
  }
  const limit = params.get('limit');
  if (limit) rows = rows.slice(0, Number(limit));
  return rows;
}

const DEFAULTS = {
  job_posts: () => ({ notify_on_apply: true, require_cv: false, require_linkedin: false, require_portfolio: false, require_cover_note: false }),
  job_applications: () => ({ status: 'pending' }),
  notifications: () => ({ read_at: null }),
};
const STATUS_LABEL = { reviewed: 'under review', accepted: 'accepted', rejected: 'not selected', pending: 'pending' };

// What the database triggers do.
function afterInsert(table, row) {
  if (table === 'job_applications') {
    const job = db.job_posts.find((j) => j.id === row.job_post_id);
    if (job && job.notify_on_apply !== false) {
      db.notifications.push({ id: randomUUID(), recipient_id: job.posted_by, job_post_id: job.id, title: 'New application: ' + job.title, body: `${row.full_name || 'Someone'} applied to your "${job.title}" posting.`, read_at: null, created_at: now() });
    }
  }
}
function afterUpdate(table, before, row) {
  if (table === 'job_applications' && before.status !== row.status) {
    const job = db.job_posts.find((j) => j.id === row.job_post_id);
    db.notifications.push({ id: randomUUID(), recipient_id: row.applicant_id, job_post_id: row.job_post_id, title: 'Application update: ' + (job?.title || 'a job'), body: `Your application for "${job?.title}" is now ${STATUS_LABEL[row.status]}.`, read_at: null, created_at: now() });
  }
}

function rpc(fn, a) {
  switch (fn) {
    case 'marketplace_is_admin': return false;
    case 'update_job_post': {
      const j = db.job_posts.find((r) => r.id === a.p_job && r.posted_by === a.p_poster);
      if (!j) throw { code: 'P0001', message: 'not_owner' };
      Object.assign(j, { title: a.p_title, company: a.p_company, industry: a.p_industry, description: a.p_description, contact_info: a.p_contact_info, notify_on_apply: a.p_notify_on_apply, require_cv: a.p_require_cv, require_linkedin: a.p_require_linkedin, require_portfolio: a.p_require_portfolio, require_cover_note: a.p_require_cover_note });
      return null;
    }
    case 'delete_job_post': {
      const j = db.job_posts.find((r) => r.id === a.p_job && r.posted_by === a.p_poster);
      if (!j) throw { code: 'P0001', message: 'not_owner' };
      db.notifications = db.notifications.filter((n) => n.job_post_id !== j.id);
      db.job_applications = db.job_applications.filter((n) => n.job_post_id !== j.id);
      db.job_posts = db.job_posts.filter((r) => r.id !== j.id);
      return null;
    }
    default: return [];
  }
}

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': '*',
  'Access-Control-Allow-Methods': 'GET,POST,PATCH,DELETE,OPTIONS',
  'Access-Control-Expose-Headers': 'Content-Range',
};
const send = (res, status, body, extra = {}) => {
  res.writeHead(status, { 'Content-Type': 'application/json', ...cors, ...extra });
  res.end(body === undefined ? '' : JSON.stringify(body));
};

http.createServer((req, res) => {
  const url = new URL(req.url, 'http://localhost');
  if (req.method === 'OPTIONS') return send(res, 204);
  let raw = '';
  req.on('data', (c) => (raw += c));
  req.on('end', () => {
    try {
      if (url.pathname === '/__reset') { db = seed(); failing = false; return send(res, 200, { ok: true }); }
      if (url.pathname === '/__fail') { failing = url.searchParams.get('on') === '1'; return send(res, 200, { failing }); }
      if (url.pathname === '/__state') return send(res, 200, db);
      const m = url.pathname.match(/^\/rest\/v1\/(\w+)(?:\/(\w+))?$/);
      if (!m) return send(res, 404, { message: 'not found' });
      if (failing) return send(res, 500, { message: 'simulated outage' });
      const [, first, second] = m;
      const body = raw ? JSON.parse(raw) : null;
      const prefer = req.headers['prefer'] || '';
      const wantsObject = (req.headers['accept'] || '').includes('vnd.pgrst.object');

      if (first === 'rpc') {
        try { return send(res, 200, rpc(second, body || {}) ?? null); } catch (e) { return send(res, 400, e); }
      }
      const table = first;
      if (!(table in db)) return send(res, 404, { code: '42P01', message: `no table ${table}` });
      const select = url.searchParams.get('select');

      if (req.method === 'GET' || req.method === 'HEAD') {
        const rows = query(table, url.searchParams);
        const extra = prefer.includes('count=exact') ? { 'Content-Range': `0-${Math.max(rows.length - 1, 0)}/${rows.length}` } : {};
        if (req.method === 'HEAD') return send(res, 200, undefined, extra);
        const out = rows.map((r) => project(table, r, select));
        if (wantsObject) {
          if (out.length !== 1) return send(res, 406, { code: 'PGRST116', message: 'JSON object requested, multiple (or no) rows returned', details: `The result contains ${out.length} rows` });
          return send(res, 200, out[0], extra);
        }
        return send(res, 200, out, extra);
      }
      if (req.method === 'POST') {
        const items = Array.isArray(body) ? body : [body];
        const made = items.map((it) => {
          const row = { id: randomUUID(), created_at: now(), ...(DEFAULTS[table]?.() || {}), ...it };
          db[table].push(row); afterInsert(table, row); return row;
        });
        if (prefer.includes('return=representation')) return send(res, 201, wantsObject ? project(table, made[0], select) : made.map((r) => project(table, r, select)));
        return send(res, 201);
      }
      if (req.method === 'PATCH') {
        const rows = query(table, url.searchParams);
        for (const r of rows) { const before = { ...r }; Object.assign(r, body); afterUpdate(table, before, r); }
        if (prefer.includes('return=representation')) return send(res, 200, rows.map((r) => project(table, r, select)));
        return send(res, 204);
      }
      if (req.method === 'DELETE') {
        const rows = new Set(query(table, url.searchParams));
        db[table] = db[table].filter((r) => !rows.has(r));
        return send(res, 204);
      }
      return send(res, 405, { message: 'method' });
    } catch (e) {
      console.error('mock error', req.method, req.url, e);
      send(res, 500, { message: String(e) });
    }
  });
}).listen(PORT, () => console.log(`mock backend on http://localhost:${PORT}`));
