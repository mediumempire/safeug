import {isIP} from 'node:net';

export function runtimeConfig(options={}) {
  const production=options.production ?? process.env.NODE_ENV==='production';
  const raw=options.publicOrigin ?? process.env.SAFEUG_PUBLIC_ORIGIN;
  let publicOrigin=null;
  if (raw) {
    const url=new URL(raw);
    if (url.protocol!=='https:' || url.username || url.password || url.search || url.hash || (url.pathname!=='/')) throw new Error('SAFEUG_PUBLIC_ORIGIN must be an HTTPS origin');
    publicOrigin=url.origin;
  }
  if (production && !publicOrigin) throw new Error('Set SAFEUG_PUBLIC_ORIGIN before starting production');
  return {production,publicOrigin,trustProxy:options.trustProxy ?? process.env.SAFEUG_TRUST_PROXY==='1'};
}

export function requestContext(req,config) {
  const address=req.socket.remoteAddress;
  const trusted=config.trustProxy && ['127.0.0.1','::1','::ffff:127.0.0.1'].includes(address);
  const forwarded=req.headers['x-real-ip'];
  return {
    clientAddress:trusted && typeof forwarded==='string' && isIP(forwarded)?forwarded:address,
    secure:!!req.socket.encrypted || (trusted && req.headers['x-forwarded-proto']==='https'),
  };
}
