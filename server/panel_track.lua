-- Seguimiento de objetos con identidad propia (instanceId 'ounit_N': armas con n. de serie, llaves, tarjetas,
-- herramientas...) para la web del panel. Logica pura: compara el estado antes y despues de cada cambio.
OSInventory = OSInventory or {}
OSInventory.PanelTrack = {}
local M = OSInventory.PanelTrack

local function describe(entry)
    local meta = type(entry.metadata) == 'table' and entry.metadata or {}
    local item = OSItems and OSItems[entry.name]
    local label = type(meta.label) == 'string' and meta.label ~= '' and meta.label or (item and item.label) or entry.name
    return entry.name, label, type(meta.serial) == 'string' and meta.serial or (meta.serial and tostring(meta.serial)) or nil
end

-- Ubicacion de cada unidad en un estado. Solo recorre los inventarios indicados (o todos si only es nil).
function M.units(state, only)
    local out = {}
    for owner, inv in pairs(state.inventories or {}) do
        if not only or only[owner] then
            for slot, entry in pairs(inv.slots or {}) do
                if entry.instanceId then
                    local name, label, serial = describe(entry)
                    out[entry.instanceId] = { unit = entry.instanceId, name = name, label = label, serial = serial, kind = 'inventory', place = owner, slot = tonumber(slot) }
                end
            end
        end
    end
    for key, drop in pairs(state.drops or {}) do
        local entry = drop.entry
        if entry and entry.instanceId then
            local name, label, serial = describe(entry)
            local p = drop.position or {}
            out[entry.instanceId] = { unit = entry.instanceId, name = name, label = label, serial = serial, kind = 'drop', place = key, x = p.x, y = p.y, z = p.z }
        end
    end
    return out
end

-- Movimientos entre dos estados consecutivos. event = { op, actor, target } del cambio.
function M.diff(old, new, event)
    local touched = {}
    for owner, inv in pairs(new.inventories or {}) do
        local before = old.inventories and old.inventories[owner]
        if not before or before.revision ~= inv.revision then touched[owner] = true end
    end
    for owner in pairs(old.inventories or {}) do if not (new.inventories or {})[owner] then touched[owner] = true end end
    local a, b = M.units(old, touched), M.units(new, touched)
    -- Los objetos del suelo siempre se comparan (son pocos).
    local moves = {}
    local actor = tostring(event and event.actor or 'sistema'):sub(1, 96)
    local op = tostring(event and event.op or 'cambio'):sub(1, 48)
    for unit, now in pairs(b) do
        local was = a[unit]
        if not was or was.kind ~= now.kind or was.place ~= now.place or was.slot ~= now.slot then
            now.op, now.actor = op, actor; moves[#moves + 1] = now
        end
    end
    for unit, was in pairs(a) do
        if not b[unit] then
            -- Puede haber pasado a un inventario no tocado? No: cualquier destino cambia su revision.
            moves[#moves + 1] = { unit = unit, name = was.name, label = was.label, serial = was.serial, kind = 'gone', place = '', op = op, actor = actor }
        end
    end
    table.sort(moves, function(x, y) return x.unit < y.unit end)
    return moves
end
