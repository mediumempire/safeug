import test from 'node:test';
import assert from 'node:assert/strict';
import {createSafeUgServer} from './server.mjs';
import {factbook} from './catalog.mjs';

test('guide applications are private, reviewed by admin, and publish only safe profile fields',async()=>{
 const server=createSafeUgServer(':memory:',{adminPassword:'test-only',seedCatalog:true,realtimeTimeoutMs:500});
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const base=`http://127.0.0.1:${server.address().port}`;
 const request=(path,headers={},method='GET',body)=>fetch(base+path,{method,headers:{'Content-Type':'application/json',...headers},body:body?JSON.stringify(body):undefined});
 const state=async h=>(await request('/api/state',h)).json();
 try{
  const login=await request('/api/auth/login',{},'POST',{username:'admin',password:'test-only'});
  const admin={Cookie:login.headers.get('set-cookie').split(';')[0]};
  const register=async()=>({Authorization:`Bearer ${(await (await request('/api/auth/device',{},'POST')).json()).token}`});
  const a=await register(),b=await register();
  const fields={name:'Example Guide',phone:'+256712345678',email:'guide@example.com',area:'Bwindi',description:'Forest walks',languages:'English, Luganda',license:'PRIVATE-LICENCE',consent:true,status:'Approved'};
  const before=await state(admin);
  const changed=request('/api/changes?since='+before.revision,admin);
  assert.equal((await request('/api/guideApplications',a,'POST',{...fields,consent:false})).status,400);
  const submitted=await (await request('/api/guideApplications',a,'POST',fields)).json();
  assert.equal(submitted.status,'Pending');
  assert.notEqual((await (await changed).json()).revision,before.revision);
  assert.equal((await state(b)).guideApplications.length,0);
  assert.equal((await state(b)).guides.length,0);
  assert.equal((await state(a)).guideApplications.length,1);
  assert.equal((await request(`/api/guideApplications/${submitted.id}/review`,b,'POST',{status:'Approved',note:''})).status,403);
  assert.equal((await request(`/api/guideApplications/${submitted.id}`,a,'PATCH',{status:'Approved'})).status,405);
  assert.equal((await request(`/api/guideApplications/${submitted.id}/review`,admin,'POST',{status:'Approved',note:'Reviewed'})).status,200);
  const guide=(await state(b)).guides[0];
  assert.equal(guide.name,fields.name);assert.equal(guide.phone,fields.phone);
  for(const field of ['email','license','consentAt','reviewNote','ownerId'])assert.equal(guide[field],undefined);
  assert.equal((await state(a)).guideApplications[0].status,'Approved');
  await request(`/api/guideApplications/${submitted.id}/review`,admin,'POST',{status:'Rejected',note:'Needs corrections'});
  assert.equal((await state(b)).guides.length,0);
  const content=await state(a);
  assert.equal(content.parks.length,40);
  assert.equal(content.parks.filter(p=>!p.referenceOnly).length,39);
  assert.equal(content.parks.filter(p=>p.categoryGroup==='National parks').length,10);
  assert.equal(content.parks.find(p=>p.referenceOnly).areaKm2,null);
  assert.ok(content.tips.length>=8);
  const ranger=await (await request('/api/incidents',a,'POST',{type:'Ranger down',description:'TEST emergency',locationSource:'unavailable'})).json();
  assert.equal(ranger.severity,'Critical');
  assert.ok((await state(admin)).incidents.some(i=>i.id===ranger.id));
  const located=await request(`/api/incidents/${ranger.id}/location`,a,'POST',{latitude:0.3,longitude:32.5,accuracy:8,locationCapturedAt:new Date().toISOString()});
  assert.equal(located.status,200);
  assert.equal((await located.json()).locationSource,'device');
  assert.equal((await request(`/api/incidents/${ranger.id}/location`,b,'POST',{})).status,403);
  assert.equal((await request(`/api/incidents/${ranger.id}/stand-down`,a,'POST',{reason:'I am safe / accidental activation'})).status,400);
 }finally{server.closeAllConnections();await new Promise(r=>server.close(r));}
});

test('factbook retains complete source rows, unknown area and qualifications',()=>{
 assert.equal(factbook.records.length,40);
 assert.equal(new Set(factbook.records.map(r=>r.id)).size,40);
 assert.ok(factbook.records.every(r=>r.sourceSheet && r.sourceRow>=4));
 assert.ok(factbook.notes.some(n=>n.topic==='Area figures'));
 assert.equal(factbook.records.filter(r=>r.categoryGroup==='Community areas').length,5);
});

test('public home has app and APK access without an admin link; mobile routing redirects',async()=>{
 const server=createSafeUgServer(':memory:',{adminPassword:'test-only'});
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const base=`http://127.0.0.1:${server.address().port}`;
 try{
  const home=await fetch(base+'/');assert.equal(home.status,200);const html=await home.text();
  assert.match(html,/href="\/mobile\/"/);assert.match(html,/href="\/downloads\/safeug.apk"/);assert.doesNotMatch(html,/href="[^\"]*admin/);
  const mobile=await fetch(base+'/mobile',{redirect:'manual'});assert.equal(mobile.status,308);assert.equal(mobile.headers.get('location'),'/mobile/');
  assert.equal((await fetch(base+'/style.css')).headers.get('content-type'),'text/css');
  assert.equal((await fetch(base+'/api/state')).status,401);
 }finally{server.closeAllConnections();await new Promise(r=>server.close(r));}
});
