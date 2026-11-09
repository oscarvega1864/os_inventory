'use strict';
const $=id=>document.getElementById(id);
let inventory=null,selected=null,busy=false,visible=false,epoch=0;
const allowedIcons=new Set(['water','food','phone','tool','card','tablet','box']);
const kg=value=>`${Number(value).toLocaleString('es-ES',{maximumFractionDigits:3})} kg`;
async function rpc(name,data={}){
 const abort=new AbortController(),timer=setTimeout(()=>abort.abort(),8000);
 try{const response=await fetch(`https://${GetParentResourceName()}/${name}`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data),signal:abort.signal});return await response.json();}
 finally{clearTimeout(timer);}
}
function status(message,error=false){$('status').textContent=message;$('status').dataset.error=String(error);}
function close(){if(drag){drag.ghost?.remove();drag=null;}visible=false;epoch++;inventory=null;selected=null;busy=false;$('inventory').hidden=true;rpc('close').catch(()=>{});}
function itemIcon(key){const svg=document.createElementNS('http://www.w3.org/2000/svg','svg');const use=document.createElementNS(svg.namespaceURI,'use');use.setAttribute('href',`icons.svg#${allowedIcons.has(key)?key:'box'}`);svg.append(use);return svg;}
function selectedEntry(){return inventory?.slots[String(selected)]??null;}
function render(){
 if(!inventory)return;
 const entry=selectedEntry();if(!entry)selected=null;
 $('slots').textContent=`${Object.keys(inventory.slots).length} / ${inventory.capacity} slots`;
 $('weight').textContent=`${kg(inventory.weight)} / ${kg(inventory.maxWeight)}`;
 $('weight-bar').max=inventory.maxWeight;$('weight-bar').value=inventory.weight;
 $('grid').replaceChildren();
 for(let slot=1;slot<=inventory.capacity;slot++){
  const e=inventory.slots[String(slot)],def=e&&inventory.items[e.name],button=document.createElement('button');
  button.type='button';button.className=`slot${e?'':' empty'}${selected===slot?' selected':''}`;button.dataset.slot=slot;button.disabled=busy;
  button.setAttribute('aria-label',e?`Slot ${slot}: ${def.label}, ${e.count}`:`Slot ${slot} vacío`);
  const number=document.createElement('span');number.className='number';number.textContent=String(slot).padStart(2,'0');button.append(number);
  if(e){button.append(itemIcon(def.icon));const label=document.createElement('span');label.className='label';label.textContent=def.label;const qty=document.createElement('span');qty.className='qty';qty.textContent=`×${e.count}`;button.append(label,qty);}
  button.addEventListener('click',()=>{if(suppressClick){suppressClick=false;return;}if(!e&&selectedEntry()){moveStack(selected,slot,false);return;}selected=e?slot:null;$('amount').value='1';render();});
  if(e)button.addEventListener('pointerdown',event=>{if(event.button===0&&!busy)drag={from:slot,x:event.clientX,y:event.clientY,active:false,ghost:null};});
  $('grid').append(button);
 }
 $('detail').hidden=!entry;$('empty-detail').hidden=!!entry;
 if(entry){
  const def=inventory.items[entry.name];$('item-name').textContent=entry.metadata.label??def.label;$('description').textContent=def.description;
  $('category').textContent=def.category;$('slot-number').textContent=`SLOT ${selected}`;$('detail-icon').setAttribute('href',`icons.svg#${allowedIcons.has(def.icon)?def.icon:'box'}`);
  $('count').textContent=entry.count;$('unit-weight').textContent=kg(def.weight);$('total-weight').textContent=kg(def.weight*entry.count);
  $('metadata').textContent=[entry.instanceId,...Object.entries(entry.metadata).filter(([key])=>key!=='label').map(([key,value])=>`${key}: ${value}`)].filter(Boolean).join(' · ');
  $('amount').max=entry.count;$('amount').disabled=busy;$('target').disabled=busy;
  $('use').disabled=busy||!def.usable;$('split').disabled=busy||entry.count<2||!firstEmpty();$('give').disabled=busy||!def.transferable;$('drop').disabled=busy||!def.transferable;
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
// Mover con el raton (sin el arrastre HTML5, poco fiable en la NUI de FiveM). Se mueve la pila
// completa: a un hueco vacio, se combina con una pila igual o se intercambia con otra. Con Mayus
// pulsado se mueve solo la cantidad indicada (dividir).
let drag=null,suppressClick=false;
function moveStack(from,to,partial){
 const e=inventory?.slots[String(from)];if(!e||from===to)return;
 const count=partial?quantity():e.count;
 if(!count||count>e.count){status('Selecciona una cantidad válida.',true);return;}
 selected=from;action('move',{slot:from,expected:e.id,count,to});
}
function slotAt(x,y){const node=document.elementFromPoint(x,y)?.closest?.('.slot');return node?Number(node.dataset.slot):null;}
function clearDragTarget(){document.querySelectorAll('.slot.dragover').forEach(n=>n.classList.remove('dragover'));}
window.addEventListener('pointermove',event=>{
 if(!drag)return;
 if(!drag.active){
  if(Math.hypot(event.clientX-drag.x,event.clientY-drag.y)<6)return;
  const source=document.querySelector(`.slot[data-slot="${drag.from}"]`);if(!source){drag=null;return;}
  drag.active=true;drag.ghost=source.cloneNode(true);drag.ghost.className='slot drag-ghost';drag.ghost.style.width=`${source.offsetWidth}px`;drag.ghost.style.height=`${source.offsetHeight}px`;document.body.append(drag.ghost);
  source.classList.add('dragging');
 }
 drag.ghost.style.transform=`translate(${event.clientX-drag.ghost.offsetWidth/2}px,${event.clientY-drag.ghost.offsetHeight/2}px)`;
 clearDragTarget();const target=slotAt(event.clientX,event.clientY);
 if(target&&target!==drag.from)document.querySelector(`.slot[data-slot="${target}"]`)?.classList.add('dragover');
});
window.addEventListener('pointerup',event=>{
 if(!drag)return;
 const current=drag;drag=null;clearDragTarget();
 if(!current.active)return;
 current.ghost?.remove();document.querySelector('.slot.dragging')?.classList.remove('dragging');suppressClick=true;setTimeout(()=>{suppressClick=false;},0);
 const target=slotAt(event.clientX,event.clientY);
 if(target&&target!==current.from)moveStack(current.from,target,event.shiftKey);
});
window.addEventListener('pointercancel',()=>{if(drag){drag.ghost?.remove();clearDragTarget();drag=null;}});
$('close').addEventListener('click',close);
$('use').addEventListener('click',()=>entryAction('use',{count:1}));
$('split').addEventListener('click',()=>{const e=selectedEntry(),to=firstEmpty(),count=quantity();if(!e||!to||!count||count>=e.count){status('Para dividir, indica una cantidad menor que la pila.',true);return;}entryAction('move',{to});});
$('give').addEventListener('click',()=>{const target=Number($('target').value);if(!Number.isSafeInteger(target)||target<1){status('Indica el ID del jugador próximo.',true);return;}entryAction('give',{target});});
$('drop').addEventListener('click',()=>entryAction('drop'));
// Con el foco en la NUI la tecla del juego no llega al cliente: la propia NUI cierra con ESC o con la tecla configurada.
let toggleKey='';
window.addEventListener('keydown',event=>{
 if(!visible)return;
 const typing=event.target instanceof HTMLInputElement;
 const toggle=!typing&&!event.repeat&&toggleKey!==''&&event.key.toLowerCase()===toggleKey;
 if(event.key==='Escape'||toggle){event.preventDefault();close();}
});
window.addEventListener('message',event=>{const data=event.data;if(!data||typeof data!=='object')return;
 if(data.type==='close'){visible=false;epoch++;busy=false;inventory=null;selected=null;$('inventory').hidden=true;}
 if((data.type==='open'||data.type==='update')&&data.inventory){if(data.type==='open'){toggleKey=typeof data.toggleKey==='string'?data.toggleKey.toLowerCase():'';epoch++;selected=null;busy=false;visible=true;$('inventory').hidden=false;status('Cambios guardados por el servidor');}if(visible){inventory=data.inventory;render();}}
});
window.addEventListener('error',()=>{if(visible)close();});
window.addEventListener('unhandledrejection',()=>{if(visible)close();});
setInterval(()=>{if(visible)rpc('heartbeat').catch(()=>close());},1500);
