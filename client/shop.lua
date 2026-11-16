-- Tiendas (config/shops.lua): blip en el mapa, aviso junto al mostrador y E para abrir. El servidor comprueba la
-- distancia, el saldo y que quepa; aqui solo se muestra el catalogo.
local shopOpen=nil
CreateThread(function()
    for _,shop in pairs(OSInventory.Shops) do
        for _,l in ipairs(shop.locations) do
            local blip=AddBlipForCoord(l.x,l.y,l.z)
            SetBlipSprite(blip,shop.blip.sprite);SetBlipColour(blip,shop.blip.color);SetBlipScale(blip,shop.blip.scale);SetBlipAsShortRange(blip,true)
            BeginTextCommandSetBlipName('STRING');AddTextComponentSubstringPlayerName(shop.label);EndTextCommandSetBlipName(blip)
        end
    end
end)
CreateThread(function()
    while true do
        local wait=1000
        local here=GetEntityCoords(PlayerPedId())
        for id,shop in pairs(OSInventory.Shops) do
            for _,l in ipairs(shop.locations) do
                local d=#(here-vector3(l.x,l.y,l.z))
                if d<15.0 then wait=0 end
                if d<shop.distance and not shopOpen and not IsNuiFocused() then
                    BeginTextCommandDisplayHelp('STRING');AddTextComponentSubstringPlayerName('~INPUT_CONTEXT~ '..shop.label);EndTextCommandDisplayHelp(0,false,false,-1)
                    if IsControlJustPressed(0,38) then TriggerServerEvent('osinventory:shop:open',id) end
                end
            end
        end
        Wait(wait)
    end
end)
RegisterNetEvent('osinventory:shop',function(catalog)
    if source~=65535 or type(catalog)~='table' then return end
    shopOpen=catalog.id
    SetNuiFocus(true,true)
    SendNUIMessage({type='shop',shop=catalog})
end)
RegisterNetEvent('osinventory:shopResult',function(ok,message)
    if source~=65535 then return end
    SendNUIMessage({type='shopResult',ok=ok==true,message=message})
end)
RegisterNUICallback('shopBuy',function(data,cb)
    cb({})
    if not shopOpen or type(data)~='table' then return end
    local shop=shopOpen
    CreateThread(function()
        -- Con tarjeta: hay que pasarla por el lector (el servidor comprueba que se lleva la tarjeta bancaria).
        if data.account=='bank' and not OSInventory.CardSwipe({card='bank',title='Pago con tarjeta',detail=data.total and ('$'..tostring(data.total)) or nil}) then
            SendNUIMessage({type='shopResult',ok=false,message='Pago cancelado.'});return
        end
        TriggerServerEvent('osinventory:shop:buy',shop,data.name,tonumber(data.qty),data.account)
    end)
end)
RegisterNUICallback('shopClose',function(_,cb) shopOpen=nil;SetNuiFocus(false,false);cb({}) end)
