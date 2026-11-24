local resource=GetCurrentResourceName()
local c,u,d=OSInventory.Config,OSInventory.Util,OSInventory.Domain
local function notify(src,text)
    if src==0 then print('[os_inventory] '..text) else TriggerClientEvent('osinventory:notify',src,text) end
end
local admin=OSInventoryAdminAccess.new({ace=IsPlayerAceAllowed,state=GetResourceState,
    permission=OSInventoryAuthorization.Permission,resource=OSInventoryAuthorization.Resource,
    delegate=function(name,src,permission) return exports[name]:HasOscarPermission(src,permission) end})
local identity=OSInventory.Identity.new({connected=function(src) return GetPlayerName(src)~=nil end,state=GetResourceState,
    identifiers=GetPlayerIdentifiers,
    active=function(src) return exports[c.Identity.Resource]:GetActiveCharacter(src) end,
    resolve=function(query) return exports[c.Identity.Resource]:ResolveCharacter(query) end})
local function position(src)
    if not u.integer(src,1,2147483647) or not GetPlayerName(src) then return nil end
    local ped=GetPlayerPed(src)
    if not ped or ped==0 or not DoesEntityExist(ped) or GetEntityHealth(ped)<=0 then return nil end
    local point=GetEntityCoords(ped)
    if not point then return nil end
    local result={x=tonumber(string.format('%.12g',point.x)),y=tonumber(string.format('%.12g',point.y)),
        z=tonumber(string.format('%.12g',point.z)),bucket=GetPlayerRoutingBucket(src)}
    return d.position(result) and result or nil
end
local function actor(src)
    for _,value in ipairs(GetPlayerIdentifiers(src) or {}) do
        if type(value)=='string' and #value==48 and value:match('^license:[0-9a-f]+$') then return value end
    end
end
local service
-- Aviso de cambios agrupado: varias operaciones seguidas (p. ej. cobros de una mision) envian un solo aviso.
local invalidatePending=false
local function invalidate()
    if invalidatePending then return end
    invalidatePending=true
    SetTimeout(250,function() invalidatePending=false;TriggerClientEvent('osinventory:invalidated',-1) end)
