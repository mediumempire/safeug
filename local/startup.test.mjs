import test from 'node:test';
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {mkdtemp, symlink, rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join, dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createServer} from 'node:net';
import {once} from 'node:events';

test('production server starts through the deployment directory symlink', async () => {
  const temp = await mkdtemp(join(tmpdir(), 'safeug-startup-'));
  const probe = createServer();
  probe.listen(0, '127.0.0.1');
  await once(probe, 'listening');
  const port = probe.address().port;
  await new Promise(resolve => probe.close(resolve));
  let child;
  let closed;
  try {
    await symlink(dirname(fileURLToPath(import.meta.url)), join(temp, 'current'), 'junction');
    child = spawn(process.execPath, [join(temp, 'current', 'server.mjs')], {
      env: {...process.env, NODE_ENV:'production', SAFEUG_HOST:'127.0.0.1', SAFEUG_PORT:String(port),
        SAFEUG_PUBLIC_ORIGIN:'https://www.safeug.online', SAFEUG_TRUST_PROXY:'1',
        SAFEUG_DATABASE_PATH:join(temp, 'data.sqlite'), SAFEUG_ADMIN_PASSWORD:'startup-test-password-only'},
      stdio:['ignore','pipe','pipe'],
    });
    closed = once(child, 'close');
    let stderr = '';
    child.stderr.on('data', chunk => {stderr += chunk;});
    await Promise.race([
      new Promise((resolve, reject) => {
        const timer = setTimeout(() => reject(new Error('Server did not start: ' + stderr)), 10000);
        child.stdout.on('data', chunk => {
          if (chunk.toString().includes('SafeUG listening')) {clearTimeout(timer); resolve();}
        });
        child.once('exit', code => {clearTimeout(timer); reject(new Error('Server exited: ' + code + ' ' + stderr));});
        child.once('error', error => {clearTimeout(timer); reject(error);});
      }),
    ]);
    const response = await fetch(`http://127.0.0.1:${port}/healthz`);
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), {ok:true, service:'safeug'});
  } finally {
    if (child && child.exitCode === null) child.kill();
    if (closed) await closed;
    await rm(temp, {recursive:true, force:true});
  }
});
