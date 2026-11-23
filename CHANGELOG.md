# Changelog

## 0.2.1 — Localizador usable y migración de armas sin atascos

- **Migración de armas antiguas sin atascos**: entran las armas que caben por peso (y su munición, hasta 500 balas por
  arma); lo que no cabe se descarta y el aviso sale una sola vez con el resumen, en vez de repetirse en cada conexión.

## 0.2.0 — Inventario a pantalla completa, accesos rápidos y armas como objetos

- **Seguimiento de objetos** con identidad propia (armas, llaves, tarjetas, herramientas): cada movimiento se envía a
  la web del panel (vía os_admin) para buscarlos por ID o número de serie y ver dónde están y quién los movió.
- Objetos de EMS y policía: botiquín, venda (se consume y cura) y esposas. Comer y beber avisa a os_hud
  (`os_inventory:consumed`). El cacheo de os_security puede retener armas y munición.
- **Armas como objetos** (`shared/weapons.lua`): 55 armas (cuerpo a cuerpo, pistolas, subfusiles, escopetas, fusiles,
  ametralladoras, francotirador, arrojadizas y otras). Cada arma de fuego es un objeto único con **número de serie**
  correlativo (1, 2, 3...) que pone el servidor. La ficha del objeto muestra "Nº de serie" y ya no el identificador interno. "Usar" (o su acceso rápido) la saca o la guarda.
- **Munición en cajas por tipo** (pistola, subfusil, escopeta, fusil, ametralladora, francotirador, bengalas): cada
  unidad es una bala. Al sacar el arma lleva toda la munición de su tipo; lo disparado se descuenta en el servidor (el
  cliente solo puede gastar, nunca sumar). Las arrojadizas son su propia munición.
- Si el arma deja de estar en el inventario (dada, tirada) se quita del personaje. Con `StrictWeapons` (activo) se retira
  cualquier arma que no venga del inventario (vMenu, recogidas del suelo...).
- Las armas guardadas por os_devtools (sistema anterior) se pasan solas al inventario la primera vez que entra cada
  personaje, con su munición; si no caben, no se pasa nada y se avisa.
- **Ammu-Nation** (`config/shops.lua`): 9 tiendas con blip; junto al mostrador, E abre el catálogo (pistolas, escopeta
  de corredera, taser, cuerpo a cuerpo y munición). Se paga en efectivo o banco (os_devtools `ChargeCharacter`); si no
  cabe en el inventario, se devuelve el dinero. Las armas pesadas solo por F10.
- **Llaves como objetos** (`shared/keys.lua`): `llave` (propiedades y negocios) y `llave_vehiculo` (llave-tarjeta), con el
  bien que abren y la versión de su cerradura. Exports `HasKey`, `ListKeys` y `PlayerHasItem` para recursos con lectura.
- **Lector de tarjetas** (`exports.os_inventory:CardSwipe({card, title, detail})`): pantalla en la que hay que arrastrar la
  tarjeta (bancaria, chapa de alarma o llave-tarjeta) hasta el lector. La usan Ammu-Nation, la tienda G6, el surtidor,
  el cajero (o-link), la chapa de alarma y los vehículos. Pagar con banco en Ammu-Nation exige la tarjeta bancaria.
- Export `GetCarriedWeapons(src)` para recursos con lectura (arco detector y cacheo de os_security).
- Nuevo diseño a pantalla completa: al abrir, la cámara deja al personaje a la izquierda con sus **accesorios**
  (máscara, sombrero, gafas, pendientes, reloj y pulsera), que se quitan o se vuelven a poner con un clic.
- A la derecha: zona **"Tirar al suelo"** (arrastra un objeto encima), rejilla de 6 columnas con una fila de casillas
  bloqueadas, **menú de clic derecho** (usar, dividir, tirar) y **"Ceder"** con los jugadores cercanos por nombre e ID:
  clic en el nombre o arrastra el objeto encima. Ya no hace falta escribir el ID.
