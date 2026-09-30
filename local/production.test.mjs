import test from 'node:test';
import assert from 'node:assert/strict';
import {createSafeUgServer} from './server.mjs';
import {requestContext,runtimeConfig} from './runtime-config.mjs';
import http from 'node:http';

test('forwarded identity is trusted only from an explicitly configured loopback proxy',()=>{
  const fake=address=>({socket:{remoteAddress:address},headers:{'x-real-ip':'203.0.113.6','x-forwarded-proto':'https'}});
  assert.deepEqual(requestContext(fake('127.0.0.1'),{trustProxy:true}),{secure:true,clientAddress:'203.0.113.6'});
  assert.deepEqual(requestContext(fake('198.51.100.3'),{trustProxy:true}),{secure:false,clientAddress:'198.51.100.3'});
  assert.deepEqual(requestContext(fake('127.0.0.1'),{trustProxy:false}),{secure:false,clientAddress:'127.0.0.1'});
  assert.throws(()=>runtimeConfig({production:true,publicOrigin:null}));
  assert.throws(()=>runtimeConfig({production:true,publicOrigin:'http://www.safeug.online'}));
  assert.throws(()=>runtimeConfig({production:true,publicOrigin:'https://www.safeug.online/path'}));
});

test('production requires canonical HTTPS, sets secure cookies and separates client limits behind Apache',async()=>{
  const server=createSafeUgServer(':memory:',{production:true,publicOrigin:'https://www.safeug.online',trustProxy:true,adminPassword:'test-production-password'});
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  const base=`http://127.0.0.1:${server.address().port}`;
  // Node fetch overrides Host. Use the actual HTTP proxy header contract here.
  const request=(path,extra={},method='GET',body)=>new Promise((resolve,reject)=>{
    const req=http.request(base+path,{method,headers:{Host:'www.safeug.online','X-Forwarded-Proto':'https','X-Real-IP':'203.0.113.1','Content-Type':'application/json',...extra}},res=>{
      let text='';res.on('data',chunk=>text+=chunk);res.on('end',()=>resolve({status:res.statusCode,headers:{get:key=>{const v=res.headers[key];return Array.isArray(v)?v.join(','):v;}},json:async()=>JSON.parse(text)}));
    });
    req.on('error',reject);req.end(body?JSON.stringify(body):undefined);
  });
  try {
    assert.equal((await fetch(base+'/healthz')).status,200);
    assert.equal((await fetch(base+'/api/state')).status,400);
    assert.equal((await request('/api/state',{'X-Forwarded-Proto':'http'})).status,400);
    assert.equal((await request('/api/state',{Host:'evil.example'})).status,400);
    assert.equal((await request('/api/auth/device',{Origin:'https://evil.example'},'POST')).status,403);
    assert.equal((await request('/api/auth/device',{Origin:'http://www.safeug.online'},'POST')).status,403);
    assert.equal((await request('/api/auth/device',{Origin:'null'},'POST')).status,403);
    const login=await request('/api/auth/login',{Origin:'https://www.safeug.online'},'POST',{username:'admin',password:'test-production-password'});
    assert.equal(login.status,200);
    assert.match(login.headers.get('set-cookie'),/; Secure/);
    assert.match(login.headers.get('set-cookie'),/HttpOnly/);
    const cookie=login.headers.get('set-cookie').split(';')[0];
    assert.equal((await request('/api/state',{Cookie:cookie})).status,200);
    for(let i=0;i<8;i++) assert.equal((await request('/api/auth/login',{'X-Real-IP':'203.0.113.9'},'POST',{username:'admin',password:'wrong'})).status,401);
    assert.equal((await request('/api/auth/login',{'X-Real-IP':'203.0.113.9'},'POST',{username:'admin',password:'wrong'})).status,429);
    assert.equal((await request('/api/auth/login',{'X-Real-IP':'203.0.113.10'},'POST',{username:'admin',password:'test-production-password'})).status,200);
    const logout=await request('/api/auth/logout',{Cookie:cookie},'POST');
    assert.match(logout.headers.get('set-cookie'),/; Secure/);
    assert.equal((await request('/api/state',{Cookie:cookie})).status,401);
  } finally {server.closeAllConnections();await new Promise(resolve=>server.close(resolve));}
});
