import test from 'node:test';
import assert from 'node:assert/strict';
import {createSafeUgServer} from './server.mjs';

test('guide ratings are validated, private per device, durable aggregates and live on mobile/admin', async () => {
  const server=createSafeUgServer(':memory:',{adminPassword:'test-only',realtimeTimeoutMs:500});
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  const base=`http://127.0.0.1:${server.address().port}`;
  const request=(path,headers={},method='GET',body)=>fetch(base+path,{method,headers:{'Content-Type':'application/json',...headers},body:body?JSON.stringify(body):undefined});
  const state=async headers=>(await request('/api/state',headers)).json();
  const change=async (headers,revision)=>(await request(`/api/changes?since=${encodeURIComponent(revision)}`,headers)).json();
  try {
    const login=await request('/api/auth/login',{},'POST',{username:'admin',password:'test-only'});
    const admin={Cookie:login.headers.get('set-cookie').split(';')[0]};
    const devices=await Promise.all([1,2].map(async()=>{const r=await (await request('/api/auth/device',{},'POST')).json();return {Authorization:`Bearer ${r.token}`};}));
    const [a,b]=devices;
    const guide={id:'test-guide',name:'Test guide',area:'Uganda',description:'Tours',phone:'0700123456',status:'Active'};
    assert.equal((await request('/api/guides',admin,'POST',guide)).status,201);
    const initial=await state(a);
    assert.equal(initial.guides[0].rating,null);
    assert.equal(initial.guides[0].ratingCount,0);
    assert.equal((await request('/api/guides/test-guide/rating',{},'PUT',{score:5})).status,401);
    assert.equal((await request('/api/guides/test-guide/rating',admin,'PUT',{score:5})).status,403);
    for(const score of [0,6,4.5,'5',null]) assert.equal((await request('/api/guides/test-guide/rating',a,'PUT',{score})).status,400);
    assert.equal((await request('/api/guides/missing/rating',a,'PUT',{score:5})).status,404);
    const adminBefore=await state(admin), otherBefore=await state(b);
    const adminChanged=change(admin,adminBefore.revision), otherChanged=change(b,otherBefore.revision);
    assert.equal((await request('/api/guides/test-guide/rating',a,'PUT',{score:5,ownerId:'forged'})).status,200);
    assert.notEqual((await adminChanged).revision,adminBefore.revision);
    assert.notEqual((await otherChanged).revision,otherBefore.revision);
    await request('/api/guides/test-guide/rating',b,'PUT',{score:3});
    let ga=(await state(a)).guides[0], gb=(await state(b)).guides[0], gd=(await state(admin)).guides[0];
    for(const g of [ga,gb,gd]) { assert.equal(g.rating,4); assert.equal(g.ratingCount,2); }
    assert.equal(ga.myRating,5); assert.equal(gb.myRating,3); assert.equal(gd.myRating,undefined);
    assert.equal(gd.ratings,undefined);
    // Repeated submissions update the existing vote; client cannot forge totals.
    for(let i=0;i<2;i++) await request('/api/guides/test-guide/rating',a,'PUT',{score:4,ratingCount:100});
    ga=(await state(a)).guides[0];
    assert.equal(ga.rating,3.5); assert.equal(ga.ratingCount,2); assert.equal(ga.myRating,4);
    assert.equal((await request('/api/guides/test-guide',a,'PATCH',{name:'Tampered'})).status,403);
    const mobileBefore=await state(a), pending=change(a,mobileBefore.revision);
    const edited=await (await request('/api/guides/test-guide',admin,'PATCH',{phone:'+256700999888',name:'Updated guide',rating:5,ratingCount:500})).json();
    assert.equal(edited.rating,3.5); assert.equal(edited.ratingCount,2);
    assert.notEqual((await pending).revision,mobileBefore.revision);
    ga=(await state(a)).guides[0]; gd=(await state(admin)).guides[0];
    const {myRating,...shared}=ga;
    assert.deepEqual(shared,gd); assert.equal(myRating,4); assert.equal(ga.phone,'+256700999888');
    await request('/api/guides/test-guide',admin,'PATCH',{status:'Inactive'});
    assert.equal((await state(a)).guides.length,0);
    assert.equal((await request('/api/guides/test-guide/rating',a,'PUT',{score:1})).status,404);
    await request('/api/guides/test-guide',admin,'PATCH',{status:'Active'});
    assert.equal((await state(a)).guides[0].rating,3.5);
  } finally { server.closeAllConnections(); await new Promise(resolve=>server.close(resolve)); }
});