- **Accesos rápidos**: las 6 primeras casillas se usan con las teclas **1-6** sin abrir el inventario, con las mismas
  reglas que "Usar" (lo valida el servidor). Las teclas 1-6 del juego para elegir arma quedan bloqueadas
  (`BlockWeaponKeys`); la rueda de armas sigue igual. El contenido se avisa a otros recursos (`os_inventory:hotbar`)
  y os_hud lo muestra abajo en el centro.

## 0.1.1

- Los recibos de operaciones (que evitan entregar dos veces lo mismo) caducan a los 30 días y se limpian
  solos cuando el registro se llena, sin perder la protección de las operaciones recientes.
- La actualización del inventario abierto se agrupa (250 ms) en vez de repetirse en cada cambio.

- Sección **Objetos e inventario** para el panel y la consola de `os_admin` (opcional): dar y quitar objetos del catálogo, ver el inventario de un personaje (huecos, cantidades y peso), vaciarlo con confirmación y consultar el catálogo. Usa la misma ruta administrativa que `/giveitem`, `/removeitem`, `/inspectinventory` y `/clearinventory`.

## 0.1.0 — Inventario standalone

- Modelo separado de economía y activos: inventarios con ID, propietario estable, capacidad en gramos, slots y revisiones; catálogo configurable con los nueve objetos solicitados.
- Proveedores explícitos de identidad: Devtools 0.1.3 o standalone por license validada. Sin dependencia obligatoria ni fallback silencioso. Cambio de personaje invalida sesiones; no se usan alias ni server IDs como propietarios permanentes.
- Añadir, retirar, consultar, mover, apilar, intercambiar, dividir, consumir agua/comida, entregar, soltar y recoger. Objetos individuales/metadatos tienen identidad de servidor y no se apilan.
- Entregas y recogidas confirmadas mediante una sola escritura del estado completo, con validación de distancia, bucket, salud, transferencia, cantidad y capacidad. Objetos en suelo persistentes y cajas locales cosméticas gestionadas por proximidad.
- Sesiones ligadas al personaje, secuencias, respuestas deduplicadas, revisión e ID de pila esperados, exclusión de transacciones y límites de frecuencia. Retirada de los eventos pretest sin ese contrato.
- NUI original en web/: F2 configurable, selección y detalle, pesos/capacidad, división, arrastre, entrega y recogida. ESC, timeout, cambio de personaje y parada liberan foco; no toma foco sobre otra NUI.
- Mantiene ACE y autorización OSCAR osinventory.admin; añade clearinventory con confirmación de misma revisión en 30 s y auditoría. /daritem admite varias pilas en una sola transacción.
- Exports solo servidor con lista explícita de recursos/operaciones/items, callbacks de uso no consumibles e IDs de operación persistentes para reintentos de altas/retiradas.
- Migración v1 → v2 conserva el origen y un respaldo exacto antes de activar snapshots alternos; resuelve aliases heredados sin mezclar propietarios. Corrupción, identidad ambigua, datos incompatibles y escritura fallida bloquean sin vaciar inventarios.
- Se conserva la corrección de SaveResourceFile: longitud en bytes, resultado true/1 y lectura de verificación. No se toca inventario real durante las pruebas.
- 38 casos Lua 5.4 pasan con códec de desarrollo y dkjson local; 8 escenarios de Chromium con transporte simulado. Validación de rutas del manifiesto y sintaxis. Pendiente ejecutar FiveM/CEF/OneSync, props y escritura mediante junction.
- Las tablets G6 y CCTV siguen siendo únicamente objetos; no se desarrolla su lógica ni se modifica OS Security. Sin push.

## 0.1.0-pretest.1 — Adaptador administrativo OSCAR

- Se verificó el contrato osinventory.admin antes de integrar el broker opcional.
- Consola y ACE true/1 compatibles; solo true literal del proveedor delegado.
- Revocaciones, proveedor detenido, export ausente y retorno nativo 0 deniegan acceso.
- Nueve pruebas iniciales del hotfix con comandos pretest y dos códecs de desarrollo. Las funcionalidades generales del inventario permanecían pendientes en aquella entrega.
