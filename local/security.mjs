import { randomBytes, createHash, scryptSync, timingSafeEqual } from 'node:crypto';
import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';

const digest = value => createHash('sha256').update(value).digest('hex');
export function createSecurity(db, databasePath, passwordOverride, config={}) {
  db.exec(`CREATE TABLE IF NOT EXISTS auth_config (id TEXT PRIMARY KEY, salt TEXT, hash TEXT);
    CREATE TABLE IF NOT EXISTS principals (hash TEXT PRIMARY KEY, id TEXT, role TEXT, expires INTEGER);`);
  if (!db.prepare('SELECT id FROM auth_config WHERE id=?').get('admin')) {
    const password = passwordOverride || process.env.SAFEUG_ADMIN_PASSWORD || randomBytes(18).toString('base64url');
    if (config.production && (!process.env.SAFEUG_ADMIN_PASSWORD && !passwordOverride || password.length<16)) throw new Error('First production start requires SAFEUG_ADMIN_PASSWORD with at least 16 characters');
    const salt = randomBytes(16).toString('hex');
    db.prepare('INSERT INTO auth_config VALUES(?,?,?)').run('admin',salt,scryptSync(password,salt,64).toString('hex'));
    if (databasePath !== ':memory:' && !passwordOverride && !process.env.SAFEUG_ADMIN_PASSWORD) writeFileSync(join(dirname(databasePath),'admin-bootstrap.txt'), `SafeUG administrator\nUsername: admin\nPassword: ${password}\nKeep this file private.\n`, {mode:0o600,flag:'wx'});
  }
  const attempts = new Map();
  const session = (role, lifetime) => {
    const token = randomBytes(32).toString('base64url');
    const id = randomBytes(16).toString('hex');
    db.prepare('INSERT INTO principals VALUES(?,?,?,?)').run(digest(token),id,role,Date.now()+lifetime);
    return {token,id,role};
  };
  function actor(req) {
    const cookie = /(?:^|;\s*)safeug_session=([^;]+)/.exec(req.headers.cookie || '')?.[1];
    const token = req.headers.authorization?.replace(/^Bearer /,'') || cookie;
    if (!token) return null;
    return db.prepare('SELECT id,role,expires FROM principals WHERE hash=? AND expires>?').get(digest(token),Date.now()) || null;
  }
  async function handle(req,res,path,readBody,reply) {
    for (const [key,entry] of attempts) if(entry.until<=Date.now()) attempts.delete(key);
    const clientAddress=req.clientAddress || req.socket.remoteAddress;
    if (path === '/api/auth/device' && req.method === 'POST') {
      const key = `device:${clientAddress}`;
      const recent = attempts.get(key);
      if (recent && recent.until > Date.now() && recent.count >= 30) { reply(429,{error:'Please wait before registering another device'}); return true; }
      attempts.set(key,{count: recent?.until > Date.now() ? recent.count+1 : 1,until: Date.now()+3600000});
      reply(201,session('device',365*86400000)); return true;
    }
    if (path === '/api/auth/login' && req.method === 'POST') {
      const key = clientAddress;
      const rate = attempts.get(key);
      if (rate && rate.until>Date.now() && rate.count>=8) { reply(429,{error:'Too many attempts. Try again in 15 minutes.'}); return true; }
      const input = JSON.parse(await readBody(4096));
      if (!input || typeof input !== 'object' || typeof input.password !== 'string') { reply(400,{error:'Invalid sign-in request'}); return true; }
      const config = db.prepare('SELECT * FROM auth_config WHERE id=?').get('admin');
      const supplied = scryptSync(String(input.password || ''),config.salt,64);
      if (input.username !== 'admin' || !timingSafeEqual(supplied,Buffer.from(config.hash,'hex'))) {
        attempts.set(key,{count: rate?.until>Date.now() ? rate.count+1 : 1,until:Date.now()+900000});
        reply(401,{error:'Invalid administrator credentials'}); return true;
      }
      attempts.delete(key);
      const auth = session('admin',8*3600000);
      res.setHeader('Set-Cookie',`safeug_session=${auth.token}; HttpOnly; SameSite=Strict; Path=/; Max-Age=28800${req.secure ? '; Secure' : ''}`);
      reply(200,{role:'admin'}); return true;
    }
    if (path === '/api/auth/logout' && req.method === 'POST') {
      const cookie = /(?:^|;\s*)safeug_session=([^;]+)/.exec(req.headers.cookie || '')?.[1];
      if (cookie) db.prepare('DELETE FROM principals WHERE hash=?').run(digest(cookie));
      res.setHeader('Set-Cookie',`safeug_session=; HttpOnly; SameSite=Strict; Path=/; Max-Age=0${req.secure ? '; Secure' : ''}`);
      reply(200,{ok:true}); return true;
    }
    if (path === '/api/auth/session') { const who = actor(req); reply(who ? 200 : 401, {role: who?.role ?? null}); return true; }
    return false;
  }
  return {actor,handle};
}
