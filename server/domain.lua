-- Modelo puro: gramos enteros, identidades individuales y mutaciones sin E/S.
OSInventory.Domain={}
local d,u,c=OSInventory.Domain,OSInventory.Util,OSInventory.Config
local function size(value) local n=0;for _ in pairs(value) do n=n+1 end;return n end
local function id(prefix,n) return prefix..string.format('%010d',n) end
local function validId(value,prefix) return type(value)=='string' and value:match('^'..prefix..'%d%d%d%d%d%d%d%d%d%d$')~=nil and tonumber(value:sub(-10))>0 end
assert(u.integer(c.Slots,1,c.MaxSlots) and u.finite(c.MaxWeight) and c.MaxWeight>0 and c.MaxWeight*1000<=c.MaxWeightGrams,'Capacidad configurada invalida.')
for name,item in pairs(OSItems) do
    assert(u.text(name,64) and u.text(item.label,128) and u.text(item.description,512) and u.finite(item.weight) and item.weight>=0
        and item.weight*1000<=c.MaxWeightGrams and u.integer(item.stack,1,c.MaxMutation) and type(item.transferable)=='boolean'
        and type(item.metadataAllowed)=='boolean' and type(item.unique)=='boolean','Catalogo de objetos invalido: '..tostring(name))
end
function d.metadata(name,meta)
    local def=OSItems[name]
    if not def or not u.object(meta) or (next(meta) and not def.metadataAllowed) then return false end
    for key,value in pairs(meta) do
        if not def.metadataSchema[key] or not u.text(value,def.metadataSchema[key]) then return false end
    end
    return true
end
function d.limit(name,meta) return (OSItems[name].unique or next(meta)) and 1 or OSItems[name].stack end
function d.weight(inv)
    local grams=0;for _,entry in pairs(inv.slots) do grams=grams+math.floor(OSItems[entry.name].weight*1000+0.5)*entry.count end
    return grams
end
function d.owner(value)
    if type(value)~='string' then return false end
    if c.Identity.Provider=='os_devtools' then return validId(value,'devtools:oschar_') end
    return c.Identity.Provider=='standalone' and #value==59 and value:match('^standalone:license:[0-9a-f]+$')~=nil
end
function d.empty()
    return {version=2,provider=c.Identity.Provider,revision=0,nextInventory=1,nextStack=1,nextDrop=1,inventories={},drops={},receipts={},audit={},legacyAudit={}}
end
function d.inventory(state,owner,create,now)
    local inv=state.inventories[owner]
    if not inv and create then
        if not d.owner(owner) or size(state.inventories)>=c.MaxInventories then return nil,'Identidad o limite de inventarios invalido.' end
        inv={id=id('oinv_',state.nextInventory),owner=owner,slotCount=c.Slots,maxWeightGrams=math.floor(c.MaxWeight*1000+0.5),revision=0,createdAt=now,slots={}}
        state.nextInventory=state.nextInventory+1;state.inventories[owner]=inv
    end
    return inv
end
function d.amount(n) return u.integer(n,1,c.MaxMutation) end
function d.count(inv,name,meta)
    local n=0;for _,entry in pairs(inv and inv.slots or {}) do
        if entry.name==name and (meta==nil or u.equal(entry.metadata,meta)) then n=n+entry.count end
    end;return n
end
function d.canCarry(inv,name,count,meta)
    meta=meta or {}
    if not OSItems[name] or not d.amount(count) or not d.metadata(name,meta) then return false,'Objeto, cantidad o metadatos invalidos.' end
    if d.weight(inv)+math.floor(OSItems[name].weight*1000+0.5)*count>inv.maxWeightGrams then return false,'Capacidad de peso insuficiente.' end
    local space=0;local limit=d.limit(name,meta)
    for slot=1,inv.slotCount do
        local entry=inv.slots[tostring(slot)]
        if not entry then space=space+limit
        elseif limit>1 and entry.name==name and u.equal(entry.metadata,meta) then space=space+math.max(0,limit-entry.count) end
    end
    return space>=count,space>=count and nil or 'No hay slots suficientes.'
