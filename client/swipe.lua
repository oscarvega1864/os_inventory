-- Lector de tarjetas: pantalla en la que hay que arrastrar la tarjeta hasta el lector. Lo usan los pagos con tarjeta,
-- el cajero, la chapa de alarma G6 y la llave-tarjeta de los vehiculos. Solo es el gesto: quien la llama comprueba
-- en el servidor que se lleva la tarjeta y hace la operacion.
--
--   local ok = exports.os_inventory:CardSwipe({ card = 'bank' | 'tag' | 'vehicle', title = 'Pago', detail = '$2.500' })
--   (bloquea el hilo hasta que la pasan o cancelan con Esc; devuelve true o false)
local pending, keepFocus = nil, false
local function finish(ok)
    local p = pending
    pending = nil
    if not keepFocus then SetNuiFocus(false, false) end
    SendNUIMessage({ type = 'swipeClose' })
    if p then p:resolve(ok == true) end
end
local function swipe(options, insidePanel)
    if pending then return false end
    -- Si la tarjeta se usa desde el inventario abierto, se cierra el inventario para pasarla.
    if IsNuiFocused() and not insidePanel and OSInventory.Close then OSInventory.Close(); Wait(150) end
    if IsNuiFocused() and not insidePanel then return false end -- otro panel abierto (tienda de otro recurso...)
    keepFocus = insidePanel == true
    options = type(options) == 'table' and options or {}
    local card = ({ bank = true, tag = true, vehicle = true })[options.card] and options.card or 'bank'
    pending = promise.new()
    local p = pending
    SetNuiFocus(true, true)
    SendNUIMessage({ type = 'swipe', data = { card = card, title = tostring(options.title or 'Lector de tarjetas'):sub(1, 60),
        detail = options.detail and tostring(options.detail):sub(1, 80) or nil } })
    -- Sin respuesta en 30 s se cancela.
    SetTimeout(30000, function() if pending == p then finish(false) end end)
    return Citizen.Await(p)
end
exports('CardSwipe', function(options) return swipe(options, false) end)
-- Desde un panel propio que ya tiene el foco (la tienda): no lo suelta al terminar.
OSInventory.CardSwipe = function(options) return swipe(options, true) end
RegisterNUICallback('swipeDone', function(data, cb) cb({}); finish(type(data) == 'table' and data.ok == true) end)
AddEventHandler('onResourceStop', function(name) if name == GetCurrentResourceName() and pending then finish(false) end end)
