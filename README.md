# OS Inventory 0.1.0

Inventario standalone para FiveM Legacy: Lua en servidor/cliente y NUI local sin frameworks, CDN ni dependencias obligatorias de otros recursos. No gestiona dinero, empleos ni bienes. Incluye inventario personal, pilas, metadatos individuales, entrega próxima, uso, objetos en suelo y persistencia JSON verificada.

## Configuración e identidad

`config/server.lua` configura 30 slots / 30 kg por defecto, distancia de entrega y recogida (3 m), objetos visibles en suelo, límites de archivo, frecuencia y sesiones. La capacidad queda registrada por inventario; los valores nuevos se aplican a inventarios nuevos. No se reduce automáticamente la capacidad de inventarios existentes, porque podría dejar objetos fuera de sus límites. El catálogo `shared/items.lua` define peso, descripción, categoría, icono, apilamiento, transferencia y metadatos permitidos.

El proveedor de identidad se elige explícitamente:

```lua
-- Entorno OSCAR; requiere os_devtools 0.1.3 iniciado antes.
Identity={Provider='os_devtools', Resource='os_devtools'}
-- Servidor sin Devtools; una cuenta license validada = un inventario.
Identity={Provider='standalone', Resource=false}
```

El valor predeterminado de este proyecto es `os_devtools`. Utiliza `GetActiveCharacter` / `ResolveCharacter`, con ID inmutable `oschar_...`; no utiliza server ID ni alias como propietario permanente. Si el proveedor se detiene, falta o está apareciendo el personaje, se deniega el acceso. **No se cambia silenciosamente a standalone.** El cambio de personaje cierra sesiones; cada acción vuelve a consultar la identidad efectiva. Devtools no depende de Inventory.

En standalone se usa `standalone:license:…`, sin crear personajes ni copiar economía. Ese proveedor no distingue varios personajes de una misma cuenta. Cambiar de proveedor con datos existentes exige una migración administrativa específica; los snapshots identifican el proveedor y bloquean mezclas. No cambiarlo para eludir un error del adaptador.

## Uso

Abrir/cerrar con **F2** o `/inventario`. La tecla se puede reasignar desde FiveM; su valor inicial está en `config/client.lua`. Se abre solo después de recibir autorización y datos reales del servidor, sin adquirir foco encima de otra NUI. ESC, cambio de personaje, parada, desconexión, muerte, error de comunicación o falta de heartbeat liberan el foco.

- Seleccionar un slot muestra descripción, cantidad, peso y metadatos.
- Ajustar la cantidad y arrastrar a otro slot o pulsar un slot vacío mueve esa cantidad. Las pilas compatibles se apilan; pilas completas incompatibles se intercambian.
- **Dividir pila** mueve la cantidad indicada al primer slot vacío; debe ser inferior al total.
- **Usar uno** consume una unidad real de agua/comida. No simula sistemas de sed/hambre inexistentes.
- Para entregar, indicar el server ID de un jugador próximo y la cantidad. Servidor comprueba existencia, mismo bucket, distancia, capacidad, cantidad y transferibilidad.
- **Dejar en el suelo** persiste el objeto. Los jugadores próximos reciben una caja local sin red, como representación del registro. En la sección **En el suelo**, acercarse y pulsar **Recoger**. Destruir o crear una entidad local no concede objetos: manda el registro del servidor.

No hay objetos de muestra en ejecución real. `telefono`, herramientas, tarjetas, tablets G6, `security_tablet` y `os_cctv_kit` son definiciones; su uso especializado no está implementado. `g6_operations_tablet` no es transferible ni se puede soltar y no concede empleo ni privilegios. Los objetos individuales y los que tienen metadatos usan `instanceId` asignado por servidor y límite de pila 1. `serial`, `reference` y `label` son datos descriptivos; la identidad de seguridad del objeto es `instanceId`.

## Comandos