end
local function boot()
    if service then return end
    local storage,err=OSInventory.openStorage(resource,identity,os.time())
    if not storage then print('[os_inventory] ERROR: '..tostring(err));return end
    service=OSInventory.Service.new({resource=resource,storage=storage,identity=identity,position=position,admin=admin,actor=actor,now=os.time,
        players=function() local list={};for _,id in ipairs(GetPlayers and GetPlayers() or {}) do list[#list+1]=tonumber(id) end;return list end,
        name=function(src) return (GetPlayerName(src) or ('Jugador '..src)):gsub('[%c<>]',''):sub(1,32) end,
        equip=function(src,data) TriggerClientEvent('osinventory:equip',src,data) end,
        -- os_hud recibe tambien lo que alimenta el objeto (shared/food.lua) para no repetir la tabla.
        consumed=function(src,name) TriggerEvent('os_inventory:consumed',src,name,OSItems[name] and OSItems[name].nutrition) end,
        charge=function(src,amount,account,reason) local ok,res,err=pcall(function() return exports[c.Identity.Resource]:ChargeCharacter(src,amount,account,reason) end);if not ok then return false,'sin servicio de dinero' end;return res,err end,
        refund=function(src,amount,account,reason) pcall(function() exports[c.Identity.Resource]:PayCharacter(src,amount,account,reason) end) end,
        -- Web del panel (via os_admin): donde esta cada objeto con ID propio y quien lo movio.
        committed=function(before,after,event)
            if GetResourceState('os_admin')~='started' then return end
            for _,move in ipairs(OSInventory.PanelTrack.diff(before,after,event)) do
                if move.place then move.place=move.place:gsub('^devtools:','') end
                move.actor=move.actor:gsub('^devtools:','')
                local ok,accepted=pcall(function() return exports.os_admin:PanelTrack('item',move) end)
                if not ok or not accepted then return end
            end
        end,
        log=function(message) print('[os_inventory] '..message) end})
    if service.start() then print('[os_inventory] v'..c.Version..' iniciado; proveedor '..c.Identity.Provider..'.')
    else print('[os_inventory] ERROR: almacenamiento bloqueado; no se habilitan operaciones.') end
    if OSInventory.AdminRuntime then OSInventory.AdminSection.publish(OSInventory.AdminRuntime) end
end
AddEventHandler('onResourceStart',function(name) if name==resource then boot() end end)
-- Durante un evento (estado 'osNoInventory', lo pone os_coopchase) no se abre ni se usa el inventario.
local function suspended(src) local ok,value=pcall(function() return Player(src).state.osNoInventory end);return ok and value==true end
RegisterNetEvent('osinventory:open',function(requestId)
    local src=source
    if not u.integer(requestId,1,2147483647) then return end
    local response=(suspended(src) and {ok=false,error='El inventario no esta disponible durante el evento.'})
        or (service and service.open(src)) or {ok=false,error='Inventario no disponible.'}
    TriggerClientEvent('osinventory:response',src,requestId,response)
end)
RegisterNetEvent('osinventory:request',function(requestId,packet)
    local src=source
    if not u.integer(requestId,1,2147483647) then return end
    local response=(suspended(src) and {ok=false,error='El inventario no esta disponible durante el evento.',close=true})
        or (service and service.request(src,packet)) or {ok=false,error='Inventario no disponible.',close=true}
    TriggerClientEvent('osinventory:response',src,requestId,response)
    if response.ok and packet.op~='refresh' then invalidate() end
end)
RegisterNetEvent('osinventory:close',function() if service then service.close(source) end end)
local nearbyAt={}
RegisterNetEvent('osinventory:nearby',function()
    local src=source;local now=os.time()
    if nearbyAt[src] and now>=nearbyAt[src] and now-nearbyAt[src]<2 then return end
    nearbyAt[src]=now
    if not service or not service.available() or not identity.active(src) then return end
    TriggerClientEvent('osinventory:drops',src,service.nearby(src))
end)
for _,name in ipairs({'giveitem','removeitem','clearinventory','inspectinventory'}) do
    RegisterCommand(name,function(src,args)
        if not admin(src) then return notify(src,'Sin autorizacion efectiva osinventory.admin. Consulta /ospermisos.') end
        if not service then return notify(src,'Inventario no disponible.') end
        if not args[1] then return notify(src,'Uso: /'..name..' <idJugador|alias|char:ID> '..((name=='giveitem' or name=='removeitem') and '<item> <cantidad>' or '')) end
        local ok,result=service.admin(src,name,args[1],args[2],tonumber(args[3]),name=='clearinventory' and args[2] or nil)
        if ok and name=='inspectinventory' then
            local entries={};for slot,entry in pairs(result.slots) do entries[#entries+1]=slot..':'..entry.name..' x'..entry.count end
            table.sort(entries);notify(src,(result.id or 'Sin inventario')..' | '..(#entries>0 and table.concat(entries,', ') or 'vacio'))
        else notify(src,ok and 'Operacion confirmada y guardada.' or tostring(result)) end
        if ok and name~='inspectinventory' then invalidate() end
    end,false)
end
-- /limpiarsuelo [metros]: borra los objetos tirados cerca (50 m por defecto y como maximo). Staff GO5 en adelante
-- (ACE osinventory.cleardrops, que os_admin da al rango Game Operator 5 y heredan los superiores).
RegisterCommand('limpiarsuelo',function(src,args)
    if src==0 then return notify(src,'Usalo desde el juego: borra lo que hay cerca de ti.') end
    if not IsPlayerAceAllowed(src,'osinventory.cleardrops') then return notify(src,'No tienes permiso (GO5 en adelante).') end
    if not service then return notify(src,'Inventario no disponible.') end
    if args[1] and not tonumber(args[1]) then return notify(src,'Uso: /limpiarsuelo [metros, hasta '..(c.ClearDropsRadius or 50)..']') end
    local ok,count,radius=service.clearDrops(src,args[1])
    if not ok then return notify(src,tostring(count)) end
    notify(src,count==0 and ('No hay objetos en el suelo a %d m.'):format(radius) or ('Borrados %d objetos del suelo en %d m.'):format(count,radius))
    if count>0 then
        invalidate()
        if GetResourceState('os_admin')=='started' then
            pcall(function() exports.os_admin:PanelLog(src,'suelo.limpiado',('%d m'):format(radius),('%d objetos'):format(count)) end)
        end
    end
end,false)
RegisterCommand('daritem',function(src,args)
    if src==0 or not service then return end
    local target,name,count=tonumber(args[1]),args[2],tonumber(args[3])
    if not u.integer(target,1,2147483647) or not OSItems[name] or not d.amount(count) then return notify(src,'Uso: /daritem <idJugador> <item> <cantidad>') end
    local ok,result=service.giveNamed(src,target,name,count)
    service.close(src);TriggerClientEvent('osinventory:forceClose',src)
    notify(src,ok and 'Entrega guardada.' or result);if ok then invalidate() end
end,false)
AddEventHandler('playerDropped',function() nearbyAt[source]=nil;if service then service.dropPlayer(source) end end)
AddEventHandler('osdev:characterChanged',function(src)
    if u.integer(src,1,2147483647) and service then service.close(src);TriggerClientEvent('osinventory:forceClose',src) end
end)
AddEventHandler('onResourceStop',function(name)
    if service then service.resourceStopped(name) end
    if name==c.Identity.Resource then TriggerClientEvent('osinventory:forceClose',-1) end
end)
for _,name in ipairs({'GetInventory','GetItemCount','HasItem','CanCarryItem','AddItem','RemoveItem'}) do
    exports(name,function(...)
        if not service then return false,'Inventario no disponible.' end
        local ok,result=service.api(GetInvokingResource(),name,...)
        if ok and (name=='AddItem' or name=='RemoveItem') then invalidate() end
        return ok,result
    end)
end
-- Armas que lleva un jugador (objetos del inventario) con la municion de su tipo, para recursos con lectura
-- (p. ej. el arco detector y el cacheo de os_security). Formato: { {name='weapon_pistol', ammo=36}, ... }.
exports('GetCarriedWeapons',function(src)
    local caller=GetInvokingResource();local access=caller and c.ResourceAccess[caller]
    if not service or not (access and access.read) then return nil end
    local data=service.hotbar(src);if not data or not data.arsenal then return nil end
    local list={}
    for _,name in pairs(data.arsenal.weapons) do
        local weapon=OSWeapons.Weapons[name]
        list[#list+1]={name=name,ammo=weapon and weapon.ammo and (data.arsenal.ammo[weapon.ammo] or 0) or 0}
    end
    return list
end)
-- Llaves (para recursos con lectura: os_devtools, os_security): si el jugador lleva la llave valida de un bien.
local function reads() local caller=GetInvokingResource();local access=caller and c.ResourceAccess[caller];return access and access.read end
exports('HasKey',function(src,kind,target,version) if not service or not reads() then return false end;return service.hasKey(src,kind,target,version) end)
exports('ListKeys',function(src) if not service or not reads() then return {} end;return service.keys(src) end)
-- Si el jugador (personaje activo) lleva al menos uno de ese objeto, p. ej. la tarjeta bancaria para pagar con tarjeta.
exports('PlayerHasItem',function(src,name) if not service or not reads() or not OSItems[name] then return false end;return service.countOf(src,name)>0 end)
-- Panel y consola de os_admin (opcional).
local adminSection={service=function() return service end,invalidate=invalidate}
OSInventory.AdminRuntime=adminSection
AddEventHandler('os_admin:ready',function() OSInventory.AdminSection.publish(adminSection) end)
exports('RegisterUsableItem',function(name,callback)
    return service and service.register(GetInvokingResource(),name,callback) or false
end)

-- Accesos rapidos (teclas 1-6): contenido para el HUD y uso directo, validado igual que "Usar".
local lastHotbar={}
RegisterNetEvent('osinventory:hotbar',function()
    local src=source
    local now=GetGameTimer()
    if lastHotbar[src] and now-lastHotbar[src]<400 then return end
    lastHotbar[src]=now
    if not service then return end
    -- Durante un evento la barra rapida (y el HUD) se ve vacia: el inventario no esta disponible.
    if suspended(src) then return TriggerClientEvent('osinventory:hotbar',src,{slots={},arsenal={weapons={},ammo={}}}) end
    local data=service.hotbar(src)
    if data then TriggerClientEvent('osinventory:hotbar',src,data) end
end)
RegisterNetEvent('osinventory:quickUse',function(slot)
    local src=source
    if not service or suspended(src) then return end
    local ok,err=service.quickUse(src,slot)
    if not ok then notify(src,err or 'No se pudo usar.') end
    TriggerClientEvent('osinventory:quickUsed',src,slot,ok==true)
end)
AddEventHandler('playerDropped',function() lastHotbar[source]=nil end)

-- Balas disparadas (el cliente solo informa de gasto) y paso de las armas guardadas del sistema anterior.
local lastAmmo={}
RegisterNetEvent('osinventory:ammo',function(name,rounds)
    local src=source
    local now=GetGameTimer()
    if lastAmmo[src] and now-lastAmmo[src]<500 then return end
    lastAmmo[src]=now
    if service then service.useAmmo(src,name,tonumber(rounds)) end
end)
local migrated={}
local function migrate(src)
    if not service or GetResourceState(c.Identity.Resource)~='started' then return end
    local person=identity.active(src);if not person or migrated[src]==person.key then return end
    migrated[src]=person.key
    local ok,list=pcall(function() return exports[c.Identity.Resource]:GetCharacterWeapons(src) end)
    if not ok or type(list)~='table' or #list==0 then return end
    local done,result=service.migrateWeapons(src,list)
    if done then
        -- Lo que no cabia se descarta: la lista antigua se borra siempre y el aviso no se repite.
        pcall(function() exports[c.Identity.Resource]:ClearCharacterWeapons(src) end)
        local added,skipped=type(result)=='table' and result.added or 0,type(result)=='table' and result.skipped or 0
        notify(src,skipped>0 and ('Armas antiguas pasadas al inventario: %d. Otras %d no cabian por peso y se han descartado.'):format(added,skipped)
            or ('Tus %d armas guardadas ahora estan en el inventario como objetos.'):format(added))
    else migrated[src]=nil;notify(src,'No se pudieron pasar tus armas al inventario: '..tostring(result)..'.') end
end
RegisterNetEvent('osinventory:weaponsReady',function() migrate(source) end)
AddEventHandler('playerDropped',function() lastAmmo[source]=nil;migrated[source]=nil end)

-- Tiendas (Ammu-Nation)
RegisterNetEvent('osinventory:shop:open',function(shopId)
    local src=source
    if not service or type(shopId)~='string' then return end
    local catalog,err=service.shopCatalog(src,shopId)
    if not catalog then return notify(src,err) end
    TriggerClientEvent('osinventory:shop',src,catalog)
end)
RegisterNetEvent('osinventory:shop:buy',function(shopId,name,qty,account)
    local src=source
    if not service or type(shopId)~='string' or type(name)~='string' then return end
    local ok,message=service.shopBuy(src,shopId,name,tonumber(qty),account)
    TriggerClientEvent('osinventory:shopResult',src,ok==true,message)
end)
