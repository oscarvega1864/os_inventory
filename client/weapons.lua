-- Armas del inventario en el personaje. "Usar" un arma (o su acceso rapido) la saca o la guarda; las balas salen de
-- la municion de su tipo y lo disparado se descuenta en el servidor (el cliente solo puede gastar). Si el arma deja de
-- estar en el inventario (dada, tirada, retenida en un cacheo) se quita. Con StrictWeapons, cualquier arma que no
-- venga del inventario se retira.
OSInventory=OSInventory or {}
local config=OSInventory.ClientConfig
local UNARMED=GetHashKey('WEAPON_UNARMED')
local equipped=nil -- {id,name,hash,ammoItem,last,pending}
local lastSend=0

local function flush(force)
    if not equipped or not equipped.ammoItem or equipped.pending<=0 then return end
    if not force and GetGameTimer()-lastSend<1500 then return end
    lastSend=GetGameTimer()
    TriggerServerEvent('osinventory:ammo',equipped.ammoItem,math.min(equipped.pending,1000))
    equipped.pending=0
    equipped.quietUntil=GetGameTimer()+1500 -- una barra en vuelo podria traer la municion de antes del gasto
end
local function holster()
    if not equipped then return end
    flush(true)
    local ped=PlayerPedId()
    RemoveWeaponFromPed(ped,equipped.hash)
    SetCurrentPedWeapon(ped,UNARMED,true)
    equipped=nil
end
local function draw(data)
    local ped=PlayerPedId()
    if IsEntityDead(ped) then return end
    holster()
    local hash=GetHashKey(data.hash)
    GiveWeaponToPed(ped,hash,0,false,true)
    if data.ammoItem then SetPedAmmo(ped,hash,math.max(0,math.floor(tonumber(data.ammo) or 0))) end
    SetCurrentPedWeapon(ped,hash,true)
    equipped={id=data.id,name=data.name,hash=hash,ammoItem=data.ammoItem,last=GetAmmoInPedWeapon(ped,hash),pending=0}
end

RegisterNetEvent('osinventory:equip',function(data)
    if source~=65535 or type(data)~='table' or type(data.hash)~='string' then return end
    if OSInventory.Suspended and OSInventory.Suspended() then return end
    if equipped and equipped.id==data.id then holster() else draw(data) end
end)

-- Contenido del inventario (llega con la barra rapida): armas que se tienen y municion por tipo.
AddEventHandler('os_inventory:hotbar',function(data)
    local arsenal=type(data)=='table' and data.arsenal
    if type(arsenal)~='table' or not equipped then return end
    if not (arsenal.weapons and arsenal.weapons[equipped.id]) then return holster() end
    if equipped.ammoItem and equipped.pending==0 and GetGameTimer()>(equipped.quietUntil or 0) then
        local total=math.floor(tonumber(arsenal.ammo and arsenal.ammo[equipped.ammoItem]) or 0)
        local ped=PlayerPedId()
        if GetAmmoInPedWeapon(ped,equipped.hash)~=total then SetPedAmmo(ped,equipped.hash,total);equipped.last=total end
    end
end)

CreateThread(function()
    while true do
        Wait(250)
        local ped=PlayerPedId()
        if equipped and OSInventory.Suspended and OSInventory.Suspended() then holster() end -- al entrar en un evento se guarda
        if equipped then
            if IsEntityDead(ped) or not HasPedGotWeapon(ped,equipped.hash,false) then
                flush(true);equipped=nil
            elseif equipped.ammoItem then
                local ammo=GetAmmoInPedWeapon(ped,equipped.hash)
                if ammo<equipped.last then equipped.pending=equipped.pending+(equipped.last-ammo);equipped.last=ammo
                elseif ammo>equipped.last then SetPedAmmo(ped,equipped.hash,equipped.last) end -- municion recogida: no cuenta
                flush(false)
            end
        end
    end
end)

-- Armas que no salen del inventario: fuera.
CreateThread(function()
    if not config.StrictWeapons then return end
    while true do
        Wait(1000)
        local ped=PlayerPedId()
        if not IsEntityDead(ped) and not (OSInventory.Suspended and OSInventory.Suspended()) then
            local _,current=GetCurrentPedWeapon(ped,true)
            if current~=UNARMED and current~=0 and not (equipped and current==equipped.hash) then RemoveWeaponFromPed(ped,current) end
            for name in pairs(OSWeapons.ByHash) do
                local hash=GetHashKey(name)
                if not (equipped and hash==equipped.hash) and HasPedGotWeapon(ped,hash,false) then RemoveWeaponFromPed(ped,hash) end
            end
        end
    end
end)

AddEventHandler('onClientResourceStop',function(name) if name==GetCurrentResourceName() then flush(true) end end)