| Comando | Acceso |
| --- | --- |
| `/inventario` | Personal; tecla F2 configurable. |
| `/daritem <idJugador> <item> <cantidad>` | Personal; admite varias pilas, conserva identidades/metadatos y confirma toda la entrega en una sola transacción. |
| `/giveitem <idJugador\|personaje> <item> <cantidad>` | `osinventory.admin`; crea únicamente objetos definidos. |
| `/removeitem <idJugador\|personaje> <item> <cantidad>` | `osinventory.admin`; rechaza cantidades no disponibles. |
| `/inspectinventory <idJugador\|personaje>` | `osinventory.admin`; consulta sin abrir la NUI de otro jugador. |
| `/clearinventory <idJugador\|personaje>` | `osinventory.admin`; prepara confirmación de ese inventario/revisión. |
| `/clearinventory <mismoDestino> CONFIRMAR` | Misma identidad administrativa, permiso vigente y revisión, en 30 s; registra vaciado en auditoría. |

Con Devtools, destino admite jugador conectado, alias existente, `alias:ALIAS` o `char:oschar_0000000001`, también personajes desconectados. Un número desnudo significa jugador conectado. En standalone los comandos administrativos usan un jugador conectado.

La consola está autorizada y ACE acepta únicamente `true`/`1`. Se conserva el adaptador administrativo OSCAR opcional, limitado a `osinventory.admin` y con permiso consultado en cada acción. Puede desactivarse en `config/authorization.lua` con `Resource=false`. Un perfil `observer`, `finance` o un cargo G6 no administra inventarios. Con txAdmin 8.1.2, autenticarse normalmente y asignar explícitamente desde Live Console `osautorizar 2 inventory_admin 10 CONFIRMAR`; `/ospermisos` y `osrevocar 2` permiten revisar/revocar. Estar en Admins por sí solo no concede este permiso. Política en [autorización OSCAR](../os_devtools/docs/authorization.md).

## Arquitectura

| Archivo | Responsabilidad |
| --- | --- |
| `shared/items.lua` | Catálogo sin lógica de cámaras/tablets. |
| `config/server.lua`, `config/client.lua`, `config/authorization.lua` | Capacidad, identidad, políticas de recursos, tecla y permisos. |
| `server/domain.lua` | Validación y operaciones puras; peso en gramos, slots e IDs. |
| `server/identity.lua` | Proveedores explícitos y resolución de personajes, sin fallback silencioso. |
| `server/service.lua` | Transacciones, sesiones, secuencias, frecuencia, comandos y exports autorizados. |
| `server/store.lua`, `server/storage/`, `server/lib/` | Migración y journal de snapshots con verificación. |
| `server/main.lua`, `server/admin_access.lua` | Nativos, comandos, eventos, exports y adaptador administrativo. |
| `client/controller.lua`, `client/main.lua` | Peticiones, foco, timeouts, cambio de personaje y props locales próximos. |
| `web/` | NUI original, HTML/CSS/JS y símbolos SVG locales. |
| `tests/` | Modelo, persistencia, permisos, contratos nativos simulados y navegador. |

Las transferencias y recogidas modifican todas las partes en una única copia/snapshot; no hay retirada y alta en escrituras separadas. Una exclusión global sin yields evita transacciones solapadas. El servidor calcula peso, límite, catálogo, posición y propietario. La NUI no puede elegir otro inventario, declarar permisos ni inventar propiedades del objeto.

Cada sesión se liga a la conexión y al personaje real durante 90 s de inactividad. Las peticiones usan token, secuencia consecutiva, revisión del inventario e ID esperado de la pila. Se devuelve la respuesta de las últimas 8 secuencias idénticas sin repetir su efecto; una secuencia vieja o alterada se rechaza. Reiniciar invalida todas las sesiones. Los eventos tienen límite de frecuencia y solo se publica un cambio después de verificar su persistencia. El cliente envía una operación cada vez y los fallos liberan controles.

## Persistencia y migración

Antes de actualizar, respaldar externamente los datos con los recursos detenidos. La primera ejecución valida `inventory_data.json` v1, resuelve cada `osdev:alias` al ID estable de Devtools y conserva los bytes originales en `data/migration-010-source.json` antes de escribir. En standalone solo se aceptan claves heredadas `license:` válidas. Se preservan cantidades, slots, metadatos admitidos y auditoría histórica; alias sin resolver, propietarios duplicados, exceso de capacidad y metadatos incompatibles bloquean la migración sin descartar objetos. No se mezclan inventarios automáticamente.

