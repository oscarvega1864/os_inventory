# Changelog

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
