OSInventory=OSInventory or {}
OSInventory.ClientConfig={Key='I',RpcMilliseconds=8000,DropPollMilliseconds=3000,UiTimeoutMilliseconds=12000,
    -- Accesos rapidos: teclas 1-6 usan el objeto de las 6 primeras casillas. Las teclas 1-6 del juego (elegir arma
    -- por tipo) se bloquean para que no hagan las dos cosas; la rueda de armas (Tab) sigue funcionando.
    HotbarSlots=6,BlockWeaponKeys=true,
    -- Camara al abrir: el personaje queda a la izquierda de la pantalla (no en vehiculo).
    Camera=true,
    -- Armas: solo se pueden llevar las del inventario. Cualquier otra (vMenu, recogidas del suelo...) se retira.
    StrictWeapons=true}
