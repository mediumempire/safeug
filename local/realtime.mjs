import {randomUUID} from 'node:crypto';

// Authenticated long-polling delivers an invalidation immediately after commit.
// Payloads contain only a revision; clients reload their authorized state.
export function createRealtime(security, {timeoutMs = 25000} = {}) {
  const epoch=randomUUID();
  let global=0, published=0;
  const owners=new Map(), waiting=new Set();
  const revision=actor=>actor.role==='admin'?`${epoch}:${global}`:`${epoch}:${published}:${owners.get(actor.id)||0}`;
  function wait(req,res,actor,since,reply) {
    if (since!==revision(actor)) return reply(200,{revision:revision(actor)});
    const entry={actor,since,finish:null};
    let timer;
    const remove=()=>{clearTimeout(timer);waiting.delete(entry);};
    entry.finish=()=>{
      remove();
      const current=security.actor(req);
      if (!current) return reply(401,{error:'Session expired'});
      reply(200,{revision:revision(current)});
    };
    waiting.add(entry);
    timer=setTimeout(entry.finish,Math.min(timeoutMs, Math.max(1,actor.expires-Date.now())));
    res.on('close',remove);
  }
  function changed(collection,record) {
    global++;
    if (['guides','tips','services','parks'].includes(collection)) published++;
    if (record.ownerId) owners.set(record.ownerId,(owners.get(record.ownerId)||0)+1);
    for (const entry of [...waiting]) if (revision(entry.actor)!==entry.since) entry.finish();
  }
  return {revision,wait,changed};
}
