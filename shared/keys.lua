-- Llaves como objetos. Propiedades y negocios: llave; vehiculos: llave-tarjeta. Cada una lleva en su metadata a que
-- bien abre (kind + target) y la version de la cerradura: si el titular cambia la cerradura, las copias anteriores
-- dejan de servir. Las crea os_devtools (titular al asignar el bien, copias con /darllave...).
OSKeys = { Items = { llave = true, llave_vehiculo = true } }
local schema = { label = 128, reference = 96, serial = 64, kind = 16, target = 16, version = 16, plate = 16 }
OSItems.llave = { label = 'Llave', weight = 0.02, stack = 1, usable = false, transferable = true,
    description = 'Llave de una propiedad o un negocio. Quien la lleva puede abrir y cerrar sus puertas.',
    category = 'llave', icon = 'key', metadataAllowed = true, unique = true, metadataSchema = schema }
OSItems.llave_vehiculo = { label = 'Llave-tarjeta de vehiculo', weight = 0.02, stack = 1, usable = false, transferable = true,
    description = 'Tarjeta de un vehiculo: pasala por el lector para abrirlo, cerrarlo o arrancarlo.',
    category = 'llave', icon = 'keycard', metadataAllowed = true, unique = true, metadataSchema = schema }

-- Metadata de una llave (cadenas, como exige el inventario).
function OSKeys.meta(kind, target, version, label, plate)
    return { kind = tostring(kind), target = tostring(target), version = tostring(version or 1), label = label, plate = plate }
end
