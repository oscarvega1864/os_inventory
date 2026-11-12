OSItems={
 agua={label='Agua',weight=0.5,stack=20,usable=true,transferable=true},
 comida={label='Comida',weight=0.4,stack=20,usable=true,transferable=true},
 telefono={label='Telefono',weight=0.3,stack=1,usable=false,transferable=true},
 herramienta={label='Herramienta',weight=1.5,stack=5,usable=false,transferable=true},
 tarjeta_acceso={label='Tarjeta de acceso',weight=0.05,stack=1,usable=false,transferable=true},
 g6_client_tablet={label='G6 Client Tablet',weight=0.8,stack=1,usable=false,transferable=true},
 g6_operations_tablet={label='G6 Operations Tablet',weight=0.8,stack=1,usable=false,transferable=false},
 security_tablet={label='Tablet de seguridad',weight=0.8,stack=1,usable=false,transferable=true},
 os_cctv_kit={label='Kit de CCTV (exterior)',weight=3.0,stack=10,usable=false,transferable=true},
 os_cctv_kit_mini={label='Kit de CCTV (mini interior)',weight=1.0,stack=10,usable=false,transferable=true},
 os_cctv_kit_dome={label='Kit de CCTV (domo 360)',weight=2.0,stack=10,usable=false,transferable=true},
 -- Materiales y herramientas de OS Security (mismos IDs que su catalogo).
 os_alarm_kit={label='Kit de alarma (teclado)',weight=3.0,stack=5,usable=false,transferable=true},
 os_alarm_kit_panel={label='Kit de alarma (panel lector)',weight=3.0,stack=5,usable=false,transferable=true},
 os_lock_kit={label='Bombin de seguridad',weight=1.0,stack=5,usable=false,transferable=true},
 os_lock_kit_high={label='Bombin de alta seguridad',weight=1.0,stack=5,usable=false,transferable=true},
 os_car_lock_kit={label='Cierre centralizado (vehiculo)',weight=2.0,stack=5,usable=false,transferable=true},
 os_car_alarm_kit={label='Alarma de vehiculo',weight=2.0,stack=5,usable=false,transferable=true},
 os_tracker_kit={label='Kit de localizador',weight=1.0,stack=5,usable=false,transferable=true},
 os_lockpick={label='Ganzua',weight=0.1,stack=10,usable=false,transferable=true},
 os_drill={label='Taladro',weight=2.0,stack=1,usable=false,transferable=true},
 os_screwdriver={label='Destornillador',weight=1.0,stack=1,usable=false,transferable=true},
 os_battery={label='Bateria',weight=1.0,stack=20,usable=false,transferable=true},
 g6_alarm_tag={label='Chapa de alarma',weight=0.02,stack=10,usable=true,transferable=true},
 -- Oxide Banking (via o-link): el numero de la tarjeta lo guarda o-link; aqui solo va la referencia.
 bank_card={label='Tarjeta bancaria',weight=0.02,stack=1,usable=false,transferable=true}
}
local details={
 agua={'Una botella de agua para consumir.','consumible','water'},
 comida={'Una racion de comida para consumir.','consumible','food'},
 telefono={'Telefono personal. Sin aplicacion funcional en esta version.','personal','phone'},
 herramienta={'Herramienta de trabajo. Uso especializado mediante un adaptador autorizado.','herramienta','tool'},
 tarjeta_acceso={'Tarjeta individual. No concede permisos por si misma.','acceso','card'},
 g6_client_tablet={'Tablet G6 Client. Solo objeto; requiere integracion de uso.','seguridad','tablet'},
 g6_operations_tablet={'Tablet G6 Operations. No concede empleo ni privilegios administrativos.','seguridad','tablet'},
 security_tablet={'Tablet de seguridad generica; sin aplicacion integrada.','seguridad','tablet'},
 os_cctv_kit={'Camara exterior con brazo de pared. Se instala desde la tablet G6 Operations.','seguridad','box'},
 os_cctv_kit_mini={'Camara pequena para interiores. Se instala desde la tablet G6 Operations.','seguridad','box'},
 os_cctv_kit_dome={'Camara domo de techo con vision 360. Se instala desde la tablet G6 Operations.','seguridad','box'},
 os_alarm_kit={'Central de alarma con teclado clasico. Se instala con Usar, como el kit CCTV.','seguridad','box'},
 os_alarm_kit_panel={'Central de alarma en panel con lector. Misma funcion que el teclado; otro acabado.','seguridad','box'},
 os_lock_kit={'Bombin antibumping para la puerta de tu propiedad (nivel 2). Usar junto a la puerta abierta, con destornillador.','seguridad','box'},
 os_lock_kit_high={'Bombin de alta seguridad antirrotura y antiganzua (nivel 3). Usar junto a la puerta abierta, con destornillador.','seguridad','box'},
 os_car_lock_kit={'Cierre centralizado para tu vehiculo (matricula OS): abre y cierra con el mando (L). Usar sentado al volante, motor apagado, con destornillador.','seguridad','box'},
 os_car_alarm_kit={'Alarma de vehiculo: se arma al cerrar y salta si intentan entrar. Necesita el cierre centralizado. Usar al volante, motor apagado.','seguridad','box'},
 os_tracker_kit={'Material de localizador GPS. Sin instalacion funcional en esta version.','seguridad','box'},
 os_lockpick={'Para forzar puertas de propiedades y vehiculos cerrados. Cuanto mejor el bombin, mas dificil. Puede romperse.','herramienta','tool'},
 os_drill={'Herramienta de instalacion de equipos de seguridad.','herramienta','tool'},
 os_screwdriver={'Herramienta de instalacion de equipos de seguridad.','herramienta','tool'},
 os_battery={'Material de alimentacion para instalaciones de seguridad.','seguridad','box'},
 g6_alarm_tag={'Chapa de proximidad de alarma. En blanco se programa desde la tablet G6 Client; programada, Usar junto al teclado arma o desarma.','seguridad','card'},
 bank_card={'Tarjeta de debito de tu banco. Usala junto a un cajero automatico.','personal','card'}
}
for name,item in pairs(OSItems) do
 local detail=details[name]
 item.description,item.category,item.icon=detail[1],detail[2],detail[3]
 item.metadataAllowed=name~='agua' and name~='comida'
 item.unique=item.stack==1
 item.metadataSchema={label=128,reference=96,serial=64}
 item.builtinUse=(name=='agua' or name=='comida') and 'consume' or nil
end
