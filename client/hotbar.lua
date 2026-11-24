-- Accesos rapidos: teclas 1-6 usan el objeto de las 6 primeras casillas (lo valida el servidor). El contenido se
-- pide al servidor al arrancar y cuando cambia el inventario, y se avisa a otros recursos (os_hud lo pinta).
OSInventory=OSInventory or {}
OSInventory.Hotbar={}
local config=OSInventory.ClientConfig
local pending=false
local WEAPON_KEYS={157,158,160,164,165,159} -- teclas 1-6 del juego: elegir arma por tipo

function OSInventory.Hotbar.request()
    if pending then return end
    pending=true
    SetTimeout(300,function() pending=false;TriggerServerEvent('osinventory:hotbar') end)
end
-- Barra de un evento (os_coopchase): con el inventario suspendido, las teclas 1-6 sacan las armas que da el evento.
-- items = { { weapon = 'WEAPON_PISTOL' }, ... } en orden de casilla (o nil para quitarla).
local eventItems=nil
local function eventHotbar()
    local slots={}
    for slot,item in ipairs(eventItems or {}) do
        local def=OSItems[item.weapon:lower()]
        slots[#slots+1]={slot=slot,name=item.weapon:lower(),label=def and def.label or item.weapon,icon=def and def.icon or 'gun',count=1,usable=true}
    end
    return {slots=slots,arsenal={weapons={},ammo={}}}
end
AddEventHandler('os_inventory:eventHotbar',function(items)
    eventItems=nil
    if type(items)=='table' then
        eventItems={}
        for i=1,math.min(#items,config.HotbarSlots) do
            if type(items[i])=='table' and type(items[i].weapon)=='string' then eventItems[#eventItems+1]={weapon=items[i].weapon} end
        end
    end
    if eventItems then TriggerEvent('os_inventory:hotbar',eventHotbar()) else OSInventory.Hotbar.request() end
end)
RegisterNetEvent('osinventory:hotbar',function(data)
    if source~=65535 or type(data)~='table' then return end
    if eventItems and OSInventory.Suspended and OSInventory.Suspended() then data=eventHotbar() end
    TriggerEvent('os_inventory:hotbar',data)
end)
RegisterNetEvent('osinventory:quickUsed',function(slot,ok)
    if source~=65535 then return end
    TriggerEvent('os_inventory:hotbarUsed',slot,ok==true)
    OSInventory.Hotbar.request()
end)

local last=0
for slot=1,config.HotbarSlots do
    RegisterCommand('accesorapido'..slot,function()
        if IsNuiFocused() or IsPauseMenuActive() or IsEntityDead(PlayerPedId()) then return end
        if OSInventory.Suspended and OSInventory.Suspended() then
            -- Evento: saca (o guarda) el arma de esa casilla si el evento la ha dado.
            local item=eventItems and eventItems[slot]
            if not item then return end
            local ped,hash=PlayerPedId(),GetHashKey(item.weapon)
            local ok=HasPedGotWeapon(ped,hash,false)
            if ok then
                local _,current=GetCurrentPedWeapon(ped,true)
                SetCurrentPedWeapon(ped,current==hash and GetHashKey('WEAPON_UNARMED') or hash,true)
            end
            TriggerEvent('os_inventory:hotbarUsed',slot,ok)
            return
        end
        if GetGameTimer()-last<400 then return end
        last=GetGameTimer()
        TriggerServerEvent('osinventory:quickUse',slot)
    end,false)
    RegisterKeyMapping('accesorapido'..slot,'Acceso rapido '..slot,'keyboard',tostring(slot))
end

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(500) end
    Wait(3000)
    OSInventory.Hotbar.request()
    TriggerServerEvent('osinventory:weaponsReady') -- pasa al inventario las armas del sistema anterior (una vez)
    if not config.BlockWeaponKeys then return end
    while true do
        Wait(0)
        -- Tambien en eventos: las teclas 1-6 son la barra rapida (que alli lleva las armas del evento).
        for _,control in ipairs(WEAPON_KEYS) do DisableControlAction(0,control,true) end
    end
end)
-- os_hud pide el contenido al arrancar (puede iniciarse despues que este recurso).
AddEventHandler('os_inventory:hotbarRequest',function() OSInventory.Hotbar.request() end)