Las revisiones v2 usan `data/inventories.a.json` y `.b.json`. Se validan estado, versión, proveedor, contadores, slots, capacidades e identidades; se comprueba serialización de ida/vuelta, longitud en bytes y lectura posterior. `SaveResourceFile` acepta resultado nativo `true` o `1`. No se modifica el origen v1 ni su antiguo backup. Una vez migrado, no volver a la versión pretest: sus archivos ya no contienen el estado nuevo.

Un error de escritura ambiguo bloquea nuevas acciones. Al reiniciar se recupera la última revisión verificada si ambos slots presentes forman una secuencia válida. Si hay corrupción o ediciones externas, se conserva todo y se bloquea: no se sustituye por un inventario vacío ni se activa silenciosamente un snapshot antiguo que resucite objetos entregados. Detener, respaldar ambos slots y solicitar revisión/recuperación desde una copia coherente. Nunca borrar datos para «arreglar» el arranque. No se garantiza fsync ante fallo de hardware ni ACID entre recursos.

Los objetos en suelo persisten, incluido bucket y metadatos. Las cajas son cosméticas y se reconstruyen cerca de cada jugador; no necesita un bucle por objeto. No hay expiración que destruya objetos. El límite de objetos en suelo rechaza nuevas sueltas sin retirar el objeto del inventario. Mantener el catálogo compatible con objetos ya guardados.

## Exports solo servidor

Sin acceso externo por defecto. Habilitar recursos exactos y objetos concretos en `config/server.lua`:

```lua
ResourceAccess={
    mi_adaptador={read=true,writeItems={herramienta=true},useItems={herramienta=true}}
}
```

Esta plantilla no activa OS Security. El recurso llamante se obtiene con `GetInvokingResource`; `nil` y recursos desconocidos se rechazan. Para Devtools el argumento es el ID estable `oschar_…`, **no el alias ni server ID**. Para standalone es la clave `standalone:license:…` previamente registrada al abrir el inventario.

```lua
local inv,reason = exports.os_inventory:GetInventory(characterId)
local count,reason = exports.os_inventory:GetItemCount(characterId, 'herramienta')
local has,reason = exports.os_inventory:HasItem(characterId, 'herramienta', 1)
local can,reason = exports.os_inventory:CanCarryItem(characterId, 'herramienta', 1, {})
local ok,reason = exports.os_inventory:AddItem(characterId, 'herramienta', 1, {reference='orden-42'}, 'orden-42:alta')
local ok,reason = exports.os_inventory:RemoveItem(characterId, 'herramienta', 1, {reference='orden-42'}, 'orden-42:retirada')
local ok = exports.os_inventory:RegisterUsableItem('herramienta', function(source, context)
    -- context={characterId, inventoryId, item={id,name,count,metadata,instanceId?}}
    -- Comprobar aqui permisos y logica propios del adaptador.
end)
```

`GetInventory` devuelve una copia completa del inventario o `nil, razón` si todavía no se registró. Las consultas de cantidad dan 0 para un personaje verificado sin objetos. Las denegaciones devuelven `false, razón`; no convertirlas en autorización usando comparaciones laxas. `HasItem` y `CanCarryItem` devuelven booleano. Add/Remove validan identidad con el proveedor y responden `booleano, razón?`. La retirada con `metadata=nil` recorre todas las pilas de ese tipo; con tabla filtra igualdad exacta de metadatos.

El `operationId` opcional, de hasta 96 bytes, es una clave persistente por recurso para reintentar Add/Remove. La misma clave y argumentos no repiten el efecto, incluso tras reiniciar; argumentos distintos se rechazan. Sin clave cada llamada representa una operación nueva. Los recibos no se eliminan automáticamente (máximo configurable 4096); al llenarse se deniegan nuevas claves hasta mantenimiento administrativo explícito.

RegisterUsableItem requiere `useItems[item]=true`, no permite sustituir consumibles incorporados y se elimina al detener el recurso registrado. El adaptador **no consume** el objeto automáticamente; el callback debe validar su propia lógica y no promete transacciones distribuidas. La repetición de la misma petición de sesión no repite el callback, pero una caída durante un efecto externo requiere la recuperación del recurso propietario. No se anuncia uso funcional de tablets ni cámaras.

