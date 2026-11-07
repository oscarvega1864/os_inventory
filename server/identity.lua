OSInventory.Identity={}
function OSInventory.Identity.new(options)
    local provider=OSInventory.Config.Identity.Provider
    local u=OSInventory.Util
    local identity={}
    local function character(id) return type(id)=='string' and id:match('^oschar_%d%d%d%d%d%d%d%d%d%d$')~=nil and tonumber(id:sub(8))>0 end
    local function license(value) return type(value)=='string' and #value==48 and value:match('^license:[0-9a-f]+$')~=nil end
    function identity.key(value)
        if provider=='os_devtools' then return character(value) and ('devtools:'..value) or nil end
        if provider=='standalone' and type(value)=='string' and value:sub(1,11)=='standalone:' and license(value:sub(12)) then return value end
        return nil
    end
    function identity.active(source)
        if not u.integer(source,1,2147483647) or not options.connected(source) then return nil,'Jugador desconectado.' end
        if provider=='os_devtools' then
            if options.state(OSInventory.Config.Identity.Resource)~='started' then return nil,'Proveedor de personajes no disponible; no se cambia de identidad.' end
            local ok,dto=pcall(options.active,source)
            if not ok or type(dto)~='table' or not character(dto.characterId) or dto.connected~=true or dto.spawning then return nil,'Personaje no disponible o aparicion en curso.' end
            return {key='devtools:'..dto.characterId,characterId=dto.characterId,alias=dto.alias or dto.characterId}
        end
        if provider~='standalone' then return nil,'Proveedor de identidad desconocido.' end
        local account
        for _,value in ipairs(options.identifiers(source) or {}) do
            if license(value) then if account and account~=value then return nil,'Identificadores contradictorios.' end;account=value end
        end
        if account then return {key='standalone:'..account,characterId='standalone:'..account,alias='Inventario personal'} end
        return nil,'Falta identificador persistente validado.'
    end
    function identity.resolve(value)
        if type(value)~='string' then return nil,'Destinatario requerido.' end
        if value:match('^%d+$') then return identity.active(tonumber(value)) end
        if provider~='os_devtools' or options.state(OSInventory.Config.Identity.Resource)~='started' then return nil,'Usa un jugador conectado o ID de inventario existente.' end
        local query=character(value) and ('char:'..value) or value
        local ok,dto=pcall(options.resolve,query)
        if not ok or type(dto)~='table' or not character(dto.characterId) then return nil,'Personaje inexistente.' end
        return {key='devtools:'..dto.characterId,characterId=dto.characterId,alias=dto.alias or dto.characterId}
    end
    function identity.legacy(value)
        if provider=='os_devtools' and type(value)=='string' and value:sub(1,6)=='osdev:' then return identity.resolve('alias:'..value:sub(7)) end
        if provider=='standalone' and license(value) then return {key='standalone:'..value,characterId='standalone:'..value,alias='Inventario personal'} end
        return nil,'Identidad heredada incompatible con el proveedor configurado; no se convierte silenciosamente.'
    end
    return identity
end
