local RESOURCE=GetCurrentResourceName()
local FILE='inventory_data.json'
local state={version=1, inventories={}, audit={}}
local ready=false
local lastAction={}
local function clone(v) return json.decode(json.encode(v)) end
local function notify(src,msg)
  if src==0 then print('[os_inventory] '..msg) else TriggerClientEvent('osinventory:notify',src,msg) end
end
local function positive(v)
 local n=tonumber(v)
 if not n or n~=math.floor(n) or n<1 or n>1000000 then return nil end
 return n
end
local function identifier(src)
 if src<=0 or not GetPlayerName(src) then return nil end
 if GetResourceState('os_devtools')=='started' then
   local ok,res=pcall(function() return exports.os_devtools:GetCharacterId(src) end)
   if ok and type(res)=='string' and #res>0 then return 'osdev:'..res end
   -- Si os_devtools esta activo, no crear un identificador alternativo silenciosamente.
   return nil
 end
 for _,id in ipairs(GetPlayerIdentifiers(src)) do
   if id:sub(1,8)=='license:' then return id end
 end
 return nil
end
local function targetId(arg)
 local id=tonumber(arg)
 if id and id>0 and math.floor(id)==id and GetPlayerName(id) then return identifier(id),id end
 if type(arg)=='string' and GetResourceState('os_devtools')=='started' then
   local ok,res=pcall(function() return exports.os_devtools:GetCharacterByAlias(arg) end)
   if ok and res then return 'osdev:'..res,nil end
 end
 return nil,nil
end
local function inv(d,id)
 d.inventories[id]=d.inventories[id] or {slots={}}
 return d.inventories[id]
end
local function sameMeta(a,b) return json.encode(a or {})==json.encode(b or {}) end
local function totals(i)
 local weight=0;local used=0
 for _,v in pairs(i.slots) do
   local def=OSItems[v.name]
   if def then weight=weight+(def.weight or 0)*v.count;used=used+1 end
 end
 return weight,used
end
local function canAdd(i,name,count,meta)
 local def=OSItems[name];if not def then return false,'Objeto desconocido.' end
 local w=totals(i)
 if w+(def.weight or 0)*count>30.00001 then return false,'Peso maximo superado (30 kg).' end
 local available=0;local empty=0
 for j=1,30 do
  local v=i.slots[tostring(j)]
  if not v then empty=empty+1
  elseif v.name==name and sameMeta(v.meta,meta) then available=available+math.max(0,def.stack-v.count) end
 end
 if available+empty*def.stack<count then return false,'No hay slots suficientes.' end
 return true
end
local function add(i,name,count,meta)
 local good,err=canAdd(i,name,count,meta);if not good then return false,err end
 local def=OSItems[name]
 for pass=1,2 do
  for j=1,30 do
   if count==0 then break end
   local key=tostring(j);local v=i.slots[key]
   if pass==1 and v and v.name==name and sameMeta(v.meta,meta) and v.count<def.stack then
     local qty=math.min(count,def.stack-v.count);v.count=v.count+qty;count=count-qty
   elseif pass==2 and not v then
     local qty=math.min(count,def.stack);i.slots[key]={name=name,count=qty,meta=clone(meta or {})};count=count-qty
   end
  end
 end
 return count==0
end
local function remove(i,name,count)
 local available=0
 for _,v in pairs(i.slots) do if v.name==name then available=available+v.count end end
 if available<count then return false,'No hay suficientes objetos.' end
 for j=1,30 do
  if count==0 then break end
  local key=tostring(j);local v=i.slots[key]
  if v and v.name==name then
   local q=math.min(v.count,count);v.count=v.count-q;count=count-q
   if v.count==0 then i.slots[key]=nil end
  end
 end
 return true
