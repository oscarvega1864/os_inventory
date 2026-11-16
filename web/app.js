'use strict';
// Inventario (NUI). El servidor decide todo; aqui solo se pinta y se piden operaciones. Texto siempre por textContent.
const $=id=>document.getElementById(id);
let inventory=null,selected=null,busy=false,visible=false,epoch=0,accessories=[];
const allowedIcons=new Set(['water','food','phone','tool','card','tablet','box','gun','ammo','key','keycard']);
const kg=value=>`${Number(value).toLocaleString('es-ES',{maximumFractionDigits:3})} kg`;
const SVG='http://www.w3.org/2000/svg';
const ACC_ICONS={
 mask:'M5 9c0-3 3-5 7-5s7 2 7 5v3c0 4-3 8-7 8s-7-4-7-8zM8 11h3M13 11h3M10 16h4',
 hat:'M3 17h18M6 17c0-6 2-10 6-10s6 4 6 10M8 12h8',
 glasses:'M2 11h20M4 11a3 3 0 0 0 6 0M14 11a3 3 0 0 0 6 0',
 ears:'M9 4a5 5 0 0 1 10 2c0 3-3 4-3 7a3 3 0 0 1-6 0M9 18v2',
 watch:'M8 3h8v4H8zM8 17h8v4H8zM7 7h10v10H7zM12 10v2l1.5 1',
 bracelet:'M12 5a7 4 0 1 0 0 14a7 4 0 1 0 0-14zM12 8a4 2 0 1 0 0 8'
};
async function rpc(name,data={}){
 const abort=new AbortController(),timer=setTimeout(()=>abort.abort(),8000);
 try{const response=await fetch(`https://${GetParentResourceName()}/${name}`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data),signal:abort.signal});return await response.json();}
 finally{clearTimeout(timer);}
}
function status(message,error=false){$('status').textContent=message;$('status').dataset.error=String(error);}
function hideMenu(){$('menu').hidden=true;}
function close(){if(drag){drag.ghost?.remove();drag=null;}hideMenu();visible=false;epoch++;inventory=null;selected=null;busy=false;$('inventory').hidden=true;rpc('close').catch(()=>{});}
function itemIcon(key){const svg=document.createElementNS(SVG,'svg');const use=document.createElementNS(SVG,'use');use.setAttribute('href',`icons.svg#${allowedIcons.has(key)?key:'box'}`);svg.append(use);return svg;}
function pathIcon(d){const svg=document.createElementNS(SVG,'svg');svg.setAttribute('viewBox','0 0 24 24');const p=document.createElementNS(SVG,'path');p.setAttribute('d',d);svg.append(p);return svg;}
function lockIcon(){const svg=document.createElementNS(SVG,'svg');svg.setAttribute('viewBox','0 0 24 24');const p=document.createElementNS(SVG,'path');p.setAttribute('d','M7 10V7a5 5 0 0 1 10 0v3h1a1 1 0 0 1 1 1v9a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1v-9a1 1 0 0 1 1-1zm2 0h6V7a3 3 0 0 0-6 0z');svg.append(p);return svg;}
function selectedEntry(){return inventory?.slots[String(selected)]??null;}
function quickSlots(){return Number(inventory?.hotbar)||0;}

function renderAccessories(){
 const box=$('accessories');box.replaceChildren();
 for(const a of accessories){
  const button=document.createElement('button');button.type='button';
  button.className=`acc${a.worn?'':a.available?' removed':' off'}`;button.disabled=!a.available;
  button.title=a.worn?`Quitar: ${a.label}`:a.available?`Poner: ${a.label}`:`${a.label}: no llevas`;
  button.append(pathIcon(ACC_ICONS[a.id]||ACC_ICONS.hat));const label=document.createElement('span');label.textContent=a.label;button.append(label);
  button.addEventListener('click',async()=>{const r=await rpc('accessory',{id:a.id}).catch(()=>null);if(r&&Array.isArray(r.accessories)){accessories=r.accessories;renderAccessories();}});
  box.append(button);
 }
}

