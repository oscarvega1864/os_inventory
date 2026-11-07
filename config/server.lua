OSInventory=OSInventory or {}
OSInventory.Config={
    Version='0.1.0', Slots=30, MaxWeight=30, MaxSlots=120, MaxWeightGrams=1000000,
    MaxInventories=1000, MaxFileBytes=8*1024*1024, MaxDrops=256, MaxReceipts=4096, MaxAudit=512,
    MaxMutation=1000000, TransferDistance=3, PickupDistance=3, DropViewDistance=25, MaxViewedDrops=48,
    SessionSeconds=90, RequestsPerWindow=30, WindowSeconds=10,
    -- Seleccion explicita: no cambia a standalone si el proveedor esta detenido.
    Identity={Provider='os_devtools',Resource='os_devtools'},
    -- Recursos de servidor autorizados por operacion e item. Vacio por defecto.
    ResourceAccess={},
    DropModel='prop_cs_cardbox_01'
}
