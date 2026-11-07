function OSInventory.openStorage(resource,identity,now)
    local files=OSInventory.ResourceFiles.new({resource=resource,load=LoadResourceFile,save=SaveResourceFile,open=io.open})
    local a,ae=files.read('data/inventories.a.json');local b,be=files.read('data/inventories.b.json')
    if ae or be then return nil,'Error de lectura de snapshots.' end
    local initial=OSInventory.Domain.empty();local legacy
    if a==nil and b==nil then
        local err;legacy,err=files.read('inventory_data.json')
        if err then return nil,'No se pudo leer inventario heredado.' end
        if legacy then
            if #legacy>OSInventory.Config.MaxFileBytes then return nil,'Datos heredados demasiado grandes.' end
            local ok,decoded=pcall(OSInventory.JsonCodec.decode,legacy)
            if not ok then return nil,'JSON heredado corrupto; no se sobrescribe.' end
            initial,err=OSInventory.Domain.migrate(decoded,identity,now)
            if not initial then return nil,err end
        end
    end
    local journal=OSInventory.JsonStorage.new({base='data/inventories',limits=OSInventory.Config,initialSnapshot=initial,validation=OSInventory.Domain,
        read=files.read,write=files.write,encode=OSInventory.JsonCodec.encode,decode=OSInventory.JsonCodec.decode,
        log=function(message) print('[os_inventory] '..message) end})
    local data,err=journal.load();if not data then return nil,err end
    local storage={data=data,needsMigration=a==nil and b==nil,journal=journal};local backed=legacy==nil
    function storage.save(candidate)
        if not backed then
            local raw,readError=files.read('data/migration-010-source.json')
            if readError or (raw and raw~=legacy) then return nil,'Respaldo heredado distinto; revision requerida.' end
            if not raw then
                local ok=files.write('data/migration-010-source.json',legacy)
                if not ok or files.read('data/migration-010-source.json')~=legacy then return nil,'Respaldo heredado no verificado.' end
            end
            backed=true
        end
        candidate.revision=storage.data.revision+1
        local ok,reason=journal.save(candidate)
        if ok then storage.data=OSInventory.Util.copy(candidate) end
        return ok,reason
    end
    return storage
end
