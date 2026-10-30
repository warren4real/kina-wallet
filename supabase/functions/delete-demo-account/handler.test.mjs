import test from 'node:test';
import assert from 'node:assert/strict';
import { createDeleteHandler } from './handler.mjs';
function setup(overrides={}) {
 const calls=[];
 const api={
  getUser:async token=>{calls.push('user');return {id:'A',email:'a@example.com',email_confirmed_at:'now'};},
  verifyPassword:async()=>{calls.push('password');return {id:'A',accessToken:'temporary-token'};},
  revokeSessions:async()=>{calls.push('revoke');},
  deleteUser:async()=>{calls.push('delete');},...overrides,
 };
 return {calls,handle:createDeleteHandler(api)};
}
function request(body={expectedUser:'A',password:'secret',confirm:'DELETE'},token='valid'){
 return new Request('https://example.invalid',{method:'POST',headers:token?{authorization:`Bearer ${token}`,'content-type':'application/json'}:{},body:JSON.stringify(body)});
}
test('Unauthenticated requests cannot call Admin APIs',async()=>{const{handle,calls}=setup();assert.equal((await handle(request({},null))).status,401);assert.deepEqual(calls,[]);});
test('Owner mismatch and missing confirmation cannot delete',async()=>{const{handle,calls}=setup();assert.equal((await handle(request({expectedUser:'B',password:'secret',confirm:'DELETE'}))).status,403);assert.ok(!calls.includes('delete'));});
test('Wrong password cannot revoke or delete',async()=>{const{handle,calls}=setup({verifyPassword:async()=>null});assert.equal((await handle(request())).status,401);assert.ok(!calls.includes('delete'));assert.ok(!calls.includes('revoke'));});
test('Successful deletion verifies password, revokes sessions, then deletes the same account',async()=>{const{handle,calls}=setup();assert.equal((await handle(request())).status,200);assert.deepEqual(calls,['user','password','revoke','delete']);});
test('Revocation failure prevents deletion and leaks no exception details',async()=>{const{handle,calls}=setup({revokeSessions:async()=>{throw Error('secret-key');}});const response=await handle(request());assert.equal(response.status,503);assert.ok(!calls.includes('delete'));assert.ok(!(await response.text()).includes('secret-key'));});

test('Oversized bodies are refused before any deletion',async()=>{const{handle,calls}=setup();const response=await handle(request({expectedUser:'A',password:'x'.repeat(10000),confirm:'DELETE'}));assert.equal(response.status,413);assert.ok(!calls.includes('delete'));});
test('Missing explicit deletion confirmation is rejected',async()=>{const{handle,calls}=setup();assert.equal((await handle(request({expectedUser:'A',password:'secret'}))).status,400);assert.ok(!calls.includes('delete'));});
