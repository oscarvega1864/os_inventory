# os_inventory 0.1.0-pretest.1
Inventario standalone ligero FiveM GTA V Legacy. **No probado todavia en FXServer real.**

Hotfix de autorización: mantiene ACE y añade el adaptador opcional de OSCAR,
exclusivamente para `osinventory.admin`, tras verificar el contrato existente.
No completa las funcionalidades pendientes de esta versión pretest.

## Incluye
- `/inventario`, F2, NUI con 30 slots, capacidad 30 kg y traslado/apilado/division (Mayus + clic al destino).
- `/giveitem <id|alias> <objeto> <cantidad>` y `/removeitem ...` con ACE `osinventory.admin`.
- `/inspectinventory <id|alias>`, `/daritem <idJugador> <objeto> <cantidad>` a menos de 3 metros.
- Personajes desde os_devtools (si esta activo), o `license:` standalone si no esta.
- JSON persistente por personaje. **No incluye data JSON**; proteger los existentes.

## No implementado en esta entrega
Suelte al suelo, recogida, uso de items, menu de envio, inventario de coches o tiendas. Los items G6 son objetos de inventario, NO activan tablets todavia. El contrato de seguridad de `os_security` no esta integrado.

## Activacion
Crear junction o copiar carpeta completa a `resources/[local]/os_inventory`.
En server.cfg, tras `ensure os_devtools`, incluir:
```
add_ace group.admin osinventory.admin allow
ensure os_inventory
```
Alternativa sin añadir cada empleado a server.cfg: autenticarlo en el menú oficial
de txAdmin 8.1.2 y, desde Live Console, ejecutar
`osautorizar <id> inventory_admin 10 CONFIRMAR`. Devtools debe estar iniciado antes
de observar esa autenticación. Ser administrador txAdmin no concede acceso por sí
solo. `osrevocar <id>` revoca la delegación; las actualizaciones de personal,
desconexión y reinicio también la invalidan. Los ACE independientes permanecen.

El adaptador puede desactivarse con `OSInventoryAuthorization.Resource=false` en
`config/authorization.lua`. No hay dependencia obligatoria de Devtools para ACE.
Si Devtools está iniciado sin el export nuevo, los errores deniegan la delegación.
Los permisos temporales caducan, con un máximo efectivo de 15 minutos desde la
autenticación observada. Para la política completa, consultar
`../os_devtools/docs/authorization.md`.

## Cuidado con cambios de identidad
Si se venia usando otro inventario, NO se importan sus objetos automaticamente. No sobreescribir datos ni dar acceso a una cuenta distinta sin migracion auditada.

## Persistencia
`inventory_data.json` se crea en primera ejecucion y se conserva en futuras actualizaciones. Rehacer copia de seguridad antes de cambiar version. Solo apto para servidor de desarrollo.

## Pruebas manuales
1. Conectar dos jugadores con identidad valida.
2. `/giveitem 1 agua 5`, F2 para comprobar cinco unidades.
3. Mover 2 unidades con Mayus + clic entre slots.
4. `/daritem 2 agua 1` cerca del jugador 2.
5. Reiniciar y comprobar que la cantidad persiste.
6. Probar acceso denegado a `/giveitem` desde cuenta normal.
7. Probar `inventory_admin`, revocarlo y comprobar denegación en los tres comandos
   administrativos. Un perfil `observer`/`finance` de Devtools no permite dar objetos.

## Pruebas del hotfix

`npm.cmd test` y `node tests/run.cjs --codec E:\Fivem-DEV\server\citizen\scripting\lua\json.lua`
ejecutan 9 pruebas Lua 5.4 con Wasmoon y APIs/archivos simulados. Cubren ACE,
delegación, revocación, export ausente, normalización de BOOL y los tres comandos
reales. No equivalen a una ejecución en FiveM. No se han validado integralmente
la persistencia, las APIs de objetos ni las demás funciones de la fase 0.1.0.