function render(){
 if(!inventory)return;
 const entry=selectedEntry();if(!entry)selected=null;
 $('slots').textContent=`${Object.keys(inventory.slots).length} / ${inventory.capacity} slots`;
 $('weight').textContent=`${kg(inventory.weight)} / ${kg(inventory.maxWeight)}`;
 $('weight-bar').max=inventory.maxWeight;$('weight-bar').value=inventory.weight;
 $('grid').replaceChildren();
 for(let slot=1;slot<=inventory.capacity;slot++){
  const e=inventory.slots[String(slot)],def=e&&inventory.items[e.name],button=document.createElement('button');
  const quick=slot<=quickSlots();
  button.type='button';button.className=`slot${e?'':' empty'}${quick?' quick':''}${selected===slot?' selected':''}`;button.dataset.slot=slot;button.disabled=busy;
  button.setAttribute('aria-label',e?`Slot ${slot}: ${def.label}, ${e.count}`:`Slot ${slot} vacío`);
  const number=document.createElement('span');number.className='number';number.textContent=quick?String(slot):String(slot).padStart(2,'0');button.append(number);
  if(e){button.append(itemIcon(def.icon));const label=document.createElement('span');label.className='label';label.textContent=e.metadata.label??def.label;const qty=document.createElement('span');qty.className='qty';qty.textContent=`×${e.count}`;button.append(label,qty);}
  button.addEventListener('click',()=>{if(suppressClick){suppressClick=false;return;}hideMenu();if(!e&&selectedEntry()){moveStack(selected,slot,false);return;}selected=e?slot:null;$('amount').value='1';render();});
  button.addEventListener('contextmenu',event=>{event.preventDefault();if(!e||busy)return;selected=slot;$('amount').value='1';render();openMenu(event.clientX,event.clientY);});
  if(e)button.addEventListener('pointerdown',event=>{if(event.button===0&&!busy)drag={from:slot,x:event.clientX,y:event.clientY,active:false,ghost:null};});
  $('grid').append(button);
 }
 // Una fila de casillas bloqueadas: se veran disponibles cuando el inventario tenga mas capacidad.
 for(let i=0;i<6;i++){const lock=document.createElement('div');lock.className='slot locked';lock.title='Bloqueado';lock.append(lockIcon());$('grid').append(lock);}

 $('detail').hidden=!entry;$('empty-detail').hidden=!!entry;
 if(entry){
  const def=inventory.items[entry.name];$('item-name').textContent=entry.metadata.label??def.label;$('description').textContent=def.description;
  $('category').textContent=def.category;$('slot-number').textContent=`SLOT ${selected}`;$('detail-icon').setAttribute('href',`icons.svg#${allowedIcons.has(def.icon)?def.icon:'box'}`);
  $('count').textContent=entry.count;$('unit-weight').textContent=kg(def.weight);$('total-weight').textContent=kg(def.weight*entry.count);
  // Solo datos legibles: el numero de serie como entero; el identificador interno del objeto no se muestra.
  $('metadata').textContent=Object.entries(entry.metadata).filter(([key])=>key!=='label').map(([key,value])=>key==='serial'?`Nº de serie: ${value}`:`${key}: ${value}`).join(' · ');
  $('amount').max=entry.count;$('amount').disabled=busy;
  $('use').disabled=busy||!def.usable;$('split').disabled=busy||entry.count<2||!firstEmpty();$('drop').disabled=busy||!def.transferable;
 }
 const players=Array.isArray(inventory.players)?inventory.players:[];
 $('players').replaceChildren();$('no-players').hidden=players.length>0;
 for(const p of players){
  const chip=document.createElement('button');chip.type='button';chip.className='player';chip.dataset.player=p.id;chip.textContent=`${p.name} (${p.id})`;
  chip.disabled=busy||!entry||!inventory.items[entry.name].transferable;chip.title='Ceder el objeto seleccionado (o arrástralo aquí)';
  chip.addEventListener('click',()=>entryAction('give',{target:p.id}));$('players').append(chip);
 }
 $('nearby-count').textContent=inventory.nearby.length;$('drops').replaceChildren();
 for(const drop of inventory.nearby){const row=document.createElement('div');row.className='ground-item';const label=document.createElement('span');label.textContent=`${inventory.items[drop.name].label} ×${drop.count}`;const button=document.createElement('button');button.textContent=drop.canPickup?'Recoger':'Acércate';button.disabled=busy||!drop.canPickup;button.addEventListener('click',()=>action('pickup',{drop:drop.id}));row.append(label,button);$('drops').append(row);}
}
function firstEmpty(){if(!inventory)return null;for(let i=1;i<=inventory.capacity;i++)if(!inventory.slots[String(i)])return i;return null;}
function quantity(){const n=Number($('amount').value);return Number.isSafeInteger(n)&&n>0?n:null;}
async function action(op,args){
 if(busy||!inventory)return;
 const version=epoch;busy=true;status('Confirmando con el servidor…');render();
 try{const response=await rpc('action',{op,args:{...args,revision:inventory.revision}});if(version!==epoch)return;if(response.close){close();return;}if(response.inventory)inventory=response.inventory;status(response.ok?'Cambios guardados':response.error??'Operación rechazada',!response.ok);}
 catch{if(version===epoch){status('Sin respuesta. Cierra con ESC y vuelve a abrir.',true);close();}}
 finally{if(version===epoch){busy=false;render();}}
}
function entryAction(op,args={}){const e=selectedEntry(),count=quantity();if(!e||!count||count>e.count){status('Selecciona una cantidad válida.',true);return;}action(op,{slot:selected,expected:e.id,count,...args});}
function stackAction(from,op,partial,args={}){
 const e=inventory?.slots[String(from)];if(!e)return;
 const count=partial?quantity():e.count;if(!count||count>e.count){status('Selecciona una cantidad válida.',true);return;}
 selected=from;action(op,{slot:from,expected:e.id,count,...args});
}
function split(){const e=selectedEntry(),to=firstEmpty(),count=quantity();if(!e||!to||!count||count>=e.count){status('Para dividir, indica una cantidad menor que la pila.',true);return;}entryAction('move',{to});}

