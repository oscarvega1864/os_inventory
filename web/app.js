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
function close(){visible=false;epoch++;inventory=null;selected=null;busy=false;$('inventory').hidden=true;rpc('close').catch(()=>{});}
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
  if(e){button.draggable=!busy;button.append(itemIcon(def.icon));const label=document.createElement('span');label.className='label';label.textContent=def.label;const qty=document.createElement('span');qty.className='qty';qty.textContent=`×${e.count}`;button.append(label,qty);}
  button.addEventListener('click',()=>{if(!e&&selectedEntry()){move(slot);return;}selected=e?slot:null;$('amount').value='1';render();});
  button.addEventListener('dragstart',event=>{selected=slot;event.dataTransfer.setData('text/plain',String(slot));event.dataTransfer.effectAllowed='move';});
  button.addEventListener('dragover',event=>{event.preventDefault();button.classList.add('dragover');});
  button.addEventListener('dragleave',()=>button.classList.remove('dragover'));
  button.addEventListener('drop',event=>{event.preventDefault();button.classList.remove('dragover');if(Number(event.dataTransfer.getData('text/plain'))===selected)move(slot);});
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
function move(to){if(to!==selected)entryAction('move',{to});}
$('close').addEventListener('click',close);
$('use').addEventListener('click',()=>entryAction('use',{count:1}));
$('split').addEventListener('click',()=>{const e=selectedEntry(),to=firstEmpty(),count=quantity();if(!e||!to||!count||count>=e.count){status('Para dividir, indica una cantidad menor que la pila.',true);return;}entryAction('move',{to});});
$('give').addEventListener('click',()=>{const target=Number($('target').value);if(!Number.isSafeInteger(target)||target<1){status('Indica el ID del jugador próximo.',true);return;}entryAction('give',{target});});
$('drop').addEventListener('click',()=>entryAction('drop'));
window.addEventListener('keydown',event=>{if(event.key==='Escape'&&visible){event.preventDefault();close();}});
window.addEventListener('message',event=>{const data=event.data;if(!data||typeof data!=='object')return;
 if(data.type==='close'){visible=false;epoch++;busy=false;inventory=null;selected=null;$('inventory').hidden=true;}
 if((data.type==='open'||data.type==='update')&&data.inventory){if(data.type==='open'){epoch++;selected=null;busy=false;visible=true;$('inventory').hidden=false;status('Cambios guardados por el servidor');}if(visible){inventory=data.inventory;render();}}
});
window.addEventListener('error',()=>{if(visible)close();});
window.addEventListener('unhandledrejection',()=>{if(visible)close();});
setInterval(()=>{if(visible)rpc('heartbeat').catch(()=>close());},1500);
