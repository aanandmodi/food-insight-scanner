const {test}=require('node:test');
const assert=require('node:assert/strict');
const http=require('node:http');
const {request}=require('gaxios');

test('patched UUID dependency preserves Google client multipart requests',async()=>{
 let received;
 const server=http.createServer(async(req,res)=>{
  const chunks=[];
  for await(const chunk of req) chunks.push(chunk);
  received={type:req.headers['content-type'],body:Buffer.concat(chunks).toString()};
  res.setHeader('Content-Type','application/json');
  res.end('{"ok":true}');
 });
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 try{
  const result=await request({url:`http://127.0.0.1:${server.address().port}/`,method:'POST',
   multipart:[{headers:{'Content-Type':'application/json'},content:'{"test":"metadata"}'},
    {headers:{'Content-Type':'text/plain'},content:'test payload'}],timeout:3000,
   noProxy:['127.0.0.1']});
  assert.equal(result.data.ok,true);
  const boundary=received.type.match(/boundary=([0-9a-f-]+)/)[1];
  assert.match(boundary,/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
  assert.ok(received.body.includes(`--${boundary}`));
  assert.ok(received.body.includes('test payload'));
  assert.ok(received.body.includes('metadata'));
 }finally{await new Promise(resolve=>server.close(resolve));}
});
