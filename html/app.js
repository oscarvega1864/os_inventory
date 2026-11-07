const app=document.getElementById('app'),slots=document.getElementById('slots'),weight=document.getElementById('weight');
let data={slots:{},items:{},weight:0,maxWeight:30},selected=null;
const send=(action,payload={})=>fetch(`https://${GetParentResourceName()}/${action}`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(payload)});
function render(){weight.textContent=`${Number(data.weight||0).toFixed(2)} / ${data.maxWeight||30} kg`;slots.textContent='';
 for(let i=1;i<=30;i++){const el=document.createElement('button');const v=data.slots?.[String(i)];el.className=`slot ${v?'':'empty'} ${selected===i?'selected':''}`;const n=document.createElement('span');n.className='num';n.textContent=i;el.append(n);
 if(v){const label=document.createElement('strong');label.textContent=data.items?.[v.name]?.label||v.name;el.append(label);const q=document.createElement('span');q.className='count';q.textContent=`×${v.count}`;el.append(q)}
 el.addEventListener('click',async(event)=>{if(selected===null){if(v){selected=i;render()}return}if(selected===i){selected=null;render();return}
 const source=data.slots?.[String(selected)];if(source){const count=event.shiftKey?Math.max(1,Math.floor(source.count/2)):source.count;await send('move',{from:selected,to:i,count})}selected=null;render()});slots.append(el)}
}
window.addEventListener('message',e=>{if(e.data.action==='toggle'){app.classList.toggle('hidden',!e.data.open);if(!e.data.open)selected=null}if(e.data.action==='data'){data=e.data.data;render()}});
document.getElementById('close').onclick=()=>send('close');window.addEventListener('keydown',e=>{if(e.key==='Escape')send('close')});
