import path from 'path';
import { fileURLToPath } from 'url';
import dotenv from 'dotenv';

const __filename = fileURLToPath(import.meta.url);
const __dirname  = path.dirname(__filename);

// Загружаем .env
dotenv.config({ path: path.resolve(__dirname, '..', '.env') });

import express from 'express';
import cors from 'cors';
import crypto from 'crypto';
import { spawn } from 'child_process';
import fs from 'fs';
import https from 'https';
import { PrismaClient } from '@prisma/client';

const ROOT      = path.resolve(__dirname, '..');
const HOST      = '0.0.0.0';
const PORT      = process.env.PORT || 8080;
const PY        = process.env.PYTHON || 'python3';
const PY_TARGET = path.join(ROOT, '.pylibs');
const BIN_DIR   = path.join(PY_TARGET, 'bin');

const CORS_ORIGIN = (process.env.CORS_ORIGIN || '*')
  .split(',').map(s => s.trim()).filter(Boolean);

const app = express();
app.use(cors({
  origin: (origin, cb) => {
    if (!origin || CORS_ORIGIN.includes('*') || CORS_ORIGIN.includes(origin)) return cb(null, true);
    return cb(new Error('Not allowed by CORS'));
  }
}));
app.use(express.json());

// Prisma
const prisma = new PrismaClient();

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

// helpers
function run(cmd, args, opts = {}) {
  return new Promise(resolve => {
    const p = spawn(cmd, args, { stdio: 'inherit', ...opts });
    p.on('exit', code => resolve(code === 0));
  });
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

async function ensurePip() {
  const ok = await run(PY, ['-m', 'pip', '--version'], { cwd: ROOT });
  if (ok) return;
  console.log('[pip] downloading get-pip.py ...');
  const tmp = '/tmp/get-pip.py';
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
    PYTHONPATH: [PY_TARGET, process.env.PYTHONPATH || ''].filter(Boolean).join(':'),
    PATH: [BIN_DIR, process.env.PATH || ''].filter(Boolean).join(':'),
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
    PYTHONPATH: [PY_TARGET, process.env.PYTHONPATH || ''].filter(Boolean).join(':'),
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
    app.listen(PORT, () => {
      console.log(`✅ Server is running on port ${PORT}`);
    });
  }
})();
process.on('SIGTERM', () => process.exit(0));
process.on('SIGINT',  () => process.exit(0));

