local resource=GetCurrentResourceName()
local focused=false
local heartbeat=0
local function notify(text) TriggerEvent('chat:addMessage',{args={'OS INVENTORY',text}}) end
local function hide()
    SendNUIMessage({type='close'})
    if focused then SetNuiFocus(false,false);focused=false end
    OSInventory.Look.stop()
end
local function canOpen()
    return NetworkIsSessionStarted() and not IsEntityDead(PlayerPedId()) and not IsPauseMenuActive() and not IsNuiFocused()
end
local controller=OSInventory.Client.new({schedule=SetTimeout,canOpen=canOpen,notify=notify,
    send=function(event,id,packet) TriggerServerEvent('osinventory:'..event,id,packet) end,
    close=function() TriggerServerEvent('osinventory:close') end,hide=hide,
    show=function(inventory)
        heartbeat=GetGameTimer();focused=true;SetNuiFocus(true,true);OSInventory.Look.start()
        SendNUIMessage({type='open',inventory=inventory,toggleKey=OSInventory.ClientConfig.Key,accessories=OSInventory.Look.accessories()})
    end,
    update=function(inventory) SendNUIMessage({type='update',inventory=inventory}) end})
RegisterCommand('inventario',function() controller.toggle() end,false)
-- Otros paneles (lector de tarjetas) cierran el inventario si esta abierto.
OSInventory.Close=function() if controller.isOpen() then controller.close() end end
RegisterKeyMapping('inventario','Abrir / cerrar inventario','keyboard',OSInventory.ClientConfig.Key)
RegisterNetEvent('osinventory:response',function(id,response) if source==65535 then controller.response(id,response) end end)
RegisterNetEvent('osinventory:notify',function(text) if source==65535 then notify(text) end end)
RegisterNetEvent('osinventory:invalidated',function() if source==65535 then controller.refresh();OSInventory.Hotbar.request() end end)
RegisterNetEvent('osinventory:forceClose',function() if source==65535 then controller.close() end end)
RegisterNUICallback('close',function(_,callback) controller.close();callback({ok=true}) end)
RegisterNUICallback('heartbeat',function(_,callback) heartbeat=GetGameTimer();callback({ok=true}) end)
RegisterNUICallback('action',function(data,callback)
    if type(data)~='table' or type(data.op)~='string' or type(data.args)~='table' then callback({ok=false,error='Solicitud invalida.'});return end
    controller.action(data.op,data.args,callback)
end)
local props,dropGeneration={},0
local function removeProps()
    dropGeneration=dropGeneration+1
    for key,entity in pairs(props) do if DoesEntityExist(entity) then DeleteEntity(entity) end;props[key]=nil end
end
RegisterNetEvent('osinventory:drops',function(drops)
    if source~=65535 or type(drops)~='table' then return end
    dropGeneration=dropGeneration+1;local generation=dropGeneration
    local wanted={};for _,drop in ipairs(drops) do wanted[drop.id]=drop end
    for key,entity in pairs(props) do if not wanted[key] then if DoesEntityExist(entity) then DeleteEntity(entity) end;props[key]=nil end end
    if next(wanted)==nil then return end
    CreateThread(function()
        local model=joaat('prop_cs_cardbox_01');RequestModel(model)
        local deadline=GetGameTimer()+5000
        while not HasModelLoaded(model) and GetGameTimer()<deadline and generation==dropGeneration do Wait(25) end
        if generation~=dropGeneration or not HasModelLoaded(model) then SetModelAsNoLongerNeeded(model);return end
        for key,drop in pairs(wanted) do
            if not props[key] or not DoesEntityExist(props[key]) then
                local p=drop.position;local entity=CreateObjectNoOffset(model,p.x,p.y,p.z-0.9,false,false,false)
                if entity and entity~=0 then
                    PlaceObjectOnGroundProperly(entity);FreezeEntityPosition(entity,true);SetEntityCollision(entity,false,false);SetEntityAsMissionEntity(entity,true,true);props[key]=entity
                end
            end
        end
        SetModelAsNoLongerNeeded(model)
    end)
end)
AddEventHandler('onClientResourceStop',function(name) if name==resource then controller.close();removeProps() end end)
CreateThread(function()
    while true do
        Wait(1000)
        if controller.isOpen() then
            local elapsed=GetGameTimer()-heartbeat
            if not NetworkIsSessionStarted() or IsEntityDead(PlayerPedId()) or not IsNuiFocused() or elapsed<0 or elapsed>OSInventory.ClientConfig.UiTimeoutMilliseconds then controller.close() end
        end
    end
end)
CreateThread(function()
    while true do
        Wait(OSInventory.ClientConfig.DropPollMilliseconds)
        if NetworkIsSessionStarted() and not IsEntityDead(PlayerPedId()) then
            TriggerServerEvent('osinventory:nearby')
            if controller.isOpen() then controller.refresh() end
        else removeProps() end
    end
end)
RegisterNUICallback('accessory',function(data,callback)
    if type(data)=='table' and type(data.id)=='string' then OSInventory.Look.toggle(data.id) end
    callback({accessories=OSInventory.Look.accessories()})
end)
