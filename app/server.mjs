import http from 'node:http';
import {readFile} from 'node:fs/promises';
import {pbkdf2, timingSafeEqual} from 'node:crypto';
import {hostname} from 'node:os';
import {fileURLToPath} from 'node:url';
const page = await readFile(new URL('./index.html', import.meta.url));
export function createApp({testToken=process.env.LOAD_TEST_TOKEN || ''}={}) {
  let pending = 0;
  const server = http.createServer((req,res)=>{
    res.setHeader('X-Content-Type-Options','nosniff');
    res.setHeader('Cache-Control','no-store');
    res.setHeader('Content-Security-Policy',"default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; connect-src 'self'; base-uri 'none'; frame-ancestors 'none'");
    const json=(status,data)=>{res.writeHead(status,{'Content-Type':'application/json'});res.end(JSON.stringify(data));};
    if(req.method!=='GET') return json(405,{error:'GET required'});
    const path=new URL(req.url,'http://localhost').pathname;
    if(path==='/healthz'||path==='/readyz') return json(200,{status:'ok'});
    if(path==='/api/info') return json(200,{app:'TAM Scaling Demo',pod:hostname(),version:'1.0.0',time:new Date().toISOString()});
    if(path==='/') {res.writeHead(200,{'Content-Type':'text/html; charset=utf-8'});return res.end(page);}
    if(path==='/work') {
      const supplied=Buffer.from(req.headers['x-load-test-token'] || '');
      const expected=Buffer.from(testToken);
      if(!expected.length || supplied.length!==expected.length || !timingSafeEqual(supplied,expected)) return json(403,{error:'Load test authorization required'});
      if(pending>=32) return json(429,{error:'Per-pod test concurrency exceeded'});
      pending++;
      // Async CPU work leaves the event loop available for health checks.
      pbkdf2('assessment-demo','fixed-demo-salt',100000,32,'sha256',(err)=>{
        pending--;
        if(err) return json(500,{error:'Test operation failed'});
        json(200,{status:'completed',pod:hostname()});
      });return;
    }
    json(404,{error:'Not found'});
  });
  server.requestTimeout=15000;server.headersTimeout=10000;server.keepAliveTimeout=5000;
  return server;
}
if(process.argv[1]===fileURLToPath(import.meta.url)) {
 const server=createApp();server.listen(Number(process.env.PORT||8080),'0.0.0.0',()=>console.log('Listening on 8080'));
 process.on('SIGTERM',()=>{server.close(()=>process.exit(0));setTimeout(()=>process.exit(1),25000).unref();});
}
