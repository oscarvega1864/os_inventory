# os_inventory 0.1.0-pretest
Inventario standalone ligero FiveM GTA V Legacy. **No probado todavia en FXServer real.**

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
No se transfieren privilegios de txAdmin a ACE: cada administrador necesita su identifier persistente correctamente configurado en `group.admin`.

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