end
local function transaction(op,cb)
 if not ready then return false,'Inventario no cargado.' end
 local copy=clone(state)
 local ok,err=cb(copy)
 if not ok then return false,err end
 local raw=json.encode(copy)
 if not raw then return false,'Datos no serializables.' end
 local previous=LoadResourceFile(RESOURCE,FILE)
 if previous and #previous>0 and not SaveResourceFile(RESOURCE,'inventory_backup.json',previous,#previous) then return false,'No se pudo crear respaldo.' end
 if not SaveResourceFile(RESOURCE,FILE,raw,#raw) then return false,'No se pudo guardar el inventario.' end
 state=copy
 return true
end
local function admin(src) return src==0 or IsPlayerAceAllowed(src,'osinventory.admin') end
local function snapshot(src)
 local id=identifier(src)
 if not id then return notify(src,'Identidad no disponible. Comprueba os_devtools.') end
 local i=state.inventories[id] or {slots={}}
 local weight=totals(i)
 TriggerClientEvent('osinventory:sync',src,{slots=i.slots,weight=weight,maxWeight=30,capacity=30,items=OSItems})
end
local function refreshOwners(ids)
 for _,s in ipairs(GetPlayers()) do
  local src=tonumber(s);local id=identifier(src)
  if id and ids[id] then snapshot(src) end
 end
end
RegisterNetEvent('osinventory:request',function() if ready then snapshot(source) end end)
RegisterCommand('inventario',function(src)
 if src>0 then TriggerClientEvent('osinventory:toggle',src) end
end,false)
RegisterCommand('giveitem',function(src,args)
 if not admin(src) then return notify(src,'Sin permiso ACE osinventory.admin.') end
 local id=targetId(args[1]);local name=args[2];local count=positive(args[3])
 if not id or not OSItems[name] or not count then return notify(src,'Uso: /giveitem <idJugador|alias> <item> <cantidad>') end
 local ok,err=transaction('giveitem',function(d)
  local good,msg=add(inv(d,id),name,count)
  if not good then return false,msg end
  d.audit[#d.audit+1]={t=os.time(),op='giveitem',actor=src,target=id,item=name,qty=count}
  return true
 end)
 notify(src,ok and ('Entregado '..count..' x '..name) or err)
 if ok then refreshOwners({[id]=true}) end
end,false)
RegisterCommand('removeitem',function(src,args)
 if not admin(src) then return notify(src,'Sin permiso ACE osinventory.admin.') end
 local id=targetId(args[1]);local name=args[2];local count=positive(args[3])
 if not id or not OSItems[name] or not count then return notify(src,'Uso: /removeitem <jugador|alias> <item> <cantidad>') end
 local ok,err=transaction('removeitem',function(d) return remove(inv(d,id),name,count) end)
 notify(src,ok and 'Objetos retirados.' or err)
 if ok then refreshOwners({[id]=true}) end
end,false)
RegisterCommand('inspectinventory',function(src,args)
 if not admin(src) then return notify(src,'Sin permiso ACE osinventory.admin.') end
 local id=targetId(args[1]);if not id then return notify(src,'Uso: /inspectinventory <jugador|alias>') end
 local i=state.inventories[id] or {slots={}}
 local values={};for slot,v in pairs(i.slots) do values[#values+1]=slot..':'..v.name..' x'..v.count end
 notify(src,id..' | '..(#values>0 and table.concat(values,', ') or 'vacio'))
end,false)
RegisterCommand('daritem',function(src,args)
 if src==0 then return end
 local from=identifier(src);local to,target=targetId(args[1]);local name=args[2];local count=positive(args[3])
 if not from or not to or not target or not OSItems[name] or not count or from==to then return notify(src,'Uso: /daritem <idJugador> <item> <cantidad>') end
 if OSItems[name].transferable==false then return notify(src,'Objeto no transferible.') end
 local a=GetEntityCoords(GetPlayerPed(src));local b=GetEntityCoords(GetPlayerPed(target))
 if #(a-b)>3.0 then return notify(src,'El jugador debe estar a menos de 3 metros.') end
 local ok,err=transaction('transfer',function(d)
  local sender=inv(d,from);local receiver=inv(d,to)
  local available=0;for _,v in pairs(sender.slots) do
   if v.name==name then
     if v.meta and next(v.meta) then return false,'Usa un sistema autorizado para transferir objetos con metadatos.' end
     available=available+v.count
   end
  end
  if available<count then return false,'No tienes esa cantidad.' end
  local can,msg=canAdd(receiver,name,count)
  if not can then return false,msg end
  local r=remove(sender,name,count);if not r then return false,'No se pudo retirar.' end
  return add(receiver,name,count)
 end)
 notify(src,ok and 'Entrega realizada.' or err)
 if ok then notify(target,'Has recibido '..count..' x '..name);refreshOwners({[from]=true,[to]=true}) end
end,false)
RegisterNetEvent('osinventory:move',function(a,b,n)
 local src=source;local now=GetGameTimer()
 if lastAction[src] and now-lastAction[src]<200 then return end
 lastAction[src]=now
 a=positive(a);b=positive(b);n=positive(n)
 if not a or not b or a>30 or b>30 or a==b or not n then return end
 local id=identifier(src);if not id then return end
 local ok=transaction('move',function(d)
  local slots=inv(d,id).slots;local from=slots[tostring(a)];local to=slots[tostring(b)]
  if not from or n>from.count then return false end
  if to then
   if to.name~=from.name or not sameMeta(to.meta,from.meta) then
    if n~=from.count then return false end
    slots[tostring(a)],slots[tostring(b)]=to,from;return true
   end
   local capacity=OSItems[to.name].stack-to.count
   if capacity<n then return false end
   to.count=to.count+n;from.count=from.count-n
  else
   slots[tostring(b)]={name=from.name,count=n,meta=clone(from.meta)}
   from.count=from.count-n
  end
  if from.count==0 then slots[tostring(a)]=nil end
  return true
 end)
 if ok then snapshot(src) end
end)
AddEventHandler('playerDropped',function() lastAction[source]=nil end)
AddEventHandler('onResourceStart',function(res)
 if res~=RESOURCE then return end
 local raw=LoadResourceFile(RESOURCE,FILE)
 if raw and #raw>0 then
  local ok,d=pcall(json.decode,raw)
  if not ok or type(d)~='table' or d.version~=1 or type(d.inventories)~='table' then
   print('[os_inventory] ERROR: datos invalidos; no se sobreescriben.');return
  end
  state=d
 else
  local rawNew=json.encode(state)
  if not SaveResourceFile(RESOURCE,FILE,rawNew,#rawNew) then print('[os_inventory] ERROR: imposible crear datos.');return end
 end
 ready=true
 print('[os_inventory] Iniciado correctamente (solo DEV).')
end)
exports('GetItemCount',function(id,name)
 if type(id)~='string' then return 0 end
 local i=state.inventories[id];local n=0
 if i then for _,v in pairs(i.slots) do if v.name==name then n=n+v.count end end end
 return n
end)
exports('AddItem',function(id,name,count,meta)
 if type(id)~='string' or #id>128 or not OSItems[name] or not positive(count) then return false end
 local ok=transaction('export add',function(d) return add(inv(d,id),name,count,meta) end)
 if ok then refreshOwners({[id]=true}) end
 return ok
end)
exports('RemoveItem',function(id,name,count)
 if type(id)~='string' or not OSItems[name] or not positive(count) then return false end
 local ok=transaction('export remove',function(d) return remove(inv(d,id),name,count) end)
 if ok then refreshOwners({[id]=true}) end
 return ok
end)
