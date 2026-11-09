OSInventory=OSInventory or {}
OSInventory.Config={
    Version='0.1.0', Slots=30, MaxWeight=30, MaxSlots=120, MaxWeightGrams=1000000,
    MaxInventories=1000, MaxFileBytes=8*1024*1024, MaxDrops=256, MaxReceipts=4096, MaxAudit=512,
    MaxMutation=1000000, TransferDistance=3, PickupDistance=3, DropViewDistance=25, MaxViewedDrops=48,
    SessionSeconds=90, RequestsPerWindow=30, WindowSeconds=10,
    -- Seleccion explicita: no cambia a standalone si el proveedor esta detenido.
    Identity={Provider='os_devtools',Resource='os_devtools'},
    -- Recursos de servidor autorizados por operacion e item.
    -- os_security: solo actua si su convar ossecurity_items=os_inventory; lee, cobra/devuelve materiales
    -- de instalacion, entrega/migra sus objetos y abre tablets o la instalacion CCTV con "Usar".
    ResourceAccess={
        os_security={read=true,
            writeItems={g6_client_tablet=true,g6_operations_tablet=true,os_cctv_kit=true,os_alarm_kit=true,os_lock_kit=true,
                os_tracker_kit=true,os_drill=true,os_screwdriver=true,os_battery=true,g6_alarm_tag=true},
            useItems={g6_client_tablet=true,g6_operations_tablet=true,os_cctv_kit=true,os_alarm_kit=true,g6_alarm_tag=true}}
    },
    DropModel='prop_cs_cardbox_01'
}
