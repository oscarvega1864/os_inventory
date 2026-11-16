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
RegisterNetEvent('osinventory:hotbar',function(data)
    if source~=65535 or type(data)~='table' then return end
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
        for _,control in ipairs(WEAPON_KEYS) do DisableControlAction(0,control,true) end
    end
end)
-- os_hud pide el contenido al arrancar (puede iniciarse despues que este recurso).
AddEventHandler('os_inventory:hotbarRequest',function() OSInventory.Hotbar.request() end)
