import path from 'path';
import os from 'os';
import { fileURLToPath } from 'url';
import dotenv from 'dotenv';

const __filename = fileURLToPath(import.meta.url);
const __dirname  = path.dirname(__filename);

// Загружаем .env
dotenv.config({ path: path.resolve(__dirname, '..', '.env') });

import express from 'express';
import cors from 'cors';
import crypto from 'crypto';
import { spawn, spawnSync } from 'child_process';
import fs from 'fs';
import https from 'https';
import { S3Client, PutObjectCommand, GetObjectCommand, DeleteObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { PrismaClient } from '@prisma/client';

const ROOT      = path.resolve(__dirname, '..');
const HOST      = '0.0.0.0';
const PORT      = process.env.PORT || 8080;
const IS_WIN    = process.platform === 'win32';
const PY        = process.env.PYTHON || (IS_WIN ? 'python' : 'python3');
const PY_TARGET = path.join(ROOT, '.pylibs');
const BIN_DIR   = path.join(PY_TARGET, IS_WIN ? 'Scripts' : 'bin');
const PATH_SEP  = path.delimiter;

const CORS_ORIGIN = (process.env.CORS_ORIGIN || '*')
  .split(',').map(s => s.trim()).filter(Boolean);

const app = express();
app.set('trust proxy', 1);
app.use(cors({
  origin: (origin, cb) => {
    if (!origin || CORS_ORIGIN.includes('*') || CORS_ORIGIN.includes(origin)) return cb(null, true);
    return cb(new Error('Not allowed by CORS'));
  }
}));
app.use(express.json());

const APP_AUTH_SCHEME = process.env.APP_AUTH_SCHEME || 'fitdew';
const APP_AUTH_HOST = process.env.APP_AUTH_HOST || 'auth';
const TELEGRAM_BOT_USERNAME = process.env.TELEGRAM_BOT_USERNAME || '';
const MOBILE_TOKEN_SECRET = process.env.MOBILE_TOKEN_SECRET || process.env.BOT_TOKEN || '';

// Prisma
const prisma = new PrismaClient();
const DB_KEEPALIVE_MS = Number(process.env.DB_KEEPALIVE_MS || 0);
if (DB_KEEPALIVE_MS > 0) {
  const keepAlive = async () => {
    try {
      await prisma.$queryRaw`SELECT 1`;
    } catch (err) {
      console.error('[db] keepalive failed', err);
    }
  };
  const timer = setInterval(keepAlive, DB_KEEPALIVE_MS);
  if (typeof timer.unref === 'function') timer.unref();
}

// health
app.get('/', (_req, res) => res.send('OK'));
app.get('/health', (_req, res) => res.json({ ok: true }));

// validate Telegram initData
app.get('/api/validate', (req, res) => {
  try {
    const initData = req.query.initData;
    console.log('\n[api/validate] initData raw:', initData);

    if (!initData) return res.status(400).json({ ok: false, error: 'no_initData' });

    const params = new URLSearchParams(initData);
    console.log('[api/validate] params:', Object.fromEntries(params.entries()));

    const hash = params.get('hash');
    if (!hash) return res.status(400).json({ ok: false, error: 'no_hash' });

    const pairs = [];
    for (const [k, v] of params.entries()) if (k !== 'hash') pairs.push(`${k}=${v}`);
    pairs.sort();
    const dataCheckString = pairs.join('\n');

    const botToken = process.env.BOT_TOKEN;
    if (!botToken) return res.status(500).json({ ok: false, error: 'no_bot_token' });

    const secretKey = crypto.createHmac('sha256', 'WebAppData').update(botToken).digest();
    const calcHash  = crypto.createHmac('sha256', secretKey).update(dataCheckString).digest('hex');

    console.log('[api/validate] calcHash=', calcHash, 'givenHash=', hash);

    if (calcHash !== hash) return res.status(401).json({ ok: false, error: 'bad_hash' });

    const authDate = Number(params.get('auth_date') || 0);
    const age = Math.floor(Date.now() / 1000) - authDate;
    if (authDate && age > 24 * 3600) return res.status(401).json({ ok: false, error: 'expired' });

    const userStr = params.get('user');
    const user = userStr ? JSON.parse(userStr) : null;

    console.log('[api/validate] user parsed:', user);

    res.json({ ok: true, user });
  } catch (e) {
    console.error('[api/validate] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

function base64urlEncode(value) {
  return Buffer.from(value).toString('base64url');
}

function signMobileToken(payload) {
  if (!MOBILE_TOKEN_SECRET) return null;
  const body = base64urlEncode(JSON.stringify(payload));
  const sig = crypto.createHmac('sha256', MOBILE_TOKEN_SECRET).update(body).digest('base64url');
  return `${body}.${sig}`;
}

function verifyTelegramLoginPayload(params) {
  const hash = params.hash;
  if (!hash) return { ok: false, error: 'no_hash' };
  const botToken = process.env.BOT_TOKEN;
  if (!botToken) return { ok: false, error: 'no_bot_token' };

  const pairs = Object.keys(params)
    .filter(k => k !== 'hash')
    .sort()
    .map(k => `${k}=${params[k]}`);

  const dataCheckString = pairs.join('\n');
  const secretKey = crypto.createHash('sha256').update(botToken).digest();
  const calcHash = crypto.createHmac('sha256', secretKey).update(dataCheckString).digest('hex');

  if (calcHash !== hash) return { ok: false, error: 'bad_hash' };
  return { ok: true };
}

app.get('/auth/telegram', (req, res) => {
  const bot = TELEGRAM_BOT_USERNAME;
  const host = req.get('host');
  const authUrl = `https://${host}/auth/telegram/callback`;
  const html = `<!doctype html>
<html lang="ru">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Fit Dew — Вход</title>
  <style>
    body { margin: 0; font-family: Arial, sans-serif; background: #0f0f10; color: #f4f1e8; display: grid; place-items: center; min-height: 100vh; }
    .card { background: #1b1b1f; padding: 24px; border-radius: 18px; border: 1px solid rgba(255,255,255,0.08); }
    .muted { color: #c6c0b2; font-size: 14px; margin-top: 6px; }
  </style>
</head>
<body>
  <div class="card">
    <h2>Вход через Telegram</h2>
    ${bot ? `<script async src="https://telegram.org/js/telegram-widget.js?22"
      data-telegram-login="${bot}"
      data-size="large"
      data-radius="20"
      data-auth-url="${authUrl}"
      data-request-access="write"></script>` : '<div class="muted">Не указан TELEGRAM_BOT_USERNAME в .env</div>'}
  </div>
</body>
</html>`;
  res.set('content-type', 'text/html; charset=utf-8');
  res.send(html);
});

app.get('/auth/telegram/callback', (req, res) => {
  const params = req.query || {};
  const check = verifyTelegramLoginPayload(params);
  if (!check.ok) return res.status(401).send(check.error);
  const tgId = Number(params.id);
  if (!Number.isFinite(tgId)) return res.status(400).send('bad_id');
  const photoUrl = typeof params.photo_url === 'string' ? params.photo_url : null;
  const firstName = typeof params.first_name === 'string' ? params.first_name : null;
  const lastName = typeof params.last_name === 'string' ? params.last_name : null;
  const username = typeof params.username === 'string' ? params.username : null;

  prisma.user.upsert({
    where: { tg_id: tgId },
    update: {
      first_name: firstName || undefined,
      last_name: lastName || undefined,
      username: username || undefined,
      photo_url: photoUrl || undefined
    },
    create: {
      tg_id: tgId,
      first_name: firstName || null,
      last_name: lastName || null,
      username: username || null,
      photo_url: photoUrl || null
    }
  }).catch(() => {});

  const token = signMobileToken({
    tg_id: tgId,
    auth_date: Number(params.auth_date) || 0,
    user: {
      id: tgId,
      username: username || null,
      first_name: firstName || null,
      last_name: lastName || null,
      photo_url: photoUrl || null
    }
  });
  if (!token) return res.status(500).send('token_disabled');
  const redirectParams = new URLSearchParams({ token });
  if (photoUrl) redirectParams.set('photo_url', photoUrl);
  if (firstName) redirectParams.set('first_name', firstName);
  const redirectUrl = `${APP_AUTH_SCHEME}://${APP_AUTH_HOST}?${redirectParams.toString()}`;
  const html = `<!doctype html>
<html lang="ru">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Fit Dew — Вход</title>
  <style>
    body { margin: 0; font-family: Arial, sans-serif; background: #0f0f10; color: #f4f1e8; display: grid; place-items: center; min-height: 100vh; }
    .card { background: #1b1b1f; padding: 24px; border-radius: 18px; border: 1px solid rgba(255,255,255,0.08); text-align: center; }
    a { display: inline-block; margin-top: 12px; padding: 10px 18px; border-radius: 999px; background: #f6e5a6; color: #1b1b1b; text-decoration: none; font-weight: 700; letter-spacing: 0.08em; text-transform: uppercase; }
  </style>
  <script>
    setTimeout(function() {
      window.location.href = ${JSON.stringify(redirectUrl)};
    }, 150);
  </script>
</head>
<body>
  <div class="card">
    <div>Вход выполнен</div>
    <a href="${redirectUrl}">Открыть приложение</a>
  </div>
</body>
</html>`;
  res.set('content-type', 'text/html; charset=utf-8');
  return res.send(html);
});

// helpers
function run(cmd, args, opts = {}) {
  return new Promise(resolve => {
    let done = false;
    const finish = ok => {
      if (done) return;
      done = true;
      resolve(ok);
    };
    const p = spawn(cmd, args, { stdio: 'inherit', ...opts });
    p.on('error', err => {
      console.error(`[spawn] ${cmd} failed:`, err?.message || err);
      finish(false);
    });
    p.on('exit', code => finish(code === 0));
  });
}

function hasPython() {
  try {
    const res = spawnSync(PY, ['--version'], { stdio: 'ignore' });
    return res.status === 0;
  } catch {
    return false;
  }
}

function fetchJson(url) {
  return new Promise((resolve, reject) => {
    https.get(url, res => {
      let data = '';
      res.setEncoding('utf8');
      res.on('data', chunk => { data += chunk; });
      res.on('end', () => {
        if (!res.statusCode || res.statusCode < 200 || res.statusCode >= 300) {
          return reject(new Error(`HTTP ${res.statusCode || 0}`));
        }
        try {
          resolve(JSON.parse(data));
        } catch (err) {
          reject(err);
        }
      });
    }).on('error', reject);
  });
}

function postJson(url, payload) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(payload || {});
    const request = https.request(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(data)
      }
    }, res => {
      let body = '';
      res.setEncoding('utf8');
      res.on('data', chunk => { body += chunk; });
      res.on('end', () => {
        if (!res.statusCode || res.statusCode < 200 || res.statusCode >= 300) {
          return reject(new Error(`HTTP ${res.statusCode || 0}`));
        }
        try {
          resolve(body ? JSON.parse(body) : {});
        } catch (err) {
          reject(err);
        }
      });
    });
    request.on('error', reject);
    request.write(data);
    request.end();
  });
}

async function ensurePip() {
  const ok = await run(PY, ['-m', 'pip', '--version'], { cwd: ROOT });
  if (ok) return;
  console.log('[pip] downloading get-pip.py ...');
  const tmp = path.join(os.tmpdir(), 'get-pip.py');
  await new Promise((resolve, reject) => {
    const file = fs.createWriteStream(tmp);
    https.get('https://bootstrap.pypa.io/get-pip.py', res => {
      if (res.statusCode !== 200) return reject(new Error('get-pip http ' + res.statusCode));
      res.pipe(file);
      file.on('finish', () => file.close(resolve));
    }).on('error', reject);
  });
  console.log('[pip] installing via get-pip.py ...');
  await run(PY, [tmp], { cwd: ROOT });
}

async function installPyDeps() {
  const hasReq = fs.existsSync(path.join(ROOT, 'requirements.txt'));
  const args = hasReq
    ? ['-m', 'pip', 'install', '--no-cache-dir', '--upgrade', '-r', 'requirements.txt', '--target', PY_TARGET]
    : ['-m', 'pip', 'install', '--no-cache-dir', '--upgrade', 'aiogram', 'python-dotenv', 'prisma', '--target', PY_TARGET];
  const ok = await run(PY, args, { cwd: ROOT });
  if (!ok) console.error('[pip] install failed (packages may be missing)');
}

async function preparePrisma() {
  const env = {
    ...process.env,
    PYTHONPATH: [PY_TARGET, process.env.PYTHONPATH || ''].filter(Boolean).join(PATH_SEP),
    PATH: [BIN_DIR, process.env.PATH || ''].filter(Boolean).join(PATH_SEP),
  };
  console.log('[prisma] generate...');
  const okGen = await run(PY, ['-m', 'prisma', 'generate'], { cwd: ROOT, env });
  if (!okGen) console.error('[prisma] generate failed');
  console.log('[prisma] db push...');
  const okPush = await run(PY, ['-m', 'prisma', 'db', 'push', '--accept-data-loss'], { cwd: ROOT, env });
  if (!okPush) console.error('[prisma] db push failed (check DATABASE_URL)');
}

function startPythonBot() {
  const env = {
    ...process.env,
    PYTHONPATH: [PY_TARGET, process.env.PYTHONPATH || ''].filter(Boolean).join(PATH_SEP),
    PATH: [BIN_DIR, process.env.PATH || ''].filter(Boolean).join(PATH_SEP),
  };
  const botPath = path.join(ROOT, 'bot.py');
  const child = spawn(PY, [botPath], { cwd: ROOT, env, stdio: 'inherit' });
  console.log(`[bot] started pid=${child.pid}`);
  child.on('exit', (code, signal) => {
    console.log(`[bot] exited code=${code} signal=${signal} -> restart in 5s`);
    setTimeout(startPythonBot, 5000);
  });
  child.on('error', err => console.error('[bot] failed to start:', err?.message));
}

// boot
(async () => {
  try {
    await ensurePip();
    await installPyDeps();
    await preparePrisma();
  } finally {
    startPythonBot();
    startAutoAssign();
    startWeightReminders();
    startChatCleanup();
    app.listen(PORT, () => {
      console.log(`✅ Server is running on port ${PORT}`);
    });
  }
})();
process.on('SIGTERM', () => process.exit(0));
process.on('SIGINT',  () => process.exit(0));

// /api/app/version
app.get('/api/app/version', async (_req, res) => {
  let versionCode = Number.isFinite(APP_UPDATE_VERSION_CODE) && APP_UPDATE_VERSION_CODE > 0
    ? APP_UPDATE_VERSION_CODE
    : null;
  let minVersionCode = Number.isFinite(APP_UPDATE_MIN_CODE) && APP_UPDATE_MIN_CODE > 0
    ? APP_UPDATE_MIN_CODE
    : null;
  let versionName = APP_UPDATE_VERSION_NAME || null;
  let url = APP_UPDATE_URL || null;

  const remote = await getAppUpdatePayload();
  if (remote && typeof remote === 'object') {
    const remoteCode = Number(remote.versionCode);
    const remoteMin = Number(remote.minVersionCode ?? remote.minCode);
    const remoteName = remote.versionName;
    const remoteUrl = remote.url;
    if (Number.isFinite(remoteCode) && remoteCode > 0) versionCode = remoteCode;
    if (Number.isFinite(remoteMin) && remoteMin > 0) minVersionCode = remoteMin;
    if (typeof remoteName === 'string' && remoteName.trim()) versionName = remoteName.trim();
    if (typeof remoteUrl === 'string' && remoteUrl.trim()) url = remoteUrl.trim();
  }

  res.json({
    ok: true,
    versionCode,
    versionName,
    minVersionCode,
    url
  });
});