end
local function newEntry(state,name,count,meta)
    local entry={id=id('ostack_',state.nextStack),name=name,count=count,metadata=u.copy(meta)}
    if d.limit(name,meta)==1 then entry.instanceId=id('ounit_',state.nextStack) end
    state.nextStack=state.nextStack+1;return entry
end
function d.add(state,inv,name,count,meta,existing)
    meta=meta or {};local ok,err=d.canCarry(inv,name,count,meta);if not ok then return false,err end
    local limit=d.limit(name,meta)
    if limit>1 then
        for slot=1,inv.slotCount do
            local entry=inv.slots[tostring(slot)]
            if entry and entry.name==name and u.equal(entry.metadata,meta) then
                local n=math.min(count,limit-entry.count);entry.count=entry.count+n;count=count-n
            end
        end
    end
    for slot=1,inv.slotCount do
        if count==0 then break end
        if not inv.slots[tostring(slot)] then
            local n=math.min(count,limit)
            if existing and existing.count==n then inv.slots[tostring(slot)]=existing;existing=nil
            else inv.slots[tostring(slot)]=newEntry(state,name,n,meta) end
            count=count-n
        end
    end
    inv.revision=inv.revision+1;return true
end
function d.remove(inv,name,count,meta)
    if not OSItems[name] or not d.amount(count) or (meta~=nil and not d.metadata(name,meta)) then return false,'Parametros invalidos.' end
    if d.count(inv,name,meta)<count then return false,'Cantidad no disponible.' end
    for slot=1,inv.slotCount do
        local key=tostring(slot);local entry=inv.slots[key]
        if entry and entry.name==name and (meta==nil or u.equal(entry.metadata,meta)) then
            local n=math.min(count,entry.count);entry.count=entry.count-n;count=count-n
            if entry.count==0 then inv.slots[key]=nil end
        end
        if count==0 then break end
    end
    inv.revision=inv.revision+1;return true
end
function d.entry(inv,slot,expected,count)
    if not u.integer(slot,1,inv.slotCount) or not d.amount(count) then return nil,'Slot o cantidad invalidos.' end
    local entry=inv.slots[tostring(slot)]
    if not entry or entry.id~=expected or count>entry.count then return nil,'El slot ha cambiado; actualiza el inventario.' end
    return entry
end
function d.take(state,inv,slot,expected,count)
    local entry,err=d.entry(inv,slot,expected,count);if not entry then return nil,err end
    local result
    if count==entry.count then result=entry;inv.slots[tostring(slot)]=nil
    else entry.count=entry.count-count;result=newEntry(state,entry.name,count,entry.metadata) end
    inv.revision=inv.revision+1;return result
end
function d.move(state,inv,slot,target,expected,count)
    local entry,err=d.entry(inv,slot,expected,count);if not entry then return false,err end
    if not u.integer(target,1,inv.slotCount) or target==slot then return false,'Destino invalido.' end
    local other=inv.slots[tostring(target)]
    if other then
        if other.name==entry.name and d.limit(entry.name,entry.metadata)>1 and u.equal(other.metadata,entry.metadata) then
            if other.count+count>d.limit(entry.name,entry.metadata) then return false,'Pila llena.' end
            other.count=other.count+count;entry.count=entry.count-count
            if entry.count==0 then inv.slots[tostring(slot)]=nil end
        else
            if count~=entry.count then return false,'Para intercambiar slots mueve la pila completa.' end
            inv.slots[tostring(slot)],inv.slots[tostring(target)]=other,entry
        end
    else
        local taken=d.take(state,inv,slot,expected,count);inv.slots[tostring(target)]=taken
    end
    inv.revision=inv.revision+1;return true
