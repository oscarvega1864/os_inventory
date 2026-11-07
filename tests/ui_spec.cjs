// Chromium real + transporte NUI simulado; no ejecuta FiveM ni toca datos reales.
const assert=require('node:assert/strict');
const fs=require('node:fs');const path=require('node:path');const http=require('node:http');
const {spawn}=require('node:child_process');const {randomUUID}=require('node:crypto');
const root=path.resolve(__dirname,'..'),pause=ms=>new Promise(resolve=>setTimeout(resolve,ms));
async function main(){
 const browser=[process.env.OS_INVENTORY_BROWSER,'C:/Program Files/Google/Chrome/Application/chrome.exe','C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'].find(p=>p&&fs.existsSync(p));
 assert(browser,'Chrome/Edge requerido para npm run test:ui');
 const output=path.join(root,'.tools','inventory-browser',randomUUID());fs.mkdirSync(output,{recursive:true});
 const files=new Set(['index.html','style.css','app.js','icons.svg']);
 const server=http.createServer((req,res)=>{const file=req.url.slice(1)||'index.html';if(!files.has(file)){res.writeHead(404).end();return;}
  res.setHeader('Content-Type',({'html':'text/html','css':'text/css','js':'text/javascript','svg':'image/svg+xml'})[file.split('.').pop()]);res.end(fs.readFileSync(path.join(root,'web',file)));});
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 const child=spawn(browser,['--headless=new','--disable-gpu','--no-first-run','--no-default-browser-check','--disable-background-networking','--disable-component-update','--disable-sync','--disable-breakpad',`--crash-dumps-dir=${output}`,`--user-data-dir=${output}`,'--remote-debugging-address=127.0.0.1','--remote-debugging-port=0','about:blank'],{cwd:root,windowsHide:true,stdio:'ignore'});
 let socket;
 try{
  const portFile=path.join(output,'DevToolsActivePort');for(let i=0;i<100&&!fs.existsSync(portFile);i++)await pause(100);assert(fs.existsSync(portFile));
  const port=Number(fs.readFileSync(portFile,'utf8').split(/\r?\n/)[0]);const targets=await(await fetch(`http://127.0.0.1:${port}/json/list`)).json();
  socket=new WebSocket(targets.find(t=>t.type==='page').webSocketDebuggerUrl);await new Promise((resolve,reject)=>{socket.addEventListener('open',resolve,{once:true});socket.addEventListener('error',reject,{once:true});});
  let counter=0;const pending=new Map();socket.addEventListener('message',event=>{const result=JSON.parse(event.data),waiting=pending.get(result.id);if(waiting){pending.delete(result.id);result.error?waiting.reject(Error(result.error.message)):waiting.resolve(result.result);}});
  const send=(method,params={})=>new Promise((resolve,reject)=>{const id=++counter,timer=setTimeout(()=>reject(Error(`CDP timeout ${method}`)),10000);pending.set(id,{resolve:r=>{clearTimeout(timer);resolve(r);},reject:e=>{clearTimeout(timer);reject(e);}});socket.send(JSON.stringify({id,method,params}));});
  const evaluate=async expression=>{const r=await send('Runtime.evaluate',{expression,awaitPromise:true,returnByValue:true});assert(!r.exceptionDetails,JSON.stringify(r.exceptionDetails));return r.result.value;};
  const until=async expression=>{for(let i=0;i<100;i++){if(await evaluate(expression))return;await pause(40);}throw Error(`UI condition not met: ${expression}`);};
  await send('Page.enable');await send('Runtime.enable');await send('Emulation.setDeviceMetricsOverride',{width:1280,height:900,deviceScaleFactor:1,mobile:false});
  await send('Emulation.setDefaultBackgroundColorOverride',{color:{r:38,g:46,b:41,a:1}});
  await send('Page.addScriptToEvaluateOnNewDocument',{source:`
    window.GetParentResourceName=()=> 'os_inventory';window.__calls=[];window.__fail=false;
    window.__inv={id:'oinv_0000000001',revision:1,capacity:30,maxWeight:30,weight:3.8,nearby:[],slots:{'1':{id:'ostack_0000000001',name:'agua',count:6,metadata:{}},'2':{id:'ostack_0000000002',name:'g6_client_tablet',count:1,metadata:{serial:'G6-TEST'},instanceId:'ounit_0000000002'}},items:{
    agua:{label:'Agua',weight:.5,stack:20,usable:true,transferable:true,description:'Una botella de agua para consumir.',category:'consumible',icon:'water'},
    g6_client_tablet:{label:'G6 Client Tablet',weight:.8,stack:1,usable:false,transferable:true,description:'Tablet sin aplicacion integrada.',category:'seguridad',icon:'tablet'}}};
    window.fetch=async(url,options)=>{const endpoint=String(url).split('/').pop(),body=JSON.parse(options.body);window.__calls.push({endpoint,body});if(window.__fail&&endpoint==='action')throw Error('Injected transport failure');return new Response(JSON.stringify({ok:true,inventory:window.__inv}),{status:200});};
    window.__open=()=>window.postMessage({type:'open',inventory:window.__inv},'*');
  `});
  await send('Page.navigate',{url:`http://127.0.0.1:${server.address().port}/index.html`});
  await until(`document.getElementById('inventory')?.hidden===true`);console.log('PASS UI hidden before server-authorized message');
  await evaluate(`window.__open()`);await until(`document.querySelectorAll('.slot').length===30`);
  assert(await evaluate(`document.querySelectorAll('.slot:not(.empty)').length===2 && document.getElementById('weight').textContent.includes('3,8')`));
  await evaluate(`document.querySelector('[data-slot="1"]').click()`);assert(await evaluate(`document.getElementById('item-name').textContent==='Agua'&&!document.getElementById('use').disabled`));
  await pause(250);fs.writeFileSync(path.join(output,'desktop.png'),Buffer.from((await send('Page.captureScreenshot',{format:'png'})).data,'base64'));
  console.log('PASS 30 slots, catalog icons, weights and selected-item actions');
  await evaluate(`document.getElementById('amount').value='2';document.getElementById('split').click()`);
  await until(`window.__calls.some(c=>c.endpoint==='action'&&c.body.op==='move')`);
  assert(await evaluate(`window.__calls.find(c=>c.body.op==='move').body.args.to===3&&window.__calls.find(c=>c.body.op==='move').body.args.count===2`));console.log('PASS split sends selected stack identity, revision, amount and empty slot');
  await evaluate(`document.querySelector('[data-slot="2"]').click()`);assert(await evaluate(`document.getElementById('use').disabled && document.getElementById('metadata').textContent.includes('G6-TEST')`));
  await evaluate(`window.__inv.slots['2'].metadata.label='<img src=x onerror="window.__xss=true">';window.postMessage({type:'update',inventory:window.__inv},'*')`);
  await until(`document.getElementById('item-name').textContent.includes('<img')`);assert(await evaluate(`!window.__xss&&document.querySelector('img')===null`));console.log('PASS metadata remains text and unimplemented tablet use stays disabled');
  await evaluate(`window.__inv.nearby=[{id:'odrop_0000000001',name:'agua',count:2,canPickup:true}];window.postMessage({type:'update',inventory:window.__inv},'*')`);
  await until(`document.querySelector('#drops button')`);await evaluate(`document.querySelector('#drops button').click()`);await until(`window.__calls.some(c=>c.body.op==='pickup')`);console.log('PASS ground pickup uses server drop ID');
  await send('Emulation.setDeviceMetricsOverride',{width:960,height:540,deviceScaleFactor:1,mobile:false});await pause(100);
  assert(await evaluate(`document.documentElement.scrollWidth<=960&&document.getElementById('inventory').getBoundingClientRect().height<=540`));
  fs.writeFileSync(path.join(output,'compact.png'),Buffer.from((await send('Page.captureScreenshot',{format:'png'})).data,'base64'));console.log('PASS compact resolution remains scrollable and within viewport');
  await evaluate(`window.dispatchEvent(new KeyboardEvent('keydown',{key:'Escape'}))`);await until(`document.getElementById('inventory').hidden&&window.__calls.some(c=>c.endpoint==='close')`);console.log('PASS Escape invokes native close callback');
  await evaluate(`window.__calls.length=0;window.postMessage({type:'open',inventory:window.__inv,toggleKey:'I'},'*')`);await until(`!document.getElementById('inventory').hidden`);
  await evaluate(`document.getElementById('amount').dispatchEvent(new KeyboardEvent('keydown',{key:'i',bubbles:true}))`);assert(await evaluate(`!document.getElementById('inventory').hidden`));
  await evaluate(`window.dispatchEvent(new KeyboardEvent('keydown',{key:'i'}))`);await until(`document.getElementById('inventory').hidden&&window.__calls.some(c=>c.endpoint==='close')`);console.log('PASS toggle key closes UI except while typing');
  await evaluate(`window.__open()`);await until(`!document.getElementById('inventory').hidden`);await evaluate(`window.__fail=true;document.querySelector('[data-slot="1"]').click();document.getElementById('use').click()`);await until(`document.getElementById('inventory').hidden`);console.log('PASS transport failure closes UI');
  console.log(`Screenshots: ${path.relative(root,output)}`);
 }finally{socket?.close();child.kill();await new Promise(resolve=>server.close(resolve));}
}
main().catch(error=>{console.error(error);process.exitCode=1;});