// /api/user
app.get('/api/user', async (req, res) => {
  try {
    const auth = getAuthFromRequest(req);
    if (!auth.ok) return res.status(auth.status || 401).json({ ok: false, error: auth.error });
    const tg_id = auth.tg_id ? Number(auth.tg_id) : null;
    const user = auth.user || null;
    const parsed = { tg_id, user };
    console.log("[api/user] tg_id =", tg_id);

    if (!tg_id) return res.status(400).json({ ok: false, error: 'no_tg_id' });

    let dbUser = null;
    try {
      dbUser = await prisma.user.findUnique({
        where: { tg_id: Number(tg_id) },
        select: {
          id: true,
          tg_id: true,
          username: true,
          first_name: true,
          last_name: true,
          photo_url: true,
          tariffName: true,
          tariffExpiresAt: true,
          trainingMode: true,
          heightCm: true,
          weightKg: true,
          age: true,
          role: true,
          trainerScope: true,
          isCurator: true,
          trainer: {
            select: {
              id: true,
              first_name: true,
              last_name: true,
              username: true
            }
          }
        }
      });
      if (!dbUser) {
        await ensureUserRecord(parsed);
        dbUser = await prisma.user.findUnique({
          where: { tg_id: Number(tg_id) },
          select: {
            id: true,
            tg_id: true,
            username: true,
            first_name: true,
            last_name: true,
            photo_url: true,
            tariffName: true,
            tariffExpiresAt: true,
            trainingMode: true,
            heightCm: true,
            weightKg: true,
            age: true,
            role: true,
            trainerScope: true,
            isCurator: true,
            trainer: {
              select: {
                id: true,
                first_name: true,
                last_name: true,
                username: true
              }
            }
          }
        });
      }
      console.log('[api/user] dbUser:', dbUser);
    } catch (e) {
      console.error('[api/user] prisma findUnique error', e);
    }

    const resolvedTgId = Number.isFinite(Number(dbUser?.tg_id))
      ? Number(dbUser.tg_id)
      : tg_id;
    const resolvedUser = user || (dbUser
      ? {
          id: resolvedTgId,
          username: dbUser.username || null,
          first_name: dbUser.first_name || null,
          last_name: dbUser.last_name || null,
          photo_url: dbUser.photo_url || null
        }
      : null);
    const isAdmin = dbUser?.role === 'admin' || dbUser?.role === 'sadmin';
    const isCurator = dbUser?.role === 'curator' || Boolean(dbUser?.isCurator);
    const tariffActive = !dbUser?.tariffExpiresAt || new Date(dbUser.tariffExpiresAt) > new Date();
    const profileTariff = tariffActive ? normalizeTariffName(dbUser?.tariffName) : null;
    const profileTariffExpiresAt = tariffActive ? dbUser?.tariffExpiresAt : null;
    const profile = {
      id: dbUser?.id ?? null,
      first_name: dbUser?.first_name || resolvedUser?.first_name || user?.first_name || 'друг',
      tariffName: profileTariff || 'Без тарифа',
      tariffExpiresAt: profileTariffExpiresAt,
      trainingMode: dbUser?.trainingMode || 'gym',
      heightCm: dbUser?.heightCm ?? null,
      weightKg: dbUser?.weightKg ?? null,
      age: dbUser?.age ?? null,
      role: dbUser?.role || 'user',
      trainerScope: normalizeTrainerScope(dbUser?.trainerScope),
      canTrain: isAdmin,
      canCurate: isAdmin || isCurator,
      isCurator,
      trainer: dbUser?.trainer
        ? {
            id: dbUser.trainer.id,
            name: [dbUser.trainer.first_name, dbUser.trainer.last_name].filter(Boolean).join(' ') || dbUser.trainer.username,
            username: dbUser.trainer.username || null
          }
        : null
    };

    console.log(`[api/user] profile for ${tg_id}:`, profile);

    return res.json({ ok: true, user: resolvedUser, profile });
  } catch (e) {
    console.error('[api/user] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

// === Yandex Disk public link resolve ===
app.get('/api/yadisk/resolve', async (req, res) => {
  try {
    const publicUrl = req.query.publicUrl;
    if (!publicUrl || typeof publicUrl !== 'string') {
      return res.status(400).json({ ok: false, error: 'missing_public_url' });
    }

    const apiUrl = `https://cloud-api.yandex.net/v1/disk/public/resources/download?public_key=${encodeURIComponent(publicUrl)}`;
    const data = await fetchJson(apiUrl);
    if (!data?.href) {
      return res.status(502).json({ ok: false, error: 'no_href' });
    }

    return res.json({ ok: true, href: data.href, method: data.method || 'GET' });
  } catch (e) {
    console.error('[api/yadisk:resolve] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

// helpers for nutrition
const toFloat = (value) => {
  if (value === null || value === undefined || value === '') return null;
  const normalized = String(value).replace(',', '.');
  const num = Number(normalized);
  return Number.isFinite(num) ? num : null;
};

const toInt = (value) => {
  const num = toFloat(value);
  if (num === null) return null;
  return Math.round(num);
};

const getDateKey = (value) => {
  if (typeof value === 'string' && value.length >= 10) return value.slice(0, 10);
  return new Date().toISOString().slice(0, 10);
};

const toDateKeyLocal = (date) => {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
};

const addDaysLocal = (date, days) => {
  const d = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  d.setDate(d.getDate() + days);
  return d;
};

const toDateKeyUTC = (date) => {
  const y = date.getUTCFullYear();
  const m = String(date.getUTCMonth() + 1).padStart(2, '0');
  const d = String(date.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
};

const toDateKeyWithOffset = (date, offsetMin) => {
  const offset = Number.isFinite(offsetMin) ? offsetMin : 0;
  const localMillis = date.getTime() - offset * 60000;
  return toDateKeyUTC(new Date(localMillis));
};

const getWeekStartKey = (dateKey) => {
  const raw = typeof dateKey === 'string' ? dateKey.slice(0, 10) : toDateKeyUTC(new Date());
  const base = new Date(`${raw}T00:00:00Z`);
  if (Number.isNaN(base.getTime())) return raw;
  const day = (base.getUTCDay() + 6) % 7;
  base.setUTCDate(base.getUTCDate() - day);
  return toDateKeyUTC(base);
};

const getMonthStartKey = (dateKey) => {
  const raw = typeof dateKey === 'string' ? dateKey.slice(0, 10) : toDateKeyUTC(new Date());
  const base = new Date(`${raw}T00:00:00Z`);
  if (Number.isNaN(base.getTime())) return raw;
  base.setUTCDate(1);
  return toDateKeyUTC(base);
};

const getWeekStartKeyWithOffset = (date, offsetMin) => {
  const localKey = toDateKeyWithOffset(date, offsetMin);
  return getWeekStartKey(localKey);
};

const getMonthStartKeyWithOffset = (date, offsetMin) => {
  const localKey = toDateKeyWithOffset(date, offsetMin);
  return getMonthStartKey(localKey);
};

const OFF_BASE = 'https://world.openfoodfacts.org';

const buildOffSearchUrl = (query, page = 1, limit = 20) => {
  const params = new URLSearchParams({
    search_terms: query,
    search_simple: '1',
    action: 'process',
    json: '1',
    page_size: String(limit),
    page: String(page),
    fields: 'code,product_name,product_name_ru,brands,image_url,nutriments'
  });
  return `${OFF_BASE}/cgi/search.pl?${params.toString()}`;
};

const buildOffBarcodeUrl = (barcode) => {
  const fields = 'code,product_name,product_name_ru,brands,image_url,nutriments';
  return `${OFF_BASE}/api/v2/product/${encodeURIComponent(barcode)}.json?fields=${encodeURIComponent(fields)}`;
};

const normalizeOffProduct = (raw) => {
  if (!raw) return null;
  const nutr = raw.nutriments || {};
  return {
    source: 'off',
    sourceId: raw.code ? String(raw.code) : null,
    barcode: raw.code ? String(raw.code) : null,
    title: cleanString(raw.product_name_ru) || cleanString(raw.product_name) || 'Продукт',
    brand: cleanString(raw.brands) || null,
    imageUrl: raw.image_url || null,
    kcal100: toFloat(nutr['energy-kcal_100g'] ?? nutr['energy-kcal']),
    protein100: toFloat(nutr['proteins_100g'] ?? nutr['proteins']),
    fat100: toFloat(nutr['fat_100g'] ?? nutr['fat']),
    carb100: toFloat(nutr['carbohydrates_100g'] ?? nutr['carbohydrates'])
  };
};

const calcMacrosFromProduct = (product, grams) => {
  const g = Math.max(0, Number(grams) || 0);
  const k = (product.kcal100 || 0) * g / 100;
  const p = (product.protein100 || 0) * g / 100;
  const f = (product.fat100 || 0) * g / 100;
  const c = (product.carb100 || 0) * g / 100;
  return {
    grams: g,
    kcal: Math.round(k),
    protein: Math.round(p * 10) / 10,
    fat: Math.round(f * 10) / 10,
    carb: Math.round(c * 10) / 10
  };
};

const upsertNutritionProduct = async (raw) => {
  if (!raw) return null;
  const data = normalizeOffProduct(raw);
  if (!data) return null;
  if (data.barcode) {
    return prisma.nutritionProduct.upsert({
      where: { barcode: data.barcode },
      update: data,
      create: data
    });
  }
  return prisma.nutritionProduct.create({ data });
};

const recalcNutritionEntryTotals = async (entryId) => {
  const items = await prisma.nutritionItem.findMany({
    where: { entryId },
    select: { kcal: true, protein: true, fat: true, carb: true, meal: true }
  });
  const totals = items.reduce(
    (acc, item) => {
      acc.kcal += item.kcal || 0;
      acc.protein += item.protein || 0;
      acc.fat += item.fat || 0;
      acc.carb += item.carb || 0;
      acc.meals.add(item.meal);
      return acc;
    },
    { kcal: 0, protein: 0, fat: 0, carb: 0, meals: new Set() }
  );
  return prisma.nutritionEntry.update({
    where: { id: entryId },
    data: {
      kcal: Math.round(totals.kcal),
      protein: Math.round(totals.protein * 10) / 10,
      fat: Math.round(totals.fat * 10) / 10,
      carb: Math.round(totals.carb * 10) / 10,
      mealsCount: totals.meals.size
    }
  });
};

const getWeightLockUntil = (entry) => {
  const updatedAt = entry?.updatedAt ? new Date(entry.updatedAt) : null;
  if (!updatedAt || Number.isNaN(updatedAt.getTime())) return null;
  return updatedAt.getTime() + WEIGHT_EDIT_WINDOW_MS;
};

const isWeightLocked = (entry, now = Date.now()) => {
  const lockUntil = getWeightLockUntil(entry);
  if (!lockUntil) return false;
  return now >= lockUntil;
};

const getMeasurementLockUntil = (entry) => {
  const updatedAt = entry?.updatedAt ? new Date(entry.updatedAt) : null;
  if (!updatedAt || Number.isNaN(updatedAt.getTime())) return null;
  return updatedAt.getTime() + MEASUREMENT_EDIT_WINDOW_MS;
};

const isMeasurementLocked = (entry, now = Date.now()) => {
  const lockUntil = getMeasurementLockUntil(entry);
  if (!lockUntil) return false;
  return now >= lockUntil;
};

function parseInitData(initData) {
  if (!initData || typeof initData !== 'string') {
    return { ok: false, status: 400, error: 'no_initData' };
  }

  const params = new URLSearchParams(initData);
  const hash = params.get('hash');
  if (!hash) return { ok: false, status: 400, error: 'no_hash' };

  const pairs = [];
  for (const [k, v] of params.entries()) if (k !== 'hash') pairs.push(`${k}=${v}`);
  pairs.sort();
  const dataCheckString = pairs.join('\n');

  const botToken = process.env.BOT_TOKEN;
  if (!botToken) return { ok: false, status: 500, error: 'no_bot_token' };

  const secretKey = crypto.createHmac('sha256', 'WebAppData').update(botToken).digest();
  const calcHash = crypto.createHmac('sha256', secretKey).update(dataCheckString).digest('hex');

  if (calcHash !== hash) return { ok: false, status: 401, error: 'bad_hash' };

  const userStr = params.get('user');
  const user = userStr ? JSON.parse(userStr) : null;
  const tg_id = user?.id ? Number(user.id) : null;
  if (!tg_id) return { ok: false, status: 400, error: 'no_tg_id' };

  return { ok: true, user, tg_id };
}

function parseMobileToken(token) {
  if (!token || typeof token !== 'string') {
    return { ok: false, status: 401, error: 'no_token' };
  }
  const parts = token.split('.');
  if (parts.length !== 2) return { ok: false, status: 401, error: 'bad_token' };
  if (!MOBILE_TOKEN_SECRET) return { ok: false, status: 500, error: 'no_mobile_secret' };
  const [body, sig] = parts;
  const calc = crypto
    .createHmac('sha256', MOBILE_TOKEN_SECRET)
    .update(body)
    .digest('base64url');
  if (calc !== sig) return { ok: false, status: 401, error: 'bad_token' };
  try {
    const payload = JSON.parse(Buffer.from(body, 'base64url').toString('utf8'));
    const tg_id = payload?.tg_id ? Number(payload.tg_id) : null;
    if (!Number.isFinite(tg_id)) return { ok: false, status: 401, error: 'bad_tg_id' };
    const user = payload?.user || null;
    return { ok: true, tg_id, payload, user };
  } catch (_) {
    return { ok: false, status: 401, error: 'bad_token_body' };
  }
}

function getAuthFromRequest(req) {
  const header = req.headers?.authorization || '';
  const bearer = header.startsWith('Bearer ') ? header.slice(7).trim() : '';
  const token = bearer || req.query?.token || req.body?.token || null;
  if (token) {
    const parsed = parseMobileToken(token);
    if (!parsed.ok) return parsed;
    return { ok: true, tg_id: parsed.tg_id, user: parsed.user || null, source: 'token' };
  }
  const initData = req.body?.initData || req.query?.initData || null;
  const parsed = parseInitData(initData);
  if (!parsed.ok) return parsed;
  return { ok: true, tg_id: parsed.tg_id, user: parsed.user, source: 'initData' };
}

const ensureUserRecord = async (parsed) => {
  const updates = {};
  if (parsed.user?.username) updates.username = parsed.user.username;
  if (parsed.user?.first_name) updates.first_name = parsed.user.first_name;
  if (parsed.user?.last_name) updates.last_name = parsed.user.last_name;
  if (parsed.user?.photo_url) updates.photo_url = parsed.user.photo_url;

  return prisma.user.upsert({
    where: { tg_id: Number(parsed.tg_id) },
    update: updates,
    create: {
      tg_id: Number(parsed.tg_id),
      username: parsed.user?.username || null,
      first_name: parsed.user?.first_name || null,
      last_name: parsed.user?.last_name || null,
      photo_url: parsed.user?.photo_url || null
    }
  });
};

const TRANSLIT_MAP = {
  'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ё': 'e', 'ж': 'zh',
  'з': 'z', 'и': 'i', 'й': 'y', 'к': 'k', 'л': 'l', 'м': 'm', 'н': 'n', 'о': 'o',
  'п': 'p', 'р': 'r', 'с': 's', 'т': 't', 'у': 'u', 'ф': 'f', 'х': 'h', 'ц': 'ts',
  'ч': 'ch', 'ш': 'sh', 'щ': 'sch', 'ъ': '', 'ы': 'y', 'ь': '', 'э': 'e', 'ю': 'yu',
  'я': 'ya'
};

function slugify(value) {
  if (!value) return '';
  const lowered = String(value).toLowerCase();
  let out = '';
  for (const ch of lowered) {
    if (TRANSLIT_MAP[ch] !== undefined) {
      out += TRANSLIT_MAP[ch];
      continue;
    }
    if ((ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9')) {
      out += ch;
      continue;
    }
    out += '-';
  }
  out = out.replace(/-+/g, '-').replace(/^-|-$/g, '');
  return out || `program-${Date.now()}`;
}

function cleanString(value) {
  if (typeof value !== 'string') return '';
  return value.trim();
}

function optionalString(value) {
  const trimmed = cleanString(value);
  return trimmed ? trimmed : null;
}

const LEGACY_OPTIMAL_TARIFF = 'Выгодный';
const ALLOWED_TARIFFS = ['Базовый', 'Оптимальный', 'Максимум'];
const PAID_TARIFFS = Array.from(new Set([...ALLOWED_TARIFFS, LEGACY_OPTIMAL_TARIFF]));

function normalizeTariffName(value) {
  const cleaned = cleanString(value);
  if (cleaned === LEGACY_OPTIMAL_TARIFF) return 'Оптимальный';
  return cleaned;
}

function isChatTariffName(value) {
  const name = normalizeTariffName(value);
  const lower = String(name || '').toLowerCase();
  return lower.includes('оптим') || lower.includes('максим');
}

function isTariffActive(expiresAt) {
  if (!expiresAt) return true;
  return new Date(expiresAt) > new Date();
}

function normalizeTariffList(value) {
  const list = Array.isArray(value) ? value : [];
  const unique = new Set();
  list.forEach((item) => {
    const cleaned = normalizeTariffName(item);
    if (ALLOWED_TARIFFS.includes(cleaned)) unique.add(cleaned);
  });
  return Array.from(unique);
}

function expandTariffFilter(value) {
  const cleaned = normalizeTariffName(value);
  if (!cleaned) return [];
  if (cleaned === 'Оптимальный') return ['Оптимальный', LEGACY_OPTIMAL_TARIFF];
  return [cleaned];
}

function normalizeTariffs(value) {
  if (!Array.isArray(value)) return [];
  const unique = new Set();
  value.forEach((item) => {
    const cleaned = normalizeTariffName(item);
    if (ALLOWED_TARIFFS.includes(cleaned)) {
      unique.add(cleaned);
    }
  });
  return Array.from(unique);
}

const TARIFF_CODE_TO_NAME = {
  base: 'Базовый',
  optimal: 'Оптимальный',
  maximum: 'Максимум'
};

function normalizeTariffCode(value) {
  if (!value) return '';
  const raw = String(value).trim().toLowerCase();
  if (raw === 'base' || raw.includes('баз')) return 'base';
  if (raw === 'optimal' || raw.includes('оптим')) return 'optimal';
  if (raw === 'maximum' || raw.includes('макс')) return 'maximum';
  return '';
}

function tariffNameFromCode(code) {
  return TARIFF_CODE_TO_NAME[code] || '';
}

const TARIFF_PRICE_RUB = {
  base: Number(process.env.TARIFF_PRICE_BASE_RUB || 1000),
  optimal: Number(process.env.TARIFF_PRICE_OPTIMAL_RUB || 5000),
  maximum: Number(process.env.TARIFF_PRICE_MAX_RUB || 15000)
};

function formatRubAmount(value) {
  const num = Number(value);
  const safe = Number.isFinite(num) && num > 0 ? num : 1;
  return safe.toFixed(2);
}

async function applyTariffToUser(userId, tariffCode) {
  const tariffName = tariffNameFromCode(tariffCode);
  if (!tariffName) return null;
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { tariffExpiresAt: true }
  });
  const now = new Date();
  const base = isTariffActive(user?.tariffExpiresAt)
    ? new Date(user.tariffExpiresAt)
    : now;
  const expiresAt = new Date(base.getTime() + TARIFF_PERIOD_DAYS * 24 * 60 * 60 * 1000);
  return prisma.user.update({
    where: { id: userId },
    data: { tariffName, tariffExpiresAt: expiresAt }
  });
}

function yookassaRequest(method, path, payload, idempotenceKey) {
  return new Promise((resolve, reject) => {
    if (!YOOKASSA_SHOP_ID || !YOOKASSA_SECRET_KEY) {
      return reject(new Error('yookassa_disabled'));
    }
    const auth = Buffer.from(`${YOOKASSA_SHOP_ID}:${YOOKASSA_SECRET_KEY}`).toString('base64');
    const body = payload ? JSON.stringify(payload) : '';
    const req = https.request(
      {
        method,
        hostname: 'api.yookassa.ru',
        path: `/v3${path}`,
        headers: {
          Authorization: `Basic ${auth}`,
          'Content-Type': 'application/json',
          'Content-Length': body ? Buffer.byteLength(body) : 0,
          ...(idempotenceKey ? { 'Idempotence-Key': idempotenceKey } : {})
        }
      },
      (res) => {
        let data = '';
        res.setEncoding('utf8');
        res.on('data', (chunk) => {
          data += chunk;
        });
        res.on('end', () => {
          if (!res.statusCode || res.statusCode < 200 || res.statusCode >= 300) {
            return reject(new Error(`yookassa_http_${res.statusCode || 0}`));
          }
          try {
            resolve(data ? JSON.parse(data) : {});
          } catch (err) {
            reject(err);
          }
        });
      }
    );
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

const buildGuestTariffConditions = () => ([
  { tariffName: null },
  { tariffName: '' },
  { tariffName: { notIn: PAID_TARIFFS } }
]);

const buildRecipientsWhere = ({ trainingMode, tariffFilters, guestAccess }) => {
  const where = { role: 'user' };
  if (trainingMode) where.trainingMode = trainingMode;
  const filters = Array.isArray(tariffFilters) ? tariffFilters.filter(Boolean) : [];
  if (filters.length) {
    if (guestAccess) {
      where.OR = [{ tariffName: { in: filters } }, ...buildGuestTariffConditions()];
    } else {
      where.tariffName = { in: filters };
    }
  } else if (!guestAccess) {
    where.tariffName = { in: PAID_TARIFFS };
  }
  return where;
};

const DEFAULT_MUSCLE = "\u041e\u0431\u0449\u0430\u044f";
const CROSSFIT_TYPES = ['dumbbells', 'barbell', 'kettlebells', 'free'];

function normalizeMuscles(value) {
  const list = Array.isArray(value) ? value : (value ? [value] : []);
  const unique = new Set();
  list.forEach((item) => {
    const cleaned = cleanString(item);
    if (cleaned) unique.add(cleaned);
  });
  return Array.from(unique);
}

function normalizeCrossfitType(value) {
  const cleaned = cleanString(value);
  return CROSSFIT_TYPES.includes(cleaned) ? cleaned : '';
}


const TRAINER_SCOPES = ['gym', 'crossfit', 'both'];

function normalizeTrainerScope(value) {
  return TRAINER_SCOPES.includes(value) ? value : 'both';
}

const AUTO_ASSIGN_HOURS = Number(process.env.AUTO_ASSIGN_HOURS || 12);
const AUTO_ASSIGN_INTERVAL_MS = Number(process.env.AUTO_ASSIGN_INTERVAL_MS || 10 * 60 * 1000);
const AUTO_ASSIGN_MIN_AGE_MS = Math.max(0, AUTO_ASSIGN_HOURS) * 60 * 60 * 1000;

const NOTIFICATION_TYPES = ['nutrition_comment', 'program_available', 'exercise_available', 'chat_message', 'curator_assigned', 'weight_reminder'];

const buildNotificationPreview = (text, limit = 160) => {
  const cleaned = cleanString(text);
  if (!cleaned) return null;
  if (cleaned.length <= limit) return cleaned;
  return `${cleaned.slice(0, limit).trim()}...`;
};

const pickRandom = (items) => {
  if (!items || items.length === 0) return null;
  return items[Math.floor(Math.random() * items.length)];
};

const buildCuratorPools = (curators) => {
  const pools = { gym: [], crossfit: [], both: [] };
  curators.forEach((curator) => {
    const scope = normalizeTrainerScope(curator.trainerScope);
    pools[scope].push(curator.id);
  });
  return pools;
};

const pickCuratorForMode = (pools, mode) => {
  const normalized = mode === 'crossfit' ? 'crossfit' : 'gym';
  const candidates = pools[normalized].concat(pools.both);
  return pickRandom(candidates);
};

async function autoAssignCurators() {
  if (!AUTO_ASSIGN_MIN_AGE_MS) return;
  try {
    const cutoff = new Date(Date.now() - AUTO_ASSIGN_MIN_AGE_MS);
    const clients = await prisma.user.findMany({
      where: {
        trainerId: null,
        role: 'user',
        isCurator: false,
        createdAt: { lte: cutoff }
      },
      select: { id: true, trainingMode: true, tariffName: true, tariffExpiresAt: true }
    });
    if (!clients.length) return;

    const curators = await prisma.user.findMany({
      where: {
        OR: [
          { role: { in: ['curator', 'admin', 'sadmin'] } },
          { isCurator: true }
        ]
      },
      select: { id: true, trainerScope: true, first_name: true, last_name: true, username: true }
    });
    if (!curators.length) return;

    const curatorById = new Map(curators.map((curator) => [curator.id, curator]));
    const pools = buildCuratorPools(curators);
    for (const client of clients) {
      const curatorId = pickCuratorForMode(pools, client.trainingMode);
      if (!curatorId) continue;
      const updated = await prisma.user.updateMany({
        where: { id: client.id, trainerId: null },
        data: { trainerId: curatorId }
      });
      if (updated.count && isChatTariffName(client.tariffName) && isTariffActive(client.tariffExpiresAt)) {
        const curator = curatorById.get(curatorId);
        const curatorName = curator
          ? [curator.first_name, curator.last_name].filter(Boolean).join(' ') || curator.username
          : null;
        const message = curatorName
          ? `Вам назначен куратор: ${curatorName}. Теперь доступен чат с куратором.`
          : 'Вам назначен куратор. Теперь доступен чат с куратором.';
        await createNotificationsForUsers([client.id], { type: 'curator_assigned', message });
      }
    }
  } catch (e) {
    console.error('[auto-assign] error', e);
  }
}

function startAutoAssign() {
  if (!AUTO_ASSIGN_MIN_AGE_MS || AUTO_ASSIGN_INTERVAL_MS <= 0) return;
  autoAssignCurators();
  setInterval(autoAssignCurators, AUTO_ASSIGN_INTERVAL_MS);
}

let weightReminderRunning = false;
const isWithinReminderWindow = (now, offsetMin) => {
  const offset = Number.isFinite(offsetMin) ? offsetMin : 0;
  const local = new Date(now.getTime() - offset * 60000);
  const hour = local.getUTCHours();
  const minute = local.getUTCMinutes();
  if (hour !== WEIGHT_REMINDER_HOUR) return false;
  return minute >= WEIGHT_REMINDER_MINUTE && minute < WEIGHT_REMINDER_MINUTE + WEIGHT_REMINDER_WINDOW_MIN;
};

const runWeightReminders = async () => {
  if (weightReminderRunning) return;
  weightReminderRunning = true;
  try {
    const now = new Date();
    const users = await prisma.user.findMany({
      where: { role: 'user', isCurator: false },
      select: { id: true, timezoneOffsetMin: true, weightReminderAt: true, tariffName: true }
    });

    for (const user of users) {
      if (!isWithinReminderWindow(now, user.timezoneOffsetMin)) continue;
      const currentWeek = getWeekStartKeyWithOffset(now, user.timezoneOffsetMin);
      const reminderWeek = user.weightReminderAt
        ? getWeekStartKeyWithOffset(new Date(user.weightReminderAt), user.timezoneOffsetMin)
        : null;
      if (reminderWeek === currentWeek) continue;

      const existing = await prisma.weightLog.findUnique({
        where: { userId_weekStart: { userId: user.id, weekStart: currentWeek } },
        select: { id: true }
      });
      if (existing) continue;

      await createNotificationsForUsers([user.id], {
        type: 'weight_reminder',
        title: '\u0414\u0438\u043d\u0430\u043c\u0438\u043a\u0430 \u0432\u0435\u0441\u0430',
        message: '\u041f\u043e\u0440\u0430 \u0432\u043d\u0435\u0441\u0442\u0438 \u0432\u0435\u0441 \u0438 \u0444\u043e\u0442\u043e \u0437\u0430\u043c\u0435\u0440\u043e\u0432 \u0437\u0430 \u043d\u0435\u0434\u0435\u043b\u044e.'
      });

      await prisma.user.update({
        where: { id: user.id },
        data: { weightReminderAt: now }
      });
    }
  } catch (e) {
    console.error('[weight-reminder] error', e);
  } finally {
    weightReminderRunning = false;
  }
};

function startWeightReminders() {
  if (WEIGHT_REMINDER_INTERVAL_MS <= 0) return;
  runWeightReminders();
  const timer = setInterval(runWeightReminders, WEIGHT_REMINDER_INTERVAL_MS);
  if (typeof timer.unref === 'function') timer.unref();
}

let chatCleanupRunning = false;
const runChatCleanup = async () => {
  if (chatCleanupRunning) return;
  chatCleanupRunning = true;
  try {
    if (CHAT_RETENTION_DAYS <= 0) return;
    const cutoff = new Date(Date.now() - CHAT_RETENTION_DAYS * 24 * 60 * 60 * 1000);
    while (true) {
      const messages = await prisma.chatMessage.findMany({
        where: { createdAt: { lt: cutoff } },
        select: { id: true, mediaKey: true },
        orderBy: { id: 'asc' },
        take: CHAT_CLEANUP_BATCH_SIZE
      });
      if (!messages.length) break;

      const deleteIds = [];
      for (const message of messages) {
        if (message.mediaKey) {
          const deleted = await deleteObjectKey(message.mediaKey);
          if (!deleted) continue;
        }
        deleteIds.push(message.id);
      }

      if (!deleteIds.length) break;

      await prisma.chatMessage.deleteMany({
        where: { id: { in: deleteIds } }
      });

      if (messages.length < CHAT_CLEANUP_BATCH_SIZE) break;
    }
  } catch (e) {
    console.error('[chat-cleanup] error', e);
  } finally {
    chatCleanupRunning = false;
  }
};

function startChatCleanup() {
  if (CHAT_CLEANUP_INTERVAL_MS <= 0 || CHAT_RETENTION_DAYS <= 0) return;
  runChatCleanup();
  const timer = setInterval(runChatCleanup, CHAT_CLEANUP_INTERVAL_MS);
  if (typeof timer.unref === 'function') timer.unref();
}

const CHAT_MAX_UPLOAD_MB = Number(process.env.CHAT_MAX_UPLOAD_MB || 50);
const CHAT_MAX_UPLOAD_BYTES = Math.round(CHAT_MAX_UPLOAD_MB * 1024 * 1024);
const CHAT_SIGNED_URL_TTL = Number(process.env.CHAT_SIGNED_URL_TTL || 900);
const YOOKASSA_SHOP_ID = process.env.YOOKASSA_SHOP_ID || '';
const YOOKASSA_SECRET_KEY = process.env.YOOKASSA_SECRET_KEY || '';
const PAYMENT_RETURN_URL = process.env.PAYMENT_RETURN_URL || `${APP_AUTH_SCHEME}://payment`;
const TARIFF_PERIOD_DAYS = Number(process.env.TARIFF_PERIOD_DAYS || 30);
const WEIGHT_REMINDER_INTERVAL_MS = Number(process.env.WEIGHT_REMINDER_INTERVAL_MS || 300000);
const WEIGHT_REMINDER_HOUR = Number(process.env.WEIGHT_REMINDER_HOUR || 15);
const WEIGHT_REMINDER_MINUTE = Number(process.env.WEIGHT_REMINDER_MINUTE || 0);
const WEIGHT_REMINDER_WINDOW_MIN = Number(process.env.WEIGHT_REMINDER_WINDOW_MIN || 15);
const CHAT_RETENTION_DAYS_RAW = Number(process.env.CHAT_RETENTION_DAYS || 20);
const CHAT_RETENTION_DAYS = Number.isFinite(CHAT_RETENTION_DAYS_RAW) ? CHAT_RETENTION_DAYS_RAW : 20;
const CHAT_CLEANUP_INTERVAL_MS = Number(process.env.CHAT_CLEANUP_INTERVAL_MS || 6 * 60 * 60 * 1000);
const CHAT_CLEANUP_BATCH_SIZE_RAW = Number(process.env.CHAT_CLEANUP_BATCH_SIZE || 200);
const CHAT_CLEANUP_BATCH_SIZE = Number.isFinite(CHAT_CLEANUP_BATCH_SIZE_RAW)
  ? Math.max(20, Math.min(CHAT_CLEANUP_BATCH_SIZE_RAW, 1000))
  : 200;
const WEIGHT_EDIT_HOURS_RAW = Number(process.env.WEIGHT_EDIT_HOURS || 24);
const WEIGHT_EDIT_HOURS = Number.isFinite(WEIGHT_EDIT_HOURS_RAW) ? WEIGHT_EDIT_HOURS_RAW : 24;
const WEIGHT_EDIT_WINDOW_MS = Math.max(1, WEIGHT_EDIT_HOURS) * 60 * 60 * 1000;
const MEASUREMENT_EDIT_DAYS_RAW = Number(process.env.MEASUREMENT_EDIT_DAYS || 3);
const MEASUREMENT_EDIT_DAYS = Number.isFinite(MEASUREMENT_EDIT_DAYS_RAW) ? MEASUREMENT_EDIT_DAYS_RAW : 3;
const MEASUREMENT_EDIT_WINDOW_MS = Math.max(1, MEASUREMENT_EDIT_DAYS) * 24 * 60 * 60 * 1000;
const CACHE_CONTROL_PUBLIC_LONG = 'public, max-age=31536000, immutable';
const CACHE_CONTROL_PRIVATE = 'private, max-age=3600';
const CACHE_CONTROL_NO_STORE = 'no-store';

const S3_BUCKET = process.env.S3_BUCKET || '';
const S3_ENDPOINT = process.env.S3_ENDPOINT || 'https://s3.twcstorage.ru';
const S3_REGION = process.env.S3_REGION || 'ru-1';
const S3_ACCESS_KEY = process.env.S3_ACCESS_KEY || '';
const S3_SECRET_KEY = process.env.S3_SECRET_KEY || '';
const S3_FORCE_PATH_STYLE = process.env.S3_FORCE_PATH_STYLE !== '0';
const S3_PUBLIC_URL = process.env.S3_PUBLIC_URL || '';

let s3Client = null;

const getS3Client = () => {
  if (!S3_BUCKET || !S3_ACCESS_KEY || !S3_SECRET_KEY) return null;
  if (!s3Client) {
    s3Client = new S3Client({
      region: S3_REGION,
      endpoint: S3_ENDPOINT,
      forcePathStyle: S3_FORCE_PATH_STYLE,
      credentials: {
        accessKeyId: S3_ACCESS_KEY,
        secretAccessKey: S3_SECRET_KEY
      }
    });
  }
  return s3Client;
};

const sanitizeFileName = (name) => {
  if (!name) return '';
  const base = path.basename(String(name));
  return base.replace(/[^\w.\-]+/g, '_').slice(0, 120);
};

const buildChatObjectKey = (threadId, fileName) => {
  const safeName = sanitizeFileName(fileName) || 'video.mp4';
  const suffix = crypto.randomBytes(6).toString('hex');
  return `chat/${threadId}/${Date.now()}-${suffix}-${safeName}`;
};

const buildMediaObjectKey = (prefix, fileName) => {
  const safeName = sanitizeFileName(fileName) || 'file';
  const suffix = crypto.randomBytes(6).toString('hex');
  const base = String(prefix || '').replace(/\/+$/, '');
  return `${base}/${Date.now()}-${suffix}-${safeName}`;
};

const getPublicObjectUrl = (key) => {
  if (!key) return null;
  if (S3_PUBLIC_URL) return `${S3_PUBLIC_URL.replace(/\/+$/, '')}/${key}`;
  if (!S3_BUCKET || !S3_ENDPOINT) return null;
  return `${S3_ENDPOINT.replace(/\/+$/, '')}/${S3_BUCKET}/${key}`;
};

const getSignedPutUrl = async ({ key, contentType, contentLength, cacheControl }) => {
  const client = getS3Client();
  if (!client || !key) return null;
  const command = new PutObjectCommand({
    Bucket: S3_BUCKET,
    Key: key,
    ContentType: contentType,
    ContentLength: contentLength,
    ...(cacheControl ? { CacheControl: cacheControl } : {})
  });
  return getSignedUrl(client, command, { expiresIn: CHAT_SIGNED_URL_TTL });
};

const getSignedGetUrl = async (key) => {
  const client = getS3Client();
  if (!client || !key) return null;
  const command = new GetObjectCommand({
    Bucket: S3_BUCKET,
    Key: key
  });
  return getSignedUrl(client, command, { expiresIn: CHAT_SIGNED_URL_TTL });
};

const deleteObjectKey = async (key) => {
  const client = getS3Client();
  if (!client || !key) return false;
  try {
    const command = new DeleteObjectCommand({ Bucket: S3_BUCKET, Key: key });
    await client.send(command);
    return true;
  } catch (e) {
    console.warn('[storage] delete failed', e?.message || e);
    return false;
  }
};

const APP_URL_RAW = process.env.APP_URL || '';
const ADMIN_URL_RAW = process.env.ADMIN_URL || '';
const APP_VERSION = process.env.APP_VERSION || '';
const APP_UPDATE_VERSION_CODE = Number(process.env.APP_UPDATE_VERSION_CODE || 0);
const APP_UPDATE_VERSION_NAME = process.env.APP_UPDATE_VERSION_NAME || APP_VERSION || '';
const APP_UPDATE_MIN_CODE = Number(process.env.APP_UPDATE_MIN_CODE || 0);
const APP_UPDATE_URL = process.env.APP_UPDATE_URL || '';
const APP_UPDATE_JSON_KEY = process.env.APP_UPDATE_JSON_KEY || 'updates/latest.json';
const APP_UPDATE_JSON_URL = process.env.APP_UPDATE_JSON_URL || '';
const APP_UPDATE_JSON_TTL_MS = Number(process.env.APP_UPDATE_JSON_TTL_MS || 60_000);

let appUpdateCache = { ts: 0, data: null };
const buildAppUpdateJsonUrl = () => {
  if (APP_UPDATE_JSON_URL) return APP_UPDATE_JSON_URL;
  if (!APP_UPDATE_JSON_KEY) return '';
  return getPublicObjectUrl(APP_UPDATE_JSON_KEY) || '';
};

const getAppUpdatePayload = async () => {
  const url = buildAppUpdateJsonUrl();
  if (!url) return null;
  const now = Date.now();
  if (appUpdateCache.data && now - appUpdateCache.ts < APP_UPDATE_JSON_TTL_MS) {
    return appUpdateCache.data;
  }
  try {
    const data = await fetchJson(url);
    appUpdateCache = { ts: now, data };
    return data;
  } catch (e) {
    console.warn('[app-update] fetch failed', e?.message || e);
    appUpdateCache = { ts: now, data: null };
    return null;
  }
};

const appendQueryParams = (url, params) => {
  if (!url) return '';
  try {
    const parsed = new URL(url);
    Object.entries(params || {}).forEach(([key, value]) => {
      if (value === null || value === undefined || value === '') return;
      parsed.searchParams.set(key, String(value));
    });
    return parsed.toString();
  } catch (e) {
    return url;
  }
};

const buildAdminClientUrl = (appUrl) => {
  if (!appUrl) return '';
  try {
    const parsed = new URL(appUrl);
    const path = parsed.pathname || '/';
    const basePath = path.endsWith('.html') ? path.replace(/\/[^/]+$/, '') : path.replace(/\/$/, '');
    parsed.pathname = `${basePath}/admin_client.html`;
    return parsed.toString();
  } catch (e) {
    return '';
  }
};

const getChatWebAppUrl = ({ recipientIsCurator, clientId }) => {
  const base = recipientIsCurator
    ? buildAdminClientUrl(ADMIN_URL_RAW || APP_URL_RAW)
    : APP_URL_RAW;
  if (!base) return null;
  const params = { openChat: '1' };
  if (recipientIsCurator && clientId) params.clientId = String(clientId);
  if (APP_VERSION) params.v = APP_VERSION;
  return appendQueryParams(base, params);
};

const buildTelegramNotificationText = (payload) => {
  const type = NOTIFICATION_TYPES.includes(payload?.type) ? payload.type : 'program_available';
  const title = optionalString(payload?.title);
  const message = optionalString(payload?.message);

  if (type === 'nutrition_comment') {
    if (message) return `\u041a\u043e\u043c\u043c\u0435\u043d\u0442\u0430\u0440\u0438\u0439 \u043f\u043e \u043f\u0438\u0442\u0430\u043d\u0438\u044e:\n${message}`;
    return '\u041d\u043e\u0432\u044b\u0439 \u043a\u043e\u043c\u043c\u0435\u043d\u0442\u0430\u0440\u0438\u0439 \u043f\u043e \u043f\u0438\u0442\u0430\u043d\u0438\u044e.';
  }

  if (type === 'program_available' || type === 'exercise_available') {
    const detail = message || title;
    return detail
      ? `\u0423 \u0432\u0430\u0441 \u043d\u043e\u0432\u043e\u0435 \u043e\u043f\u043e\u0432\u0435\u0449\u0435\u043d\u0438\u0435.\n${detail}`
      : '\u0423 \u0432\u0430\u0441 \u043d\u043e\u0432\u043e\u0435 \u043e\u043f\u043e\u0432\u0435\u0449\u0435\u043d\u0438\u0435.';
  }

  if (type === 'chat_message') {
    return title || '\u041d\u043e\u0432\u043e\u0435 \u0441\u043e\u043e\u0431\u0449\u0435\u043d\u0438\u0435 \u0432 \u0447\u0430\u0442\u0435.';
  }

  if (type === 'curator_assigned') {
    return message || '??? ???????? ???????. ?????? ???????? ??? ? ?????????.';
  }

  if (type === 'weight_reminder') {
    return message || '\u041f\u043e\u0440\u0430 \u0432\u043d\u0435\u0441\u0442\u0438 \u0432\u0435\u0441 \u0438 \u0444\u043e\u0442\u043e \u0437\u0430\u043c\u0435\u0440\u043e\u0432 \u0437\u0430 \u043d\u0435\u0434\u0435\u043b\u044e.';
  }

  if (title && message) return `${title}\n${message}`;
  return title || message || null;
};

const buildTelegramReplyMarkup = (payload) => {
  if (payload?.type !== 'chat_message') return null;
  const webAppUrl = payload?.webAppUrl;
  if (!webAppUrl) return null;
  return {
    inline_keyboard: [
      [
        {
          text: '\u041e\u0442\u043a\u0440\u044b\u0442\u044c \u0447\u0430\u0442',
          web_app: { url: webAppUrl }
        }
      ]
    ]
  };
};

async function sendTelegramNotifications(userIds, payload) {
  const ids = Array.isArray(userIds) ? userIds.filter((id) => Number.isInteger(id)) : [];
  if (!ids.length) return;

  const botToken = process.env.BOT_TOKEN;
  if (!botToken) return;

  const text = buildTelegramNotificationText(payload);
  if (!text) return;
  const replyMarkup = buildTelegramReplyMarkup(payload);

  try {
    const users = await prisma.user.findMany({
      where: { id: { in: ids } },
      select: { tg_id: true }
    });
    const url = `https://api.telegram.org/bot${botToken}/sendMessage`;
    await Promise.allSettled(
      users.map((user) => {
        if (user?.tg_id === null || user?.tg_id === undefined) return Promise.resolve();
        const chatId = typeof user.tg_id === 'bigint' ? user.tg_id.toString() : String(user.tg_id);
        const body = {
          chat_id: chatId,
          text,
          disable_web_page_preview: true
        };
        if (replyMarkup) body.reply_markup = replyMarkup;
        return postJson(url, body);
      })
    );
  } catch (e) {
    console.error('[telegram] notify failed', e);
  }
}

async function createNotificationsForUsers(userIds, payload) {
  const ids = Array.isArray(userIds) ? userIds.filter((id) => Number.isInteger(id)) : [];
  if (!ids.length) return;

  const type = NOTIFICATION_TYPES.includes(payload?.type) ? payload.type : 'program_available';
  const title = optionalString(payload?.title);
  const message = optionalString(payload?.message);
  const data = payload?.data ?? null;

  const rows = ids.map((userId) => ({
    userId,
    type,
    title,
    message,
    data
  }));

  await prisma.notification.createMany({ data: rows });
  await sendTelegramNotifications(ids, { type, title, message, data });
}

async function requireAdmin(initData) {
  const parsed = parseInitData(initData);
  if (!parsed.ok) return parsed;

  const user = await prisma.user.findUnique({
    where: { tg_id: Number(parsed.tg_id) },
    select: { role: true }
  });

  if (!user || (user.role !== 'admin' && user.role !== 'sadmin')) {
    return { ok: false, status: 403, error: 'forbidden' };
  }

  return { ok: true, tg_id: parsed.tg_id };
}

async function requireSuperAdmin(initData) {
  const parsed = parseInitData(initData);
  if (!parsed.ok) return parsed;

  const user = await prisma.user.findUnique({
    where: { tg_id: Number(parsed.tg_id) },
    select: { role: true }
  });

  if (!user || user.role !== 'sadmin') {
    return { ok: false, status: 403, error: 'forbidden' };
  }

  return { ok: true, tg_id: parsed.tg_id };
}

async function requireStaff(initData) {
  const parsed = parseInitData(initData);
  if (!parsed.ok) return parsed;

  const user = await prisma.user.findUnique({
    where: { tg_id: Number(parsed.tg_id) },
    select: { id: true, role: true, trainerScope: true, isCurator: true, first_name: true, last_name: true, username: true }
  });

  const isAdmin = user?.role === 'admin' || user?.role === 'sadmin';
  const isCurator = user?.role === 'curator' || Boolean(user?.isCurator);
  if (!user || (!['admin', 'sadmin', 'curator'].includes(user.role) && !isCurator)) {
    return { ok: false, status: 403, error: 'forbidden' };
  }

  return {
    ok: true,
    tg_id: parsed.tg_id,
    userId: user.id,
    role: user.role,
    trainerScope: normalizeTrainerScope(user.trainerScope),
    canTrain: isAdmin,
    canCurate: isAdmin || isCurator,
    user
  };
}

function buildUserDisplayName(user) {
  if (!user) return '';
  const fullName = [user.first_name, user.last_name].filter(Boolean).join(' ');
  return fullName || user.username || `Пользователь #${user.id}`;
}

async function getUserFromAuth(auth) {
  if (!auth?.ok) return auth || { ok: false, status: 401, error: 'unauthorized' };
  const user = await prisma.user.findUnique({
    where: { tg_id: Number(auth.tg_id) },
    select: {
      id: true,
      role: true,
      isCurator: true,
      trainerId: true,
      tariffName: true,
      tariffExpiresAt: true,
      first_name: true,
      last_name: true,
      username: true
    }
  });

  if (!user) {
    return { ok: false, status: 404, error: 'user_not_found' };
  }

  return { ok: true, user, tg_id: auth.tg_id };
}

async function getUserFromInitData(initData) {
  const parsed = parseInitData(initData);
  if (!parsed.ok) return parsed;
  return getUserFromAuth({ ok: true, tg_id: parsed.tg_id });
}

async function resolveChatContext(auth, clientId, ensureThread = true) {
  const authResult = await getUserFromAuth(auth);
  if (!authResult.ok) return authResult;

  const requester = authResult.user;
  const requesterIsCurator = requester.role === 'curator' || requester.isCurator;
  const isClient = requester.role === 'user' && !requesterIsCurator;

  let client = null;
  let curator = null;

  if (isClient) {
    if (!requester.trainerId) {
      return { ok: false, status: 400, error: 'no_curator' };
    }
    client = requester;
    curator = await prisma.user.findUnique({
      where: { id: requester.trainerId },
      select: { id: true, first_name: true, last_name: true, username: true }
    });
    if (!curator) {
      return { ok: false, status: 404, error: 'curator_not_found' };
    }
  } else {
    if (!clientId || !Number.isInteger(clientId)) {
      return { ok: false, status: 400, error: 'missing_client_id' };
    }
      client = await prisma.user.findUnique({
        where: { id: clientId },
        select: {
          id: true,
          trainerId: true,
          role: true,
          isCurator: true,
          tariffName: true,
          tariffExpiresAt: true,
          first_name: true,
          last_name: true,
          username: true
        }
      });
    if (!client) return { ok: false, status: 404, error: 'client_not_found' };
    if (client.role !== 'user' || client.isCurator) {
      return { ok: false, status: 400, error: 'invalid_client' };
    }
    if (!client.trainerId) {
      return { ok: false, status: 400, error: 'no_curator' };
    }
    if (client.trainerId !== requester.id) {
      return { ok: false, status: 403, error: 'forbidden' };
    }
    curator = await prisma.user.findUnique({
      where: { id: client.trainerId },
      select: { id: true, first_name: true, last_name: true, username: true }
    });
    if (!curator) {
      return { ok: false, status: 404, error: 'curator_not_found' };
    }
  }

  let thread = await prisma.chatThread.findUnique({
    where: { clientId_curatorId: { clientId: client.id, curatorId: curator.id } }
  });

  if (!thread && ensureThread) {
    thread = await prisma.chatThread.create({
      data: { clientId: client.id, curatorId: curator.id }
    });
  }

  return {
    ok: true,
    requester,
    client,
    curator,
    thread,
    isClient
  };
}

const CHAT_NOTIFY_DELAYS_MS = [
  0,
  10 * 60 * 1000,
  60 * 60 * 1000,
  3 * 60 * 60 * 1000,
  6 * 60 * 60 * 1000
];

const notifyChatIfUnread = async ({ messageId, recipientId, title, webAppUrl }) => {
  try {
    const message = await prisma.chatMessage.findUnique({
      where: { id: messageId },
      select: { readAt: true }
    });
    if (!message || message.readAt) return;
    await sendTelegramNotifications([recipientId], {
      type: 'chat_message',
      title,
      message: null,
      webAppUrl
    });
  } catch (e) {
    console.error('[chat] notify failed', e);
  }
};

const scheduleChatNotification = ({ messageId, recipientId, title, webAppUrl }) => {
  CHAT_NOTIFY_DELAYS_MS.forEach((delay) => {
    if (delay === 0) {
      void notifyChatIfUnread({ messageId, recipientId, title, webAppUrl });
      return;
    }
    setTimeout(() => {
      void notifyChatIfUnread({ messageId, recipientId, title, webAppUrl });
    }, delay);
  });
};

const PROGRAM_SEED = [
  {
    slug: 'crossfit-busy-fullbody',
    type: 'crossfit',
    title: 'Для самых занятых: программа на все тело',
    subtitle: 'Кроссфит • Фуллбоди',
    summary: 'Короткие, но плотные тренировки для старта и тонуса.',
    description: 'Тренировочная программа на все тело для новичков. Компактные занятия помогают включить все группы мышц, развить выносливость и сформировать привычку тренироваться регулярно.',
    level: 'Новички',
    gender: 'Универсальная',
    frequency: '3 трен/нед',
    weeksCount: 4,
    coverImage: 'crossfit-amber',
    authorName: 'Тестов Тест Тестович',
    authorRole: 'Куратор Fit Dew',
    authorAvatar: null,
    weeks: [
      {
        index: 1,
        title: 'Неделя 1',
        workouts: [
          {
            index: 1,
            title: 'Тренировка 1',
            description: 'Круговая работа, 3 раунда.',
            exercises: [
              { order: 1, label: '1a', title: 'Бёрпи', details: '30 сек' },
              { order: 2, label: '1b', title: 'Приседания с собственным весом', details: '20 повторов' },
              { order: 3, label: '2a', title: 'Отжимания', details: '12 повторов' },
              { order: 4, label: '2b', title: 'Планка', details: '40 сек' },
              { order: 5, label: '3a', title: 'Махи гирей', details: '15 повторов' },
              { order: 6, label: '3b', title: 'Скручивания', details: '15 повторов' },
              { order: 7, label: '4', title: 'Бег на месте с высоким подъемом колен', details: '60 сек' }
            ]
          },
          {
            index: 2,
            title: 'Тренировка 2',
            description: 'Силовая + кардио.',
            exercises: [
              { order: 1, label: '1a', title: 'Тяга гантели в наклоне', details: '12 повторов' },
              { order: 2, label: '1b', title: 'Прыжки на тумбу', details: '10 повторов' },
              { order: 3, label: '2a', title: 'Выпады назад', details: '12 повторов' },
              { order: 4, label: '2b', title: 'Русские скручивания', details: '20 повторов' },
              { order: 5, label: '3a', title: 'Тяга резинки к поясу', details: '15 повторов' },
              { order: 6, label: '3b', title: 'Планка боковая', details: '30 сек на сторону' },
              { order: 7, label: '4', title: 'Фермерская ходьба', details: '40 сек' }
            ]
          }
        ]
      },
      {
        index: 2,
        title: 'Неделя 2',
        workouts: [
          {
            index: 1,
            title: 'Тренировка 1',
            description: 'Интервалы 20/10.',
            exercises: [
              { order: 1, label: '1a', title: 'Джампинг-джек', details: '60 сек' },
              { order: 2, label: '1b', title: 'Приседания сумо', details: '18 повторов' },
              { order: 3, label: '2a', title: 'Отжимания с колен', details: '12 повторов' },
              { order: 4, label: '2b', title: 'Сит-ап', details: '15 повторов' },
              { order: 5, label: '3a', title: 'Гребля (или имитация)', details: '1 мин' },
              { order: 6, label: '3b', title: 'Планка', details: '45 сек' },
              { order: 7, label: '4', title: 'Бёрпи', details: '10 повторов' }
            ]
          },
          {
            index: 2,
            title: 'Тренировка 2',
            description: 'Выносливость + сила.',
            exercises: [
              { order: 1, label: '1a', title: 'Тяга гантели в опоре', details: '12 повторов' },
              { order: 2, label: '1b', title: 'Махи гирей', details: '20 повторов' },
              { order: 3, label: '2a', title: 'Приседания плие', details: '15 повторов' },
              { order: 4, label: '2b', title: 'Подъемы колен в упоре', details: '15 повторов' },
              { order: 5, label: '3a', title: 'Прыжки через линию', details: '40 сек' },
              { order: 6, label: '3b', title: 'Отжимания узким хватом', details: '10 повторов' },
              { order: 7, label: '4', title: 'Бег 400 м (или 2 мин)', details: '' }
            ]
          }
        ]
      },
      {
        index: 3,
        title: 'Неделя 3',
        workouts: [
          {
            index: 1,
            title: 'Тренировка 1',
            description: 'Силовой фокус + кор.',
            exercises: [
              { order: 1, label: '1a', title: 'Приседания с паузой', details: '12 повторов' },
              { order: 2, label: '1b', title: 'Тяга сумо с гирей', details: '12 повторов' },
              { order: 3, label: '2a', title: 'Отжимания', details: '14 повторов' },
              { order: 4, label: '2b', title: 'Планка на локтях', details: '50 сек' },
              { order: 5, label: '3a', title: 'Выпады в стороны', details: '12 повторов' },
              { order: 6, label: '3b', title: 'Скручивания велосипед', details: '20 повторов' },
              { order: 7, label: '4', title: 'Бёрпи', details: '12 повторов' }
            ]
          },
          {
            index: 2,
            title: 'Тренировка 2',
            description: 'Смешанный формат.',
            exercises: [
              { order: 1, label: '1a', title: 'Тяга гантели к поясу', details: '12 повторов' },
              { order: 2, label: '1b', title: 'Прыжки на месте', details: '45 сек' },
              { order: 3, label: '2a', title: 'Присед + жим', details: '12 повторов' },
              { order: 4, label: '2b', title: 'Альпинист', details: '40 сек' },
              { order: 5, label: '3a', title: 'Румынская тяга с гантелями', details: '12 повторов' },
              { order: 6, label: '3b', title: 'Планка боковая', details: '35 сек' },
              { order: 7, label: '4', title: 'Скакалка', details: '2 мин' }
            ]
          }
        ]
      },
      {
        index: 4,
        title: 'Неделя 4',
        workouts: [
          {
            index: 1,
            title: 'Тренировка 1',
            description: 'Итоговая неделя.',
            exercises: [
              { order: 1, label: '1a', title: 'Тяга в наклоне', details: '14 повторов' },
              { order: 2, label: '1b', title: 'Прыжки звездочкой', details: '50 сек' },
              { order: 3, label: '2a', title: 'Приседания', details: '20 повторов' },
              { order: 4, label: '2b', title: 'Скручивания', details: '20 повторов' },
              { order: 5, label: '3a', title: 'Махи гирей', details: '20 повторов' },
              { order: 6, label: '3b', title: 'Планка', details: '60 сек' },
              { order: 7, label: '4', title: 'Бёрпи', details: '14 повторов' }
            ]
          },
          {
            index: 2,
            title: 'Тренировка 2',
            description: 'Кардио + тонус.',
            exercises: [
              { order: 1, label: '1a', title: 'Выпады вперед', details: '12 повторов' },
              { order: 2, label: '1b', title: 'Отжимания', details: '12 повторов' },
              { order: 3, label: '2a', title: 'Тяга резинки', details: '15 повторов' },
              { order: 4, label: '2b', title: 'Альпинист', details: '45 сек' },
              { order: 5, label: '3a', title: 'Приседания сумо', details: '18 повторов' },
              { order: 6, label: '3b', title: 'Русские скручивания', details: '25 повторов' },
              { order: 7, label: '4', title: 'Бег 600 м (или 3 мин)', details: '' }
            ]
          }
        ]
      }
    ]
  }
];
PROGRAM_SEED.length = 0;

async function ensureProgramSeed() {
  if (!PROGRAM_SEED.length) return;
  await prisma.trainingProgram.updateMany({
    where: { authorName: 'Виктор Ярославский' },
    data: { authorName: 'Тестов Тест Тестович' }
  });

  const existing = await prisma.trainingProgram.findFirst();
  if (existing) return;

  for (const program of PROGRAM_SEED) {
    await prisma.trainingProgram.create({
      data: {
        slug: program.slug,
        type: program.type,
        title: program.title,
        subtitle: program.subtitle,
        summary: program.summary,
        description: program.description,
        level: program.level,
        gender: program.gender,
        frequency: program.frequency,
        weeksCount: program.weeksCount,
        coverImage: program.coverImage,
        authorName: program.authorName,
        authorRole: program.authorRole,
        authorAvatar: program.authorAvatar,
        weeks: {
          create: program.weeks.map((week) => ({
            index: week.index,
            title: week.title,
            workouts: {
              create: week.workouts.map((workout) => ({
                index: workout.index,
                title: workout.title,
                description: workout.description,
                exercises: {
                  create: workout.exercises.map((exercise) => ({
                    order: exercise.order,
                    label: exercise.label,
                    title: exercise.title,
                    details: exercise.details
                  }))
                }
              }))
            }
          }))
        }
      }
    });
  }
}

// === Профиль (POST) ===
app.post('/api/profile', async (req, res) => {
  try {
    const auth = getAuthFromRequest(req);
    if (!auth.ok) return res.status(auth.status || 401).json({ ok: false, error: auth.error });
    const parsed = { tg_id: auth.tg_id, user: auth.user };

    const body = req.body || {};
    const data = {};

    if (Object.prototype.hasOwnProperty.call(body, 'heightCm')) {
      data.heightCm = toInt(body.heightCm);
    }
    if (Object.prototype.hasOwnProperty.call(body, 'weightKg')) {
      data.weightKg = toFloat(body.weightKg);
    }
    if (Object.prototype.hasOwnProperty.call(body, 'age')) {
      data.age = toInt(body.age);
    }
    if (Object.prototype.hasOwnProperty.call(body, 'timezoneOffsetMin')) {
      const offset = Number(body.timezoneOffsetMin);
      data.timezoneOffsetMin = Number.isFinite(offset) ? Math.round(offset) : null;
    }

    const tg_id = parsed.tg_id;

    const dbUser = await prisma.user.upsert({
      where: { tg_id: Number(tg_id) },
      update: data,
      create: {
        tg_id: Number(tg_id),
        username: parsed.user?.username || null,
        first_name: parsed.user?.first_name || null,
        ...data
      }
    });

    res.json({
      ok: true,
      profile: {
        heightCm: dbUser.heightCm ?? null,
        weightKg: dbUser.weightKg ?? null,
        age: dbUser.age ?? null
      }
    });
  } catch (e) {
    console.error('[api/profile] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

// === Payments (YooKassa) ===
app.post('/api/payments/create', async (req, res) => {
  try {
    const auth = getAuthFromRequest(req);
    if (!auth.ok) return res.status(auth.status || 401).json({ ok: false, error: auth.error });
    const parsed = { tg_id: auth.tg_id, user: auth.user };

    if (!YOOKASSA_SHOP_ID || !YOOKASSA_SECRET_KEY) {
      return res.status(500).json({ ok: false, error: 'payment_disabled' });
    }

    const tariffRaw = cleanString(req.body?.tariff || req.body?.tariffCode || req.body?.tariffName);
    const tariffCode = normalizeTariffCode(tariffRaw);
    if (!tariffCode) {
      return res.status(400).json({ ok: false, error: 'invalid_tariff' });
    }
    const tariffName = tariffNameFromCode(tariffCode);
    const priceRub = TARIFF_PRICE_RUB[tariffCode];
    if (!Number.isFinite(priceRub) || priceRub <= 0) {
      return res.status(400).json({ ok: false, error: 'invalid_price' });
    }

    const dbUser = await ensureUserRecord(parsed);
    const idempotenceKey = crypto.randomUUID();
    const payload = {
      amount: { value: formatRubAmount(priceRub), currency: 'RUB' },
      capture: true,
      confirmation: { type: 'redirect', return_url: PAYMENT_RETURN_URL },
      description: `Тариф ${tariffName}`,
      metadata: { userId: dbUser.id, tariff: tariffCode }
    };

    const payment = await yookassaRequest('POST', '/payments', payload, idempotenceKey);
    const confirmationUrl = payment?.confirmation?.confirmation_url || '';
    if (!confirmationUrl) {
      return res.status(502).json({ ok: false, error: 'no_confirmation_url' });
    }

    res.json({
      ok: true,
      paymentId: payment.id,
      status: payment.status,
      confirmationUrl
    });
  } catch (e) {
    console.error('[api/payments:create] error', e?.message || e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

app.post('/api/payments/confirm', async (req, res) => {
  try {
    const auth = getAuthFromRequest(req);
    if (!auth.ok) return res.status(auth.status || 401).json({ ok: false, error: auth.error });
    const parsed = { tg_id: auth.tg_id, user: auth.user };

    if (!YOOKASSA_SHOP_ID || !YOOKASSA_SECRET_KEY) {
      return res.status(500).json({ ok: false, error: 'payment_disabled' });
    }

    const paymentId = cleanString(req.body?.paymentId);
    if (!paymentId) {
      return res.status(400).json({ ok: false, error: 'missing_payment_id' });
    }

    const dbUser = await ensureUserRecord(parsed);
    const payment = await yookassaRequest('GET', `/payments/${paymentId}`);
    const metaUserId = Number(payment?.metadata?.userId);
    if (!Number.isFinite(metaUserId) || metaUserId !== dbUser.id) {
      return res.status(403).json({ ok: false, error: 'forbidden' });
    }

    const tariffCode = normalizeTariffCode(payment?.metadata?.tariff);
    if (!tariffCode) {
      return res.status(400).json({ ok: false, error: 'invalid_tariff' });
    }

    if (payment?.status === 'succeeded') {
      await applyTariffToUser(dbUser.id, tariffCode);
    }

    res.json({
      ok: true,
      status: payment?.status || 'unknown',
      paid: payment?.status === 'succeeded',
      tariff: tariffCode
    });
  } catch (e) {
    console.error('[api/payments:confirm] error', e?.message || e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

// === Вес (GET / POST) ===
app.get('/api/weight/history', async (req, res) => {
  try {
    const auth = getAuthFromRequest(req);
    if (!auth.ok) return res.status(auth.status || 401).json({ ok: false, error: auth.error });
    const parsed = { tg_id: auth.tg_id, user: auth.user };

    const monthsRaw = Number(req.query.months);
    const weeksRaw = Number(req.query.weeks ?? (Number.isFinite(monthsRaw) ? monthsRaw * 4 : 12));
    const weeks = Number.isFinite(weeksRaw) ? Math.max(1, Math.min(weeksRaw, 52)) : 12;

    const dbUser = await ensureUserRecord(parsed);
    const logs = await prisma.weightLog.findMany({
      where: { userId: dbUser.id },
      orderBy: { weekStart: 'desc' },
      take: weeks
    });

    res.json({ ok: true, weeks, logs });
  } catch (e) {
    console.error('[api/weight:history] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

app.post('/api/weight', async (req, res) => {
  try {
    const auth = getAuthFromRequest(req);
    if (!auth.ok) return res.status(auth.status || 401).json({ ok: false, error: auth.error });
    const parsed = { tg_id: auth.tg_id, user: auth.user };

    const weightKg = toFloat(req.body?.weightKg);
    if (weightKg === null) {
      return res.status(400).json({ ok: false, error: 'missing_weight' });
    }

    const offsetRaw = Number(req.body?.timezoneOffsetMin);
    const timezoneOffsetMin = Number.isFinite(offsetRaw) ? Math.round(offsetRaw) : null;
    const rawPeriodStart = req.body?.weekStart || req.body?.monthStart;
    const dateKey = rawPeriodStart
      ? getDateKey(rawPeriodStart)
      : (req.body?.date ? getDateKey(req.body.date) : toDateKeyWithOffset(new Date(), timezoneOffsetMin));
    const weekStart = getWeekStartKey(dateKey);

    const dbUser = await ensureUserRecord(parsed);
    const existing = await prisma.weightLog.findUnique({
      where: { userId_weekStart: { userId: dbUser.id, weekStart } },
      select: { id: true, updatedAt: true }
    });
    if (existing && isWeightLocked(existing)) {
      return res.status(403).json({
        ok: false,
        error: 'locked',
        lockUntil: getWeightLockUntil(existing) ? new Date(getWeightLockUntil(existing)).toISOString() : null
      });
    }

    const log = await prisma.weightLog.upsert({
      where: { userId_weekStart: { userId: dbUser.id, weekStart } },
      update: { weightKg },
      create: { userId: dbUser.id, weekStart, weightKg }
    });

    const userUpdate = {
      weightKg,
      ...(timezoneOffsetMin !== null ? { timezoneOffsetMin } : {})
    };
    await prisma.user.update({
      where: { id: dbUser.id },
      data: userUpdate
    });

    res.json({ ok: true, weekStart, log, weightKg });
  } catch (e) {
    console.error('[api/weight:post] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

// === Замеры (GET / POST) ===
// === Steps (GET / POST) ===
app.get('/api/steps', async (req, res) => {
  try {
    const auth = getAuthFromRequest(req);
    if (!auth.ok) return res.status(auth.status || 401).json({ ok: false, error: auth.error });
    const parsed = { tg_id: auth.tg_id, user: auth.user };

    const offsetRaw = Number(req.query?.timezoneOffsetMin);
    const timezoneOffsetMin = Number.isFinite(offsetRaw) ? Math.round(offsetRaw) : null;
    const dateKey = req.query?.date
      ? getDateKey(req.query.date)
      : toDateKeyWithOffset(new Date(), timezoneOffsetMin);

    const dbUser = await ensureUserRecord(parsed);
    if (timezoneOffsetMin !== null) {
      await prisma.user.update({
        where: { id: dbUser.id },
        data: { timezoneOffsetMin }
      });
    }

    const log = await prisma.stepLog.findUnique({
      where: { userId_date: { userId: dbUser.id, date: dateKey } },
      select: { steps: true, date: true }
    });

    res.json({ ok: true, date: dateKey, steps: log?.steps ?? null });
  } catch (e) {
    console.error('[api/steps:get] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

app.post('/api/steps', async (req, res) => {
  try {
    const auth = getAuthFromRequest(req);
    if (!auth.ok) return res.status(auth.status || 401).json({ ok: false, error: auth.error });
    const parsed = { tg_id: auth.tg_id, user: auth.user };

    const steps = toInt(req.body?.steps);
    if (steps === null || !Number.isFinite(steps) || steps < 0) {
      return res.status(400).json({ ok: false, error: 'invalid_steps' });
    }

    const offsetRaw = Number(req.body?.timezoneOffsetMin);
    const timezoneOffsetMin = Number.isFinite(offsetRaw) ? Math.round(offsetRaw) : null;
    const dateKey = req.body?.date
      ? getDateKey(req.body.date)
      : toDateKeyWithOffset(new Date(), timezoneOffsetMin);

    const dbUser = await ensureUserRecord(parsed);
    const log = await prisma.stepLog.upsert({
      where: { userId_date: { userId: dbUser.id, date: dateKey } },
      update: { steps },
      create: { userId: dbUser.id, date: dateKey, steps }
    });

    if (timezoneOffsetMin !== null) {
      await prisma.user.update({
        where: { id: dbUser.id },
        data: { timezoneOffsetMin }
      });
    }

    res.json({ ok: true, date: dateKey, steps: log.steps });
  } catch (e) {
    console.error('[api/steps:post] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

app.get('/api/measurements/history', async (req, res) => {
  try {
    const auth = getAuthFromRequest(req);
    if (!auth.ok) return res.status(auth.status || 401).json({ ok: false, error: auth.error });
    const parsed = { tg_id: auth.tg_id, user: auth.user };

    const monthsRaw = Number(req.query.months ?? req.query.weeks ?? 12);
    const months = Number.isFinite(monthsRaw) ? Math.max(1, Math.min(monthsRaw, 36)) : 12;

    const dbUser = await ensureUserRecord(parsed);
    const rows = await prisma.bodyMeasurement.findMany({
      where: { userId: dbUser.id },
      orderBy: { weekStart: 'desc' },
      take: months
    });

    const now = Date.now();
    const items = await Promise.all(
      rows.map(async (row) => ({
        weekStart: row.weekStart,
        frontUrl: row.frontKey ? (getPublicObjectUrl(row.frontKey) || await getSignedGetUrl(row.frontKey)) : null,
        sideUrl: row.sideKey ? (getPublicObjectUrl(row.sideKey) || await getSignedGetUrl(row.sideKey)) : null,
        backUrl: row.backKey ? (getPublicObjectUrl(row.backKey) || await getSignedGetUrl(row.backKey)) : null,
        waistCm: row.waistCm ?? null,
        chestCm: row.chestCm ?? null,
        hipsCm: row.hipsCm ?? null,
        updatedAt: row.updatedAt,
        locked: isMeasurementLocked(row, now),
        lockUntil: getMeasurementLockUntil(row) ? new Date(getMeasurementLockUntil(row)).toISOString() : null
      }))
    );

    res.json({ ok: true, months, items });
  } catch (e) {
    console.error('[api/measurements:history] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

app.post('/api/measurements/upload-url', async (req, res) => {
  try {
    const auth = getAuthFromRequest(req);
    if (!auth.ok) return res.status(auth.status || 401).json({ ok: false, error: auth.error });
    const parsed = { tg_id: auth.tg_id, user: auth.user };

    const side = cleanString(req.body?.side);
    if (!['front', 'back', 'side'].includes(side)) {
      return res.status(400).json({ ok: false, error: 'invalid_side' });
    }

    const fileName = optionalString(req.body?.fileName);
    const contentType = optionalString(req.body?.contentType);
    const size = req.body?.size ? Number(req.body.size) : null;
    if (!contentType || !contentType.startsWith('image/')) {
      return res.status(400).json({ ok: false, error: 'invalid_content_type' });
    }
    if (!Number.isFinite(size) || size <= 0 || size > CHAT_MAX_UPLOAD_BYTES) {
      return res.status(400).json({ ok: false, error: 'invalid_size' });
    }

    const offsetRaw = Number(req.body?.timezoneOffsetMin);
    const timezoneOffsetMin = Number.isFinite(offsetRaw) ? Math.round(offsetRaw) : null;
    const rawPeriodStart = req.body?.monthStart || req.body?.weekStart;
    const dateKey = rawPeriodStart
      ? getDateKey(rawPeriodStart)
      : (req.body?.date ? getDateKey(req.body.date) : toDateKeyWithOffset(new Date(), timezoneOffsetMin));
    const weekStart = getMonthStartKey(dateKey);

    const dbUser = await ensureUserRecord(parsed);
    if (timezoneOffsetMin !== null) {
      await prisma.user.update({
        where: { id: dbUser.id },
        data: { timezoneOffsetMin }
      });
    }

    const existing = await prisma.bodyMeasurement.findUnique({
      where: { userId_weekStart: { userId: dbUser.id, weekStart } },
      select: { id: true, updatedAt: true }
    });
    if (existing && isMeasurementLocked(existing)) {
      return res.status(403).json({
        ok: false,
        error: 'locked',
        lockUntil: getMeasurementLockUntil(existing) ? new Date(getMeasurementLockUntil(existing)).toISOString() : null
      });
    }

    const client = getS3Client();
    if (!client || !S3_BUCKET) {
      return res.status(500).json({ ok: false, error: 'storage_not_configured' });
    }

    const prefix = `measurements/${dbUser.id}/${weekStart}`;
    const key = buildMediaObjectKey(prefix, fileName);
    const uploadUrl = await getSignedPutUrl({
      key,
      contentType,
      contentLength: Math.round(size),
      cacheControl: CACHE_CONTROL_PRIVATE
    });
    if (!uploadUrl) {
      return res.status(500).json({ ok: false, error: 'upload_url_failed' });
    }

    res.json({
      ok: true,
      uploadUrl,
      objectKey: key,
      publicUrl: getPublicObjectUrl(key),
      weekStart,
      side,
      maxBytes: CHAT_MAX_UPLOAD_BYTES
    });
  } catch (e) {
    console.error('[api/measurements:upload-url] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

app.post('/api/measurements', async (req, res) => {
  try {
    const auth = getAuthFromRequest(req);
    if (!auth.ok) return res.status(auth.status || 401).json({ ok: false, error: auth.error });
    const parsed = { tg_id: auth.tg_id, user: auth.user };

    const side = cleanString(req.body?.side);
    if (!['front', 'back', 'side'].includes(side)) {
      return res.status(400).json({ ok: false, error: 'invalid_side' });
    }
    const objectKey = optionalString(req.body?.objectKey);
    if (!objectKey) {
      return res.status(400).json({ ok: false, error: 'missing_object_key' });
    }

    const rawPeriodStart = req.body?.monthStart || req.body?.weekStart;
    const dateKey = rawPeriodStart
      ? getDateKey(rawPeriodStart)
      : (req.body?.date ? getDateKey(req.body.date) : getDateKey(new Date().toISOString()));
    const weekStart = getMonthStartKey(dateKey);

    const dbUser = await ensureUserRecord(parsed);
    if (!objectKey.startsWith(`measurements/${dbUser.id}/`)) {
      return res.status(400).json({ ok: false, error: 'invalid_object_key' });
    }

    const existing = await prisma.bodyMeasurement.findUnique({
      where: { userId_weekStart: { userId: dbUser.id, weekStart } },
      select: { id: true, updatedAt: true }
    });
    if (existing && isMeasurementLocked(existing)) {
      return res.status(403).json({
        ok: false,
        error: 'locked',
        lockUntil: getMeasurementLockUntil(existing) ? new Date(getMeasurementLockUntil(existing)).toISOString() : null
      });
    }

    const data = {};
    if (side === 'front') data.frontKey = objectKey;
    if (side === 'side') data.sideKey = objectKey;
    if (side === 'back') data.backKey = objectKey;

    const item = await prisma.bodyMeasurement.upsert({
      where: { userId_weekStart: { userId: dbUser.id, weekStart } },
      update: data,
      create: { userId: dbUser.id, weekStart, ...data }
    });

    res.json({ ok: true, weekStart, item });
  } catch (e) {
    console.error('[api/measurements:post] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

app.post('/api/measurements/metrics', async (req, res) => {
  try {
    const auth = getAuthFromRequest(req);
    if (!auth.ok) return res.status(auth.status || 401).json({ ok: false, error: auth.error });
    const parsed = { tg_id: auth.tg_id, user: auth.user };

    const hasWaist = Object.prototype.hasOwnProperty.call(req.body || {}, 'waistCm');
    const hasChest = Object.prototype.hasOwnProperty.call(req.body || {}, 'chestCm');
    const hasHips = Object.prototype.hasOwnProperty.call(req.body || {}, 'hipsCm');

    if (!hasWaist && !hasChest && !hasHips) {
      return res.status(400).json({ ok: false, error: 'missing_metrics' });
    }

    const waistCm = hasWaist ? toFloat(req.body?.waistCm) : null;
    const chestCm = hasChest ? toFloat(req.body?.chestCm) : null;
    const hipsCm = hasHips ? toFloat(req.body?.hipsCm) : null;

    const offsetRaw = Number(req.body?.timezoneOffsetMin);
    const timezoneOffsetMin = Number.isFinite(offsetRaw) ? Math.round(offsetRaw) : null;
    const rawPeriodStart = req.body?.monthStart || req.body?.weekStart;
    const dateKey = rawPeriodStart
      ? getDateKey(rawPeriodStart)
      : (req.body?.date ? getDateKey(req.body.date) : toDateKeyWithOffset(new Date(), timezoneOffsetMin));
    const weekStart = getMonthStartKey(dateKey);

    const dbUser = await ensureUserRecord(parsed);
    if (timezoneOffsetMin !== null) {
      await prisma.user.update({
        where: { id: dbUser.id },
        data: { timezoneOffsetMin }
      });
    }

    const existing = await prisma.bodyMeasurement.findUnique({
      where: { userId_weekStart: { userId: dbUser.id, weekStart } },
      select: { id: true, updatedAt: true }
    });
    if (existing && isMeasurementLocked(existing)) {
      return res.status(403).json({
        ok: false,
        error: 'locked',
        lockUntil: getMeasurementLockUntil(existing) ? new Date(getMeasurementLockUntil(existing)).toISOString() : null
      });
    }

    const data = {};
    if (hasWaist) data.waistCm = waistCm;
    if (hasChest) data.chestCm = chestCm;
    if (hasHips) data.hipsCm = hipsCm;

    const item = await prisma.bodyMeasurement.upsert({
      where: { userId_weekStart: { userId: dbUser.id, weekStart } },
      update: data,
      create: { userId: dbUser.id, weekStart, ...data }
    });

    res.json({ ok: true, weekStart, item });
  } catch (e) {
    console.error('[api/measurements:metrics] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

app.post('/api/measurements/delete', async (req, res) => {
  try {
    const auth = getAuthFromRequest(req);
    if (!auth.ok) return res.status(auth.status || 401).json({ ok: false, error: auth.error });
    const parsed = { tg_id: auth.tg_id, user: auth.user };

    const side = cleanString(req.body?.side);
    if (!['front', 'back', 'side'].includes(side)) {
      return res.status(400).json({ ok: false, error: 'invalid_side' });
    }

    const rawPeriodStart = req.body?.monthStart || req.body?.weekStart || req.body?.date || '';
    const weekStart = getMonthStartKey(rawPeriodStart);
    if (!weekStart) return res.status(400).json({ ok: false, error: 'invalid_week' });

    const dbUser = await ensureUserRecord(parsed);
    const entry = await prisma.bodyMeasurement.findUnique({
      where: { userId_weekStart: { userId: dbUser.id, weekStart } }
    });
    if (!entry) return res.json({ ok: true, removed: false });
    if (isMeasurementLocked(entry)) {
      return res.status(403).json({
        ok: false,
        error: 'locked',
        lockUntil: getMeasurementLockUntil(entry) ? new Date(getMeasurementLockUntil(entry)).toISOString() : null
      });
    }

    const key = side === 'front' ? entry.frontKey : side === 'side' ? entry.sideKey : entry.backKey;
    if (key) await deleteObjectKey(key);

    const update = {};
    if (side === 'front') update.frontKey = null;
    if (side === 'side') update.sideKey = null;
    if (side === 'back') update.backKey = null;

    const updated = await prisma.bodyMeasurement.update({
      where: { id: entry.id },
      data: update
    });

    if (!updated.frontKey && !updated.sideKey && !updated.backKey) {
      await prisma.bodyMeasurement.delete({ where: { id: entry.id } });
    }

    res.json({ ok: true, removed: true });
  } catch (e) {
    console.error('[api/measurements:delete] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

// === История питания (GET) ===
app.get('/api/nutrition/history', async (req, res) => {
  try {
    const auth = getAuthFromRequest(req);
    if (!auth.ok) return res.status(auth.status || 401).json({ ok: false, error: auth.error });

    const daysRaw = Number(req.query.days || 7);
    const days = Number.isFinite(daysRaw) ? Math.max(1, Math.min(daysRaw, 31)) : 7;

    const toKey = req.query.to ? getDateKey(req.query.to) : toDateKeyLocal(new Date());
    let fromKey = req.query.from ? getDateKey(req.query.from) : null;
    if (!fromKey) {
      const endDate = new Date(`${toKey}T00:00:00`);
      const startDate = addDaysLocal(endDate, -(days - 1));
      fromKey = toDateKeyLocal(startDate);
    }

    let startKey = fromKey;
    let endKey = toKey;
    if (startKey > endKey) {
      [startKey, endKey] = [endKey, startKey];
    }

    const dbUser = await prisma.user.upsert({
      where: { tg_id: Number(auth.tg_id) },
      update: {},
      create: {
        tg_id: Number(auth.tg_id),
        username: auth.user?.username || null,
        first_name: auth.user?.first_name || null
      }
    });

    const entries = await prisma.nutritionEntry.findMany({
      where: {
        userId: dbUser.id,
        date: { gte: startKey, lte: endKey }
      },
      orderBy: { date: 'desc' }
    });

    const comments = await prisma.nutritionComment.findMany({
      where: {
        userId: dbUser.id,
        date: { gte: startKey, lte: endKey }
      },
      select: { date: true, text: true }
    });
    const commentMap = new Map(comments.map((comment) => [comment.date, comment.text]));
    const entriesWithComments = entries.map((entry) => ({
      ...entry,
      comment: commentMap.get(entry.date) || null
    }));

    res.json({
      ok: true,
      from: startKey,
      to: endKey,
      entries: entriesWithComments,
      commentDates: comments.map((comment) => comment.date)
    });
  } catch (e) {
    console.error('[api/nutrition:history] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

// === Дневник питания (GET / POST) ===
app.get('/api/nutrition', async (req, res) => {
  try {
    const auth = getAuthFromRequest(req);
    if (!auth.ok) return res.status(auth.status || 401).json({ ok: false, error: auth.error });

    const date = getDateKey(req.query.date);
    const tg_id = auth.tg_id;

    const dbUser = await prisma.user.upsert({
      where: { tg_id: Number(tg_id) },
      update: {},
      create: {
        tg_id: Number(tg_id),
        username: auth.user?.username || null,
        first_name: auth.user?.first_name || null
      }
    });

    const entry = await prisma.nutritionEntry.findUnique({
      where: { userId_date: { userId: dbUser.id, date } }
    });

    const items = entry
      ? await prisma.nutritionItem.findMany({
          where: { entryId: entry.id },
          orderBy: { createdAt: 'desc' }
        })
      : [];

    const comment = await prisma.nutritionComment.findUnique({
      where: { userId_date: { userId: dbUser.id, date } },
      select: { text: true }
    });

    res.json({ ok: true, date, entry, items, comment: comment?.text || null });
  } catch (e) {
    console.error('[api/nutrition:get] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

app.post('/api/nutrition', async (req, res) => {
  try {
    const { date: rawDate } = req.body || {};
    const auth = getAuthFromRequest(req);
    if (!auth.ok) return res.status(auth.status || 401).json({ ok: false, error: auth.error });

    const date = getDateKey(rawDate);
    const tg_id = auth.tg_id;

    const dbUser = await prisma.user.upsert({
      where: { tg_id: Number(tg_id) },
      update: {},
      create: {
        tg_id: Number(tg_id),
        username: auth.user?.username || null,
        first_name: auth.user?.first_name || null
      }
    });

    const kcal = toInt(req.body?.kcal);
    const protein = toFloat(req.body?.protein);
    const fat = toFloat(req.body?.fat);
    const carb = toFloat(req.body?.carb);
    const waterLiters = toFloat(req.body?.water);
    const mealsCount = toInt(req.body?.meals);

    const entry = await prisma.nutritionEntry.upsert({
      where: { userId_date: { userId: dbUser.id, date } },
      update: { kcal, protein, fat, carb, waterLiters, mealsCount },
      create: { userId: dbUser.id, date, kcal, protein, fat, carb, waterLiters, mealsCount }
    });

    res.json({ ok: true, date, entry });
  } catch (e) {
    console.error('[api/nutrition:post] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

// === Food search (OpenFoodFacts) ===
app.get('/api/food/search', async (req, res) => {
  try {
    const auth = getAuthFromRequest(req);
    if (!auth.ok) return res.status(auth.status || 401).json({ ok: false, error: auth.error });

    const query = cleanString(req.query.query);
    if (!query) return res.status(400).json({ ok: false, error: 'no_query' });
    const pageRaw = Number(req.query.page || 1);
    const limitRaw = Number(req.query.limit || 20);
    const page = Number.isFinite(pageRaw) ? Math.max(1, Math.min(pageRaw, 50)) : 1;
    const limit = Number.isFinite(limitRaw) ? Math.max(5, Math.min(limitRaw, 50)) : 20;

    const url = buildOffSearchUrl(query, page, limit);
    const data = await fetchJson(url);
    const products = Array.isArray(data?.products) ? data.products : [];
    const items = products
      .map(normalizeOffProduct)
      .filter(Boolean)
      .map((p) => ({
        barcode: p.barcode,
        title: p.title,
        brand: p.brand,
        imageUrl: p.imageUrl,
        kcal100: p.kcal100,
        protein100: p.protein100,
        fat100: p.fat100,
        carb100: p.carb100
      }));

    res.json({ ok: true, items });
  } catch (e) {
    console.error('[api/food:search] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

app.get('/api/food/barcode', async (req, res) => {
  try {
    const auth = getAuthFromRequest(req);
    if (!auth.ok) return res.status(auth.status || 401).json({ ok: false, error: auth.error });

    const barcode = cleanString(req.query.barcode);
    if (!barcode) return res.status(400).json({ ok: false, error: 'no_barcode' });

    let product = await prisma.nutritionProduct.findUnique({
      where: { barcode }
    });
    if (!product) {
      const data = await fetchJson(buildOffBarcodeUrl(barcode));
      if (!data || data.status !== 1) {
        return res.status(404).json({ ok: false, error: 'not_found' });
      }
      product = await upsertNutritionProduct(data.product);
    }

    if (!product) return res.status(404).json({ ok: false, error: 'not_found' });
    res.json({
      ok: true,
      product: {
        id: product.id,
        barcode: product.barcode,
        title: product.title,
        brand: product.brand,
        imageUrl: product.imageUrl,
        kcal100: product.kcal100,
        protein100: product.protein100,
        fat100: product.fat100,
        carb100: product.carb100
      }
    });
  } catch (e) {
    console.error('[api/food:barcode] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

// === Nutrition items ===
app.post('/api/nutrition/item', async (req, res) => {
  try {
    const auth = getAuthFromRequest(req);
    if (!auth.ok) return res.status(auth.status || 401).json({ ok: false, error: auth.error });

    const date = getDateKey(req.body?.date);
    const meal = cleanString(req.body?.meal) || 'other';
    const grams = toFloat(req.body?.grams);
    if (!grams || grams <= 0) return res.status(400).json({ ok: false, error: 'bad_grams' });

    const tg_id = auth.tg_id;
    const dbUser = await prisma.user.upsert({
      where: { tg_id: Number(tg_id) },
      update: {},
      create: {
        tg_id: Number(tg_id),
        username: auth.user?.username || null,
        first_name: auth.user?.first_name || null
      }
    });

    const entry = await prisma.nutritionEntry.upsert({
      where: { userId_date: { userId: dbUser.id, date } },
      update: {},
      create: { userId: dbUser.id, date }
    });

    let product = null;
    const productId = Number(req.body?.productId);
    const barcode = cleanString(req.body?.barcode);
    if (Number.isFinite(productId) && productId > 0) {
      product = await prisma.nutritionProduct.findUnique({ where: { id: productId } });
    } else if (barcode) {
      product = await prisma.nutritionProduct.findUnique({ where: { barcode } });
      if (!product) {
        const data = await fetchJson(buildOffBarcodeUrl(barcode));
        if (data && data.status === 1) {
          product = await upsertNutritionProduct(data.product);
        }
      }
    }

    let title = cleanString(req.body?.title);
    let brand = cleanString(req.body?.brand) || null;
    let kcal100 = toFloat(req.body?.kcal100);
    let protein100 = toFloat(req.body?.protein100);
    let fat100 = toFloat(req.body?.fat100);
    let carb100 = toFloat(req.body?.carb100);

    if (product) {
      title = product.title;
      brand = product.brand;
      kcal100 = product.kcal100;
      protein100 = product.protein100;
      fat100 = product.fat100;
      carb100 = product.carb100;
    } else if (title) {
      const created = await prisma.nutritionProduct.create({
        data: {
          source: 'custom',
          title,
          brand,
          kcal100,
          protein100,
          fat100,
          carb100
        }
      });
      product = created;
    } else {
      return res.status(400).json({ ok: false, error: 'no_product' });
    }

    const macros = calcMacrosFromProduct(
      {
        kcal100: kcal100 || 0,
        protein100: protein100 || 0,
        fat100: fat100 || 0,
        carb100: carb100 || 0
      },
      grams
    );

    const item = await prisma.nutritionItem.create({
      data: {
        entryId: entry.id,
        productId: product?.id || null,
        title,
        brand,
        meal,
        grams: macros.grams,
        kcal: macros.kcal,
        protein: macros.protein,
        fat: macros.fat,
        carb: macros.carb
      }
    });

    const updated = await recalcNutritionEntryTotals(entry.id);

    res.json({ ok: true, entry: updated, item });
  } catch (e) {
    console.error('[api/nutrition:item] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

app.post('/api/nutrition/item/delete', async (req, res) => {
  try {
    const auth = getAuthFromRequest(req);
    if (!auth.ok) return res.status(auth.status || 401).json({ ok: false, error: auth.error });

    const id = Number(req.body?.id);
    if (!Number.isFinite(id)) return res.status(400).json({ ok: false, error: 'bad_id' });

    const item = await prisma.nutritionItem.findUnique({
      where: { id },
      select: { id: true, entryId: true }
    });
    if (!item) return res.json({ ok: true, removed: false });

    const entry = await prisma.nutritionEntry.findUnique({
      where: { id: item.entryId },
      select: { id: true, userId: true }
    });
    if (!entry) return res.json({ ok: true, removed: false });

    const dbUser = await prisma.user.findUnique({
      where: { tg_id: Number(auth.tg_id) },
      select: { id: true }
    });
    if (!dbUser || dbUser.id !== entry.userId) {
      return res.status(403).json({ ok: false, error: 'forbidden' });
    }

    await prisma.nutritionItem.delete({ where: { id } });
    const updated = await recalcNutritionEntryTotals(entry.id);

    res.json({ ok: true, removed: true, entry: updated });
  } catch (e) {
    console.error('[api/nutrition:item:delete] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

// === Получить текущий режим пользователя ===
app.get('/api/mode', async (req, res) => {
  try {
    const tg_id = Number(req.query.tg_id);
    if (!tg_id) return res.status(400).json({ ok: false, error: 'no_tg_id' });

    const user = await prisma.user.findUnique({
      where: { tg_id },
      select: { trainingMode: true }
    });

    if (!user) return res.status(404).json({ ok: false, error: 'user_not_found' });

    res.json({ ok: true, trainingMode: user.trainingMode });
  } catch (e) {
    console.error('[api/mode:get] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

// === Установить новый режим (gym / crossfit) ===
app.post('/api/mode', async (req, res) => {
  try {
    const hasAuth = Boolean(req.headers?.authorization)
      || Boolean(req.query?.token)
      || Boolean(req.body?.token)
      || Boolean(req.query?.initData)
      || Boolean(req.body?.initData);
    let tg_id = null;
    if (hasAuth) {
      const auth = getAuthFromRequest(req);
      if (!auth.ok) return res.status(auth.status || 401).json({ ok: false, error: auth.error });
      tg_id = auth.tg_id;
    } else {
      tg_id = req.body?.tg_id;
    }
    const { mode } = req.body;
    if (!tg_id || !mode) return res.status(400).json({ ok: false, error: 'missing_params' });

    if (!['gym', 'crossfit'].includes(mode)) {
      return res.status(400).json({ ok: false, error: 'invalid_mode' });
    }

    await prisma.user.update({
      where: { tg_id: Number(tg_id) },
      data: { trainingMode: mode }
    });

    res.json({ ok: true });
  } catch (e) {
    console.error('[api/mode:post] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

// === Notifications (GET / POST) ===
app.get('/api/notifications', async (req, res) => {
  try {
    const auth = getAuthFromRequest(req);
    if (!auth.ok) return res.status(auth.status || 401).json({ ok: false, error: auth.error });

    const limitRaw = Number(req.query.limit || 20);
    const offsetRaw = Number(req.query.offset || 0);
    const limit = Number.isFinite(limitRaw) ? Math.max(1, Math.min(limitRaw, 50)) : 20;
    const offset = Number.isFinite(offsetRaw) ? Math.max(0, offsetRaw) : 0;
    const unreadOnly = String(req.query.unreadOnly || '').toLowerCase() === 'true' || String(req.query.unreadOnly) === '1';

    const dbUser = await ensureUserRecord(auth);

    const [notifications, unreadCount] = await Promise.all([
      prisma.notification.findMany({
        where: {
          userId: dbUser.id,
          ...(unreadOnly ? { readAt: null } : {})
        },
        orderBy: { createdAt: 'desc' },
        skip: offset,
        take: limit
      }),
      prisma.notification.count({
        where: { userId: dbUser.id, readAt: null }
      })
    ]);

    res.json({ ok: true, notifications, unreadCount });
  } catch (e) {
    console.error('[api/notifications:get] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

app.post('/api/notifications/read', async (req, res) => {
  try {
    const auth = getAuthFromRequest(req);
    if (!auth.ok) return res.status(auth.status || 401).json({ ok: false, error: auth.error });

    const ids = Array.isArray(req.body?.ids)
      ? req.body.ids.map((id) => Number(id)).filter((id) => Number.isInteger(id))
      : [];
    const markAll = Boolean(req.body?.all);

    const dbUser = await ensureUserRecord(auth);

    const where = { userId: dbUser.id };
    if (!markAll && ids.length) {
      where.id = { in: ids };
    }

    await prisma.notification.updateMany({
      where,
      data: { readAt: new Date() }
    });

    res.json({ ok: true });
  } catch (e) {
    console.error('[api/notifications:read] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

// === Chat: messages ===
app.get('/api/chat/messages', async (req, res) => {
  try {
    const auth = getAuthFromRequest(req);
    if (!auth.ok) return res.status(auth.status || 401).json({ ok: false, error: auth.error });
    const clientId = req.query?.clientId ? Number(req.query.clientId) : null;
    const afterId = req.query?.afterId ? Number(req.query.afterId) : null;
  const markRead = req.query?.markRead !== '0';
  const includeLast = String(req.query?.includeLast || '').toLowerCase() === 'true'
    || String(req.query?.includeLast) === '1';

    const ctx = await resolveChatContext(auth, clientId, true);
    if (!ctx.ok) return res.status(ctx.status).json({ ok: false, error: ctx.error });
    if (!ctx.thread) {
      return res.json({ ok: true, threadId: null, messages: [], counterpart: null });
    }

    const where = { threadId: ctx.thread.id };
    if (Number.isInteger(afterId)) {
      where.id = { gt: afterId };
    }

  const messages = await prisma.chatMessage.findMany({
    where,
    orderBy: { id: 'asc' }
  });

  let lastMessage = null;
  if (includeLast) {
    lastMessage = await prisma.chatMessage.findFirst({
      where: { threadId: ctx.thread.id },
      orderBy: { id: 'desc' }
    });
  }

  if (markRead) {
    await prisma.chatMessage.updateMany({
      where: {
        threadId: ctx.thread.id,
        senderId: { not: ctx.requester.id },
        readAt: null
        },
        data: { readAt: new Date() }
      });
    }

    const counterpart = ctx.isClient ? ctx.curator : ctx.client;
  const uniqueMessages = new Map();
  messages.forEach((msg) => uniqueMessages.set(msg.id, msg));
  if (lastMessage) uniqueMessages.set(lastMessage.id, lastMessage);

  const formatted = await Promise.all(
    Array.from(uniqueMessages.values())
      .sort((a, b) => a.id - b.id)
      .map(async (msg) => {
      let media = null;
      if (msg.mediaKey) {
        const url = await getSignedGetUrl(msg.mediaKey);
        if (url) {
            media = {
              url,
              type: msg.mediaType || null,
              name: msg.mediaName || null,
              size: msg.mediaSize || null
            };
          }
        }
      return {
        id: msg.id,
        text: msg.text || null,
        createdAt: msg.createdAt,
        readAt: msg.readAt,
        isMine: msg.senderId === ctx.requester.id,
        media
      };
    })
  );

    res.json({
      ok: true,
      threadId: ctx.thread.id,
      counterpart: counterpart
        ? { id: counterpart.id, name: buildUserDisplayName(counterpart) }
        : null,
      messages: formatted
    });
  } catch (e) {
    console.error('[api/chat:messages] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

app.get('/api/chat/unread-count', async (req, res) => {
  try {
    const auth = getAuthFromRequest(req);
    if (!auth.ok) return res.status(auth.status || 401).json({ ok: false, error: auth.error });
    const clientId = req.query?.clientId ? Number(req.query.clientId) : null;
    const ctx = await resolveChatContext(auth, clientId, true);
    if (!ctx.ok) return res.status(ctx.status).json({ ok: false, error: ctx.error });
    if (!ctx.thread) return res.json({ ok: true, unreadCount: 0 });

    const unreadCount = await prisma.chatMessage.count({
      where: {
        threadId: ctx.thread.id,
        senderId: { not: ctx.requester.id },
        readAt: null
      }
    });

    res.json({ ok: true, unreadCount });
  } catch (e) {
    console.error('[api/chat:unread-count] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

app.post('/api/chat/upload-url', async (req, res) => {
  try {
    const auth = getAuthFromRequest(req);
    if (!auth.ok) return res.status(auth.status || 401).json({ ok: false, error: auth.error });
    const clientId = req.body?.clientId ? Number(req.body.clientId) : null;
    const fileName = optionalString(req.body?.fileName);
    const contentType = optionalString(req.body?.contentType);
    const size = req.body?.size ? Number(req.body.size) : null;

    if (!contentType || (!contentType.startsWith('video/') && !contentType.startsWith('image/'))) {
      return res.status(400).json({ ok: false, error: 'invalid_content_type' });
    }
    if (!Number.isFinite(size) || size <= 0 || size > CHAT_MAX_UPLOAD_BYTES) {
      return res.status(400).json({ ok: false, error: 'invalid_size' });
    }

    const ctx = await resolveChatContext(auth, clientId, true);
    if (!ctx.ok) return res.status(ctx.status).json({ ok: false, error: ctx.error });
    if (!ctx.thread) return res.status(400).json({ ok: false, error: 'no_thread' });

    const chatAllowed = isChatTariffName(ctx.client?.tariffName)
      && isTariffActive(ctx.client?.tariffExpiresAt);
    if (!chatAllowed) {
      return res.status(403).json({ ok: false, error: 'chat_not_allowed' });
    }

    const client = getS3Client();
    if (!client || !S3_BUCKET) {
      return res.status(500).json({ ok: false, error: 'storage_not_configured' });
    }

    const key = buildChatObjectKey(ctx.thread.id, fileName);
    const uploadUrl = await getSignedPutUrl({
      key,
      contentType,
      contentLength: Math.round(size),
      cacheControl: CACHE_CONTROL_NO_STORE
    });
    if (!uploadUrl) {
      return res.status(500).json({ ok: false, error: 'upload_url_failed' });
    }

    res.json({
      ok: true,
      uploadUrl,
      objectKey: key,
      maxBytes: CHAT_MAX_UPLOAD_BYTES
    });
  } catch (e) {
    console.error('[api/chat:upload-url] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

app.post('/api/admin/upload-url', async (req, res) => {
  try {
    const auth = await requireStaff(req.body?.initData);
    if (!auth.ok) return res.status(auth.status).json({ ok: false, error: auth.error });
    if (!auth.canTrain) return res.status(403).json({ ok: false, error: 'forbidden' });

    const kind = optionalString(req.body?.kind);
    const fileName = optionalString(req.body?.fileName);
    const contentType = optionalString(req.body?.contentType);
    const size = req.body?.size ? Number(req.body.size) : null;

    const kindMap = {
      exercise_video: { prefix: 'exercises/videos', types: ['video/'], cacheControl: CACHE_CONTROL_PUBLIC_LONG },
      program_video: { prefix: 'programs/videos', types: ['video/'], cacheControl: CACHE_CONTROL_PUBLIC_LONG },
      program_cover: { prefix: 'programs/covers', types: ['image/'], cacheControl: CACHE_CONTROL_PUBLIC_LONG }
    };
    const rule = kind ? kindMap[kind] : null;
    if (!rule) return res.status(400).json({ ok: false, error: 'invalid_kind' });
    if (!contentType || !rule.types.some((type) => contentType.startsWith(type))) {
      return res.status(400).json({ ok: false, error: 'invalid_content_type' });
    }
    if (!Number.isFinite(size) || size <= 0 || size > CHAT_MAX_UPLOAD_BYTES) {
      return res.status(400).json({ ok: false, error: 'invalid_size' });
    }

    const client = getS3Client();
    if (!client || !S3_BUCKET) {
      return res.status(500).json({ ok: false, error: 'storage_not_configured' });
    }

    const key = buildMediaObjectKey(rule.prefix, fileName);
    const uploadUrl = await getSignedPutUrl({
      key,
      contentType,
      contentLength: Math.round(size),
      cacheControl: rule.cacheControl
    });
    if (!uploadUrl) {
      return res.status(500).json({ ok: false, error: 'upload_url_failed' });
    }

    res.json({
      ok: true,
      uploadUrl,
      objectKey: key,
      publicUrl: getPublicObjectUrl(key),
      maxBytes: CHAT_MAX_UPLOAD_BYTES
    });
  } catch (e) {
    console.error('[api/admin:upload-url] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

app.post('/api/chat/messages', async (req, res) => {
  try {
    const auth = getAuthFromRequest(req);
    if (!auth.ok) return res.status(auth.status || 401).json({ ok: false, error: auth.error });
    const clientId = req.body?.clientId ? Number(req.body.clientId) : null;
    const text = optionalString(req.body?.text);
    const mediaKey = optionalString(req.body?.mediaKey);
    const mediaType = optionalString(req.body?.mediaType);
    const mediaName = optionalString(req.body?.mediaName);
    const mediaSize = req.body?.mediaSize ? Number(req.body.mediaSize) : null;
    if (!text && !mediaKey) return res.status(400).json({ ok: false, error: 'missing_content' });

    const ctx = await resolveChatContext(auth, clientId, true);
    if (!ctx.ok) return res.status(ctx.status).json({ ok: false, error: ctx.error });
    if (!ctx.thread) return res.status(400).json({ ok: false, error: 'no_thread' });

    const chatAllowed = isChatTariffName(ctx.client?.tariffName)
      && isTariffActive(ctx.client?.tariffExpiresAt);
    if (!chatAllowed) {
      return res.status(403).json({ ok: false, error: 'chat_not_allowed' });
    }

    if (mediaKey) {
      if (!mediaKey.startsWith(`chat/${ctx.thread.id}/`)) {
        return res.status(400).json({ ok: false, error: 'invalid_media_key' });
      }
      if (!mediaType || (!mediaType.startsWith('video/') && !mediaType.startsWith('image/'))) {
        return res.status(400).json({ ok: false, error: 'invalid_media_type' });
      }
      if (!Number.isFinite(mediaSize) || mediaSize <= 0 || mediaSize > CHAT_MAX_UPLOAD_BYTES) {
        return res.status(400).json({ ok: false, error: 'invalid_media_size' });
      }
    }

    const message = await prisma.chatMessage.create({
      data: {
        threadId: ctx.thread.id,
        senderId: ctx.requester.id,
        text,
        mediaKey,
        mediaType,
        mediaName: mediaName ? sanitizeFileName(mediaName) : null,
        mediaSize: Number.isFinite(mediaSize) ? Math.round(mediaSize) : null
      }
    });

    const senderIsCurator = ctx.requester.id === ctx.curator.id;
    const recipientId = senderIsCurator ? ctx.client.id : ctx.curator.id;
    const recipientIsCurator = recipientId === ctx.curator.id;
    const senderName = buildUserDisplayName(ctx.client);
    const curatorTitle = '\u0412\u0430\u043c \u043d\u0430\u043f\u0438\u0441\u0430\u043b \u043a\u0443\u0440\u0430\u0442\u043e\u0440';
    const clientTitle = '\u0412\u0430\u043c \u043d\u0430\u043f\u0438\u0441\u0430\u043b \u043a\u043b\u0438\u0435\u043d\u0442';
    const title = senderIsCurator ? curatorTitle : `${clientTitle} ${senderName}`;
    const webAppUrl = getChatWebAppUrl({ recipientIsCurator, clientId: ctx.client.id });
    scheduleChatNotification({
      messageId: message.id,
      recipientId,
      title,
      webAppUrl
    });

    const mediaUrl = mediaKey ? await getSignedGetUrl(mediaKey) : null;
      res.json({
        ok: true,
        message: {
          id: message.id,
          text: message.text || null,
          createdAt: message.createdAt,
          readAt: message.readAt,
          isMine: true,
          media: mediaUrl
            ? {
                url: mediaUrl,
              type: mediaType || null,
              name: mediaName || null,
              size: Number.isFinite(mediaSize) ? Math.round(mediaSize) : null
            }
          : null
      }
    });
  } catch (e) {
    console.error('[api/chat:messages] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

// === Admin: create training program ===
app.post('/api/admin/programs', async (req, res) => {
  try {
    const auth = await requireStaff(req.body?.initData);
    if (!auth.ok) return res.status(auth.status).json({ ok: false, error: auth.error });
    if (!auth.canTrain) return res.status(403).json({ ok: false, error: 'forbidden' });

    const payload = req.body?.program || {};
    const title = cleanString(payload.title);
    const type = cleanString(payload.type).toLowerCase();
    const tariffs = normalizeTariffs(payload.tariffs);
    const guestAccess = Boolean(payload.guestAccess);
    const trainerId = payload.trainerId ? Number(payload.trainerId) : null;
    let trainer = null;

    if (trainerId) {
      if (!Number.isInteger(trainerId)) {
        return res.status(400).json({ ok: false, error: 'invalid_trainer_id' });
      }
      trainer = await prisma.user.findUnique({
        where: { id: trainerId },
        select: { first_name: true, last_name: true, username: true, role: true, isCurator: true }
      });
      if (!trainer || (trainer.role !== 'curator' && trainer.role !== 'admin' && trainer.role !== 'sadmin' && !trainer.isCurator)) {
        return res.status(400).json({ ok: false, error: 'curator_not_found' });
      }
    }

    if (!title) {
      return res.status(400).json({ ok: false, error: 'missing_title' });
    }
    if (!['gym', 'crossfit'].includes(type)) {
      return res.status(400).json({ ok: false, error: 'invalid_type' });
    }
    if (!tariffs.length) {
      return res.status(400).json({ ok: false, error: 'missing_tariffs' });
    }

    const slugSource = cleanString(payload.slug) || title;
    const slug = slugify(slugSource);
    const existing = await prisma.trainingProgram.findUnique({ where: { slug } });
    if (existing) {
      return res.status(409).json({ ok: false, error: 'slug_exists', slug });
    }

    const weeks = Array.isArray(payload.weeks) ? payload.weeks : [];
    if (!weeks.length) {
      return res.status(400).json({ ok: false, error: 'no_weeks' });
    }

    const errors = [];
    const weeksData = weeks.map((week, weekIndex) => {
      const weekTitle = optionalString(week?.title) || `Неделя ${weekIndex + 1}`;
      const workouts = Array.isArray(week?.workouts) ? week.workouts : [];
      if (!workouts.length) {
        errors.push(`Неделя ${weekIndex + 1}: добавьте хотя бы одну тренировку.`);
      }

      const workoutsData = workouts.map((workout, workoutIndex) => {
        const workoutTitle = cleanString(workout?.title);
        if (!workoutTitle) {
          errors.push(`Неделя ${weekIndex + 1}: заполните название тренировки ${workoutIndex + 1}.`);
        }
        const exercises = Array.isArray(workout?.exercises) ? workout.exercises : [];
        if (!exercises.length) {
          errors.push(`Неделя ${weekIndex + 1}: тренировка ${workoutIndex + 1} должна содержать упражнения.`);
        }

        const exercisesData = exercises.map((exercise, exerciseIndex) => {
          const exerciseTitle = cleanString(exercise?.title);
          if (!exerciseTitle) {
            errors.push(`Неделя ${weekIndex + 1}: тренировка ${workoutIndex + 1}, упражнение ${exerciseIndex + 1} — нет названия.`);
          }
          return {
            order: exerciseIndex + 1,
            label: optionalString(exercise?.label),
            title: exerciseTitle || `Упражнение ${exerciseIndex + 1}`,
            details: optionalString(exercise?.details),
            description: optionalString(exercise?.description),
            videoUrl: optionalString(exercise?.videoUrl)
          };
        });

        return {
          index: workoutIndex + 1,
          title: workoutTitle || `Тренировка ${workoutIndex + 1}`,
          description: optionalString(workout?.description),
          exercises: { create: exercisesData }
        };
      });

      return {
        index: weekIndex + 1,
        title: weekTitle,
        workouts: { create: workoutsData }
      };
    });

    if (errors.length) {
      return res.status(400).json({ ok: false, error: 'validation_failed', details: errors });
    }

    const weeksCount = weeks.length;
    const trainerName = trainer
      ? [trainer.first_name, trainer.last_name].filter(Boolean).join(' ') || trainer.username
      : null;
    const authorName = optionalString(payload.authorName) || trainerName || 'Тестов Тест Тестович';
    const authorRole = optionalString(payload.authorRole) || 'Куратор Fit Dew';
    const created = await prisma.trainingProgram.create({
      data: {
        slug,
        title,
        type,
        subtitle: optionalString(payload.subtitle),
        summary: optionalString(payload.summary),
        description: optionalString(payload.description),
        level: optionalString(payload.level),
        gender: optionalString(payload.gender),
        frequency: optionalString(payload.frequency),
        weeksCount,
        coverImage: optionalString(payload.coverImage),
        tariffs,
        guestAccess,
        authorUserId: trainer?.id || null,
        authorName,
        authorRole,
        authorAvatar: optionalString(payload.authorAvatar),
        weeks: { create: weeksData }
      }
    });

    const tariffFilters = Array.from(new Set(tariffs.flatMap((item) => expandTariffFilter(item))));
    const recipients = await prisma.user.findMany({
      where: buildRecipientsWhere({ trainingMode: type, tariffFilters, guestAccess }),
      select: { id: true }
    });
    await createNotificationsForUsers(
      recipients.map((user) => user.id),
      {
        type: 'program_available',
        title: '\u041d\u043e\u0432\u0430\u044f \u043f\u0440\u043e\u0433\u0440\u0430\u043c\u043c\u0430',
        message: buildNotificationPreview(`\u0414\u043e\u0441\u0442\u0443\u043f\u043d\u0430 \u043d\u043e\u0432\u0430\u044f \u043f\u0440\u043e\u0433\u0440\u0430\u043c\u043c\u0430: ${title}`),
        data: { slug: created.slug, type }
      }
    );

    res.json({ ok: true, program: { id: created.id, slug: created.slug } });
  } catch (e) {
    console.error('[api/admin/programs] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

// === Admin: update training program ===
app.put('/api/admin/programs/:slug', async (req, res) => {
  try {
    const auth = await requireStaff(req.body?.initData);
    if (!auth.ok) return res.status(auth.status).json({ ok: false, error: auth.error });
    if (!auth.canTrain) return res.status(403).json({ ok: false, error: 'forbidden' });

    const currentSlug = req.params.slug;
    if (!currentSlug) return res.status(400).json({ ok: false, error: 'missing_slug' });

    const existingProgram = await prisma.trainingProgram.findUnique({
      where: { slug: currentSlug },
      select: { id: true, slug: true, type: true }
    });
    if (!existingProgram) {
      return res.status(404).json({ ok: false, error: 'not_found' });
    }

    const payload = req.body?.program || {};
    const title = cleanString(payload.title);
    const type = cleanString(payload.type).toLowerCase();
    const tariffs = normalizeTariffs(payload.tariffs);
    const guestAccess = Boolean(payload.guestAccess);
    const trainerId = payload.trainerId ? Number(payload.trainerId) : null;
    let trainer = null;

    if (trainerId) {
      if (!Number.isInteger(trainerId)) {
        return res.status(400).json({ ok: false, error: 'invalid_trainer_id' });
      }
      trainer = await prisma.user.findUnique({
        where: { id: trainerId },
        select: { first_name: true, last_name: true, username: true, role: true, isCurator: true }
      });
      if (!trainer || (trainer.role !== 'curator' && trainer.role !== 'admin' && trainer.role !== 'sadmin' && !trainer.isCurator)) {
        return res.status(400).json({ ok: false, error: 'curator_not_found' });
      }
    }

    if (!title) {
      return res.status(400).json({ ok: false, error: 'missing_title' });
    }
    if (!['gym', 'crossfit'].includes(type)) {
      return res.status(400).json({ ok: false, error: 'invalid_type' });
    }
    if (!tariffs.length) {
      return res.status(400).json({ ok: false, error: 'missing_tariffs' });
    }

    const slugSource = cleanString(payload.slug) || title;
    const nextSlug = slugify(slugSource);
    if (nextSlug !== currentSlug) {
      const duplicate = await prisma.trainingProgram.findUnique({ where: { slug: nextSlug } });
      if (duplicate) {
        return res.status(409).json({ ok: false, error: 'slug_exists', slug: nextSlug });
      }
    }

    const weeks = Array.isArray(payload.weeks) ? payload.weeks : [];
    if (!weeks.length) {
      return res.status(400).json({ ok: false, error: 'no_weeks' });
    }

    const errors = [];
    const weeksData = weeks.map((week, weekIndex) => {
      const weekTitle = optionalString(week?.title) || `Неделя ${weekIndex + 1}`;
      const workouts = Array.isArray(week?.workouts) ? week.workouts : [];
      if (!workouts.length) {
        errors.push(`Неделя ${weekIndex + 1}: добавьте хотя бы одну тренировку.`);
      }

      const workoutsData = workouts.map((workout, workoutIndex) => {
        const workoutTitle = cleanString(workout?.title);
        if (!workoutTitle) {
          errors.push(`Неделя ${weekIndex + 1}: заполните название тренировки ${workoutIndex + 1}.`);
        }
        const exercises = Array.isArray(workout?.exercises) ? workout.exercises : [];
        if (!exercises.length) {
          errors.push(`Неделя ${weekIndex + 1}: тренировка ${workoutIndex + 1} должна содержать упражнения.`);
        }

        const exercisesData = exercises.map((exercise, exerciseIndex) => {
          const exerciseTitle = cleanString(exercise?.title);
          if (!exerciseTitle) {
            errors.push(`Неделя ${weekIndex + 1}: тренировка ${workoutIndex + 1}, упражнение ${exerciseIndex + 1} - нет названия.`);
          }
          return {
            order: exerciseIndex + 1,
            label: optionalString(exercise?.label),
            title: exerciseTitle || `Упражнение ${exerciseIndex + 1}`,
            details: optionalString(exercise?.details),
            description: optionalString(exercise?.description),
            videoUrl: optionalString(exercise?.videoUrl)
          };
        });

        return {
          index: workoutIndex + 1,
          title: workoutTitle || `Тренировка ${workoutIndex + 1}`,
          description: optionalString(workout?.description),
          exercises: { create: exercisesData }
        };
      });

      return {
        index: weekIndex + 1,
        title: weekTitle,
        workouts: { create: workoutsData }
      };
    });

    if (errors.length) {
      return res.status(400).json({ ok: false, error: 'validation_failed', details: errors });
    }

    const weeksCount = weeks.length;
    const trainerName = trainer
      ? [trainer.first_name, trainer.last_name].filter(Boolean).join(' ') || trainer.username
      : null;
    const authorName = optionalString(payload.authorName) || trainerName || 'Тестов Тест Тестович';
    const authorRole = optionalString(payload.authorRole) || 'Куратор Fit Dew';

    const updated = await prisma.trainingProgram.update({
      where: { slug: currentSlug },
      data: {
        slug: nextSlug,
        title,
        type,
        subtitle: optionalString(payload.subtitle),
        summary: optionalString(payload.summary),
        description: optionalString(payload.description),
        level: optionalString(payload.level),
        gender: optionalString(payload.gender),
        frequency: optionalString(payload.frequency),
        weeksCount,
        coverImage: optionalString(payload.coverImage),
        tariffs,
        guestAccess,
        authorUserId: trainer?.id || null,
        authorName,
        authorRole,
        authorAvatar: optionalString(payload.authorAvatar),
        weeks: {
          deleteMany: {},
          create: weeksData
        }
      }
    });

    res.json({ ok: true, program: { id: updated.id, slug: updated.slug } });
  } catch (e) {
    console.error('[api/admin/programs:update] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

// === Admin: delete training program ===
app.delete('/api/admin/programs/:slug', async (req, res) => {
  try {
    const initData = req.body?.initData || req.query?.initData;
    const auth = await requireStaff(initData);
    if (!auth.ok) return res.status(auth.status).json({ ok: false, error: auth.error });
    if (!auth.canTrain) return res.status(403).json({ ok: false, error: 'forbidden' });

    const slug = req.params.slug;
    if (!slug) return res.status(400).json({ ok: false, error: 'missing_slug' });

    await prisma.trainingProgram.delete({ where: { slug } });
    res.json({ ok: true });
  } catch (e) {
    if (e?.code === 'P2025') {
      return res.status(404).json({ ok: false, error: 'not_found' });
    }
    console.error('[api/admin/programs:delete] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

// === Admin: curators list (legacy trainers endpoint) ===
app.get('/api/admin/trainers', async (req, res) => {
  try {
    const auth = await requireStaff(req.query?.initData);
    if (!auth.ok) return res.status(auth.status).json({ ok: false, error: auth.error });
    if (!auth.canTrain) return res.status(403).json({ ok: false, error: 'forbidden' });

    const trainers = await prisma.user.findMany({
      where: {
        OR: [
          { role: { in: ['curator', 'admin', 'sadmin'] } },
          { isCurator: true }
        ]
      },
      orderBy: { id: 'asc' },
      select: {
        id: true,
        first_name: true,
        last_name: true,
        username: true,
        trainerScope: true
      }
    });

    res.json({ ok: true, trainers });
  } catch (e) {
    console.error('[api/admin/trainers] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

// === Admin: curators list ===
app.get('/api/admin/curators', async (req, res) => {
  try {
    const auth = await requireStaff(req.query?.initData);
    if (!auth.ok) return res.status(auth.status).json({ ok: false, error: auth.error });
    if (auth.role !== 'admin' && auth.role !== 'sadmin') {
      return res.status(403).json({ ok: false, error: 'forbidden' });
    }

    const curators = await prisma.user.findMany({
      where: {
        OR: [
          { role: { in: ['curator', 'admin', 'sadmin'] } },
          { isCurator: true }
        ]
      },
      orderBy: { id: 'asc' },
      select: {
        id: true,
        first_name: true,
        last_name: true,
        username: true,
        role: true,
        trainerScope: true,
        isCurator: true
      }
    });

    const normalized = curators.map((curator) => ({
      id: curator.id,
      first_name: curator.first_name,
      last_name: curator.last_name,
      username: curator.username,
      role: curator.role,
      isCurator: curator.isCurator,
      trainerScope: normalizeTrainerScope(curator.trainerScope)
    }));

    res.json({ ok: true, curators: normalized });
  } catch (e) {
    console.error('[api/admin/curators] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

// === Admin: clients list ===
app.get('/api/admin/clients', async (req, res) => {
  try {
    const auth = await requireStaff(req.query?.initData);
    if (!auth.ok) return res.status(auth.status).json({ ok: false, error: auth.error });
    if (!auth.canCurate) return res.status(403).json({ ok: false, error: 'forbidden' });

    let where = { role: 'user', isCurator: false };
    if (auth.role === 'sadmin') {
      where = {};
    } else if (auth.role !== 'admin') {
      where.trainerId = auth.userId;
    }

    const clients = await prisma.user.findMany({
      where,
      orderBy: { id: 'desc' },
      select: {
        id: true,
        tg_id: true,
        first_name: true,
        last_name: true,
          username: true,
          tariffName: true,
          tariffExpiresAt: true,
          trainingMode: true,
        heightCm: true,
        weightKg: true,
        phone: true,
        role: true,
        isCurator: true,
        trainerScope: true,
        trainerId: true,
        trainer: {
          select: { id: true, first_name: true, last_name: true, username: true }
        }
      }
    });

    const todayKey = toDateKeyLocal(new Date());
    const ids = clients.map((client) => client.id);
    let filledSet = new Set();
    let reviewedSet = new Set();
    if (ids.length) {
      const filled = await prisma.nutritionEntry.findMany({
        where: { userId: { in: ids }, date: todayKey },
        select: { userId: true, reviewedAt: true }
      });
      filledSet = new Set(filled.map((entry) => entry.userId));
      reviewedSet = new Set(filled.filter((entry) => entry.reviewedAt).map((entry) => entry.userId));
    }

    const unreadByClient = new Map();
    const clientIds = clients
      .filter((client) => client.role === 'user' && !client.isCurator)
      .map((client) => client.id);
    if (clientIds.length && auth.userId) {
      const threads = await prisma.chatThread.findMany({
        where: { curatorId: auth.userId, clientId: { in: clientIds } },
        select: { id: true, clientId: true }
      });
      const threadIds = threads.map((thread) => thread.id);
      const threadClient = new Map(threads.map((thread) => [thread.id, thread.clientId]));
      if (threadIds.length) {
        const unreadMessages = await prisma.chatMessage.findMany({
          where: {
            threadId: { in: threadIds },
            senderId: { in: clientIds },
            readAt: null
          },
          select: { threadId: true }
        });
        unreadMessages.forEach((msg) => {
          const clientId = threadClient.get(msg.threadId);
          if (!clientId) return;
          unreadByClient.set(clientId, (unreadByClient.get(clientId) || 0) + 1);
        });
      }
    }

    const normalized = clients.map((client) => ({
      ...client,
      tg_id: client.tg_id ? String(client.tg_id) : null,
      tariffName: normalizeTariffName(client.tariffName),
      trainer: client.trainer
        ? {
            id: client.trainer.id,
            name: [client.trainer.first_name, client.trainer.last_name].filter(Boolean).join(' ') || client.trainer.username,
            username: client.trainer.username || null
          }
        : null,
      hasTodayNutrition: filledSet.has(client.id),
      hasTodayNutritionReviewed: reviewedSet.has(client.id),
      unreadChatCount: unreadByClient.get(client.id) || 0
    }));

    res.json({ ok: true, date: todayKey, clients: normalized });
  } catch (e) {
    console.error('[api/admin/clients:get] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

// === Admin: client profile ===
app.get('/api/admin/clients/:id', async (req, res) => {
  try {
    const auth = await requireStaff(req.query?.initData);
    if (!auth.ok) return res.status(auth.status).json({ ok: false, error: auth.error });
    if (!auth.canCurate) return res.status(403).json({ ok: false, error: 'forbidden' });

    const clientId = Number(req.params.id);
    if (!Number.isInteger(clientId)) {
      return res.status(400).json({ ok: false, error: 'invalid_client_id' });
    }

    const client = await prisma.user.findUnique({
      where: { id: clientId },
      select: {
        id: true,
        tg_id: true,
        first_name: true,
        last_name: true,
        username: true,
        tariffName: true,
        trainingMode: true,
        heightCm: true,
        weightKg: true,
        phone: true,
        role: true,
        trainerScope: true,
        isCurator: true,
        trainerId: true,
        trainer: {
          select: { id: true, first_name: true, last_name: true, username: true, trainerScope: true }
        }
      }
    });

    if (!client || client.tg_id === null) {
      return res.status(404).json({ ok: false, error: 'not_found' });
    }

    const isClientTarget = client.role === 'user' && !client.isCurator;
    if (auth.role !== 'sadmin' && !isClientTarget) {
      return res.status(403).json({ ok: false, error: 'forbidden' });
    }
    if (auth.role !== 'admin' && auth.role !== 'sadmin' && client.trainerId !== auth.userId) {
      return res.status(403).json({ ok: false, error: 'forbidden' });
    }

    res.json({
      ok: true,
      client: {
        ...client,
        tg_id: client.tg_id ? String(client.tg_id) : null,
        tariffName: normalizeTariffName(client.tariffName),
        trainer: client.trainer
          ? {
              id: client.trainer.id,
              name: [client.trainer.first_name, client.trainer.last_name].filter(Boolean).join(' ') || client.trainer.username,
              username: client.trainer.username || null,
              trainerScope: normalizeTrainerScope(client.trainer.trainerScope)
            }
          : null
      }
    });
  } catch (e) {
    console.error('[api/admin/clients:detail] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

// === Admin: assign trainer to client ===
app.post('/api/admin/clients/:id/trainer', async (req, res) => {
  try {
    const auth = await requireStaff(req.body?.initData);
    if (!auth.ok) return res.status(auth.status).json({ ok: false, error: auth.error });
    if (auth.role !== 'admin' && auth.role !== 'sadmin') {
      return res.status(403).json({ ok: false, error: 'forbidden' });
    }

    const clientId = Number(req.params.id);
    if (!Number.isInteger(clientId)) {
      return res.status(400).json({ ok: false, error: 'invalid_client_id' });
    }

    const client = await prisma.user.findUnique({
      where: { id: clientId },
      select: { id: true, trainerId: true, tariffName: true, tariffExpiresAt: true, role: true, isCurator: true }
    });
    if (!client) {
      return res.status(404).json({ ok: false, error: 'not_found' });
    }

    const rawTrainerId = req.body?.trainerId;
    const trainerId = rawTrainerId === null || rawTrainerId === undefined || rawTrainerId === ''
      ? null
      : Number(rawTrainerId);
    if (trainerId !== null && !Number.isInteger(trainerId)) {
      return res.status(400).json({ ok: false, error: 'invalid_trainer_id' });
    }

    let trainer = null;
    if (trainerId !== null) {
      trainer = await prisma.user.findUnique({
        where: { id: trainerId },
        select: { id: true, role: true, trainerScope: true, isCurator: true, first_name: true, last_name: true, username: true }
      });
      if (!trainer || (trainer.role !== 'curator' && trainer.role !== 'admin' && trainer.role !== 'sadmin' && !trainer.isCurator)) {
        return res.status(400).json({ ok: false, error: 'curator_not_found' });
      }
    }

    const updated = await prisma.user.update({
      where: { id: clientId },
      data: { trainerId }
    });

    const isClientTarget = client.role === 'user' && !client.isCurator;
    if (
      trainerId !== null &&
      updated.trainerId &&
      updated.trainerId !== client.trainerId &&
      isClientTarget &&
      isChatTariffName(client.tariffName) &&
      isTariffActive(client.tariffExpiresAt)
    ) {
      const curatorName = trainer
        ? [trainer.first_name, trainer.last_name].filter(Boolean).join(' ') || trainer.username
        : null;
      const message = curatorName
        ? `Вам назначен куратор: ${curatorName}. Теперь доступен чат с куратором.`
        : 'Вам назначен куратор. Теперь доступен чат с куратором.';
      await createNotificationsForUsers([client.id], { type: 'curator_assigned', message });
    }

    res.json({ ok: true, trainerId: updated.trainerId });
  } catch (e) {
    console.error('[api/admin/clients:trainer] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

// === Admin: update staff roles ===
app.post('/api/admin/clients/:id/staff', async (req, res) => {
  try {
    const auth = await requireStaff(req.body?.initData);
    if (!auth.ok) return res.status(auth.status).json({ ok: false, error: auth.error });
    if (auth.role !== 'admin' && auth.role !== 'sadmin') {
      return res.status(403).json({ ok: false, error: 'forbidden' });
    }

    const clientId = Number(req.params.id);
    if (!Number.isInteger(clientId)) {
      return res.status(400).json({ ok: false, error: 'invalid_client_id' });
    }

    const target = await prisma.user.findUnique({
      where: { id: clientId },
      select: { id: true, role: true }
    });
    if (!target) return res.status(404).json({ ok: false, error: 'not_found' });

    const requestedRole = cleanString(req.body?.role);
    let role = 'user';
    if (requestedRole === 'admin' || requestedRole === 'sadmin' || requestedRole === 'curator') {
      role = requestedRole;
    }

    if ((role === 'admin' || role === 'sadmin') && auth.role !== 'sadmin') {
      return res.status(403).json({ ok: false, error: 'forbidden' });
    }

    const isCurator = role === 'curator';
    const trainerScope = isCurator
      ? normalizeTrainerScope(req.body?.trainerScope)
      : null;

    const updated = await prisma.user.update({
      where: { id: clientId },
      data: {
        role,
        isCurator,
        trainerScope
      },
      select: { id: true, role: true, isCurator: true, trainerScope: true }
    });

    res.json({
      ok: true,
      user: {
        id: updated.id,
        role: updated.role,
        isCurator: updated.isCurator,
        trainerScope: normalizeTrainerScope(updated.trainerScope)
      }
    });
  } catch (e) {
    console.error('[api/admin/clients:staff] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

// === Admin: client nutrition (history) ===
app.get('/api/admin/clients/:id/nutrition', async (req, res) => {
  try {
    const auth = await requireStaff(req.query?.initData);
    if (!auth.ok) return res.status(auth.status).json({ ok: false, error: auth.error });
    if (!auth.canCurate) return res.status(403).json({ ok: false, error: 'forbidden' });

    const clientId = Number(req.params.id);
    if (!Number.isInteger(clientId)) {
      return res.status(400).json({ ok: false, error: 'invalid_client_id' });
    }

    const client = await prisma.user.findUnique({
      where: { id: clientId },
      select: { id: true, trainerId: true, role: true, isCurator: true }
    });
    if (!client) return res.status(404).json({ ok: false, error: 'not_found' });
    const isClientTarget = client.role === 'user' && !client.isCurator;
    if (auth.role !== 'sadmin' && !isClientTarget) {
      return res.status(403).json({ ok: false, error: 'forbidden' });
    }
    if (auth.role !== 'admin' && auth.role !== 'sadmin' && client.trainerId !== auth.userId) {
      return res.status(403).json({ ok: false, error: 'forbidden' });
    }

    const toKey = req.query.to ? getDateKey(req.query.to) : toDateKeyLocal(new Date());
    let fromKey = req.query.from ? getDateKey(req.query.from) : null;
    if (!fromKey) {
      const endDate = new Date(`${toKey}T00:00:00`);
      const startDate = addDaysLocal(endDate, -30);
      fromKey = toDateKeyLocal(startDate);
    }

    let startKey = fromKey;
    let endKey = toKey;
    if (startKey > endKey) {
      [startKey, endKey] = [endKey, startKey];
    }

    const entries = await prisma.nutritionEntry.findMany({
      where: { userId: client.id, date: { gte: startKey, lte: endKey } },
      orderBy: { date: 'desc' }
    });

    const comments = await prisma.nutritionComment.findMany({
      where: { userId: client.id, date: { gte: startKey, lte: endKey } },
      select: { date: true, text: true, authorId: true, updatedAt: true }
    });

    res.json({
      ok: true,
      from: startKey,
      to: endKey,
      entries,
      comments
    });
  } catch (e) {
    console.error('[api/admin/clients:nutrition] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

// === Admin: client nutrition comment ===
app.post('/api/admin/clients/:id/nutrition-comment', async (req, res) => {
  try {
    const auth = await requireStaff(req.body?.initData);
    if (!auth.ok) return res.status(auth.status).json({ ok: false, error: auth.error });
    if (!auth.canCurate) return res.status(403).json({ ok: false, error: 'forbidden' });

    const clientId = Number(req.params.id);
    if (!Number.isInteger(clientId)) {
      return res.status(400).json({ ok: false, error: 'invalid_client_id' });
    }

    const client = await prisma.user.findUnique({
      where: { id: clientId },
      select: { id: true, trainerId: true, role: true, isCurator: true }
    });
    if (!client) return res.status(404).json({ ok: false, error: 'not_found' });
    const isClientTarget = client.role === 'user' && !client.isCurator;
    if (auth.role !== 'sadmin' && !isClientTarget) {
      return res.status(403).json({ ok: false, error: 'forbidden' });
    }
    if (auth.role !== 'admin' && auth.role !== 'sadmin' && client.trainerId !== auth.userId) {
      return res.status(403).json({ ok: false, error: 'forbidden' });
    }

    const date = getDateKey(req.body?.date);
    const text = cleanString(req.body?.text);
    if (!text) {
      return res.status(400).json({ ok: false, error: 'missing_text' });
    }

    const comment = await prisma.nutritionComment.upsert({
      where: { userId_date: { userId: client.id, date } },
      update: { text, authorId: auth.userId },
      create: { userId: client.id, date, text, authorId: auth.userId }
    });

    const preview = buildNotificationPreview(text);
    await createNotificationsForUsers([client.id], {
      type: 'nutrition_comment',
      title: '\u041a\u043e\u043c\u043c\u0435\u043d\u0442\u0430\u0440\u0438\u0439 \u043a \u043f\u0438\u0442\u0430\u043d\u0438\u044e',
      message: preview,
      data: { date }
    });

    res.json({ ok: true, comment });
  } catch (e) {
    console.error('[api/admin/clients:comment] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

app.post('/api/admin/clients/:id/nutrition-reviewed', async (req, res) => {
  try {
    const auth = await requireStaff(req.body?.initData);
    if (!auth.ok) return res.status(auth.status).json({ ok: false, error: auth.error });
    if (!auth.canCurate) return res.status(403).json({ ok: false, error: 'forbidden' });

    const clientId = Number(req.params.id);
    if (!Number.isInteger(clientId)) {
      return res.status(400).json({ ok: false, error: 'invalid_client_id' });
    }

    const client = await prisma.user.findUnique({
      where: { id: clientId },
      select: { id: true, trainerId: true, role: true, isCurator: true }
    });
    if (!client) return res.status(404).json({ ok: false, error: 'not_found' });
    const isClientTarget = client.role === 'user' && !client.isCurator;
    if (auth.role !== 'sadmin' && !isClientTarget) {
      return res.status(403).json({ ok: false, error: 'forbidden' });
    }
    if (auth.role !== 'admin' && auth.role !== 'sadmin' && client.trainerId !== auth.userId) {
      return res.status(403).json({ ok: false, error: 'forbidden' });
    }

    const date = getDateKey(req.body?.date);
    const entry = await prisma.nutritionEntry.findUnique({
      where: { userId_date: { userId: client.id, date } }
    });
    if (!entry) {
      return res.status(404).json({ ok: false, error: 'no_entry' });
    }

    const updated = await prisma.nutritionEntry.update({
      where: { id: entry.id },
      data: {
        reviewedAt: entry.reviewedAt ? entry.reviewedAt : new Date(),
        reviewedById: entry.reviewedById || auth.userId
      }
    });

    res.json({ ok: true, entry: updated });
  } catch (e) {
    console.error('[api/admin/clients:reviewed] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

// === Admin: exercise library ===
app.get('/api/admin/exercises', async (req, res) => {
  try {
    const auth = await requireStaff(req.query?.initData);
    if (!auth.ok) return res.status(auth.status).json({ ok: false, error: auth.error });
    if (!auth.canTrain) return res.status(403).json({ ok: false, error: 'forbidden' });

    const exercises = await prisma.exercise.findMany({
      orderBy: { updatedAt: 'desc' }
    });

    const normalized = exercises.map((exercise) => ({
      ...exercise,
      tariffs: normalizeTariffList(exercise.tariffs)
    }));
    res.json({ ok: true, exercises: normalized });
  } catch (e) {
    console.error('[api/admin/exercises:get] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

app.post('/api/admin/exercises', async (req, res) => {
  try {
    const auth = await requireStaff(req.body?.initData);
    if (!auth.ok) return res.status(auth.status).json({ ok: false, error: auth.error });
    if (!auth.canTrain) return res.status(403).json({ ok: false, error: 'forbidden' });

  const payload = req.body?.exercise || {};
  const title = cleanString(payload.title);
  const typeRaw = cleanString(payload.type);
  const normalizedType = typeRaw === 'crossfit' ? 'crossfit' : 'gym';
  const tariffs = normalizeTariffs(payload.tariffs);
  const crossfitType = normalizedType === 'crossfit' ? normalizeCrossfitType(payload.crossfitType) : '';
  const guestAccess = Boolean(payload.guestAccess);
  if (!['gym', 'crossfit'].includes(normalizedType)) {
    return res.status(400).json({ ok: false, error: 'invalid_type' });
  }
  if (normalizedType === 'crossfit' && !crossfitType) {
    return res.status(400).json({ ok: false, error: 'missing_crossfit_type' });
  }
    const rawMuscles = Array.isArray(payload.muscles) ? payload.muscles : payload.muscle;
    const muscles = normalizedType === 'gym' ? normalizeMuscles(rawMuscles) : [];
    const finalMuscles = normalizedType === 'gym'
      ? (muscles.length ? muscles : [DEFAULT_MUSCLE])
      : [];
    const muscle = normalizedType === 'gym' ? (finalMuscles[0] || DEFAULT_MUSCLE) : null;
    if (!title) {
      return res.status(400).json({ ok: false, error: 'missing_title' });
    }

    const created = await prisma.exercise.create({
      data: {
        title,
        type: normalizedType,
        tariffs,
        muscle,
        muscles: finalMuscles,
        crossfitType: normalizedType === 'crossfit' ? crossfitType : null,
        guestAccess,
        description: optionalString(payload.description),
        videoUrl: optionalString(payload.videoUrl)
      }
    });

    const tariffFilters = Array.from(new Set(tariffs.flatMap((item) => expandTariffFilter(item))));
    const recipients = await prisma.user.findMany({
      where: buildRecipientsWhere({ trainingMode: normalizedType, tariffFilters, guestAccess }),
      select: { id: true }
    });
    await createNotificationsForUsers(
      recipients.map((user) => user.id),
      {
        type: 'exercise_available',
        title: '\u041d\u043e\u0432\u043e\u0435 \u0443\u043f\u0440\u0430\u0436\u043d\u0435\u043d\u0438\u0435',
        message: buildNotificationPreview(`\u0414\u043e\u0441\u0442\u0443\u043f\u043d\u043e \u043d\u043e\u0432\u043e\u0435 \u0443\u043f\u0440\u0430\u0436\u043d\u0435\u043d\u0438\u0435: ${title}`),
        data: { id: created.id, type: normalizedType }
      }
    );

    res.json({ ok: true, exercise: created });
  } catch (e) {
    console.error('[api/admin/exercises:post] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

app.put('/api/admin/exercises/:id', async (req, res) => {
  try {
    const auth = await requireStaff(req.body?.initData);
    if (!auth.ok) return res.status(auth.status).json({ ok: false, error: auth.error });
    if (!auth.canTrain) return res.status(403).json({ ok: false, error: 'forbidden' });

    const id = Number(req.params.id);
    if (!Number.isInteger(id)) {
      return res.status(400).json({ ok: false, error: 'invalid_id' });
    }

    const payload = req.body?.exercise || {};
    const title = cleanString(payload.title);
    const typeRaw = cleanString(payload.type);
    const normalizedType = typeRaw === 'crossfit' ? 'crossfit' : 'gym';
    const tariffs = normalizeTariffs(payload.tariffs);
    const crossfitType = normalizedType === 'crossfit' ? normalizeCrossfitType(payload.crossfitType) : '';
    const guestAccess = Boolean(payload.guestAccess);

    if (!['gym', 'crossfit'].includes(normalizedType)) {
      return res.status(400).json({ ok: false, error: 'invalid_type' });
    }
    if (normalizedType === 'crossfit' && !crossfitType) {
      return res.status(400).json({ ok: false, error: 'missing_crossfit_type' });
    }

    const existing = await prisma.exercise.findUnique({
      where: { id },
      select: { type: true }
    });
    if (!existing) {
      return res.status(404).json({ ok: false, error: 'not_found' });
    }

    const rawMuscles = Array.isArray(payload.muscles) ? payload.muscles : payload.muscle;
    const muscles = normalizedType === 'gym' ? normalizeMuscles(rawMuscles) : [];
    const finalMuscles = normalizedType === 'gym'
      ? (muscles.length ? muscles : [DEFAULT_MUSCLE])
      : [];
    const muscle = normalizedType === 'gym' ? (finalMuscles[0] || DEFAULT_MUSCLE) : null;
    if (!title) {
      return res.status(400).json({ ok: false, error: 'missing_title' });
    }

    const updated = await prisma.exercise.update({
      where: { id },
      data: {
        title,
        type: normalizedType,
        tariffs,
        muscle,
        muscles: finalMuscles,
        crossfitType: normalizedType === 'crossfit' ? crossfitType : null,
        guestAccess,
        description: optionalString(payload.description),
        videoUrl: optionalString(payload.videoUrl)
      }
    });

    res.json({ ok: true, exercise: updated });
  } catch (e) {
    console.error('[api/admin/exercises:put] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

// === Admin: client weight history ===
app.get('/api/admin/clients/:id/weight-history', async (req, res) => {
  try {
    const auth = await requireStaff(req.query?.initData);
    if (!auth.ok) return res.status(auth.status).json({ ok: false, error: auth.error });
    if (!auth.canCurate) return res.status(403).json({ ok: false, error: 'forbidden' });

    const clientId = Number(req.params.id);
    if (!Number.isInteger(clientId)) {
      return res.status(400).json({ ok: false, error: 'invalid_client_id' });
    }

    const client = await prisma.user.findUnique({
      where: { id: clientId },
      select: { id: true, trainerId: true, role: true, isCurator: true }
    });
    if (!client) return res.status(404).json({ ok: false, error: 'not_found' });
    const isClientTarget = client.role === 'user' && !client.isCurator;
    if (auth.role !== 'sadmin' && !isClientTarget) {
      return res.status(403).json({ ok: false, error: 'forbidden' });
    }
    if (auth.role !== 'admin' && auth.role !== 'sadmin' && client.trainerId !== auth.userId) {
      return res.status(403).json({ ok: false, error: 'forbidden' });
    }

    const weeksRaw = Number(req.query.weeks ?? req.query.months ?? 12);
    const weeks = Number.isFinite(weeksRaw) ? Math.max(1, Math.min(weeksRaw, 52)) : 12;

    const logs = await prisma.weightLog.findMany({
      where: { userId: client.id },
      orderBy: { weekStart: 'desc' },
      take: weeks
    });

    res.json({ ok: true, weeks, logs });
  } catch (e) {
    console.error('[api/admin/clients:weight-history] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

// === Admin: client measurements ===
app.get('/api/admin/clients/:id/measurements', async (req, res) => {
  try {
    const auth = await requireStaff(req.query?.initData);
    if (!auth.ok) return res.status(auth.status).json({ ok: false, error: auth.error });
    if (!auth.canCurate) return res.status(403).json({ ok: false, error: 'forbidden' });

    const clientId = Number(req.params.id);
    if (!Number.isInteger(clientId)) {
      return res.status(400).json({ ok: false, error: 'invalid_client_id' });
    }

    const client = await prisma.user.findUnique({
      where: { id: clientId },
      select: { id: true, trainerId: true, role: true, isCurator: true }
    });
    if (!client) return res.status(404).json({ ok: false, error: 'not_found' });
    const isClientTarget = client.role === 'user' && !client.isCurator;
    if (auth.role !== 'sadmin' && !isClientTarget) {
      return res.status(403).json({ ok: false, error: 'forbidden' });
    }
    if (auth.role !== 'admin' && auth.role !== 'sadmin' && client.trainerId !== auth.userId) {
      return res.status(403).json({ ok: false, error: 'forbidden' });
    }

    const monthsRaw = Number(req.query.months ?? req.query.weeks ?? 12);
    const months = Number.isFinite(monthsRaw) ? Math.max(1, Math.min(monthsRaw, 36)) : 12;

    const rows = await prisma.bodyMeasurement.findMany({
      where: { userId: client.id },
      orderBy: { weekStart: 'desc' },
      take: months
    });

    const now = Date.now();
    const items = await Promise.all(
      rows.map(async (row) => ({
        weekStart: row.weekStart,
        frontUrl: row.frontKey ? (getPublicObjectUrl(row.frontKey) || await getSignedGetUrl(row.frontKey)) : null,
        sideUrl: row.sideKey ? (getPublicObjectUrl(row.sideKey) || await getSignedGetUrl(row.sideKey)) : null,
        backUrl: row.backKey ? (getPublicObjectUrl(row.backKey) || await getSignedGetUrl(row.backKey)) : null,
        waistCm: row.waistCm ?? null,
        chestCm: row.chestCm ?? null,
        hipsCm: row.hipsCm ?? null,
        updatedAt: row.updatedAt,
        locked: isMeasurementLocked(row, now),
        lockUntil: getMeasurementLockUntil(row) ? new Date(getMeasurementLockUntil(row)).toISOString() : null
      }))
    );

    res.json({ ok: true, months, items });
  } catch (e) {
    console.error('[api/admin/clients:measurements] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

app.delete('/api/admin/exercises/:id', async (req, res) => {
  try {
    const initData = req.body?.initData || req.query?.initData;
    const auth = await requireStaff(initData);
    if (!auth.ok) return res.status(auth.status).json({ ok: false, error: auth.error });
    if (!auth.canTrain) return res.status(403).json({ ok: false, error: 'forbidden' });

    const id = Number(req.params.id);
    if (!Number.isInteger(id)) {
      return res.status(400).json({ ok: false, error: 'invalid_id' });
    }

    await prisma.exercise.delete({ where: { id } });
    res.json({ ok: true });
  } catch (e) {
    if (e?.code === 'P2025') {
      return res.status(404).json({ ok: false, error: 'not_found' });
    }
    if (e?.code === 'P2003') {
      return res.status(409).json({ ok: false, error: 'in_use' });
    }
    console.error('[api/admin/exercises:delete] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

// === Exercises (public) ===
app.get('/api/exercises', async (req, res) => {
  try {
    const typeRaw = cleanString(req.query?.type);
    const normalizedType = typeRaw === 'crossfit' ? 'crossfit' : typeRaw === 'gym' ? 'gym' : '';
    const tariff = normalizeTariffName(cleanString(req.query?.tariff));
    const guestOnly = String(req.query?.guest || '').toLowerCase() === '1'
      || String(req.query?.guest || '').toLowerCase() === 'true';
    const where = {};
    if (normalizedType) where.type = normalizedType;
    if (guestOnly) where.guestAccess = true;
    if (tariff && ALLOWED_TARIFFS.includes(tariff)) {
      const filterTariffs = expandTariffFilter(tariff);
      where.OR = [
        { tariffs: { hasSome: filterTariffs } },
        { tariffs: { isEmpty: true } }
      ];
    }
    const exercises = await prisma.exercise.findMany({
      where: Object.keys(where).length ? where : undefined,
      orderBy: { updatedAt: 'desc' }
    });
    const normalized = exercises.map((exercise) => ({
      ...exercise,
      tariffs: normalizeTariffList(exercise.tariffs)
    }));
    res.json({ ok: true, exercises: normalized });
  } catch (e) {
    console.error('[api/exercises:get] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

// === Programs (GET list + detail) ===
app.get('/api/programs', async (req, res) => {
  try {
    await ensureProgramSeed();
    const type = req.query.type;
    const tariff = normalizeTariffName(cleanString(req.query.tariff));
    const guestOnly = String(req.query?.guest || '').toLowerCase() === '1'
      || String(req.query?.guest || '').toLowerCase() === 'true';
    const where = {};
    if (type && ['gym', 'crossfit'].includes(type)) {
      where.type = type;
    }
    if (guestOnly) {
      where.guestAccess = true;
    }
    if (tariff && ALLOWED_TARIFFS.includes(tariff)) {
      const filterTariffs = expandTariffFilter(tariff);
      where.OR = [
        { tariffs: { hasSome: filterTariffs } },
        { tariffs: { isEmpty: true } }
      ];
    }

    const programs = await prisma.trainingProgram.findMany({
      where,
      orderBy: { createdAt: 'asc' },
      select: {
        slug: true,
        title: true,
        subtitle: true,
        summary: true,
        type: true,
        level: true,
        gender: true,
        frequency: true,
        weeksCount: true,
        coverImage: true,
        tariffs: true,
        guestAccess: true,
        authorUserId: true,
        authorName: true,
        authorRole: true,
        authorAvatar: true
      }
    });

    const normalized = programs.map((program) => ({
      ...program,
      tariffs: normalizeTariffList(program.tariffs)
    }));
    res.json({ ok: true, programs: normalized });
  } catch (e) {
    console.error('[api/programs] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

app.get('/api/programs/:slug', async (req, res) => {
  try {
    await ensureProgramSeed();
    const slug = req.params.slug;
    if (!slug) return res.status(400).json({ ok: false, error: 'missing_slug' });

    const program = await prisma.trainingProgram.findUnique({
      where: { slug },
      include: {
        weeks: {
          orderBy: { index: 'asc' },
          include: {
            workouts: {
              orderBy: { index: 'asc' },
              include: {
                exercises: { orderBy: { order: 'asc' } }
              }
            }
          }
        }
      }
    });

    if (!program) return res.status(404).json({ ok: false, error: 'not_found' });
    const normalized = {
      ...program,
      tariffs: normalizeTariffList(program.tariffs)
    };
    res.json({ ok: true, program: normalized });
  } catch (e) {
    console.error('[api/programs:detail] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});
