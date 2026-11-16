-- Armas y municion como objetos del inventario. Cada arma es un objeto unico con numero de serie (lo pone el
-- servidor al crearla); la municion va en cajas por tipo (cada unidad es una bala). Al "Usar" un arma se saca o se
-- guarda; las balas que se disparan se descuentan de la municion de su tipo. Las arrojadizas (granadas, bengalas...)
-- son su propia municion: cada unidad es un lanzamiento.
OSWeapons = { Ammo = {}, Weapons = {}, ByHash = {} }

local AMMO = {
    { 'ammo_pistol', 'Municion de pistola', 0.01 },
    { 'ammo_smg', 'Municion de subfusil', 0.01 },
    { 'ammo_shotgun', 'Cartuchos de escopeta', 0.03 },
    { 'ammo_rifle', 'Municion de fusil', 0.015 },
    { 'ammo_mg', 'Municion de ametralladora', 0.015 },
    { 'ammo_sniper', 'Municion de francotirador', 0.03 },
    { 'ammo_flare', 'Bengalas de pistola', 0.05 },
}
-- { objeto (nombre del arma en GTA en minusculas), etiqueta, peso kg, municion | nil (cuerpo a cuerpo) | 'self' }
local WEAPONS = {
    -- Cuerpo a cuerpo
    { 'weapon_knife', 'Cuchillo', 0.3 }, { 'weapon_switchblade', 'Navaja', 0.2 }, { 'weapon_nightstick', 'Porra', 0.6 },
    { 'weapon_bat', 'Bate de beisbol', 1.0 }, { 'weapon_crowbar', 'Palanca', 1.2 }, { 'weapon_hammer', 'Martillo', 0.8 },
    { 'weapon_knuckle', 'Puno americano', 0.2 }, { 'weapon_machete', 'Machete', 0.8 }, { 'weapon_wrench', 'Llave inglesa', 1.0 },
    { 'weapon_golfclub', 'Palo de golf', 0.5 }, { 'weapon_flashlight', 'Linterna', 0.4 },
    -- Pistolas
    { 'weapon_pistol', 'Pistola', 0.9, 'ammo_pistol' }, { 'weapon_combatpistol', 'Pistola de combate', 0.9, 'ammo_pistol' },
    { 'weapon_appistol', 'Pistola AP', 1.0, 'ammo_pistol' }, { 'weapon_pistol50', 'Pistola .50', 1.3, 'ammo_pistol' },
    { 'weapon_heavypistol', 'Pistola pesada', 1.1, 'ammo_pistol' }, { 'weapon_snspistol', 'Pistola SNS', 0.6, 'ammo_pistol' },
    { 'weapon_vintagepistol', 'Pistola vintage', 0.8, 'ammo_pistol' }, { 'weapon_revolver', 'Revolver pesado', 1.4, 'ammo_pistol' },
    { 'weapon_stungun', 'Taser', 0.5 }, { 'weapon_flaregun', 'Pistola de bengalas', 0.7, 'ammo_flare' },
    -- Subfusiles
    { 'weapon_microsmg', 'Micro SMG', 1.8, 'ammo_smg' }, { 'weapon_smg', 'Subfusil', 2.5, 'ammo_smg' },
    { 'weapon_assaultsmg', 'Subfusil de asalto', 2.8, 'ammo_smg' }, { 'weapon_combatpdw', 'PDW de combate', 2.7, 'ammo_smg' },
    { 'weapon_machinepistol', 'Pistola ametralladora', 1.5, 'ammo_smg' }, { 'weapon_minismg', 'Mini SMG', 1.6, 'ammo_smg' },
    -- Escopetas
    { 'weapon_pumpshotgun', 'Escopeta de corredera', 3.2, 'ammo_shotgun' }, { 'weapon_sawnoffshotgun', 'Escopeta recortada', 2.5, 'ammo_shotgun' },
    { 'weapon_assaultshotgun', 'Escopeta de asalto', 4.0, 'ammo_shotgun' }, { 'weapon_bullpupshotgun', 'Escopeta bullpup', 3.5, 'ammo_shotgun' },
    { 'weapon_heavyshotgun', 'Escopeta pesada', 4.2, 'ammo_shotgun' },
    -- Fusiles
    { 'weapon_assaultrifle', 'Fusil de asalto', 3.5, 'ammo_rifle' }, { 'weapon_carbinerifle', 'Carabina', 3.2, 'ammo_rifle' },
    { 'weapon_advancedrifle', 'Fusil avanzado', 3.3, 'ammo_rifle' }, { 'weapon_specialcarbine', 'Carabina especial', 3.4, 'ammo_rifle' },
    { 'weapon_bullpuprifle', 'Fusil bullpup', 3.3, 'ammo_rifle' }, { 'weapon_compactrifle', 'Fusil compacto', 2.8, 'ammo_rifle' },
    -- Ametralladoras
    { 'weapon_mg', 'Ametralladora', 8.0, 'ammo_mg' }, { 'weapon_combatmg', 'Ametralladora de combate', 9.0, 'ammo_mg' },
    { 'weapon_gusenberg', 'Gusenberg', 5.0, 'ammo_mg' },
    -- Francotirador
    { 'weapon_sniperrifle', 'Rifle de francotirador', 6.5, 'ammo_sniper' }, { 'weapon_heavysniper', 'Francotirador pesado', 9.0, 'ammo_sniper' },
    { 'weapon_marksmanrifle', 'Rifle de tirador', 5.5, 'ammo_sniper' },
    -- Arrojadizas (cada unidad es un lanzamiento)
    { 'weapon_grenade', 'Granada', 0.4, 'self' }, { 'weapon_smokegrenade', 'Granada de humo', 0.4, 'self' },
    { 'weapon_bzgas', 'Granada de gas', 0.4, 'self' }, { 'weapon_molotov', 'Coctel molotov', 0.6, 'self' },
    { 'weapon_flare', 'Bengala de mano', 0.3, 'self' },
    -- Otras
    { 'weapon_petrolcan', 'Bidon de gasolina', 2.0 }, { 'weapon_fireextinguisher', 'Extintor', 4.0 },
}

