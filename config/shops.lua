-- Tiendas del inventario (cliente y servidor). Ammu-Nation vende armas cortas, cuerpo a cuerpo, escopeta y municion;
-- las armas pesadas solo las da un administrador (F10). Precios en dolares; se paga en efectivo o con el banco.
OSInventory=OSInventory or {}
OSInventory.Shops={
    ammunation={
        label='Ammu-Nation', blip={sprite=110,color=1,scale=0.7}, distance=2.5,
        -- Mostradores de las Ammu-Nation del mapa. Si alguno no cuadra, ajustalo con /coords en el juego.
        locations={
            {x=-662.18,y=-934.96,z=21.83}, {x=810.25,y=-2157.60,z=29.62}, {x=1693.44,y=3760.16,z=34.71},
            {x=-330.24,y=6083.88,z=31.45}, {x=252.63,y=-50.00,z=69.94}, {x=22.56,y=-1109.89,z=29.80},
            {x=2567.69,y=294.38,z=108.73}, {x=-1117.58,y=2698.61,z=18.55}, {x=842.44,y=-1033.42,z=28.19}
        },
        items={
            {name='weapon_pistol',price=2500},{name='weapon_snspistol',price=1800},{name='weapon_combatpistol',price=3500},
            {name='weapon_heavypistol',price=4200},{name='weapon_vintagepistol',price=3000},{name='weapon_revolver',price=5500},
            {name='weapon_pumpshotgun',price=7500},{name='weapon_stungun',price=1500},{name='weapon_flaregun',price=900},
            {name='weapon_knife',price=250},{name='weapon_switchblade',price=350},{name='weapon_bat',price=120},
            {name='weapon_crowbar',price=200},{name='weapon_hammer',price=150},{name='weapon_knuckle',price=400},
            {name='weapon_machete',price=450},{name='weapon_flashlight',price=150},
            {name='ammo_pistol',price=3},{name='ammo_shotgun',price=7},{name='ammo_flare',price=25}
        }
    }
}
