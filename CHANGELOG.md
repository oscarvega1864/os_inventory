# Changelog

## 0.1.0-pretest.1 — Adaptador administrativo OSCAR

- Contrato existente `osinventory.admin` verificado en manifiesto y servidor
  antes de modificar el recurso. Se mantienen los tres comandos y sus sintaxis.
- Adaptador opcional a `os_devtools:HasOscarPermission`; conserva consola y ACE
  nativo, acepta solo `true`/`1` del native y `true` literal del proveedor.
- Un usuario normal no puede autorizarse mediante el retorno numérico `0`.
  Revocaciones, recurso detenido, errores o export ausente deniegan delegaciones.
- Perfiles de Inventory separados del resto de OSCAR. No se modifican ítems,
  identidad RP, persistencia, NUI ni los exports de objetos de la versión pretest.
- Nueve pruebas automatizadas del adaptador y de giveitem/removeitem/inspectinventory
  pasan con dos códecs de desarrollo. Pendiente validación real en FiveM.

Las funcionalidades y la revisión completa de la fase 0.1.0 permanecen pendientes;
este hotfix no afirma completar esa fase ni activa las tablets de Gruppe Sechs.
