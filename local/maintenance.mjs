import {DatabaseSync,backup} from 'node:sqlite';
import {existsSync,mkdirSync,chmodSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {randomBytes,scryptSync} from 'node:crypto';

const [command,...args]=process.argv.slice(2);
const value=flag=>{const i=args.indexOf(flag);return i<0?undefined:args[i+1];};
const source=value('--database') || process.env.SAFEUG_DATABASE_PATH;
if (!source || !existsSync(source)) throw new Error('Provide an existing database with --database or SAFEUG_DATABASE_PATH');
const db=new DatabaseSync(resolve(source),{readOnly:command!=='reset-admin'});
try {
  if(command==='backup') {
    const output=value('--output');
    if(!output || existsSync(output)) throw new Error('Provide a new backup path with --output');
    mkdirSync(dirname(resolve(output)),{recursive:true,mode:0o700});
    await backup(db,resolve(output));
    chmodSync(resolve(output),0o600);
    console.log('Database backup complete. Keep this file private.');
  } else if(command==='check') {
    const result=db.prepare('PRAGMA quick_check').get();
    if(Object.values(result)[0]!=='ok') throw new Error('SQLite integrity check failed');
    console.log('Database integrity: ok');
  } else if(command==='reset-admin' && args.includes('--password-stdin')) {
    let input='';
    for await(const chunk of process.stdin) {input+=chunk;if(input.length>4096)throw new Error('Password is too long');}
    const password=input.replace(/\r?\n$/,'');
    if(password.length<16)throw new Error('Use at least 16 characters');
    const salt=randomBytes(16).toString('hex');
    db.exec('BEGIN IMMEDIATE');
    try {
      db.prepare('UPDATE auth_config SET salt=?,hash=? WHERE id=?').run(salt,scryptSync(password,salt,64).toString('hex'),'admin');
      db.prepare("DELETE FROM principals WHERE role='admin'").run();
      db.exec('COMMIT');
    }catch(error){db.exec('ROLLBACK');throw error;}
    console.log('Admin password changed; existing admin sessions revoked.');
  } else throw new Error('Use backup --output FILE, check, or reset-admin --password-stdin');
} finally {db.close();}
