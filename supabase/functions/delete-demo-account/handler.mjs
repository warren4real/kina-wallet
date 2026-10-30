const headers = { 'Content-Type': 'application/json', 'Cache-Control': 'no-store',
 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type' };
const reply = (status, error) => new Response(JSON.stringify(typeof error === 'string' ? {error} : error),{status,headers});
export function createDeleteHandler(api) {
 return async function handle(req) {
  if(req.method === 'OPTIONS')return new Response('ok',{headers});
  if(req.method !== 'POST')return reply(405,'POST required');
  const match = /^Bearer ([^\s]+)$/.exec(req.headers.get('authorization') ?? '');
  if(!match)return reply(401,'Sign in before deleting your test account.');
  try {
   const reader=req.body?.getReader();
   if(!reader)return reply(400,'Invalid request');
   let size=0;const chunks=[];
   while(true){const {done,value}=await reader.read();if(done)break;size+=value.byteLength;
    if(size>4096){await reader.cancel();return reply(413,'Request too large');}chunks.push(value);}
   const bytes=new Uint8Array(size);let offset=0;for(const chunk of chunks){bytes.set(chunk,offset);offset+=chunk.byteLength;}
   const text=new TextDecoder().decode(bytes);
   let body;try{body=JSON.parse(text);}catch{return reply(400,'Invalid request');}
   if(!body || typeof body.expectedUser!=='string' || typeof body.password!=='string' ||
      body.password.length<1 || body.password.length>1024 || body.confirm!=='DELETE')return reply(400,'Confirm deletion and supply your account password.');
   const user=await api.getUser(match[1]);
   if(!user?.id || !user.email || !user.email_confirmed_at)return reply(401,'Sign in with a confirmed email account.');
   if(user.id!==body.expectedUser)return reply(403,'The active account changed. Reopen account settings.');
   const verified=await api.verifyPassword(user.email,body.password);
   if(!verified || verified.id!==user.id || !verified.accessToken)return reply(401,'Account password was not accepted.');
   await api.revokeSessions(verified.accessToken);
   await api.deleteUser(user.id);
   return reply(200,{deleted:true});
  } catch { return reply(503,'Could not confirm account deletion. Sign in again before retrying.'); }
 };
}
