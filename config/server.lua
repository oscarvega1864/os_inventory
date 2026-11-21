OSInventory=OSInventory or {}
OSInventory.Config={
    Version='0.2.0', Slots=30, MaxWeight=30, MaxSlots=120, MaxWeightGrams=1000000,
    MaxInventories=1000, MaxFileBytes=8*1024*1024, MaxDrops=256, ClearDropsRadius=50, MaxReceipts=4096, ReceiptDays=30, -- recibos de operaciones idempotentes: se retiran los de mas de ReceiptDays dias
    MaxAudit=512,
    MaxMutation=1000000, TransferDistance=3, PickupDistance=3, DropViewDistance=25, MaxViewedDrops=48,
    SessionSeconds=90, RequestsPerWindow=30, WindowSeconds=10,
    -- Seleccion explicita: no cambia a standalone si el proveedor esta detenido.
    Identity={Provider='os_devtools',Resource='os_devtools'},
    -- Recursos de servidor autorizados por operacion e item.
    -- os_security: solo actua si su convar ossecurity_items=os_inventory; lee, cobra/devuelve materiales
    -- de instalacion, entrega/migra sus objetos y abre tablets o la instalacion CCTV con "Usar".
    ResourceAccess={
        os_security={read=true,
            writeItems={g6_client_tablet=true,g6_operations_tablet=true,os_cctv_kit=true,os_cctv_kit_mini=true,os_cctv_kit_dome=true,os_alarm_kit=true,os_alarm_kit_panel=true,os_lock_kit=true,os_lock_kit_high=true,os_car_lock_kit=true,os_car_alarm_kit=true,os_lockpick=true,
                os_tracker_kit=true,os_drill=true,os_screwdriver=true,os_battery=true,g6_alarm_tag=true,
                -- Control de acceso: el arco detector (colocar/recoger) y la herramienta que se retiene en un cacheo.
                os_metal_detector=true,herramienta=true,os_bodycam=true},
            useItems={g6_client_tablet=true,g6_operations_tablet=true,os_cctv_kit=true,os_cctv_kit_mini=true,os_cctv_kit_dome=true,os_alarm_kit=true,os_alarm_kit_panel=true,os_lock_kit=true,os_lock_kit_high=true,os_car_lock_kit=true,os_car_alarm_kit=true,os_lockpick=true,g6_alarm_tag=true,
                os_metal_detector=true,os_bodycam=true}},
        -- Oxide Banking a traves de o-link: entrega, retira y usa la tarjeta bancaria.
        ['o-link']={read=true,writeItems={bank_card=true},useItems={bank_card=true}},
        -- os_devtools: crea las llaves de propiedades, negocios y vehiculos y comprueba quien las lleva.
        os_devtools={read=true,writeItems={llave=true,llave_vehiculo=true}},
        -- LegacyFuel: comprobar que se lleva la tarjeta bancaria para pagar con tarjeta en el surtidor.
        LegacyFuel={read=true},
        -- os_life: el medico gasta un botiquin al reanimar. os_police: comprobar esposas.
        os_life={read=true,writeItems={botiquin=true}},
        os_police={read=true}
    },
    DropModel='prop_cs_cardbox_01',
    HotbarSlots=6 -- primeras casillas = accesos rapidos (teclas 1-6)
}

-- os_security: el cacheo puede retener armas y municion (y devolverlas desde la custodia).
if OSWeapons then
    local write=OSInventory.Config.ResourceAccess.os_security.writeItems
    for name in pairs(OSWeapons.Weapons) do write[name]=true end
    for name in pairs(OSWeapons.Ammo) do write[name]=true end
end