## Instalación manual

No se crea junction ni se modifica `server.cfg` o txData automáticamente. Comprobar primero que el destino no existe; desde PowerShell del operador:

```powershell
Test-Path -LiteralPath 'E:\Fivem-DEV\txData\FiveMBasicServerCFXDefault_EC7A2D.base\resources\[local]\os_inventory'
# Solo si devuelve False:
New-Item -ItemType Junction -Path 'E:\Fivem-DEV\txData\FiveMBasicServerCFXDefault_EC7A2D.base\resources\[local]\os_inventory' -Target 'E:\Fivem-DEV\development\os_inventory'
```

Activación administrada por el operador:

```cfg
add_ace group.admin osinventory.admin allow
ensure spawnmanager
ensure os_devtools
ensure os_inventory
```

Con identidad standalone omitir Devtools y elegir antes ese proveedor; ACE funciona sin broker. El `add_ace` concede al grupo, no convierte a todo miembro de txAdmin en `group.admin`. Usar la sincronización explícita OSCAR cuando corresponda. Este recurso no contiene licencias, tokens ni datos reales.

## Pruebas y validación en FiveM

```powershell
npm.cmd ci --ignore-scripts --no-audit --no-fund
npm.cmd test
node tests/run.cjs --codec 'E:\Fivem-DEV\server\citizen\scripting\lua\json.lua'
npm.cmd run test:ui
```

38 casos Lua 5.4 con Wasmoon y archivos/nativos simulados; cubren los 20 requisitos obligatorios, migración, identidad, permisos efectivos, sesiones, repeticiones, exports, escritura fallida/parcial, reinicio y corrupción. Ocho escenarios adicionales en Chromium real, con transporte NUI simulado, comprueban cuadrícula, acciones, división, metadatos sin HTML, recogida, resoluciones, ESC y cierre tras error. `test:ui` usa Chrome/Edge local (o `OS_INVENTORY_BROWSER`) y guarda capturas privadas bajo `.tools/`.

Pendiente validación real en FiveM con dos jugadores de prueba, IDs de ejemplo 1 y 2:

1. Desde admin: `/giveitem 1 agua 8`, `/giveitem 1 comida 2`, `/giveitem 1 g6_client_tablet 1`. Desde jugador normal, los cuatro comandos administrativos deben denegarse; comprobar revocación del perfil mientras está conectado.
2. Abrir con F2 y `/inventario`, seleccionar agua, indicar 3 y dividir: deben quedar 5 y 3. Arrastrar/apilar y comparar peso. ESC libera el ratón. Abrir otra NUI primero y comprobar que Inventory no toma foco.
3. Aproximar al jugador 2, entregar 2 desde la NUI o `/daritem 2 agua 2`. Alejarlo/cambiar bucket y verificar rechazo. Probar receptor lleno y objeto no transferible.
4. Usar una comida: queda una menos. La tablet no abre ninguna aplicación. Soltar agua y recogerla con el otro jugador: una sola entrega, incluso con clic repetido. Confirmar caja, distancia y bucket en OneSync.
5. Desconectar con NUI abierta, reconectar con otro ID temporal y comprobar cantidades/IDs. Cambiar personaje y confirmar inventario separado y cierre de sesión anterior.
6. Reiniciar el recurso y el servidor de pruebas: cantidades, metadatos y objetos en suelo deben conservarse. No inyectar corrupción en datos reales; esas pruebas ya se realizan sobre archivos simulados.
7. `/clearinventory 1`, revisar destino y ejecutar `/clearinventory 1 CONFIRMAR` dentro de 30 s. Comprobar auditoría y que un cambio de inventario o revocación exige nueva confirmación.

No se ha realizado una ejecución controlada de estos casos dentro de FiveM. Foco CEF, creación cosmética de props, sincronización de OneSync y escritura nativa mediante junction requieren esa prueba. Las pruebas estáticas, Wasmoon y Chromium no equivalen a una ejecución real del recurso.

No incluye tiendas, economía, inventarios de vehículos/propiedades/empresas, crafting, armas, NUI de tablets, CCTV, contratos ni rondas. No se modifica OS Security ni se avanza a 0.1.1.
