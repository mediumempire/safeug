import test from 'node:test';
import assert from 'node:assert/strict';
import {createSafeUgServer} from './server.mjs';

test('committed SOS and response data reach the correct clients immediately and survive reconnect', async () => {
  const server=createSafeUgServer(':memory:',{adminPassword:'test-only',realtimeTimeoutMs:300});
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  const base=`http://127.0.0.1:${server.address().port}`;
  const request=(path,headers={},method='GET',body)=>fetch(base+path,{method,headers:{'Content-Type':'application/json',...headers},body:body?JSON.stringify(body):undefined});
  const state=async headers=>(await request('/api/state',headers)).json();
  const change=async (headers,revision)=>(await request(`/api/changes?since=${encodeURIComponent(revision)}`,headers)).json();
  try {
    assert.equal((await request('/api/changes')).status,401);
    const login=await request('/api/auth/login',{},'POST',{username:'admin',password:'test-only'});
    const admin={Cookie:login.headers.get('set-cookie').split(';')[0]};
    const a=await (await request('/api/auth/device',{},'POST')).json();
    const b=await (await request('/api/auth/device',{},'POST')).json();
    const mobile={Authorization:`Bearer ${a.token}`}, other={Authorization:`Bearer ${b.token}`};
    const oldAdmin=await state(admin), oldMobile=await state(mobile), oldOther=await state(other);
    const waitAdmin=change(admin,oldAdmin.revision), waitOther=change(other,oldOther.revision);
    const start=performance.now();
    const input={id:'realtime-sos',type:'SOS',severity:'Critical',description:'Test emergency',reporter:'Test visitor',phone:'+256700123456',area:'Test gate',latitude:0.3,longitude:32.5,accuracy:4,locationSource:'device',locationCapturedAt:new Date().toISOString(),occurredAt:new Date().toISOString()};
    const receipt=await (await request('/api/incidents',mobile,'POST',input)).json();
    const signal=await waitAdmin;
    assert.notEqual(signal.revision,oldAdmin.revision);
    assert.ok(performance.now()-start<2000,'SOS must wake admin without waiting for the five-second timer');
    let mobileState=await state(mobile), adminState=await state(admin);
    assert.deepEqual(mobileState.incidents[0],adminState.incidents[0]);
    for (const [key,value] of Object.entries(input)) assert.deepEqual(adminState.incidents[0][key],value);
    assert.equal(receipt.ownerId,a.id);
    assert.equal((await waitOther).revision,oldOther.revision);
    assert.deepEqual((await state(other)).incidents,[]);
    const waitingMobile=change(mobile,mobileState.revision);
    await request('/api/incidents/realtime-sos',admin,'PATCH',{status:'Acknowledged',responseAgency:'UPF',responseNote:'Response team notified.'});
    assert.notEqual((await waitingMobile).revision,mobileState.revision);
    adminState=await state(admin); mobileState=await state(mobile);
    assert.deepEqual(mobileState.incidents[0],adminState.incidents[0]);
    assert.equal(mobileState.incidents[0].status,'Acknowledged');
    // A disconnected client can resume from an old revision with no event loss.
    assert.equal((await change(mobile,oldMobile.revision)).revision,mobileState.revision);
    const waitingClosure=change(admin,adminState.revision);
    await request('/api/incidents/realtime-sos/stand-down',mobile,'POST',{reason:'I am safe / accidental activation'});
    assert.notEqual((await waitingClosure).revision,adminState.revision);
    mobileState=await state(mobile); adminState=await state(admin);
    assert.deepEqual(mobileState.incidents[0],adminState.incidents[0]);
    assert.equal(mobileState.incidents[0].status,'False Alarm');
    const revision=adminState.revision;
    await request('/api/incidents',mobile,'POST',input);
    assert.equal((await state(admin)).revision,revision,'idempotent retry cannot generate duplicate alerts');
    const published=change(other,oldOther.revision);
    await request('/api/tips',admin,'POST',{name:'Test safety tip',status:'Active'});
    assert.notEqual((await published).revision,oldOther.revision);
    const beforeLogout=await state(admin);
    const expired=request(`/api/changes?since=${encodeURIComponent(beforeLogout.revision)}`,admin);
    await request('/api/auth/logout',admin,'POST');
    assert.equal((await expired).status,401);
  } finally { server.closeAllConnections(); await new Promise(resolve=>server.close(resolve)); }
});
