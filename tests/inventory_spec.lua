local total,failures=0,__failures or 0
local function test(name,fn) total=total+1;local ok,err=pcall(fn);if not ok then failures=failures+1 end;__report(name,ok,tostring(err));__failures=failures end
local modules={'config/server.lua','config/shops.lua','shared/items.lua','shared/weapons.lua','shared/keys.lua','shared/jobs_items.lua','server/lib/util.lua','server/storage/codec.lua','server/storage/resource_files.lua',
 'server/storage/json.lua','server/identity.lua','server/domain.lua','server/store.lua','server/service.lua','server/panel_track.lua'}
local function fixture(options)
    options=options or {}
    OSInventory={};for _,file in ipairs(modules) do dofile('/repo/'..file) end
    local u,d,c=OSInventory.Util,OSInventory.Domain,OSInventory.Config
    if options.standalone then c.Identity.Provider='standalone' end
    if options.slots then c.Slots=options.slots end
    if options.weight then c.MaxWeight=options.weight end
    local f={files=options.files or {},clock=1000,writes=0,connected={[1]=true,[2]=true,[3]=true},characters={[1]=1,[2]=2,[3]=3},admin={[1]=true},provider=true,position={
        [1]={x=100,y=100,z=30,bucket=0},[2]={x=101,y=100,z=30,bucket=0},[3]={x=150,y=100,z=30,bucket=0}}}
    local function dto(n) return {characterId=string.format('oschar_%010d',n),alias='person_'..n,connected=true,spawning=f.spawning==n} end
    f.identity=OSInventory.Identity.new({connected=function(src) return f.connected[src]==true end,state=function() return f.provider and 'started' or 'stopped' end,
        identifiers=function(src) return {'license:'..string.rep(src==1 and 'a' or 'b',40)} end,
        active=function(src) if f.characters[src] then return dto(f.characters[src]) end end,
        resolve=function(value) local n=tonumber(value:match('oschar_0*(%d+)$') or value:match('person_(%d+)$'));if n and n<20 then return dto(n) end end})
    LoadResourceFile=function(_,file) return f.files[file] end
    SaveResourceFile=function(_,file,raw,length)
        assert(length==#raw);f.writes=f.writes+1
        if f.fail then return false end
        f.files[file]=f.partial and raw:sub(1,5) or raw
        if f.ambiguous then return false end
        return f.integer and 1 or true
    end
    io.open=function() return nil,'not found',2 end
    f.storage,f.error=OSInventory.openStorage('os_inventory',f.identity,f.clock)
    if not f.storage then return f end
    f.service=OSInventory.Service.new({resource='os_inventory',storage=f.storage,identity=f.identity,now=function() return f.clock end,committed=options.committed,
        position=function(src) return f.connected[src] and f.position[src] end,
        admin=function(src) return src==0 or f.admin[src]==true end,actor=function(src) return 'account:'..src end,log=function() end,
        players=function() local list={};for src in pairs(f.connected) do list[#list+1]=src end;return list end,name=function(src) return 'Nombre '..src end,equip=function(src,data) f.equipped={src=src,data=data} end,
        charge=function(src,amount,account) if f.broke then return false,'insufficient_funds' end;f.charged=(f.charged or 0)+amount;return true end,
        refund=function(src,amount) f.refunded=(f.refunded or 0)+amount end})
    assert(f.service.start())
    function f.owner(src) local person=f.identity.active(src);return person and person.key end
    function f.inv(src) return f.service.state().inventories[f.owner(src)] end
    function f.add(src,name,n,meta,op) return f.service.api('os_inventory','AddItem',string.format('oschar_%010d',f.characters[src]),name,n,meta,op) end
    function f.count(src,name) return d.count(f.inv(src),name) end
    function f.open(src) local result=f.service.open(src);assert(result.ok,result.error);return result end
    function f.request(src,opened,op,args)
        opened.sequence=opened.sequence+1
        args=args or {};local inv=f.inv(src);args.revision=args.revision or (inv and inv.revision or 0)
        local packet={token=opened.token,sequence=opened.sequence,op=op,args=args}
        return f.service.request(src,packet),packet
    end
    function f.args(src,slot,n) local entry=f.inv(src).slots[tostring(slot)];return {slot=slot,expected=entry.id,count=n} end
    return f
end
InventoryTest={test=test,fixture=fixture}
test('Empty inventory is persisted without giving prototype objects',function()
    local f=fixture();local o=f.open(1);assert(next(o.inventory.slots)==nil and o.inventory.weight==0 and o.inventory.capacity==30)
    assert(f.inv(1).owner=='devtools:oschar_0000000001' and f.inv(1).id=='oinv_0000000001')
end)
test('Add, count, remove and incompatible quantities are authoritative',function()
    local f=fixture();assert(f.add(1,'agua',3));assert(f.count(1,'agua')==3)
    assert(f.service.api('os_inventory','RemoveItem','oschar_0000000001','agua',2));assert(f.count(1,'agua')==1)
    for _,n in ipairs({-1,0,1.5,1000001,math.huge}) do assert(not f.add(1,'agua',n)) end
    assert(not f.add(1,'unregistered',1));assert(f.count(1,'agua')==1)
end)
test('Stack limits split additions into slots and moving merges or splits correctly',function()
    local f=fixture();assert(f.add(1,'agua',25));assert(f.inv(1).slots['1'].count==20 and f.inv(1).slots['2'].count==5)
    local o=f.open(1);local a=f.args(1,1,4);a.to=3;assert(f.request(1,o,'move',a).ok)
    assert(f.inv(1).slots['1'].count==16 and f.inv(1).slots['3'].count==4)
    a=f.args(1,3,4);a.to=2;assert(f.request(1,o,'move',a).ok);assert(f.inv(1).slots['2'].count==9 and not f.inv(1).slots['3'])
end)
test('Different items swap only when moving the complete stack',function()
    local f=fixture();assert(f.add(1,'agua',4));assert(f.add(1,'comida',2));local o=f.open(1)
    local a=f.args(1,1,1);a.to=2;assert(not f.request(1,o,'move',a).ok)
    a=f.args(1,1,4);a.to=2;assert(f.request(1,o,'move',a).ok);assert(f.inv(1).slots['1'].name=='comida')
end)
test('Weight and slot capacity reject full operations without losing existing items',function()
    local f=fixture({slots=2,weight=1});assert(f.add(1,'agua',2));assert(not f.add(1,'comida',1));assert(f.count(1,'agua')==2)
    f=fixture({slots=2});assert(f.add(1,'telefono',2));assert(not f.add(1,'telefono',1));assert(f.count(1,'telefono')==2)
end)
test('Unique metadata and individual IDs never mix in stacks',function()
    local f=fixture();assert(f.add(1,'herramienta',2,{serial='SERIAL-A'}));local inv=f.inv(1)
    assert(inv.slots['1'].count==1 and inv.slots['2'].count==1 and inv.slots['1'].instanceId~=inv.slots['2'].instanceId)
    assert(not f.add(1,'agua',1,{serial='bad'}));assert(not f.add(1,'tarjeta_acceso',1,{admin=true}))
    assert(not f.add(1,'telefono',1,{serial=string.rep('s',65)}))
end)
test('Nearby transfer atomically preserves unique identity and metadata',function()
    local f=fixture();assert(f.add(1,'tarjeta_acceso',1,{serial='A'}));local before=f.inv(1).slots['1'];local o=f.open(1)
    local a=f.args(1,1,1);a.target=2;assert(f.request(1,o,'give',a).ok)
    local after=f.inv(2).slots['1'];assert(after.id==before.id and after.instanceId==before.instanceId and after.metadata.serial=='A' and f.count(1,'tarjeta_acceso')==0)
end)
test('Transfer denies distance, bucket, unavailable target, nontransferable and full receiver',function()
    local f=fixture({slots=1});assert(f.add(1,'agua',2));assert(f.add(2,'telefono',1));local o=f.open(1)
    local a=f.args(1,1,1);a.target=2;assert(not f.request(1,o,'give',a).ok)
    a=f.args(1,1,1);a.target=3;assert(not f.request(1,o,'give',a).ok)
    f.position[2].bucket=9;a.target=2;assert(not f.request(1,o,'give',a).ok)
    f.connected[2]=false;assert(not f.request(1,o,'give',a).ok);assert(f.count(1,'agua')==2)
    f=fixture();assert(f.add(1,'g6_operations_tablet',1));o=f.open(1);a=f.args(1,1,1);a.target=2;assert(not f.request(1,o,'give',a).ok)
    assert(not f.request(1,o,'drop',f.args(1,1,1)).ok)
end)
test('Drop and pickup persist representation and permit exactly one successful collection',function()
    local f=fixture();assert(f.add(1,'agua',4));local o=f.open(1);assert(f.request(1,o,'drop',f.args(1,1,2)).ok)
    local key=next(f.service.state().drops);assert(key and f.count(1,'agua')==2 and #f.service.nearby(2)==1)
    local p=f.open(2);assert(f.request(2,p,'pickup',{drop=key}).ok);assert(f.count(2,'agua')==2)
    assert(not f.request(1,o,'pickup',{drop=key}).ok);assert(next(f.service.state().drops)==nil)
end)
test('Repeated and modified sequence packets cannot duplicate effects',function()
    local f=fixture();assert(f.add(1,'agua',4));local o=f.open(1)
    local response,packet=f.request(1,o,'drop',f.args(1,1,2));assert(response.ok)
    local revision=f.service.state().revision;assert(f.service.request(1,packet).ok);assert(f.service.state().revision==revision)
    packet.args.count=1;assert(not f.service.request(1,packet).ok);assert(f.count(1,'agua')==2)
    o=f.open(1);packet.token='forged';assert(not f.service.request(1,packet).ok)
end)
test('Sessions bind actual character, expire, reject foreign source and close on provider stop',function()
    local f=fixture();assert(f.add(1,'agua',4));local o=f.open(1);local _,packet=f.request(1,o,'refresh',{})
    assert(not f.service.request(2,packet).ok);f.characters[1]=3;assert(not f.request(1,o,'refresh',{}).ok)
    f.characters[1]=1;o=f.open(1);f.clock=f.clock+91;assert(not f.request(1,o,'refresh',{}).ok)
    o=f.open(1);f.provider=false;assert(not f.request(1,o,'refresh',{}).ok);assert(not f.service.open(1).ok)
end)
test('Rate limiting rejects floods without removing items',function()
    local f=fixture();local o=f.open(1)
    local response;for _=1,40 do response=f.request(1,o,'refresh',{}) end
    assert(not response.ok);assert(next(f.inv(1).slots)==nil)
end)
test('Built-in use consumes one real item; future tablets have no invented functionality',function()
    local f=fixture();assert(f.add(1,'agua',2));assert(f.add(1,'g6_client_tablet',1));local o=f.open(1)
    assert(f.request(1,o,'use',f.args(1,1,1)).ok and f.count(1,'agua')==1)
    assert(not f.request(1,o,'use',f.args(1,2,1)).ok)
end)
test('External exports default deny and explicit per-item rules preserve permissions',function()
    local f=fixture();assert(not f.service.api('attacker','AddItem','oschar_0000000001','agua',1))
    OSInventory.Config.ResourceAccess.partner={read=true,writeItems={agua=true},useItems={telefono=true}}
    assert(f.service.api('partner','AddItem','oschar_0000000001','agua',1));assert(f.service.api('partner','GetItemCount','oschar_0000000001','agua')==1)
    assert(not f.service.api('partner','AddItem','oschar_0000000001','telefono',1));assert(not f.service.api(nil,'AddItem','oschar_0000000001','agua',1))
    assert(not f.service.api('partner','AddItem','oschar_9999999999','agua',1));assert(not f.service.api('partner','AddItem','1','agua',1))
    -- GetInventory lleva el nombre visible de cada objeto (catalogo o metadatos), sin tocar el estado guardado.
    local inv=f.service.api('partner','GetInventory','oschar_0000000001')
    local label;for _,slot in pairs(inv.slots) do if slot.name=='agua' then label=slot.label end end
    assert(label==OSItems.agua.label and label~='agua')
    local again=f.service.api('partner','GetInventory','oschar_0000000001')
    for _,slot in pairs(again.slots) do assert(slot.label==nil or slot.label==OSItems[slot.name].label) end
end)
test('os_security access covers only its own items and tablet use',function()
    local f=fixture();f.service.api('os_security','GetItemCount','oschar_0000000001','agua')
    assert(f.service.api('os_security','AddItem','oschar_0000000001','os_cctv_kit',2,nil,'g6-test:add'))
    assert(f.service.api('os_security','RemoveItem','oschar_0000000001','os_cctv_kit',1,nil,'g6-test:take'))
    assert(f.service.api('os_security','GetItemCount','oschar_0000000001','os_cctv_kit')==1)
    assert(not f.service.api('os_security','AddItem','oschar_0000000001','agua',1))
    -- Referencia invocable entre recursos (tabla con __call), como la entrega FiveM a traves de exports.
    local used=0;local funcref=setmetatable({},{__call=function(_,src,context) assert(src==1 and context.item.name=='g6_client_tablet');used=used+1 end})
    assert(f.service.register('os_security','g6_client_tablet',funcref))
    assert(f.service.register('os_security','os_cctv_kit',function() end))
    assert(not f.service.register('os_security','os_drill',function() end))
    assert(not f.service.register('os_security','g6_operations_tablet',{}))
    assert(f.add(1,'g6_client_tablet',1));local o=f.open(1);local slot
    for key,entry in pairs(f.inv(1).slots) do if entry.name=='g6_client_tablet' then slot=tonumber(key) end end
    assert(f.request(1,o,'use',f.args(1,slot,1)).ok and used==1)
    for _,name in ipairs({'os_alarm_kit','os_lock_kit','os_tracker_kit','os_drill','os_screwdriver','os_battery'}) do assert(OSItems[name],name) end
end)
test('Durable export operation receipts survive restarts and reject changed payloads',function()
    local f=fixture();assert(f.add(1,'agua',2,nil,'add-1'));assert(f.add(1,'agua',2,nil,'add-1'));assert(f.count(1,'agua')==2)
    assert(not f.add(1,'agua',3,nil,'add-1'));local g=fixture({files=f.files});assert(g.add(1,'agua',2,nil,'add-1'));assert(g.count(1,'agua')==2)
end)
test('Full receipt registry retires receipts older than ReceiptDays instead of blocking item operations forever',function()
    local f=fixture();local c=OSInventory.Config;local saved=c.MaxReceipts;c.MaxReceipts=3
    local ok,err=pcall(function()
        assert(f.add(1,'agua',1,nil,'r-1'));assert(f.add(1,'agua',1,nil,'r-2'));assert(f.add(1,'agua',1,nil,'r-3'))
        assert(not f.add(1,'agua',1,nil,'r-4')) -- lleno y ninguno caducado
        f.clock=f.clock+c.ReceiptDays*86400+1
        assert(f.add(1,'agua',1,nil,'r-4') and f.count(1,'agua')==4) -- se retiran los caducados y sigue
        local g=fixture({files=f.files});assert(g.count(1,'agua')==4) -- el cambio supera la validacion al reiniciar
        local old={revision=1,provider=c.Identity.Provider,nextInventory=1,nextStack=1,nextDrop=1,inventories={},receipts={k={signature='s',at=f.clock}},audit={}}
        local new={revision=2,provider=c.Identity.Provider,nextInventory=1,nextStack=1,nextDrop=1,inventories={},receipts={},audit={{at=f.clock+10}}}
        assert(not OSInventory.Domain.successor(old,new)) -- un recibo reciente no puede desaparecer
    end)
    c.MaxReceipts=saved;assert(ok,err)
end)
test('Registered item use is server-only, scoped, deduplicated and removed on resource stop',function()
    local f=fixture();local calls=0;OSInventory.Config.ResourceAccess.partner={useItems={telefono=true}}
    assert(not f.service.register('attacker','telefono',function() end))
    assert(f.service.register('partner','telefono',function(src,context) assert(src==1 and context.characterId=='oschar_0000000001');calls=calls+1 end))
    assert(f.add(1,'telefono',1));local o=f.open(1);local r,p=f.request(1,o,'use',f.args(1,1,1));assert(r.ok and calls==1)
    assert(f.service.request(1,p).ok and calls==1);f.service.resourceStopped('partner');assert(not f.request(1,o,'use',f.args(1,1,1)).ok)
end)
test('Admin commands require effective permission and clear requires same revision confirmation',function()
    local f=fixture();assert(not f.service.admin(2,'giveitem','1','agua',3));assert(f.service.admin(1,'giveitem','2','agua',3));assert(f.count(2,'agua')==3)
    assert(not f.service.admin(1,'clearinventory','2'));assert(f.service.admin(1,'clearinventory','2',nil,nil,'CONFIRMAR'));assert(f.count(2,'agua')==0)
    assert(not f.service.admin(1,'clearinventory','2'));f.admin[1]=false;assert(not f.service.admin(1,'clearinventory','2',nil,nil,'CONFIRMAR'))
    local audit=f.service.state().audit;assert(audit[#audit].op=='clearinventory' and audit[#audit].actor=='account:1')
end)
test('Standalone works without Devtools and project mode never silently changes identities',function()
    local f=fixture({standalone=true});f.provider=false;local o=f.open(1);assert(o.inventory.id and f.owner(1):match('^standalone:license:'))
    f=fixture();f.provider=false;assert(not f.service.open(1).ok)
    f.provider=true;f.spawning=1;assert(not f.service.open(1).ok)
end)
test('Legacy aliases migrate quantities and slots with exact source backup; unknown identities block',function()
    local raw=json.encode({version=1,inventories={['osdev:person_1']={slots={['4']={name='agua',count=3,meta={}}}}},audit={{op='old'}}})
    local f=fixture({files={['inventory_data.json']=raw}});assert(f.service,f.error)
    assert(f.files['inventory_data.json']==raw and f.files['data/migration-010-source.json']==raw)
    assert(f.inv(1).slots['4'].count==3 and #f.service.state().legacyAudit==1)
    local bad=fixture({files={['inventory_data.json']=json.encode({version=1,inventories={['osdev:unknown']={slots={}}},audit={}})}})
    assert(not bad.service and bad.error and bad.writes==0)
end)
test('Journal restart restores transfers and drops without resurrecting removed items',function()
    local f=fixture();assert(f.add(1,'agua',8));local o=f.open(1);local a=f.args(1,1,2);a.target=2;assert(f.request(1,o,'give',a).ok)
    assert(f.request(1,o,'drop',f.args(1,1,3)).ok);local g=fixture({files=f.files})
    assert(g.count(1,'agua')==3 and g.count(2,'agua')==2 and next(g.service.state().drops))
end)
test('Failed and partial writes publish no items and fail closed, preserving the prior slot',function()
    local f=fixture();assert(f.add(1,'agua',2));local before=OSInventory.Util.copy(f.files);f.fail=true
    assert(not f.add(1,'agua',1));assert(f.count(1,'agua')==2);assert(not f.add(1,'agua',1))
    for key,value in pairs(before) do assert(f.files[key]==value) end
    f=fixture();assert(f.add(1,'agua',2));f.partial=true;assert(not f.add(1,'agua',1));assert(f.count(1,'agua')==2)
    local g=fixture({files=f.files});assert(not g.service and g.error)
end)
test('Ambiguous completed write is recovered only after restart, native integer success is accepted',function()
    local f=fixture();f.integer=true;assert(f.add(1,'agua',2));f.ambiguous=true;assert(not f.add(1,'agua',1));assert(f.count(1,'agua')==2)
    local g=fixture({files=f.files});assert(g.count(1,'agua')==3)
end)
test('Corruption and external edits never reset to an empty inventory',function()
    local f=fixture({files={['inventory_data.json']='{broken'}});assert(not f.service and f.writes==0)
    f=fixture();assert(f.add(1,'agua',2));f.files['data/inventories.a.json']='changed';assert(not f.add(1,'agua',1));assert(f.count(1,'agua')==2)
    local g=fixture({files=f.files});assert(not g.service and g.writes==0)
end)
test('Snapshot validation rejects forged quantities, reused instance IDs and counter regressions',function()
    local f=fixture();assert(f.add(1,'telefono',2));local state=f.service.state();local inv=state.inventories[f.owner(1)]
    inv.slots['1'].count=-1;assert(not OSInventory.Domain.snapshot(state))
    state=f.service.state();inv=state.inventories[f.owner(1)];inv.slots['2'].instanceId=inv.slots['1'].instanceId;assert(not OSInventory.Domain.snapshot(state))
    state=f.service.state();state.nextStack=1;assert(not OSInventory.Domain.snapshot(state))
end)
print(('Inventory domain/service/storage: %d cases'):format(total))

test('Hotbar lists the first six slots and quick use follows the same rules as Use',function()
    local f=fixture();assert(f.add(1,'agua',2));assert(f.add(1,'g6_client_tablet',1))
    local inv=f.inv(1);local moved=f.open(1);assert(f.request(1,moved,'move',{slot=2,expected=inv.slots['2'].id,count=1,to=8}).ok)
    local bar=f.service.hotbar(1);assert(#bar.slots==1 and bar.slots[1].slot==1 and bar.slots[1].name=='agua' and bar.slots[1].count==2 and bar.slots[1].usable==true)
    assert(f.service.quickUse(1,1) and f.count(1,'agua')==1)
    local ok,err=f.service.quickUse(1,3);assert(not ok and err:find('acceso rapido 3'))
    assert(not f.service.quickUse(1,8),'slot 8 is not a quick-access slot');assert(not f.service.quickUse(1,0) and not f.service.quickUse(1,'1'))
    assert(f.service.hotbar(9)==nil,'no character, no hotbar')
end)
test('Give list shows only nearby players with a character, never yourself',function()
    local f=fixture();assert(f.add(1,'agua',1));local opened=f.open(1)
    local players=opened.inventory.players;assert(#players==1 and players[1].id==2 and players[1].name=='Nombre 2')
    assert(opened.inventory.hotbar==6)
    f.characters[2]=nil;assert(#f.service.players(1)==0)
end)

test('Weapons are unique items with a server serial; Use draws them without consuming and sends the ammo of their type',function()
    local f=fixture();assert(f.add(1,'weapon_pistol',2));assert(f.add(1,'ammo_pistol',40))
    local a,b=f.inv(1).slots['1'],f.inv(1).slots['2']
    assert(a.name=='weapon_pistol' and b.name=='weapon_pistol' and a.metadata.serial=='1' and b.metadata.serial=='2','weapon serials start at 1 and count up')
    assert(f.add(1,'weapon_knife',1) and f.inv(1).slots['4'].metadata.serial=='3')
    local o=f.open(1);assert(f.request(1,o,'use',f.args(1,1,1)).ok)
    assert(f.count(1,'weapon_pistol')==2,'drawing a weapon does not consume it')
    assert(f.equipped.src==1 and f.equipped.data.hash=='WEAPON_PISTOL' and f.equipped.data.ammoItem=='ammo_pistol' and f.equipped.data.ammo==40 and f.equipped.data.id==a.id)
    local bar=f.service.hotbar(1);assert(bar.arsenal.weapons[a.id]=='weapon_pistol' and bar.arsenal.ammo.ammo_pistol==40)
end)
test('Fired rounds only ever reduce ammo, never below zero, and only for ammo items',function()
    local f=fixture();assert(f.add(1,'ammo_rifle',30));assert(f.add(1,'agua',2))
    assert(f.service.useAmmo(1,'ammo_rifle',12) and f.count(1,'ammo_rifle')==18)
    assert(f.service.useAmmo(1,'ammo_rifle',100) and f.count(1,'ammo_rifle')==0)
    assert(not f.service.useAmmo(1,'agua',1) and f.count(1,'agua')==2)
    assert(not f.service.useAmmo(1,'ammo_rifle',-5) and not f.service.useAmmo(1,'ammo_rifle',0) and not f.service.useAmmo(1,'ammo_rifle',5000))
end)
test('Saved weapons from the old system become items with their ammo, all or nothing',function()
    local f=fixture()
    assert(f.service.migrateWeapons(1,{{name='WEAPON_PISTOL',ammo=36},{name='WEAPON_KNIFE',ammo=0},{name='WEAPON_GRENADE',ammo=3},{name='WEAPON_UNKNOWN',ammo=5}}))
    assert(f.count(1,'weapon_pistol')==1 and f.count(1,'ammo_pistol')==36 and f.count(1,'weapon_knife')==1 and f.count(1,'weapon_grenade')==3)
    local g=fixture({slots=1});assert(not g.service.migrateWeapons(1,{{name='WEAPON_PISTOL',ammo=10},{name='WEAPON_KNIFE',ammo=0}}))
    assert(g.count(1,'weapon_pistol')==0,'nothing is added when it does not all fit')
end)

test('Ammu-Nation: only at a counter, listed items, valid amounts; charge then deliver, refund when it does not fit',function()
    local f=fixture();local counter=OSInventory.Shops.ammunation.locations[1]
    assert(not f.service.shopBuy(1,'ammunation','weapon_pistol',1,'cash'),'far from any counter')
    f.position[1]={x=counter.x,y=counter.y,z=counter.z,bucket=0}
    local ok,msg=f.service.shopBuy(1,'ammunation','weapon_pistol',1,'cash');assert(ok,msg)
    assert(f.count(1,'weapon_pistol')==1 and f.charged==2500 and f.inv(1).slots['1'].metadata.serial)
    assert(not f.service.shopBuy(1,'ammunation','ammo_pistol',60,'bank'),'paying by card needs the bank card')
    assert(f.add(1,'bank_card',1))
    assert(f.service.shopBuy(1,'ammunation','ammo_pistol',60,'bank') and f.count(1,'ammo_pistol')==60 and f.charged==2500+180)
    assert(not f.service.shopBuy(1,'ammunation','weapon_carbinerifle',1,'cash'),'rifles are not sold')
    assert(not f.service.shopBuy(1,'ammunation','ammo_pistol',0,'cash') and not f.service.shopBuy(1,'ammunation','ammo_pistol',300,'cash'))
    assert(not f.service.shopBuy(1,'ammunation','ammo_pistol',5,'crypto'))
    f.broke=true;local before=f.count(1,'ammo_pistol');assert(not f.service.shopBuy(1,'ammunation','ammo_pistol',5,'cash') and f.count(1,'ammo_pistol')==before)
    local catalog=f.service.shopCatalog(1,'ammunation');assert(#catalog.items>10 and catalog.items[1].price>0)
end)

test('Panel tracking reports where each unique unit goes and who moved it',function()
    local moves={}
    local f=fixture({committed=function(before,after,event) for _,m in ipairs(OSInventory.PanelTrack.diff(before,after,event)) do moves[#moves+1]=m end end})
    assert(f.add(1,'llave',1,{label='Llave propiedad 200',kind='prop',target='200',version='1'}))
    assert(f.add(1,'agua',3)) -- sin identidad propia: no se sigue
    assert(#moves==1 and moves[1].unit:match('^ounit_%d+$') and moves[1].kind=='inventory' and moves[1].label=='Llave propiedad 200' and moves[1].op=='AddItem' and moves[1].actor=='os_inventory')
    local unit=moves[1].unit
    assert(f.service.api('os_inventory','RemoveItem',string.format('oschar_%010d',1),'llave',1,{label='Llave propiedad 200',kind='prop',target='200',version='1'}))
    assert(#moves==2 and moves[2].unit==unit and moves[2].kind=='gone')
end)

