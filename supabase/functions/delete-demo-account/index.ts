import { createClient } from 'npm:@supabase/supabase-js@2.118.0';
import { createDeleteHandler } from './handler.mjs';
const url=Deno.env.get('SUPABASE_URL')!;
const publicKey=Deno.env.get('SUPABASE_ANON_KEY')!;
const adminKey=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
Deno.serve(async(req:Request)=>{
 const options={auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false}};
 const auth=createClient(url,publicKey,options);
 const admin=createClient(url,adminKey,options);
 return createDeleteHandler({
  getUser:async(token:string)=>{const {data,error}=await auth.auth.getUser(token);return error?null:data.user;},
  verifyPassword:async(email:string,password:string)=>{
   const {data,error}=await auth.auth.signInWithPassword({email,password});
   return error||!data.user||!data.session?null:{id:data.user.id,accessToken:data.session.access_token};
  },
  revokeSessions:async(token:string)=>{const {error}=await admin.auth.admin.signOut(token,'global');if(error)throw error;},
  deleteUser:async(id:string)=>{const {error}=await admin.auth.admin.deleteUser(id,false);if(error)throw error;},
 })(req);
});
