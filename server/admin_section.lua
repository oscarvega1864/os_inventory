-- Seccion "Objetos e inventario" para el panel y la consola de os_admin (opcional).
-- Usa service.admin, la misma ruta que /giveitem, /removeitem, /inspectinventory y
-- /clearinventory: mismo permiso osinventory.admin, validacion, auditoria y persistencia.
OSInventory.AdminSection = {}

function OSInventory.AdminSection.build(env)
    local items = {}
    for name, item in pairs(OSItems) do items[#items + 1] = { value = name, label = item.label .. ' (' .. name .. ')' } end
    table.sort(items, function(a, b) return a.label < b.label end)
    local destino = { id = 'destino', label = 'Jugador o personaje (ID, alias o char:ID)', type = 'text', max = 64 }
    local objeto = { id = 'objeto', label = 'Objeto', type = 'select', options = items }
    local cantidad = { id = 'cantidad', label = 'Cantidad', type = 'number', integer = true, min = 1, max = 1000, default = 1 }
    local function call(source, operation, target, name, count, confirmation)
        local service = env.service()
        if not service then return false, 'Inventario no disponible.' end
        return service.admin(source, operation, target, name, count, confirmation)
    end
    local function changed(ok, result, message)
        if not ok then return { ok = false, message = tostring(result) } end
        env.invalidate()
        return { ok = true, message = message }
    end
    return {
        id = 'objetos', label = 'Objetos e inventario', order = 50,
        actions = {
            { id = 'dar', label = 'Dar objeto', ace = 'osinventory.admin', fields = { destino, objeto, cantidad },
              handler = function(source, values)
                  local ok, result = call(source, 'giveitem', values.destino, values.objeto, values.cantidad)
                  return changed(ok, result, ('Entregado %s x%d a %s.'):format(OSItems[values.objeto].label, values.cantidad, values.destino))
              end },
            { id = 'quitar', label = 'Quitar objeto', ace = 'osinventory.admin', fields = { destino, objeto, cantidad },
              handler = function(source, values)
                  local ok, result = call(source, 'removeitem', values.destino, values.objeto, values.cantidad)
                  return changed(ok, result, ('Retirado %s x%d de %s.'):format(OSItems[values.objeto].label, values.cantidad, values.destino))
              end },
            { id = 'ver', label = 'Ver inventario', ace = 'osinventory.admin', fields = { destino },
              description = 'Huecos, cantidades y peso del personaje.',
              handler = function(source, values)
                  local ok, inventory = call(source, 'inspectinventory', values.destino)
                  if not ok then return { ok = false, message = tostring(inventory) } end
                  local rows, grams = {}, 0
                  for slot, entry in pairs(inventory.slots or {}) do
                      local item = OSItems[entry.name]
                      local weight = item and item.weight * entry.count or 0
                      grams = grams + math.floor(weight * 1000 + 0.5)
                      rows[#rows + 1] = { tonumber(slot), item and item.label or entry.name, entry.name, entry.count, ('%.2f kg'):format(weight) }
                  end
                  table.sort(rows, function(a, b) return a[1] < b[1] end)
                  local message = inventory.id and ('%s: %d huecos ocupados, %.2f kg.'):format(values.destino, #rows, grams / 1000)
                      or ('%s no tiene inventario todavia.'):format(values.destino)
                  return { ok = true, message = message, columns = { 'Hueco', 'Objeto', 'ID', 'Cantidad', 'Peso' }, rows = rows }
              end },
            { id = 'vaciar', label = 'Vaciar inventario', ace = 'osinventory.admin', confirm = true, fields = { destino },
              description = 'Borra todos los objetos del personaje. No se puede deshacer.',
              handler = function(source, values)
                  -- El panel ya pidio confirmacion: se completa el doble paso de /clearinventory.
                  call(source, 'clearinventory', values.destino)
                  local ok, result = call(source, 'clearinventory', values.destino, nil, nil, 'CONFIRMAR')
                  return changed(ok, result, ('Inventario de %s vaciado.'):format(values.destino))
              end },
            { id = 'catalogo', label = 'Catalogo de objetos', ace = 'osinventory.admin',
              handler = function()
                  local rows = {}
                  for name, item in pairs(OSItems) do
                      rows[#rows + 1] = { name, item.label, ('%.2f kg'):format(item.weight), item.stack, item.usable and 'Si' or 'No', item.transferable and 'Si' or 'No' }
                  end
                  table.sort(rows, function(a, b) return a[1] < b[1] end)
                  return { ok = true, message = ('%d objetos.'):format(#rows), columns = { 'ID', 'Nombre', 'Peso', 'Pila', 'Usable', 'Transferible' }, rows = rows }
              end }
        }
    }
end

function OSInventory.AdminSection.publish(env)
    local state = GetResourceState('os_admin')
    if state ~= 'started' and state ~= 'starting' then return end
    local ok, err = pcall(function() return exports.os_admin:RegisterSection(OSInventory.AdminSection.build(env)) end)
    if not ok then print('[os_inventory] No se pudo registrar la seccion de administracion: ' .. tostring(err)) end
end