// Menu de clic derecho
function openMenu(x,y){
 const e=selectedEntry();if(!e)return;const def=inventory.items[e.name];const menu=$('menu');
 menu.querySelector('[data-op="use"]').disabled=!def.usable;menu.querySelector('[data-op="split"]').disabled=e.count<2||!firstEmpty();menu.querySelector('[data-op="drop"]').disabled=!def.transferable;
 menu.hidden=false;menu.style.left=`${Math.min(x,innerWidth-menu.offsetWidth-8)}px`;menu.style.top=`${Math.min(y,innerHeight-menu.offsetHeight-8)}px`;
}
$('menu').addEventListener('click',event=>{
 const op=event.target.closest('button')?.dataset.op;if(!op)return;hideMenu();
 if(op==='use')entryAction('use',{count:1});else if(op==='split'){$('amount').value=String(Math.max(1,Math.floor((selectedEntry()?.count||2)/2)));split();}else if(op==='drop')entryAction('drop');
});
window.addEventListener('pointerdown',event=>{if(!event.target.closest('#menu'))hideMenu();});

// Arrastrar con el raton (sin el arrastre HTML5, poco fiable en la NUI de FiveM). Destinos: otra casilla (mover,
// juntar o intercambiar), "Tirar al suelo" o un jugador de "Ceder". Con Mayus se usa solo la cantidad indicada.
let drag=null,suppressClick=false;
function moveStack(from,to,partial){if(from===to)return;stackAction(from,'move',partial,{to});}
function targetAt(x,y){
 const node=document.elementFromPoint(x,y);if(!node?.closest)return null;
 const slot=node.closest('.slot:not(.locked)');if(slot)return{kind:'slot',node:slot,slot:Number(slot.dataset.slot)};
 const zone=node.closest('#dropzone');if(zone)return{kind:'drop',node:zone};
 const player=node.closest('.player');if(player)return{kind:'give',node:player,target:Number(player.dataset.player)};
 return null;
}
function clearDragTarget(){document.querySelectorAll('.dragover').forEach(n=>n.classList.remove('dragover'));}
window.addEventListener('pointermove',event=>{
 if(!drag)return;
 if(!drag.active){
  if(Math.hypot(event.clientX-drag.x,event.clientY-drag.y)<6)return;
  const source=document.querySelector(`.slot[data-slot="${drag.from}"]`);if(!source){drag=null;return;}
  drag.active=true;drag.ghost=source.cloneNode(true);drag.ghost.className='slot drag-ghost';drag.ghost.style.width=`${source.offsetWidth}px`;drag.ghost.style.height=`${source.offsetHeight}px`;
  // Nace ya bajo el cursor: sin esto partia de (0,0) y se veia volar desde la esquina.
  drag.ghost.style.transform=`translate(${event.clientX-source.offsetWidth/2}px,${event.clientY-source.offsetHeight/2}px)`;document.body.append(drag.ghost);
  source.classList.add('dragging');$('dropzone').classList.add('armed');
 }
 drag.ghost.style.transform=`translate(${event.clientX-drag.ghost.offsetWidth/2}px,${event.clientY-drag.ghost.offsetHeight/2}px)`;
 clearDragTarget();const target=targetAt(event.clientX,event.clientY);
 if(target&&!(target.kind==='slot'&&target.slot===drag.from))target.node.classList.add('dragover');
});
window.addEventListener('pointerup',event=>{
 if(!drag)return;
 const current=drag;drag=null;clearDragTarget();$('dropzone').classList.remove('armed');
 if(!current.active)return;
 current.ghost?.remove();document.querySelector('.slot.dragging')?.classList.remove('dragging');suppressClick=true;setTimeout(()=>{suppressClick=false;},0);
 const target=targetAt(event.clientX,event.clientY);if(!target)return;
 if(target.kind==='slot'&&target.slot!==current.from)moveStack(current.from,target.slot,event.shiftKey);
 else if(target.kind==='drop')stackAction(current.from,'drop',event.shiftKey);
 else if(target.kind==='give')stackAction(current.from,'give',event.shiftKey,{target:target.target});
});
window.addEventListener('pointercancel',()=>{if(drag){drag.ghost?.remove();clearDragTarget();drag=null;}});
$('close').addEventListener('click',close);
$('use').addEventListener('click',()=>entryAction('use',{count:1}));
$('split').addEventListener('click',split);
$('drop').addEventListener('click',()=>entryAction('drop'));
// Con el foco en la NUI la tecla del juego no llega al cliente: la propia NUI cierra con ESC o con la tecla configurada.
let toggleKey='';
window.addEventListener('keydown',event=>{
 if(!visible)return;
 const typing=event.target instanceof HTMLInputElement;
 const toggle=!typing&&!event.repeat&&toggleKey!==''&&event.key.toLowerCase()===toggleKey;
 if(event.key==='Escape'&&!$('menu').hidden){event.preventDefault();hideMenu();return;}
 if(event.key==='Escape'||toggle){event.preventDefault();close();}
});
window.addEventListener('message',event=>{const data=event.data;if(!data||typeof data!=='object')return;
 if(data.type==='close'){visible=false;epoch++;busy=false;inventory=null;selected=null;hideMenu();$('inventory').hidden=true;}
 if((data.type==='open'||data.type==='update')&&data.inventory){
  if(data.type==='open'){toggleKey=typeof data.toggleKey==='string'?data.toggleKey.toLowerCase():'';epoch++;selected=null;busy=false;visible=true;$('inventory').hidden=false;status('Cambios guardados por el servidor');
   accessories=Array.isArray(data.accessories)?data.accessories:[];renderAccessories();}
  if(visible){inventory=data.inventory;render();}
 }
});
window.addEventListener('error',()=>{if(visible)close();});
window.addEventListener('unhandledrejection',()=>{if(visible)close();});
setInterval(()=>{if(visible)rpc('heartbeat').catch(()=>close());},1500);

