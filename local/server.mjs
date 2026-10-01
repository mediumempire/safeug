import http from 'node:http';
import { DatabaseSync } from 'node:sqlite';
import { mkdirSync, existsSync, statSync, createReadStream, realpathSync } from 'node:fs';
import { resolve, dirname, extname, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { randomUUID, randomBytes } from 'node:crypto';
import { createSecurity } from './security.mjs';
import { integrationStatus } from './integrations.mjs';
import { createRealtime } from './realtime.mjs';
import { runtimeConfig, requestContext } from './runtime-config.mjs';
import {seedCatalog} from './catalog.mjs';
import {guideApplications} from './guide-applications.mjs';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const collections = ['incidents', 'rangers', 'tourists', 'parks', 'wildlife', 'devices', 'contacts', 'guides', 'tips', 'services', 'locations', 'welfare', 'guideApplications'];
const statuses = ['Reported', 'Acknowledged', 'Dispatched', 'En Route', 'Resolved', 'False Alarm'];
const incidentTypes = ['Suspicious Activity', 'Animal Sighting', 'Safety Hazard', 'Human-Wildlife Conflict', 'Illegal Encroachment', 'Other', 'SOS', 'Poaching', 'Medical', 'Lost tourist', 'Fire', 'Ranger down', 'Backup needed', 'Wildlife'];
const severities = ['Low', 'Medium', 'High', 'Critical'];
const normalizeIncidentType = value => {
  const key = String(value).trim().toLowerCase();
  const aliases = {'sos activation':'SOS', 'safety concern':'Safety Hazard', 'poaching activity':'Poaching'};
  return aliases[key] || incidentTypes.find(type => type.toLowerCase() === key);
};
const isTimestamp = value => typeof value === 'string' && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/.test(value) && Number.isFinite(Date.parse(value));

export function createSafeUgServer(databasePath = process.env.SAFEUG_DATABASE_PATH || resolve(root, 'local/data/safeug.sqlite'), options = {}) {
  const config=runtimeConfig(options);
  if (config.production && databasePath !== ':memory:' && !process.env.SAFEUG_DATABASE_PATH && !options.allowDefaultDatabase) throw new Error('Production requires SAFEUG_DATABASE_PATH outside the release directory');
  if (databasePath !== ':memory:') mkdirSync(dirname(databasePath), { recursive: true });
  const db = new DatabaseSync(databasePath);
  db.exec('PRAGMA journal_mode=WAL; PRAGMA busy_timeout=5000; CREATE TABLE IF NOT EXISTS records (collection TEXT NOT NULL, id TEXT NOT NULL, data TEXT NOT NULL, PRIMARY KEY(collection,id));');
  const all = db.prepare('SELECT collection, data FROM records');
  const get = db.prepare('SELECT data FROM records WHERE collection=? AND id=?');
  const put = db.prepare('INSERT OR REPLACE INTO records(collection,id,data) VALUES(?,?,?)');
  const security = createSecurity(db,databasePath,options.adminPassword,config);
  db.exec('CREATE TABLE IF NOT EXISTS guide_ratings (guide TEXT NOT NULL, owner TEXT NOT NULL, score INTEGER NOT NULL CHECK(score BETWEEN 1 AND 5), updatedAt TEXT NOT NULL, PRIMARY KEY(guide,owner));');
  const guideView = (record, actor) => {
    const summary=db.prepare('SELECT AVG(score) AS rating, COUNT(*) AS ratingCount FROM guide_ratings WHERE guide=?').get(record.id);
    const mine=actor.role==='admin'?null:db.prepare('SELECT score FROM guide_ratings WHERE guide=? AND owner=?').get(record.id,actor.id);
    return {...record,rating:summary.rating,ratingCount:summary.ratingCount,...(actor.role==='admin'?{}:{myRating:mine?.score ?? null})};
  };
  const realtime = createRealtime(security,{timeoutMs:options.realtimeTimeoutMs});
  if(options.seedCatalog===true || (config.production && options.seedCatalog!==false)) seedCatalog(db);
  if(options.seedContacts!==false) {
    const defaults=[
      {id:'ug-police',name:'National Police',phone:'999',description:'Uganda Police emergency line. Alternate: 112. Source: upf.go.ug/faq/'},
      {id:'ug-ambulance',name:'Ambulance / Medical emergency',phone:'912',description:'Ministry of Health emergency short code. Network and regional availability may vary. Alternate health line: 0800100066. Source: alerts.health.go.ug/add-alert'},
      {id:'ug-tourist-police',name:'Tourist Police',phone:'0800300117',description:'Tourism Police toll-free contact. Source: Uganda Police Annual Crime Report 2024. If unavailable, call 999 or 112.'},
    ];
    for(const record of defaults) if(!get.get('services',record.id)) put.run('services',record.id,JSON.stringify({...record,status:'Active',area:'Uganda',createdAt:new Date().toISOString(),updatedAt:new Date().toISOString()}));
  }
  const published = ['guides','tips','services','parks'];
  const owned = ['incidents','contacts','locations','welfare','guideApplications'];
  db.exec('CREATE TABLE IF NOT EXISTS evidence (id TEXT PRIMARY KEY, owner TEXT, incident TEXT, mime TEXT, data BLOB);');
  const server = http.createServer(async (req, res) => {
    Object.assign(req,requestContext(req,config));
    res.setHeader('X-Content-Type-Options','nosniff');
    res.setHeader('Referrer-Policy','strict-origin-when-cross-origin');
    res.setHeader('X-Frame-Options','DENY');
    const reply = (code, data) => { res.writeHead(code, {'Content-Type':'application/json', 'Cache-Control':'no-store'}); res.end(JSON.stringify(data)); };
    try {
      const url = new URL(req.url, 'http://localhost');
      if (url.pathname==='/healthz' && req.method==='GET') {
        db.prepare('SELECT 1').get();
        return reply(200,{ok:true,service:'safeug'});
      }
      if (config.production && (!req.secure || req.headers.host!==new URL(config.publicOrigin).host)) return reply(400,{error:'Use the configured HTTPS SafeUG address'});
      // A separate, revocable capability per contact; never expose the owner's
      // identity, other contacts, or historical positions through this endpoint.
      const share = url.pathname.match(/^\/share\/([a-f0-9]{64})$/);
      if (share && req.method === 'GET') {
        const contactRow = db.prepare("SELECT data FROM records WHERE collection='contacts' AND json_extract(data,'$.shareToken')=?").get(share[1]);
        const contact = contactRow && JSON.parse(contactRow.data);
        if (!contact || contact.status === 'Inactive' || contact.shareLocation !== true) return reply(404,{error:'Location sharing is off or this link has expired.'});
        const row = get.get('locations', `live_${contact.ownerId}`);
        const location = row && JSON.parse(row.data);
        if (!location || location.status !== 'Sharing' || !isTimestamp(location.locationCapturedAt) || Date.now()-Date.parse(location.locationCapturedAt)>120000) return reply(410,{error:'No recent device location. The sender must open SafeUG and allow location access.'});
        const map = `https://www.openstreetmap.org/?mlat=${location.latitude}&mlon=${location.longitude}#map=16/${location.latitude}/${location.longitude}`;
        res.writeHead(200,{'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store','Referrer-Policy':'no-referrer','Content-Security-Policy':"default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; frame-ancestors 'none'",'X-Content-Type-Options':'nosniff'});
        return res.end(`<!doctype html><html lang="en"><meta name="viewport" content="width=device-width,initial-scale=1"><title>SafeUG shared location</title><style>body{font:18px system-ui;max-width:600px;margin:60px auto;padding:24px;background:#eff5f4;color:#123c31}a{display:inline-block;padding:16px;background:#006b52;color:white;border-radius:12px}</style><h1>SafeUG shared location</h1><p>Last updated: ${location.locationCapturedAt}</p><p>Accuracy: ${Math.round(location.accuracy || 0)} metres</p><a rel="noreferrer" href="${map}">Open location on map</a><p>Refresh this page for the latest position. Access ends when sharing is switched off. Keep this private link with the intended contact.</p></html>`);
      }
      if (url.pathname.startsWith('/api/')) {
        if (req.headers.origin) {
          let origin; try { origin=new URL(req.headers.origin).origin; } catch { return reply(403,{error:'Invalid origin'}); }
          const expected=config.publicOrigin || `${req.secure?'https':'http'}://${req.headers.host}`;
          if (origin!==expected) return reply(403,{error:'Cross-origin access is disabled'});
        }
        const readBody = async (limit=12*1024*1024) => { const chunks=[]; let size=0; for await (const chunk of req) { size+=chunk.length; if(size>limit) { const error=new Error('Body too large'); error.status=413; throw error; } chunks.push(chunk); } return Buffer.concat(chunks).toString('utf8'); };
        if (await security.handle(req,res,url.pathname,readBody,reply)) return;
        const actor = security.actor(req);
        if (!actor) return reply(401,{error:'Authentication required'});
        const admin = actor.role === 'admin';
        if(url.pathname==='/api/guideApplications' || url.pathname.startsWith('/api/guideApplications/')) {
          if(req.method!=='POST')return reply(405,{error:'Use the application workflow'});
          return guideApplications({path:url.pathname,method:req.method,input:JSON.parse(await readBody(12000)),actor,db,realtime,reply});
        }
        if (url.pathname === '/api/changes' && req.method === 'GET') {
          return realtime.wait(req,res,actor,url.searchParams.get('since'),reply);
        }
        const guideRating=url.pathname.match(/^\/api\/guides\/([a-zA-Z0-9_-]{1,100})\/rating$/);
        if (guideRating && req.method === 'PUT') {
          if (admin) return reply(403,{error:'Only mobile visitors can rate guides'});
          const input=JSON.parse(await readBody(1000));
          if (!input || !Number.isInteger(input.score) || input.score<1 || input.score>5) return reply(400,{error:'Choose a rating from 1 to 5'});
          const row=get.get('guides',guideRating[1]);
          if (!row || JSON.parse(row.data).status==='Inactive') return reply(404,{error:'Guide is no longer available'});
          const guide=JSON.parse(row.data);
          db.prepare('INSERT INTO guide_ratings(guide,owner,score,updatedAt) VALUES(?,?,?,?) ON CONFLICT(guide,owner) DO UPDATE SET score=excluded.score,updatedAt=excluded.updatedAt').run(guide.id,actor.id,input.score,new Date().toISOString());
          realtime.changed('guides',guide);
          return reply(200,guideView(guide,actor));
        }
        if (url.pathname === '/api/live-location' && req.method === 'PUT') {
          if (admin) return reply(403,{error:'Mobile device required'});
          const input=JSON.parse(await readBody(4000));
          if (typeof input?.latitude !== 'number' || !Number.isFinite(input.latitude) || Math.abs(input.latitude)>90 || typeof input.longitude !== 'number' || !Number.isFinite(input.longitude) || Math.abs(input.longitude)>180 || typeof input.accuracy !== 'number' || !Number.isFinite(input.accuracy) || input.accuracy<0 || !isTimestamp(input.locationCapturedAt) || Math.abs(Date.now()-Date.parse(input.locationCapturedAt))>120000) return reply(400,{error:'A recent device location is required'});
          const enabled=db.prepare("SELECT data FROM records WHERE collection='contacts' AND json_extract(data,'$.ownerId')=? AND json_extract(data,'$.shareLocation')=1 AND json_extract(data,'$.status')!='Inactive'").all(actor.id);
          if (!enabled.length) return reply(409,{error:'No contacts selected for location sharing'});
          const id=`live_${actor.id}`;
          const record={id,ownerId:actor.id,name:'Shared device location',status:'Sharing',latitude:input.latitude,longitude:input.longitude,accuracy:input.accuracy,locationCapturedAt:new Date(input.locationCapturedAt).toISOString(),locationSource:'device',updatedAt:new Date().toISOString()};
          put.run('locations',id,JSON.stringify(record));
          realtime.changed('locations',record);
          return reply(200,record);
        }
        if (url.pathname === '/api/tourist-profile' && req.method === 'PUT') {
          if (admin) return reply(403,{error:'Mobile device registration required'});
          const input=JSON.parse(await readBody(16000));
          if (!input || Array.isArray(input) || typeof input!=='object' || input.consent!==true) return reply(400,{error:'Consent to share your profile with administrators is required'});
          const profile={};
          for (const key of ['name','phone','email','country','area','emergencyContactName','emergencyContactPhone']) {
            const value=input[key] ?? '';
            if(typeof value!=='string' || value.length>200) return reply(400,{error:`Invalid ${key}`});
            profile[key]=value.trim();
          }
          if(!profile.name || !/^[+\d ()-]{5,40}$/.test(profile.phone)) return reply(400,{error:'Full name and a valid phone number are required'});
          if(profile.email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(profile.email)) return reply(400,{error:'Invalid email address'});
          const id=`tourist_${actor.id}`;
          const existing=get.get('tourists',id);
          const previous=existing?JSON.parse(existing.data):{};
          const now=new Date().toISOString();
          const record={...previous,...profile,id,ownerId:actor.id,status:previous.status || 'Active',source:'Mobile registration',consentAt:previous.consentAt || now,createdAt:previous.createdAt || now,updatedAt:now};
          put.run('tourists',id,JSON.stringify(record));
          realtime.changed('tourists',record);
          return reply(existing?200:201,record);
        }
        if(url.pathname==='/api/integrations' && req.method==='GET') {
          if(!admin)return reply(403,{error:'Administrator permission required'});
          return reply(200,integrationStatus());
        }
        if (url.pathname === '/api/translate' && req.method === 'POST') {
          if (!process.env.SAFEUG_TRANSLATE_URL) return reply(503,{error:'Translation service not configured. Set SAFEUG_TRANSLATE_URL to a LibreTranslate-compatible service on the laptop.'});
          const input=JSON.parse(await readBody(12000));
          if (typeof input.q !== 'string' || input.q.length>2000 || !['en','sw','fr','es','de'].includes(input.source) || !['en','sw','fr','es','de'].includes(input.target)) return reply(400,{error:'Invalid translation request'});
          const upstream=await fetch(process.env.SAFEUG_TRANSLATE_URL,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({q:input.q,source:input.source,target:input.target,format:'text',api_key:process.env.SAFEUG_TRANSLATE_KEY}),signal:AbortSignal.timeout(20000)});
          if(!upstream.ok) return reply(502,{error:'Translation provider unavailable'});
          const translated=await upstream.json();
          if(typeof translated.translatedText!=='string') return reply(502,{error:'Unexpected translation response'});
          return reply(200,{translatedText:translated.translatedText});
        }
        if (url.pathname.startsWith('/api/dispatch/') && req.method==='POST') {
          if(!admin)return reply(403,{error:'Administrator permission required'});
          if(!process.env.SAFEUG_DISPATCH_URL)return reply(503,{error:'No external dispatch gateway configured. No responder has been contacted.'});
          const id=url.pathname.split('/').pop();
          const existing=get.get('incidents',id);
          if(!existing)return reply(404,{error:'Incident not found'});
          const incident=JSON.parse(existing.data);
          if(incident.externalDelivery==='Submitted')return reply(200,incident);
          const destination=new URL(process.env.SAFEUG_DISPATCH_URL);
          if(destination.protocol!=='https:')return reply(503,{error:'Dispatch gateway requires HTTPS'});
          const response=await fetch(destination,{method:'POST',headers:{'Content-Type':'application/json','Idempotency-Key':id,...(process.env.SAFEUG_DISPATCH_TOKEN?{Authorization:`Bearer ${process.env.SAFEUG_DISPATCH_TOKEN}`}:{})},body:JSON.stringify({id,type:incident.type,severity:incident.severity,description:incident.description,area:incident.area,reporter:incident.reporter,phone:incident.phone,latitude:incident.latitude,longitude:incident.longitude,accuracy:incident.accuracy,locationCapturedAt:incident.locationCapturedAt,occurredAt:incident.occurredAt,reportedAt:incident.reportedAt}),signal:AbortSignal.timeout(15000)});
          incident.externalDelivery=response.ok?'Submitted':'Failed';
          incident.externalSubmittedAt=new Date().toISOString();
          incident.updatedAt=incident.externalSubmittedAt;
          put.run('incidents',id,JSON.stringify(incident));
          realtime.changed('incidents',incident);
          return reply(response.ok?200:502, response.ok?incident:{error:'Gateway rejected the request. No delivery confirmed.'});
        }
        if (url.pathname.startsWith('/api/evidence/') && req.method === 'GET') {
          const file = db.prepare('SELECT * FROM evidence WHERE id=?').get(url.pathname.split('/').pop());
          if (!file || (!admin && file.owner !== actor.id)) return reply(404,{error:'Evidence not found'});
          res.writeHead(200,{'Content-Type':file.mime,'Cache-Control':'no-store','X-Content-Type-Options':'nosniff'}); return res.end(file.data);
        }
        if (req.method === 'GET' && url.pathname === '/api/state') {
          const data = Object.fromEntries(collections.map(c => [c, []]));
          for (const row of all.all()) {
            const record=JSON.parse(row.data);
            if (admin || (published.includes(row.collection) && record.status !== 'Inactive') || ((owned.includes(row.collection) || row.collection==='tourists') && record.ownerId === actor.id)) data[row.collection]?.push(row.collection==='guides'?guideView(record,actor):record);
          }
          return reply(200, { ...data, ...(admin?{integrations:integrationStatus()}:{}), revision:realtime.revision(actor), serverTime: new Date().toISOString() });
        }
        const incidentAction=url.pathname.match(/^\/api\/incidents\/([a-zA-Z0-9_-]{1,100})\/(location|stand-down)$/);
        if (incidentAction && req.method === 'POST') {
          const [, id, action]=incidentAction;
          const existing=get.get('incidents',id);
          if (!existing) return reply(404,{error:'Incident not found'});
          const incident=JSON.parse(existing.data);
          if (!admin && incident.ownerId !== actor.id) return reply(403,{error:'Record belongs to another device'});
          if (normalizeIncidentType(incident.type) !== 'SOS' && !(action === 'location' && normalizeIncidentType(incident.type) === 'Ranger down')) return reply(400,{error:'This action is not available for this incident'});
          const input=JSON.parse(await readBody(4000));
          if (!input || Array.isArray(input) || typeof input !== 'object') return reply(400,{error:'Expected an SOS update'});
          // A repeated retry or a late GPS response must never reopen a closed alert.
          if (['Resolved','False Alarm'].includes(incident.status)) return reply(200,incident);
          const now=new Date().toISOString();
          if (action === 'location') {
            if (typeof input.latitude !== 'number' || !Number.isFinite(input.latitude) || Math.abs(input.latitude)>90 || typeof input.longitude !== 'number' || !Number.isFinite(input.longitude) || Math.abs(input.longitude)>180 || (input.accuracy != null && (typeof input.accuracy !== 'number' || !Number.isFinite(input.accuracy) || input.accuracy<0)) || !isTimestamp(input.locationCapturedAt)) return reply(400,{error:'Invalid device location'});
            const capturedAt=new Date(input.locationCapturedAt).toISOString();
            if (incident.locationCapturedAt && Date.parse(incident.locationCapturedAt)>=Date.parse(capturedAt)) return reply(200,incident);
            Object.assign(incident,{latitude:input.latitude,longitude:input.longitude,accuracy:input.accuracy ?? null,locationCapturedAt:capturedAt,locationSource:'device'});
            incident.initialLatitude ??= input.latitude;
            incident.initialLongitude ??= input.longitude;
            incident.locationHistory=[...(incident.locationHistory || []),{latitude:input.latitude,longitude:input.longitude,accuracy:input.accuracy ?? null,capturedAt}].slice(-100);
          } else {
            if (input.reason !== 'I am safe / accidental activation') return reply(400,{error:'Confirm that you are safe or the activation was accidental'});
            incident.statusHistory ??= [{status:incident.status,at:incident.createdAt,actor:'system'}];
            incident.statusHistory.push({status:'False Alarm',at:now,actor:admin?'admin':'mobile',note:input.reason});
            incident.status='False Alarm';
            incident.resolutionDetails=input.reason;
            incident.resolvedAt=now;
            incident.standDownAt=now;
            incident.standDownBy=admin?'admin':'mobile';
          }
          incident.updatedAt=now;
          put.run('incidents',id,JSON.stringify(incident));
          realtime.changed('incidents',incident);
          return reply(200,incident);
        }
        const [, , collection, pathId] = url.pathname.split('/');
        if (!collections.includes(collection) || !['POST','PATCH'].includes(req.method)) return reply(404, {error:'Unknown operation'});
        if (!admin && (!owned.includes(collection) || (collection === 'incidents' && req.method !== 'POST'))) return reply(403,{error:'Administrator permission required'});
        const body = await readBody();
        let input; try { input = JSON.parse(body); } catch { return reply(400, {error:'Invalid JSON'}); }
        if (!input || Array.isArray(input) || typeof input !== 'object') return reply(400, {error:'Expected a record'});
        const id = pathId || input.id || randomUUID();
        if (typeof id !== 'string' || !/^[a-zA-Z0-9_-]{1,100}$/.test(id)) return reply(400, {error:'Invalid record ID'});
        const existing = get.get(collection, id);
        if (existing && !admin && JSON.parse(existing.data).ownerId !== actor.id) return reply(403,{error:'Record belongs to another device'});
        if (req.method === 'POST' && existing) return reply(200, collection==='guides'?guideView(JSON.parse(existing.data),actor):JSON.parse(existing.data));
        if (req.method === 'PATCH' && !existing) return reply(404, {error:'Record not found'});
        const data = existing ? JSON.parse(existing.data) : {};
        const previousStatus = data.status;
        const allowed = ['name','type','area','status','description','phone','health','latitude','longitude','accuracy','battery','reportedAt','reporter','language','assignment','locationCapturedAt','locationSource'];
        if(collection==='incidents') allowed.push('severity','occurredAt','resolutionDetails');
        if(collection==='incidents' && admin) allowed.push('responseAgency','responseNote');
        if(collection==='tourists') allowed.push('email','country','emergencyContactName','emergencyContactPhone');
        if(collection==='tips') allowed.push('category','tags','sourceUrl');
        if(collection==='contacts') allowed.push('relationship');
        for (const key of allowed) {
          if (!(key in input)) continue;
          const value = input[key];
          if (['latitude','longitude','accuracy','battery'].includes(key)) {
            if (value !== null && (typeof value !== 'number' || !Number.isFinite(value))) return reply(400, {error:`Invalid ${key}`});
            if (key === 'latitude' && value !== null && Math.abs(value) > 90) return reply(400, {error:'Invalid latitude'});
            if (key === 'longitude' && value !== null && Math.abs(value) > 180) return reply(400, {error:'Invalid longitude'});
            if (key === 'accuracy' && value !== null && value < 0) return reply(400, {error:'Invalid accuracy'});
            if (key === 'battery' && value !== null && (value < 0 || value > 100)) return reply(400, {error:'Invalid battery'});
          } else if (typeof value !== 'string' || value.length > 4000) return reply(400, {error:`Invalid ${key}`});
          data[key] = value;
        }
        for (const key of ['reportedAt','occurredAt','locationCapturedAt']) {
          if (key in input && !isTimestamp(input[key])) return reply(400,{error:`Invalid ${key}`});
          if (key in input) data[key]=new Date(input[key]).toISOString();
        }
        if (data.locationSource && !['device','landmark','unavailable'].includes(data.locationSource)) return reply(400,{error:'Invalid location source'});
        if (collection === 'incidents') {
          if (admin && input.responseAgency?.trim()) {
            data.agencyResponses = {...(data.agencyResponses || {}), [input.responseAgency.trim()]: {note: data.responseNote || '', at: new Date().toISOString(), actor: 'admin'}};
          }
          if (!admin) data.status='Reported';
          data.status ??= 'Reported';
          if (!statuses.includes(data.status)) return reply(400, {error:'Invalid incident status'});
          data.type=normalizeIncidentType(data.type ?? 'SOS');
          if (data.type === 'SOS') data.requestedAgencies=['UPF','Tourist Police','UPDF'];
          if (!data.type) return reply(400,{error:'Invalid incident type'});
          data.severity ??= ['SOS','Ranger down'].includes(data.type)?'Critical':'Medium';
          if(!severities.includes(data.severity)) return reply(400,{error:'Invalid incident severity'});
          if ((data.latitude == null) !== (data.longitude == null)) return reply(400,{error:'A complete device location is required'});
          if (data.phone && !/^[+\d ()-]{5,40}$/.test(data.phone)) return reply(400,{error:'Invalid reporter phone number'});
          if (!admin) {
            // Link the report to its authenticated device profile, never an ID
            // supplied by the mobile client. Explicit contact fields remain optional.
            const profileRow=get.get('tourists',`tourist_${actor.id}`);
            if (profileRow) {
              const profile=JSON.parse(profileRow.data);
              data.reporterTouristId=profile.id;
              data.reporter ||= profile.name;
              data.phone ||= profile.phone;
            }
          }
          data.locationSource ??= data.latitude != null?'device':data.area?.trim()?'landmark':'unavailable';
          if (data.locationSource === 'device' && data.latitude == null) return reply(400,{error:'Device location is missing'});
          if (!existing && !['SOS','Ranger down'].includes(data.type)) {
            if (!data.description?.trim()) return reply(400,{error:'Describe what happened'});
            if (data.latitude == null && !data.area?.trim()) return reply(400,{error:'Attach your device location or enter an area or landmark'});
          }
        } else if (!data.name?.trim()) return reply(400, {error:'Name is required'});
        if (collection === 'contacts') {
          if (!/^[+\d ()-]{5,40}$/.test(data.phone || '')) return reply(400,{error:'A valid contact phone number is required'});
          if (!data.relationship?.trim() || data.relationship.length>100 || data.name.length>200) return reply(400,{error:'Contact name and relationship are required'});
          if ('shareLocation' in input && typeof input.shareLocation !== 'boolean') return reply(400,{error:'Invalid sharing preference'});
          data.status ??= 'Active';
          if (!['Active','Inactive'].includes(data.status)) return reply(400,{error:'Invalid contact status'});
          const enabled=data.status !== 'Inactive' && (input.shareLocation ?? data.shareLocation ?? false);
          // Rotate capabilities whenever consent is revoked or the recipient changes.
          if (!enabled || !data.shareLocation || (existing && JSON.parse(existing.data).phone !== data.phone)) data.shareToken=enabled?randomBytes(32).toString('hex'):null;
          data.shareLocation=enabled;
        }
        data.ownerId ??= actor.id;
        const attachments=[];
        let total=0;
        if (input.evidence !== undefined && (!Array.isArray(input.evidence) || collection !== 'incidents' || input.evidence.length>4)) return reply(400,{error:'Invalid evidence'});
        for (const item of input.evidence || []) {
          if (!item || Array.isArray(item) || typeof item !== 'object') return reply(400,{error:'Invalid evidence item'});
          if (!['image/jpeg','image/png','image/webp','video/mp4','video/webm','video/quicktime'].includes(item.mime) || typeof item.base64 !== 'string') return reply(400,{error:'Unsupported evidence type'});
          const bytes=Buffer.from(item.base64,'base64'); total+=bytes.length;
          if (!bytes.length || total>8*1024*1024) return reply(413,{error:'Evidence limit is 8 MB per report'});
          const magic=bytes.subarray(0,12);
          const valid = item.mime==='image/jpeg' ? magic[0]===255 && magic[1]===216 : item.mime==='image/png' ? magic.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10])) : item.mime==='image/webp' ? magic.toString('ascii',0,4)==='RIFF' && magic.toString('ascii',8,12)==='WEBP' : item.mime==='video/webm' ? magic.subarray(0,4).equals(Buffer.from([26,69,223,163])) : magic.toString('ascii',4,8)==='ftyp';
          if (!valid) return reply(400,{error:'Evidence format does not match the file'});
          attachments.push({id:randomUUID(),mime:item.mime,name:String(item.name || 'Evidence').slice(0,120),bytes});
        }
        const now = new Date().toISOString();
        data.id = id; data.createdAt ??= now; data.updatedAt = now;
        if (collection === 'incidents') {
          data.reportedAt ??= now;
          data.occurredAt ??= data.reportedAt;
          if ((!existing || 'occurredAt' in input) && Date.parse(data.occurredAt)>Date.now()+5*60*1000) return reply(400,{error:'The incident time cannot be in the future'});
          data.receivedAt ??= now;
          data.source ??= admin?'Admin portal':'Mobile app';
          if (!existing && data.latitude != null) {
            data.initialLatitude=data.latitude;
            data.initialLongitude=data.longitude;
            data.locationHistory=[{latitude:data.latitude,longitude:data.longitude,accuracy:data.accuracy ?? null,capturedAt:data.locationCapturedAt || data.reportedAt}];
          }
          if (!Array.isArray(data.statusHistory)) {
            data.statusHistory=previousStatus?[{status:previousStatus,at:data.createdAt,actor:'system'}]:[];
          }
          if (!existing || previousStatus !== data.status) {
            data.statusHistory.push({status:data.status,at:now,actor:admin?'admin':'mobile'});
          }
          if (['Resolved','False Alarm'].includes(data.status)) data.resolvedAt ??= now;
          else delete data.resolvedAt;
        }
        if (attachments.length) data.evidence=attachments.map(({id,mime,name})=>({id,mime,name}));
        db.exec('BEGIN');
        try {
          put.run(collection, id, JSON.stringify(data));
          for (const file of attachments) db.prepare('INSERT INTO evidence VALUES(?,?,?,?,?)').run(file.id,actor.id,id,file.mime,file.bytes);
          db.exec('COMMIT');
        } catch(error) { db.exec('ROLLBACK'); throw error; }
        realtime.changed(collection,data);
        return reply(req.method === 'POST' ? 201 : 200, collection==='guides'?guideView(data,actor):data);
      }
      if (!['GET','HEAD'].includes(req.method)) return reply(405,{error:'Method not allowed'});
      if(['/mobile','/admin'].includes(url.pathname)) {res.writeHead(308,{Location:url.pathname+'/'+url.search});return res.end();}
      const isAdminPath=url.pathname.startsWith('/admin/');
      const isMobilePath=url.pathname.startsWith('/mobile/');
      const shared=url.pathname.startsWith('/downloads/') || ['/safeug-notifications.js','/flutter_service_worker.js'].includes(url.pathname);
      const webRoot = resolve(root, isAdminPath ? 'build/admin' : isMobilePath || shared ? 'build/web' : 'landing');
      const requested = isAdminPath ? url.pathname.slice(6) : isMobilePath ? url.pathname.slice(7) : url.pathname;
      let path = resolve(webRoot, '.' + decodeURIComponent(requested));
      if (!path.startsWith(webRoot + sep) && path !== webRoot) return reply(403, {error:'Invalid path'});
      if (path === webRoot || ((isAdminPath || isMobilePath) && !extname(path))) path = resolve(webRoot, 'index.html');
      if (!existsSync(path) || !statSync(path).isFile()) return reply(404, {error:'Build the web app with flutter build web --release'});
      const types = {'.html':'text/html; charset=utf-8','.css':'text/css','.webp':'image/webp','.js':'text/javascript','.json':'application/json','.wasm':'application/wasm','.png':'image/png','.jpg':'image/jpeg','.svg':'image/svg+xml','.woff2':'font/woff2','.ttf':'font/ttf','.apk':'application/vnd.android.package-archive'};
      res.writeHead(200, {'Content-Type': types[extname(path)] || 'application/octet-stream', 'Content-Length':statSync(path).size, 'Cache-Control':'no-cache'});
      if(req.method==='HEAD') return res.end();
      const stream=createReadStream(path);
      stream.on('error',()=>res.destroy());
      res.on('close',()=>stream.destroy());
      stream.pipe(res);
    } catch (error) { reply(error.status || (error instanceof SyntaxError ? 400 : 500), {error: error.status===413?'Upload is too large':error instanceof SyntaxError?'Invalid JSON':'Local operation failed'}); if(!error.status && !(error instanceof SyntaxError))console.error(error); }
  });
  server.on('close', () => db.close());
  server.requestTimeout=60000;
  server.headersTimeout=15000;
  return server;
}

if (process.argv[1] && existsSync(process.argv[1]) && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const port = Number(process.env.SAFEUG_PORT || 8099);
  const host = process.env.SAFEUG_HOST || '127.0.0.1';
  if (process.env.NODE_ENV==='production' && host!=='127.0.0.1') throw new Error('Production listens on loopback behind Apache only');
  const server=createSafeUgServer();
  server.listen(port,host,()=>console.log(`SafeUG listening on ${host}:${port}. Public origin: ${process.env.SAFEUG_PUBLIC_ORIGIN || 'development'}`));
  for (const signal of ['SIGTERM','SIGINT']) process.on(signal,()=>{
    server.close(()=>process.exit(0));
    setTimeout(()=>server.closeAllConnections(),2000).unref();
    setTimeout(()=>process.exit(1),5000).unref();
  });
}