local LABEL = { ammo_pistol = 'pistola', ammo_smg = 'subfusil', ammo_shotgun = 'escopeta', ammo_rifle = 'fusil', ammo_mg = 'ametralladora', ammo_sniper = 'francotirador', ammo_flare = 'pistola de bengalas' }

for _, a in ipairs(AMMO) do
    OSWeapons.Ammo[a[1]] = true
    OSItems[a[1]] = { label = a[2], weight = a[3], stack = 250, usable = false, transferable = true,
        description = ('Balas para armas de %s. Cada unidad es una bala; las usa el arma al disparar.'):format(LABEL[a[1]]),
        category = 'municion', icon = 'ammo', metadataAllowed = false, unique = false, metadataSchema = { label = 128, reference = 96, serial = 64 } }
end
for _, w in ipairs(WEAPONS) do
    local name, label, weight, ammo = w[1], w[2], w[3], w[4]
    local throwable = ammo == 'self'
    local entry = { name = name, label = label, hash = name:upper(), ammo = throwable and name or ammo, throwable = throwable }
    OSWeapons.Weapons[name] = entry
    OSWeapons.ByHash[name:upper()] = entry
    OSItems[name] = { label = label, weight = weight, stack = throwable and 10 or 1, usable = true, transferable = true,
        description = throwable and 'Arrojadiza. Usar para sacarla; cada lanzamiento gasta una.'
            or ammo and ('Arma de fuego con numero de serie. Usar para sacarla o guardarla; dispara %s.'):format(OSItems[ammo].label:lower())
            or 'Arma cuerpo a cuerpo. Usar para sacarla o guardarla.',
        category = 'arma', icon = throwable and 'box' or 'gun', weapon = true, metadataAllowed = not throwable, unique = not throwable,
        metadataSchema = { label = 128, reference = 96, serial = 64 }, builtinUse = 'weapon' }
end
