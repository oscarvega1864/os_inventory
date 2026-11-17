-- Tiendas del inventario (cliente y servidor). Ammu-Nation vende armas cortas, cuerpo a cuerpo, escopeta y municion;
-- las armas pesadas solo las da un administrador (web del panel o /giveitem). Las 24/7 venden comida y bebida. Precios en dolares; se paga en efectivo o con el banco.
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
    },
    -- Tiendas de barrio (24/7, LTD y licorerias): comida y bebida (shared/food.lua).
    supermercado={
        label='Tienda 24/7', blip={sprite=52,color=2,scale=0.65}, distance=2.5,
        -- Mostradores aproximados; si alguno no cuadra, ajustalo con /coords en el juego.
        locations={
            {x=25.74,y=-1346.32,z=29.50}, {x=-48.40,y=-1757.94,z=29.42}, {x=1135.81,y=-982.28,z=46.42},
            {x=1163.37,y=-323.80,z=69.21}, {x=373.88,y=325.89,z=103.57}, {x=-707.50,y=-914.26,z=19.22},
            {x=-1222.92,y=-906.98,z=12.33}, {x=-1487.55,y=-379.11,z=40.16}, {x=-2968.24,y=390.91,z=15.04},
            {x=-3241.93,y=1001.46,z=12.83}, {x=-3039.54,y=585.66,z=7.91}, {x=1729.22,y=6414.13,z=35.04},
            {x=1698.39,y=4924.40,z=42.06}, {x=1961.46,y=3740.67,z=32.34}, {x=547.43,y=2671.71,z=42.16},
            {x=2678.92,y=3280.67,z=55.24}, {x=2557.46,y=382.28,z=108.62}, {x=-1820.52,y=792.52,z=138.12}
        },
        items={
            {name='agua',price=3},{name='refresco',price=4},{name='zumo',price=5},{name='cafe',price=4},
            {name='leche',price=4},{name='bebida_energetica',price=6},
            {name='bocadillo',price=8},{name='hamburguesa',price=12},{name='pizza',price=7},{name='perrito',price=6},
            {name='tacos',price=9},{name='ensalada',price=7},{name='sopa',price=6},{name='patatas',price=3},
            {name='donut',price=3},{name='chocolatina',price=2},{name='manzana',price=2},{name='comida',price=10}
        }
    }
}
