local opened=false
local function notify(msg)
 TriggerEvent('chat:addMessage',{color={104,206,173},args={'OS INVENTORY',msg}})
end
RegisterNetEvent('osinventory:notify',notify)
RegisterNetEvent('osinventory:toggle',function()
 opened=not opened
 SetNuiFocus(opened,opened)
 SendNUIMessage({action='toggle',open=opened})
 if opened then TriggerServerEvent('osinventory:request') end
end)
RegisterCommand('inventario_f2',function() ExecuteCommand('inventario') end,false)
RegisterKeyMapping('inventario_f2','Abrir inventario OS','keyboard','F2')
RegisterNetEvent('osinventory:sync',function(data) SendNUIMessage({action='data',data=data}) end)
RegisterNUICallback('close',function(_,cb)
 opened=false;SetNuiFocus(false,false)
 SendNUIMessage({action='toggle',open=false});cb({ok=true})
end)
RegisterNUICallback('move',function(data,cb)
 TriggerServerEvent('osinventory:move',tonumber(data.from),tonumber(data.to),tonumber(data.count))
 cb({ok=true})
end)
AddEventHandler('onClientResourceStop',function(resource)
 if resource==GetCurrentResourceName() then SetNuiFocus(false,false) end
end)