// Tienda: catalogo del servidor, cantidad y cuenta; la compra la valida y la cobra el servidor.
const shopView={open:false};
function shopMessage(text,kind){$('shop-status').textContent=text;$('shop-status').className='shop-status'+(kind?' '+kind:'');}
function renderShop(shop){
 $('shop-title').textContent=shop.label||'Tienda';$('shop-items').replaceChildren();shopMessage('');
 for(const item of Array.isArray(shop.items)?shop.items:[]){
  const row=document.createElement('div');row.className='shop-item';row.append(itemIcon(item.icon));
  const info=document.createElement('div');info.className='info';const name=document.createElement('b');name.textContent=item.label;const desc=document.createElement('small');desc.textContent=item.description||'';info.append(name,desc);
  const price=document.createElement('span');price.className='price';price.textContent=`$${Number(item.price).toLocaleString('es-ES')}`;
  const qty=document.createElement('input');qty.type='number';qty.min='1';qty.max=String(item.max||1);qty.value='1';
  const buy=document.createElement('button');buy.textContent='Comprar';
  buy.addEventListener('click',()=>{const n=Number(qty.value);if(!Number.isSafeInteger(n)||n<1||n>(item.max||1)){shopMessage('Cantidad no válida.','error');return;}
   shopMessage('Pagando…');rpc('shopBuy',{name:item.name,qty:n,account:$('shop-account').value,total:(Number(item.price)*n).toLocaleString('es-ES')}).catch(()=>{});});
  row.append(info,price,qty,buy);$('shop-items').append(row);
 }
 shopView.open=true;$('shop').hidden=false;
}
function closeShop(){if(!shopView.open)return;shopView.open=false;$('shop').hidden=true;rpc('shopClose').catch(()=>{});}
$('shop-close').addEventListener('click',closeShop);
window.addEventListener('keydown',e=>{if(shopView.open&&e.key==='Escape')closeShop();});
window.addEventListener('message',e=>{const d=e.data;if(!d||typeof d!=='object')return;
 if(d.type==='shop'&&d.shop)renderShop(d.shop);
 else if(d.type==='shopResult'&&shopView.open)shopMessage(d.message||'',d.ok?'ok':'error');
});

