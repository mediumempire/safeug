import test from 'node:test';
import assert from 'node:assert/strict';
import {createSafeUgServer} from './server.mjs';

test('contacts are private; location consent creates distinct, revocable, expiring links', async () => {
  const server=createSafeUgServer(':memory:',{adminPassword:'test-only-password'});
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  const base=`http://127.0.0.1:${server.address().port}`;
  const request=(path,method='GET',body,token) => fetch(base+path,{method,headers:{'Content-Type':'application/json',...(token?{Authorization:`Bearer ${token}`}:{})},body:body?JSON.stringify(body):undefined});
  try {
    const owner=await (await request('/api/auth/device','POST')).json();
    const stranger=await (await request('/api/auth/device','POST')).json();
    const save=(path,body)=>request(path,path==='/api/contacts'?'POST':'PATCH',body,owner.token);
    const contact=await (await save('/api/contacts',{name:'Test Contact',relationship:'Friend',phone:'+256700123456',shareLocation:false})).json();
    assert.equal(contact.shareLocation,false);
    assert.equal(contact.shareToken,null);
    assert.equal((await (await request('/api/state','GET',undefined,stranger.token)).json()).contacts.length,0);
    assert.equal((await request(`/api/contacts/${contact.id}`,'PATCH',{shareLocation:true},stranger.token)).status,403);
    assert.equal((await save(`/api/contacts/${contact.id}`,{shareLocation:'yes'})).status,400);
    const enabled=await (await save(`/api/contacts/${contact.id}`,{shareLocation:true})).json();
    assert.match(enabled.shareToken,/^[a-f0-9]{64}$/);
    assert.equal((await request(`/share/${enabled.shareToken}`)).status,410);
    const position={latitude:0.3,longitude:32.5,accuracy:7,locationCapturedAt:new Date().toISOString()};
    assert.equal((await request('/api/live-location','PUT',position,stranger.token)).status,409);
    assert.equal((await request('/api/live-location','PUT',{...position,latitude:100},owner.token)).status,400);
    assert.equal((await request('/api/live-location','PUT',{...position,locationCapturedAt:'2000-01-01T00:00:00Z'},owner.token)).status,400);
    assert.equal((await request('/api/live-location','PUT',position,owner.token)).status,200);
    const shared=await request(`/share/${enabled.shareToken}`);
    assert.equal(shared.status,200);
    const page=await shared.text();
    assert.match(page,/mlat=0.3/);
    assert.ok(!page.includes(contact.phone));
    assert.ok(!page.includes(owner.id));
    await save(`/api/contacts/${contact.id}`,{shareLocation:false});
    assert.equal((await request(`/share/${enabled.shareToken}`)).status,404);
    const again=await (await save(`/api/contacts/${contact.id}`,{shareLocation:true})).json();
    assert.notEqual(again.shareToken,enabled.shareToken);
    assert.equal((await request(`/share/${enabled.shareToken}`)).status,404);
    const second=await (await save('/api/contacts',{name:'Second Contact',relationship:'Family',phone:'+256700654321',shareLocation:true})).json();
    assert.notEqual(second.shareToken,again.shareToken);
    await save(`/api/contacts/${contact.id}`,{status:'Inactive'});
    assert.equal((await request(`/share/${again.shareToken}`)).status,404);
    assert.equal((await request(`/share/${second.shareToken}`)).status,200);
    // Expired locations must never be presented as live.
    await request(`/api/locations/live_${owner.id}`,'PATCH',{locationCapturedAt:'2000-01-01T00:00:00Z'},owner.token);
    assert.equal((await request(`/share/${second.shareToken}`)).status,410);
    const login=await request('/api/auth/login','POST',{username:'admin',password:'test-only-password'});
    const cookie=login.headers.get('set-cookie').split(';')[0];
    const sos=await (await request('/api/incidents','POST',{type:'SOS'},owner.token)).json();
    assert.deepEqual(sos.requestedAgencies,['UPF','Tourist Police','UPDF']);
    for (const responseAgency of sos.requestedAgencies) {
      const response=await fetch(base+`/api/incidents/${sos.id}`,{method:'PATCH',headers:{Cookie:cookie,'Content-Type':'application/json'},body:JSON.stringify({responseAgency,responseNote:'Test confirmation'})});
      assert.equal(response.status,200);
    }
    const state=await (await request('/api/state','GET',undefined,owner.token)).json();
    assert.equal(Object.keys(state.incidents[0].agencyResponses).length,3);
  } finally { await new Promise(resolve=>server.close(resolve)); }
});
