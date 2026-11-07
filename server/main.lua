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
local function invalidate() TriggerClientEvent('osinventory:invalidated',-1) end
local function boot()
    if service then return end
    local storage,err=OSInventory.openStorage(resource,identity,os.time())
    if not storage then print('[os_inventory] ERROR: '..tostring(err));return end
    service=OSInventory.Service.new({resource=resource,storage=storage,identity=identity,position=position,admin=admin,actor=actor,now=os.time,
        log=function(message) print('[os_inventory] '..message) end})
    if service.start() then print('[os_inventory] v'..c.Version..' iniciado; proveedor '..c.Identity.Provider..'.')
    else print('[os_inventory] ERROR: almacenamiento bloqueado; no se habilitan operaciones.') end
end
AddEventHandler('onResourceStart',function(name) if name==resource then boot() end end)
RegisterNetEvent('osinventory:open',function(requestId)
    local src=source
    if not u.integer(requestId,1,2147483647) then return end
    local response=service and service.open(src) or {ok=false,error='Inventario no disponible.'}
    TriggerClientEvent('osinventory:response',src,requestId,response)
end)
RegisterNetEvent('osinventory:request',function(requestId,packet)
    local src=source
    if not u.integer(requestId,1,2147483647) then return end
    local response=service and service.request(src,packet) or {ok=false,error='Inventario no disponible.',close=true}
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
exports('RegisterUsableItem',function(name,callback)
    return service and service.register(GetInvokingResource(),name,callback) or false
end)