end
function d.position(point)
    return u.object(point,{x=true,y=true,z=true,bucket=true}) and u.finite(point.x) and math.abs(point.x)<=20000
        and u.finite(point.y) and math.abs(point.y)<=20000 and u.finite(point.z) and point.z>=-200 and point.z<=3000
        and u.integer(point.bucket,0,2147483647)
end
function d.near(a,b,range) return d.position(a) and d.position(b) and a.bucket==b.bucket and (a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2<=range^2 end
function d.drop(state,inv,slot,expected,count,position,now)
    if not d.position(position) or size(state.drops)>=c.MaxDrops then return false,'Destino o limite de objetos en suelo invalido.' end
    local entry,err=d.take(state,inv,slot,expected,count);if not entry then return false,err end
    local key=id('odrop_',state.nextDrop);state.nextDrop=state.nextDrop+1
    state.drops[key]={id=key,entry=entry,position=u.copy(position),createdAt=now};return true,key
end
function d.pickup(state,inv,key,position)
    local drop=state.drops[key]
    if not drop or not d.near(position,drop.position,c.PickupDistance) then return false,'Objeto ausente o demasiado lejos.' end
    local e=drop.entry;local ok,err=d.add(state,inv,e.name,e.count,e.metadata,e)
    if not ok then return false,err end
    state.drops[key]=nil;return true
end
function d.audit(state,event)
    state.audit[#state.audit+1]=event
    while #state.audit>c.MaxAudit do table.remove(state.audit,1) end
end
function d.snapshot(state)
    if not u.object(state,{version=true,provider=true,revision=true,nextInventory=true,nextStack=true,nextDrop=true,inventories=true,drops=true,receipts=true,audit=true,legacyAudit=true})
        or state.version~=2 or state.provider~=c.Identity.Provider or not u.integer(state.revision,0,9007199254740990)
        or not u.object(state.inventories) or size(state.inventories)>c.MaxInventories or not u.object(state.drops) or size(state.drops)>c.MaxDrops
        or not u.object(state.receipts) or size(state.receipts)>c.MaxReceipts or not u.array(state.audit,c.MaxAudit) or not u.array(state.legacyAudit,100000) then return false,'Cabecera de inventario invalida.' end
    for _,field in ipairs({'nextInventory','nextStack','nextDrop'}) do if not u.integer(state[field],1,9999999999) then return false,'Contador invalido.' end end
    local ids,units={},{}
    local function entry(e)
        if not u.object(e,{id=true,name=true,count=true,metadata=true,instanceId=true}) or not validId(e.id,'ostack_') or ids[e.id] or tonumber(e.id:sub(8))>=state.nextStack
            or not OSItems[e.name] or not d.amount(e.count) or not d.metadata(e.name,e.metadata) or e.count>d.limit(e.name,e.metadata) then return false end
        ids[e.id]=true
        if d.limit(e.name,e.metadata)==1 then
            if e.instanceId~=('ounit_'..e.id:sub(8)) or units[e.instanceId] then return false end;units[e.instanceId]=true
        elseif e.instanceId~=nil then return false end
        return true
    end
    local inventories={}
    for owner,inv in pairs(state.inventories) do
        if not d.owner(owner) or not u.object(inv,{id=true,owner=true,slotCount=true,maxWeightGrams=true,revision=true,createdAt=true,slots=true}) or inv.owner~=owner
            or not validId(inv.id,'oinv_') or inventories[inv.id] or tonumber(inv.id:sub(6))>=state.nextInventory
            or not u.integer(inv.slotCount,1,c.MaxSlots) or not u.integer(inv.maxWeightGrams,1,c.MaxWeightGrams)
            or not u.integer(inv.revision,0,9007199254740990) or not u.integer(inv.createdAt,0,9007199254740990) or not u.object(inv.slots) then return false,'Inventario invalido.' end
        inventories[inv.id]=true
        for slot,e in pairs(inv.slots) do
            if tostring(tonumber(slot))~=slot or not u.integer(tonumber(slot),1,inv.slotCount) or not entry(e) then return false,'Slot o identidad de objeto invalidos.' end
        end
        if d.weight(inv)>inv.maxWeightGrams then return false,'Inventario por encima de su capacidad.' end
    end
    for key,drop in pairs(state.drops) do
        if not validId(key,'odrop_') or tonumber(key:sub(7))>=state.nextDrop or not u.object(drop,{id=true,entry=true,position=true,createdAt=true}) or drop.id~=key
            or not d.position(drop.position) or not u.integer(drop.createdAt,0,9007199254740990) or not entry(drop.entry) then return false,'Objeto en suelo invalido.' end
    end
    for key,receipt in pairs(state.receipts) do
        if not u.text(key,192) or not u.object(receipt,{signature=true,at=true}) or not u.text(receipt.signature,2048) or not u.integer(receipt.at,0,9007199254740990) then return false,'Recibo invalido.' end
    end
    return true
end
function d.successor(old,new)
    if new.revision~=old.revision+1 or new.provider~=old.provider then return false,'Revision no consecutiva.' end
    for _,field in ipairs({'nextInventory','nextStack','nextDrop'}) do if new[field]<old[field] then return false,'Contador reutilizado.' end end
    for owner,inv in pairs(old.inventories) do
        local nextInv=new.inventories[owner]
        if not nextInv or nextInv.id~=inv.id or nextInv.revision<inv.revision then return false,'Inventario eliminado o renumerado.' end
    end
    -- Un recibo solo puede desaparecer si ya tenia mas de ReceiptDays dias cuando se guardo este cambio.
    local last=new.audit[#new.audit]
    local cutoff=last and u.integer(last.at,0,9007199254740990) and last.at-c.ReceiptDays*86400 or nil
    for key,receipt in pairs(old.receipts) do
        local kept=new.receipts[key]
        if kept==nil then
            if not cutoff or receipt.at>=cutoff then return false,'Recibo perdido o alterado.' end
        elseif not u.equal(kept,receipt) then return false,'Recibo perdido o alterado.' end
    end
    return true
end
-- Retira los recibos caducados (mas de ReceiptDays dias). Devuelve cuantos quita.
function d.pruneReceipts(state,now)
    local cutoff,removed=now-c.ReceiptDays*86400,0
    for key,receipt in pairs(state.receipts) do
        if receipt.at<cutoff then state.receipts[key]=nil;removed=removed+1 end
    end
    return removed
end
function d.migrate(old,identity,now)
    if old.version==2 then local ok,err=d.snapshot(old);return ok and u.copy(old) or nil,err end
    if not u.object(old,{version=true,inventories=true,audit=true}) or old.version~=1 or not u.object(old.inventories) or not u.array(old.audit,100000) then return nil,'Formato heredado invalido.' end
    local state=d.empty();state.legacyAudit=u.copy(old.audit)
    local owners={};for owner in pairs(old.inventories) do owners[#owners+1]=owner end;table.sort(owners)
    for _,owner in ipairs(owners) do
        local person,err=identity.legacy(owner);if not person then return nil,err end
        if state.inventories[person.key] then return nil,'Dos inventarios heredados apuntan al mismo personaje; se requiere revision.' end
        local inv,reason=d.inventory(state,person.key,true,now);if not inv then return nil,reason end
        local source=old.inventories[owner]
        if not u.object(source,{slots=true}) or not u.object(source.slots) then return nil,'Inventario heredado invalido.' end
        for slot,e in pairs(source.slots) do
            if tostring(tonumber(slot))~=slot or not u.integer(tonumber(slot),1,inv.slotCount) or not u.object(e,{name=true,count=true,meta=true})
                or not OSItems[e.name] or not d.amount(e.count) or not d.metadata(e.name,e.meta or {}) or e.count>d.limit(e.name,e.meta or {}) then return nil,'Slot heredado incompatible; no se descartan objetos.' end
            inv.slots[slot]=newEntry(state,e.name,e.count,e.meta or {})
        end
    end
    local ok,err=d.snapshot(state);return ok and state or nil,err
end