// /api/user
app.get('/api/user', async (req, res) => {
  try {
    const initData = req.query.initData;
    console.log('\n[api/user] initData raw:', initData);

    if (!initData || typeof initData !== 'string') {
      return res.status(400).json({ ok: false, error: 'no_initData' });
    }

    const params = new URLSearchParams(initData);
    console.log('[api/user] params:', Object.fromEntries(params.entries()));

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

    console.log('[api/user] calcHash=', calcHash, 'givenHash=', hash);

    if (calcHash !== hash) return res.status(401).json({ ok: false, error: 'bad_hash' });

    const userStr = params.get('user');
    const user = userStr ? JSON.parse(userStr) : null;
    const tg_id = user?.id ? Number(user.id) : null;
    console.log("[api/user] tg_id =", tg_id);

    if (!tg_id) return res.status(400).json({ ok: false, error: 'no_tg_id' });

    let dbUser = null;
    try {
      dbUser = await prisma.user.findUnique({
        where: { tg_id: Number(tg_id) },
        select: {
          first_name: true,
          tariffName: true,
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
      console.log('[api/user] dbUser:', dbUser);
    } catch (e) {
      console.error('[api/user] prisma findUnique error', e);
    }

    const isTrainer = dbUser?.role === 'trainer';
    const isCurator = Boolean(dbUser?.isCurator);
    const profile = {
      first_name: dbUser?.first_name || user?.first_name || 'друг',
      tariffName: normalizeTariffName(dbUser?.tariffName) || 'Базовый',
      trainingMode: dbUser?.trainingMode || 'gym',
      heightCm: dbUser?.heightCm ?? null,
      weightKg: dbUser?.weightKg ?? null,
      age: dbUser?.age ?? null,
      role: dbUser?.role || 'user',
      trainerScope: normalizeTrainerScope(dbUser?.trainerScope),
      canTrain: (dbUser?.role === 'admin') || isTrainer,
      canCurate: (dbUser?.role === 'admin') || isCurator,
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

    return res.json({ ok: true, user, profile });
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

function normalizeTariffName(value) {
  const cleaned = cleanString(value);
  if (cleaned === LEGACY_OPTIMAL_TARIFF) return 'Оптимальный';
  return cleaned;
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

const DEFAULT_MUSCLE = "\u041e\u0431\u0449\u0430\u044f";

function normalizeMuscles(value) {
  const list = Array.isArray(value) ? value : (value ? [value] : []);
  const unique = new Set();
  list.forEach((item) => {
    const cleaned = cleanString(item);
    if (cleaned) unique.add(cleaned);
  });
  return Array.from(unique);
}


const TRAINER_SCOPES = ['gym', 'crossfit', 'both'];

function normalizeTrainerScope(value) {
  return TRAINER_SCOPES.includes(value) ? value : 'both';
}

const NOTIFICATION_TYPES = ['nutrition_comment', 'program_available'];

const buildNotificationPreview = (text, limit = 160) => {
  const cleaned = cleanString(text);
  if (!cleaned) return null;
  if (cleaned.length <= limit) return cleaned;
  return `${cleaned.slice(0, limit).trim()}…`;
};

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
}

async function requireAdmin(initData) {
  const parsed = parseInitData(initData);
  if (!parsed.ok) return parsed;

  const user = await prisma.user.findUnique({
    where: { tg_id: Number(parsed.tg_id) },
    select: { role: true }
  });

  if (!user || user.role !== 'admin') {
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

  const isTrainer = user?.role === 'trainer';
  const isCurator = Boolean(user?.isCurator);
  if (!user || (!['admin', 'trainer'].includes(user.role) && !isCurator)) {
    return { ok: false, status: 403, error: 'forbidden' };
  }

  return {
    ok: true,
    tg_id: parsed.tg_id,
    userId: user.id,
    role: user.role,
    trainerScope: normalizeTrainerScope(user.trainerScope),
    canTrain: user.role === 'admin' || isTrainer,
    canCurate: user.role === 'admin' || isCurator,
    user
  };
}

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
    authorRole: 'Тренер Fit Dew',
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
    const parsed = parseInitData(req.body?.initData);
    if (!parsed.ok) return res.status(parsed.status).json({ ok: false, error: parsed.error });

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

// === История питания (GET) ===
app.get('/api/nutrition/history', async (req, res) => {
  try {
    const parsed = parseInitData(req.query.initData);
    if (!parsed.ok) return res.status(parsed.status).json({ ok: false, error: parsed.error });

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
      where: { tg_id: Number(parsed.tg_id) },
      update: {},
      create: {
        tg_id: Number(parsed.tg_id),
        username: parsed.user?.username || null,
        first_name: parsed.user?.first_name || null
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
    const parsed = parseInitData(req.query.initData);
    if (!parsed.ok) return res.status(parsed.status).json({ ok: false, error: parsed.error });

    const date = getDateKey(req.query.date);
    const tg_id = parsed.tg_id;

    const dbUser = await prisma.user.upsert({
      where: { tg_id: Number(tg_id) },
      update: {},
      create: {
        tg_id: Number(tg_id),
        username: parsed.user?.username || null,
        first_name: parsed.user?.first_name || null
      }
    });

    const entry = await prisma.nutritionEntry.findUnique({
      where: { userId_date: { userId: dbUser.id, date } }
    });

    const comment = await prisma.nutritionComment.findUnique({
      where: { userId_date: { userId: dbUser.id, date } },
      select: { text: true }
    });

    res.json({ ok: true, date, entry, comment: comment?.text || null });
  } catch (e) {
    console.error('[api/nutrition:get] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

app.post('/api/nutrition', async (req, res) => {
  try {
    const { initData, date: rawDate } = req.body || {};
    const parsed = parseInitData(initData);
    if (!parsed.ok) return res.status(parsed.status).json({ ok: false, error: parsed.error });

    const date = getDateKey(rawDate);
    const tg_id = parsed.tg_id;

    const dbUser = await prisma.user.upsert({
      where: { tg_id: Number(tg_id) },
      update: {},
      create: {
        tg_id: Number(tg_id),
        username: parsed.user?.username || null,
        first_name: parsed.user?.first_name || null
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
    const { tg_id, mode } = req.body;
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
    const parsed = parseInitData(req.query.initData);
    if (!parsed.ok) return res.status(parsed.status).json({ ok: false, error: parsed.error });

    const limitRaw = Number(req.query.limit || 20);
    const offsetRaw = Number(req.query.offset || 0);
    const limit = Number.isFinite(limitRaw) ? Math.max(1, Math.min(limitRaw, 50)) : 20;
    const offset = Number.isFinite(offsetRaw) ? Math.max(0, offsetRaw) : 0;
    const unreadOnly = String(req.query.unreadOnly || '').toLowerCase() === 'true' || String(req.query.unreadOnly) === '1';

    const dbUser = await prisma.user.upsert({
      where: { tg_id: Number(parsed.tg_id) },
      update: {},
      create: {
        tg_id: Number(parsed.tg_id),
        username: parsed.user?.username || null,
        first_name: parsed.user?.first_name || null
      }
    });

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
    const parsed = parseInitData(req.body?.initData);
    if (!parsed.ok) return res.status(parsed.status).json({ ok: false, error: parsed.error });

    const ids = Array.isArray(req.body?.ids)
      ? req.body.ids.map((id) => Number(id)).filter((id) => Number.isInteger(id))
      : [];
    const markAll = Boolean(req.body?.all);

    const dbUser = await prisma.user.upsert({
      where: { tg_id: Number(parsed.tg_id) },
      update: {},
      create: {
        tg_id: Number(parsed.tg_id),
        username: parsed.user?.username || null,
        first_name: parsed.user?.first_name || null
      }
    });

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
    const trainerId = payload.trainerId ? Number(payload.trainerId) : null;
    let trainer = null;

    if (trainerId) {
      if (!Number.isInteger(trainerId)) {
        return res.status(400).json({ ok: false, error: 'invalid_trainer_id' });
      }
      trainer = await prisma.user.findUnique({
        where: { id: trainerId },
        select: { first_name: true, last_name: true, username: true, role: true }
      });
      if (!trainer || trainer.role !== 'trainer') {
        return res.status(400).json({ ok: false, error: 'trainer_not_found' });
      }
    }

    if (!title) {
      return res.status(400).json({ ok: false, error: 'missing_title' });
    }
    if (!['gym', 'crossfit'].includes(type)) {
      return res.status(400).json({ ok: false, error: 'invalid_type' });
    }
    if (auth.role === 'trainer') {
      const scope = normalizeTrainerScope(auth.trainerScope);
      if (scope !== 'both' && type !== scope) {
        return res.status(403).json({ ok: false, error: 'forbidden_type' });
      }
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
    const authorRole = optionalString(payload.authorRole) || 'Тренер Fit Dew';
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
        authorUserId: trainer?.id || null,
        authorName,
        authorRole,
        authorAvatar: optionalString(payload.authorAvatar),
        weeks: { create: weeksData }
      }
    });

    const tariffFilters = Array.from(new Set(tariffs.flatMap((item) => expandTariffFilter(item))));
    if (tariffFilters.length) {
      const recipients = await prisma.user.findMany({
        where: {
          role: 'user',
          trainingMode: type,
          tariffName: { in: tariffFilters }
        },
        select: { id: true }
      });
      await createNotificationsForUsers(
        recipients.map((user) => user.id),
        {
          type: 'program_available',
          title: 'Новая программа',
          message: buildNotificationPreview(`Доступна новая программа: ${title}`),
          data: { slug: created.slug, type }
        }
      );
    }

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
    const trainerId = payload.trainerId ? Number(payload.trainerId) : null;
    let trainer = null;

    if (trainerId) {
      if (!Number.isInteger(trainerId)) {
        return res.status(400).json({ ok: false, error: 'invalid_trainer_id' });
      }
      trainer = await prisma.user.findUnique({
        where: { id: trainerId },
        select: { first_name: true, last_name: true, username: true, role: true }
      });
      if (!trainer || trainer.role !== 'trainer') {
        return res.status(400).json({ ok: false, error: 'trainer_not_found' });
      }
    }

    if (!title) {
      return res.status(400).json({ ok: false, error: 'missing_title' });
    }
    if (!['gym', 'crossfit'].includes(type)) {
      return res.status(400).json({ ok: false, error: 'invalid_type' });
    }
    if (auth.role === 'trainer') {
      const scope = normalizeTrainerScope(auth.trainerScope);
      if (scope !== 'both' && existingProgram.type !== scope) {
        return res.status(403).json({ ok: false, error: 'forbidden_type' });
      }
      if (scope !== 'both' && type !== scope) {
        return res.status(403).json({ ok: false, error: 'forbidden_type' });
      }
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
    const authorRole = optionalString(payload.authorRole) || 'Тренер Fit Dew';

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

    if (auth.role === 'trainer') {
      const existingProgram = await prisma.trainingProgram.findUnique({
        where: { slug },
        select: { type: true }
      });
      if (!existingProgram) {
        return res.status(404).json({ ok: false, error: 'not_found' });
      }
      const scope = normalizeTrainerScope(auth.trainerScope);
      if (scope !== 'both' && existingProgram.type !== scope) {
        return res.status(403).json({ ok: false, error: 'forbidden_type' });
      }
    }

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

// === Admin: trainers list ===
app.get('/api/admin/trainers', async (req, res) => {
  try {
    const auth = await requireStaff(req.query?.initData);
    if (!auth.ok) return res.status(auth.status).json({ ok: false, error: auth.error });
    if (!auth.canTrain) return res.status(403).json({ ok: false, error: 'forbidden' });

    if (auth.role === 'trainer') {
      const trainer = auth.user;
      return res.json({
        ok: true,
        trainers: trainer ? [{
          id: trainer.id,
          first_name: trainer.first_name,
          last_name: trainer.last_name,
          username: trainer.username,
          trainerScope: normalizeTrainerScope(trainer.trainerScope)
        }] : []
      });
    }

    const trainers = await prisma.user.findMany({
      where: { role: 'trainer' },
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
    if (auth.role !== 'admin') return res.status(403).json({ ok: false, error: 'forbidden' });

    const curators = await prisma.user.findMany({
      where: { isCurator: true },
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

    const where = { role: 'user', isCurator: false };
    if (auth.role !== 'admin') {
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
        trainingMode: true,
        heightCm: true,
        weightKg: true,
        phone: true,
        trainerId: true,
        trainer: {
          select: { id: true, first_name: true, last_name: true, username: true }
        }
      }
    });

    const todayKey = toDateKeyLocal(new Date());
    const ids = clients.map((client) => client.id);
    let filledSet = new Set();
    if (ids.length) {
      const filled = await prisma.nutritionEntry.findMany({
        where: { userId: { in: ids }, date: todayKey },
        select: { userId: true }
      });
      filledSet = new Set(filled.map((entry) => entry.userId));
    }

    const normalized = clients.map((client) => ({
      ...client,
      tariffName: normalizeTariffName(client.tariffName),
      trainer: client.trainer
        ? {
            id: client.trainer.id,
            name: [client.trainer.first_name, client.trainer.last_name].filter(Boolean).join(' ') || client.trainer.username,
            username: client.trainer.username || null
          }
        : null,
      hasTodayNutrition: filledSet.has(client.id)
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

    if (auth.role !== 'admin' && client.trainerId !== auth.userId) {
      return res.status(403).json({ ok: false, error: 'forbidden' });
    }

    res.json({
      ok: true,
      client: {
        ...client,
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
    if (auth.role !== 'admin') return res.status(403).json({ ok: false, error: 'forbidden' });

    const clientId = Number(req.params.id);
    if (!Number.isInteger(clientId)) {
      return res.status(400).json({ ok: false, error: 'invalid_client_id' });
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
        select: { id: true, role: true, trainerScope: true, isCurator: true }
      });
      if (!trainer || (!trainer.isCurator && trainer.role !== 'trainer')) {
        return res.status(400).json({ ok: false, error: 'trainer_not_found' });
      }
    }

    const updated = await prisma.user.update({
      where: { id: clientId },
      data: { trainerId }
    });

    res.json({ ok: true, trainerId: updated.trainerId });
  } catch (e) {
    console.error('[api/admin/clients:trainer] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

// === Admin: update staff roles ===
app.post('/api/admin/clients/:id/staff', async (req, res) => {
  try {
    const auth = await requireAdmin(req.body?.initData);
    if (!auth.ok) return res.status(auth.status).json({ ok: false, error: auth.error });

    const clientId = Number(req.params.id);
    if (!Number.isInteger(clientId)) {
      return res.status(400).json({ ok: false, error: 'invalid_client_id' });
    }

    const target = await prisma.user.findUnique({
      where: { id: clientId },
      select: { id: true, role: true }
    });
    if (!target) return res.status(404).json({ ok: false, error: 'not_found' });
    if (target.role === 'admin') {
      return res.status(400).json({ ok: false, error: 'cannot_edit_admin' });
    }

    const isTrainer = Boolean(req.body?.isTrainer);
    const isCurator = Boolean(req.body?.isCurator);
    const trainerScope = isTrainer ? normalizeTrainerScope(req.body?.trainerScope) : null;
    const role = isTrainer ? 'trainer' : 'user';

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
      select: { id: true, trainerId: true }
    });
    if (!client) return res.status(404).json({ ok: false, error: 'not_found' });
    if (auth.role !== 'admin' && client.trainerId !== auth.userId) {
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
      select: { id: true, trainerId: true }
    });
    if (!client) return res.status(404).json({ ok: false, error: 'not_found' });
    if (auth.role !== 'admin' && client.trainerId !== auth.userId) {
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
    await prisma.notification.create({
      data: {
        userId: client.id,
        type: 'nutrition_comment',
        title: 'Комментарий к питанию',
        message: preview,
        data: { date }
      }
    });

    res.json({ ok: true, comment });
  } catch (e) {
    console.error('[api/admin/clients:comment] error', e);
    res.status(500).json({ ok: false, error: 'server_error' });
  }
});

// === Admin: exercise library ===
app.get('/api/admin/exercises', async (req, res) => {
  try {
    const auth = await requireStaff(req.query?.initData);
    if (!auth.ok) return res.status(auth.status).json({ ok: false, error: auth.error });
    if (!auth.canTrain) return res.status(403).json({ ok: false, error: 'forbidden' });

    const where = {};
    if (auth.role === 'trainer') {
      const scope = normalizeTrainerScope(auth.trainerScope);
      if (scope !== 'both') {
        where.type = scope;
      }
    }

    const exercises = await prisma.exercise.findMany({
      where,
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
  if (auth.role === 'trainer') {
    const scope = normalizeTrainerScope(auth.trainerScope);
    if (scope !== 'both' && normalizedType !== scope) {
      return res.status(403).json({ ok: false, error: 'forbidden_type' });
      }
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
        description: optionalString(payload.description),
        videoUrl: optionalString(payload.videoUrl)
      }
    });

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
  if (auth.role === 'trainer') {
    const scope = normalizeTrainerScope(auth.trainerScope);
    if (scope !== 'both' && normalizedType !== scope) {
      return res.status(403).json({ ok: false, error: 'forbidden_type' });
      }
      const existing = await prisma.exercise.findUnique({
        where: { id },
        select: { type: true }
      });
      if (!existing) {
        return res.status(404).json({ ok: false, error: 'not_found' });
      }
      if (scope !== 'both' && existing.type !== scope) {
        return res.status(403).json({ ok: false, error: 'forbidden_type' });
      }
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

// === Exercises (public) ===
app.get('/api/exercises', async (req, res) => {
  try {
    const typeRaw = cleanString(req.query?.type);
    const normalizedType = typeRaw === 'crossfit' ? 'crossfit' : typeRaw === 'gym' ? 'gym' : '';
    const tariff = normalizeTariffName(cleanString(req.query?.tariff));
    const where = {};
    if (normalizedType) where.type = normalizedType;
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
    const where = {};
    if (type && ['gym', 'crossfit'].includes(type)) {
      where.type = type;
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