// Lector de tarjetas: arrastrar la tarjeta hasta el lector (raton, sin arrastre HTML5).
const swipeView={open:false,drag:null,done:false};
const SWIPE_CARDS={bank:['Tarjeta bancaria','Debito'],tag:['G6','Chapa de alarma'],vehicle:['Llave-tarjeta','Vehiculo']};
function openSwipe(data){
 const card=$('swipe-card');const kind=SWIPE_CARDS[data.card]?data.card:'bank';
 card.className='swipe-card'+(kind==='bank'?'':' '+kind);card.style.transform='';
 $('swipe-brand').textContent=SWIPE_CARDS[kind][0];$('swipe-sub').textContent=SWIPE_CARDS[kind][1];
 $('swipe-title').textContent=data.title||'Lector de tarjetas';$('swipe-detail').textContent=data.detail||'';
 $('swipe-reader').classList.remove('ok','hover');swipeView.open=true;swipeView.done=false;$('swipe').hidden=false;
}
function closeSwipe(ok){if(!swipeView.open)return;swipeView.open=false;$('swipe').hidden=true;rpc('swipeDone',{ok:!!ok}).catch(()=>{});}
$('swipe-card').addEventListener('pointerdown',e=>{if(!swipeView.open||swipeView.done)return;const r=$('swipe-card').getBoundingClientRect();swipeView.drag={x:e.clientX,y:e.clientY};$('swipe-card').classList.add('dragging');e.preventDefault();});
window.addEventListener('pointermove',e=>{const d=swipeView.drag;if(!d)return;$('swipe-card').style.transform=`translate(${e.clientX-d.x}px,${e.clientY-d.y}px)`;
 const r=$('swipe-reader').getBoundingClientRect();$('swipe-reader').classList.toggle('hover',e.clientX>r.left&&e.clientX<r.right&&e.clientY>r.top&&e.clientY<r.bottom);});
window.addEventListener('pointerup',e=>{const d=swipeView.drag;if(!d)return;swipeView.drag=null;$('swipe-card').classList.remove('dragging');
 const r=$('swipe-reader').getBoundingClientRect();const inside=e.clientX>r.left&&e.clientX<r.right&&e.clientY>r.top&&e.clientY<r.bottom;
 $('swipe-reader').classList.remove('hover');
 if(inside){swipeView.done=true;$('swipe-reader').classList.add('ok');setTimeout(()=>closeSwipe(true),550);}
 else $('swipe-card').style.transform='';});
window.addEventListener('keydown',e=>{if(swipeView.open&&e.key==='Escape')closeSwipe(false);});
window.addEventListener('message',e=>{const m=e.data;if(!m||typeof m!=='object')return;
 if(m.type==='swipe'&&m.data)openSwipe(m.data);else if(m.type==='swipeClose'){swipeView.open=false;$('swipe').hidden=true;}});
