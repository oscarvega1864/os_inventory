OSInventory.Service={}
function OSInventory.Service.new(options)
    local u,d,c=OSInventory.Util,OSInventory.Domain,OSInventory.Config
    local storage,state,ready,busy=options.storage,options.storage and options.storage.data,false,false
    local sessions,rates,usable,confirmations={},{},{},{}
    local serial=0;local service={}
    local function rate(src)
        local now=options.now();local r=rates[src]
        if not r or now-r.at>=c.WindowSeconds or now<r.at then r={at=now,n=0};rates[src]=r end
        r.n=r.n+1;return r.n<=c.RequestsPerWindow
    end
    function service.change(event,callback)
        if not ready or busy or storage.journal.isBlocked() then return false,'Inventario bloqueado o no disponible; revisar almacenamiento.' end
        busy=true
        local candidate=u.copy(state)
        local ran,ok,result=pcall(callback,candidate)
        if ran and ok then
            event.at=options.now();d.audit(candidate,event)
            local saved,err=storage.save(candidate)
            if saved then state=storage.data else ok=false;result=err end
        end
        busy=false
        if not ran then options.log('Operacion rechazada por error interno; no se publica el cambio.');return false,'Operacion no completada.' end
        return ok==true,result
    end
    function service.start()
        if not storage then return false end
        ready=true
        if storage.needsMigration then
            local ok=service.change({op='migration',actor='system'},function() return true end)
            if not ok then ready=false;return false end
        end
        return true
    end
    function service.state() return state and u.copy(state) or nil end
    function service.available() return ready and not busy and not storage.journal.isBlocked() end
    function service.ensure(owner)
        if not service.available() or not d.owner(owner) then return nil,'Inventario no disponible.' end
        if not state.inventories[owner] then
            local ok,err=service.change({op='create',actor=owner},function(nextState)
                local inv,reason=d.inventory(nextState,owner,true,options.now());return inv~=nil,reason
            end)
            if not ok then return nil,err end
        end
        return u.copy(state.inventories[owner])
    end
    local function catalog()
        local items=u.copy(OSItems)
        for name,item in pairs(items) do item.usable=item.builtinUse~=nil or usable[name]~=nil end
        return items
    end
    function service.nearby(src)
        local position=options.position(src);local result={}
        if not position then return result end
        for _,drop in pairs(state and state.drops or {}) do
            if d.near(position,drop.position,c.DropViewDistance) then
                result[#result+1]={id=drop.id,name=drop.entry.name,count=drop.entry.count,position=u.copy(drop.position),canPickup=d.near(position,drop.position,c.PickupDistance)}
            end
        end
        table.sort(result,function(a,b) return a.id<b.id end)
        while #result>c.MaxViewedDrops do table.remove(result) end
        return result
    end
    local function snapshot(src,owner)
        local inv=state.inventories[owner]
        return {id=inv.id,revision=inv.revision,slots=u.copy(inv.slots),capacity=inv.slotCount,weight=d.weight(inv)/1000,
            maxWeight=inv.maxWeightGrams/1000,items=catalog(),nearby=service.nearby(src)}
    end
    function service.open(src)
        if not rate(src) then return {ok=false,error='Demasiadas solicitudes.'} end
        local person,err=options.identity.active(src)
        if not person or not options.position(src) then return {ok=false,error=err or 'Jugador no disponible.'} end
        local inv,reason=service.ensure(person.key);if not inv then return {ok=false,error=reason} end
        serial=serial+1
        local token=('%d:%d:%d'):format(src,serial,options.now())
        sessions[src]={token=token,owner=person.key,expires=options.now()+c.SessionSeconds,sequence=0,responses={}}
        return {ok=true,token=token,sequence=0,inventory=snapshot(src,person.key)}
    end
    local function perform(src,person,op,args)
        local allowed={slot=true,expected=true,count=true,target=true,to=true,drop=true,revision=true}
        if not u.object(args,allowed) then return false,'Argumentos invalidos.' end
        if op=='refresh' then return true end
        local inv=state.inventories[person.key]
        if not inv or args.revision~=inv.revision then return false,'Inventario actualizado; revisa la seleccion.' end
        local point=options.position(src);if not point then return false,'Jugador no disponible.' end
        local receiver,entry,callback
        if op~='pickup' then
            local reason;entry,reason=d.entry(inv,args.slot,args.expected,args.count)
            if not entry then return false,reason end
        end
        if op=='give' then
            if not u.integer(args.target,1,2147483647) or args.target==src then return false,'Destinatario invalido.' end
            receiver=options.identity.active(args.target)
            if not receiver or receiver.key==person.key or not d.near(point,options.position(args.target),c.TransferDistance) then return false,'Destinatario no disponible o fuera de alcance.' end
            if not OSItems[entry.name].transferable then return false,'Objeto no transferible.' end
        elseif op=='drop' then
            if not OSItems[entry.name].transferable then return false,'Objeto no transferible; no puede dejarse en el suelo.' end
        elseif op=='use' then
            if args.count~=1 then return false,'Usa un objeto cada vez.' end
            callback=usable[entry.name]
            if not OSItems[entry.name].builtinUse and not callback then return false,'Este objeto no tiene uso implementado.' end
        elseif op~='move' and op~='pickup' then return false,'Accion desconocida.' end
        local event={op=op,actor=person.key,item=entry and entry.name or nil,qty=args.count,target=receiver and receiver.key or nil}
        local ok,result=service.change(event,function(nextState)
            local current=nextState.inventories[person.key]
            if op=='move' then return d.move(nextState,current,args.slot,args.to,args.expected,args.count) end
            if op=='pickup' then
                if not u.text(args.drop,32) then return false,'Objeto en suelo invalido.' end
                return d.pickup(nextState,current,args.drop,point)
            end
            if op=='drop' then return d.drop(nextState,current,args.slot,args.expected,args.count,point,options.now()) end
            if op=='give' then
                local target,err=d.inventory(nextState,receiver.key,true,options.now());if not target then return false,err end
                local can,reason=d.canCarry(target,entry.name,args.count,entry.metadata);if not can then return false,reason end
                local taken=d.take(nextState,current,args.slot,args.expected,args.count)
                return d.add(nextState,target,taken.name,taken.count,taken.metadata,taken)
            end
            if OSItems[entry.name].builtinUse then return d.take(nextState,current,args.slot,args.expected,1)~=nil end
            -- Los adaptadores de uso no consumen objetos. Su efecto pertenece al recurso registrado.
            return true
        end)
        if ok and callback and not OSItems[entry.name].builtinUse then
            local called=pcall(callback.fn,src,{characterId=person.characterId,inventoryId=inv.id,item=u.copy(entry)})
            if not called then options.log('Adaptador de uso fallo; revisar recurso registrado.');result='El adaptador no completo el uso.' end
        end
        return ok,result
    end
    function service.request(src,packet)
        if not rate(src) then return {ok=false,error='Demasiadas solicitudes.'} end
        if not service.available() or not u.object(packet,{token=true,sequence=true,op=true,args=true}) or not u.text(packet.token,64)
            or not u.integer(packet.sequence,1,2147483647) or not u.text(packet.op,16) or type(packet.args)~='table' then return {ok=false,error='Solicitud invalida o almacenamiento no disponible.',close=true} end
        local session=sessions[src];local person=options.identity.active(src)
        if not session or session.token~=packet.token or session.expires<options.now() or not person or person.key~=session.owner then
            sessions[src]=nil;return {ok=false,error='Sesion caducada o personaje cambiado.',close=true}
        end
        local cached=session.responses[packet.sequence]
        if cached then
            if u.equal(cached.packet,packet) then return u.copy(cached.response) end
            return {ok=false,error='Secuencia reutilizada con otros argumentos.',close=true}
        end
        if packet.sequence~=session.sequence+1 then return {ok=false,error='Secuencia fuera de orden.',close=true} end
        session.sequence=packet.sequence;session.expires=options.now()+c.SessionSeconds
        local ok,result=perform(src,person,packet.op,packet.args)
        local response={ok=ok,error=not ok and result or nil,message=ok and 'Operacion completada.' or nil,inventory=snapshot(src,person.key)}
        session.responses[packet.sequence]={packet=u.copy(packet),response=u.copy(response)}
        session.responses[packet.sequence-8]=nil
        return response
    end
    function service.close(src) sessions[src]=nil;confirmations[src]=nil end
    function service.dropPlayer(src) service.close(src);rates[src]=nil end
    function service.giveNamed(src,target,name,count)
        if not rate(src) or not service.available() or not OSItems[name] or not d.amount(count) or not OSItems[name].transferable then return false,'Item, cantidad o frecuencia invalidos.' end
        local sender,receiver=options.identity.active(src),options.identity.active(target)
        if not sender or not receiver or sender.key==receiver.key or not d.near(options.position(src),options.position(target),c.TransferDistance) then return false,'Personajes no disponibles o fuera de alcance.' end
        local inv=state.inventories[sender.key]
        if d.count(inv,name)<count then return false,'Cantidad no disponible.' end
        return service.change({op='give',actor=sender.key,target=receiver.key,item=name,qty=count},function(nextState)
            local from=nextState.inventories[sender.key]
            local to,err=d.inventory(nextState,receiver.key,true,options.now());if not to then return false,err end
            local remaining=count
            for slot=1,from.slotCount do
                local e=from.slots[tostring(slot)]
                if e and e.name==name then
                    local n=math.min(remaining,e.count)
                    local taken=d.take(nextState,from,slot,e.id,n)
                    local ok,reason=d.add(nextState,to,taken.name,taken.count,taken.metadata,taken)
                    if not ok then return false,reason end
                    remaining=remaining-n;if remaining==0 then return true end
                end
            end
            return false,'La cantidad ha cambiado.'
        end)
    end
    function service.admin(src,operation,target,name,count,confirmation)
        if not options.admin(src) then return false,'Sin autorizacion efectiva osinventory.admin.' end
        local person,err=options.identity.resolve(target);if not person then return false,err end
        if not service.available() then return false,'Inventario no disponible.' end
        local inv=state.inventories[person.key]
        if operation=='inspectinventory' then return true,inv and u.copy(inv) or {slots={}} end
        local actor=src==0 and 'console' or options.actor(src)
        if not actor then return false,'Identidad administrativa no disponible.' end
        if operation=='clearinventory' then
            local pending=confirmations[src]
            if confirmation~='CONFIRMAR' or not pending or pending.owner~=person.key or pending.actor~=actor or pending.expires<options.now() or pending.revision~=(inv and inv.revision or 0) then
                confirmations[src]={owner=person.key,actor=actor,expires=options.now()+30,revision=inv and inv.revision or 0}
                return false,'Confirma en 30 s: /clearinventory '..target..' CONFIRMAR'
            end
            confirmations[src]=nil
        elseif not OSItems[name] or not d.amount(count) then return false,'Item o cantidad invalidos.' end
        return service.change({op=operation,actor=actor,target=person.key,item=name,qty=count},function(nextState)
            local current,reason=d.inventory(nextState,person.key,true,options.now());if not current then return false,reason end
            if operation=='giveitem' then return d.add(nextState,current,name,count,{}) end
            if operation=='removeitem' then return d.remove(current,name,count) end
            if operation=='clearinventory' then current.slots={};current.revision=current.revision+1;return true end
            return false,'Operacion administrativa desconocida.'
        end)
    end
    local function permitted(caller,operation,name)
        if caller==options.resource then return true end
        local policy=type(caller)=='string' and c.ResourceAccess[caller]
        if not policy then return false end
        if operation=='read' then return policy.read==true end
        return type(policy[operation])=='table' and policy[operation][name]==true
    end
    function service.api(caller,operation,character,name,count,meta,operationId)
        local scope=(operation=='AddItem' or operation=='RemoveItem') and 'writeItems' or 'read'
        if not permitted(caller,scope,name) or not service.available() then return false,'Recurso no autorizado o inventario no disponible.' end
        local owner=options.identity.key(character)
        if not owner then return false,'Identificador estable invalido.' end
        -- Solo identidades conocidas por el proveedor o inventarios ya registrados.
        if not state.inventories[owner] then
            local person=options.identity.resolve(character)
            if not person or person.key~=owner then return false,'Personaje no verificado.' end
        end
        local inv=state.inventories[owner] or {slotCount=c.Slots,maxWeightGrams=math.floor(c.MaxWeight*1000+0.5),slots={}}
        if operation=='GetInventory' then
            if not inv.id then return nil,'Inventario no registrado; se crea al abrir o recibir objetos.' end
            -- Cada hueco lleva tambien el nombre visible del objeto (el de sus metadatos o el del catalogo),
            -- para que otros recursos (p. ej. el cacheo de os_security) muestren que objeto es de verdad.
            local copy=u.copy(inv)
            for _,slot in pairs(copy.slots or {}) do
                if type(slot)=='table' and type(slot.name)=='string' then
                    local meta=type(slot.metadata)=='table' and slot.metadata or nil
                    slot.label=(meta and type(meta.label)=='string' and meta.label~='' and meta.label) or (OSItems[slot.name] and OSItems[slot.name].label) or slot.name
                end
            end
            return copy
        end
        if not OSItems[name] then return false,'Objeto inexistente.' end
        if operation=='GetItemCount' then return d.count(inv,name,meta) end
        if not d.amount(count) or (meta~=nil and not d.metadata(name,meta)) then return false,'Cantidad o metadatos invalidos.' end
        if operation=='HasItem' then return d.count(inv,name,meta)>=count end
        if operation=='CanCarryItem' then return d.canCarry(inv,name,count,meta or {}) end
        if operation~='AddItem' and operation~='RemoveItem' then return false,'Export desconocido.' end
        local key,signature
        if operationId~=nil then
            if not u.text(operationId,96) then return false,'ID de operacion invalido.' end
            key=caller..':'..operationId
            -- Orden fijo; no depender del orden de claves de json.encode.
            local values={operation,owner,name,tostring(count),meta and meta.label or '',meta and meta.reference or '',meta and meta.serial or '',meta==nil and 'nil' or 'meta'}
            local parts={};for _,value in ipairs(values) do parts[#parts+1]=#value..':'..value end;signature=table.concat(parts)
            local receipt=state.receipts[key]
            if receipt then return receipt.signature==signature,receipt.signature==signature and 'Operacion ya confirmada.' or 'ID de operacion reutilizado.' end
            local n=0;for _ in pairs(state.receipts) do n=n+1 end
            if n>=c.MaxReceipts then
                -- Lleno: se retiran los recibos caducados en un cambio propio y validado.
                local removed=0
                service.change({op='prune_receipts',actor='system'},function(nextState) removed=d.pruneReceipts(nextState,options.now());return removed>0,'Sin recibos caducados.' end)
                n=0;for _ in pairs(state.receipts) do n=n+1 end
                if n>=c.MaxReceipts then return false,'Registro de recibos lleno; requiere mantenimiento explicito.' end
                options.log(('Recibos caducados retirados: %d.'):format(removed))
            end
        end
        return service.change({op=operation,actor=caller,target=owner,item=name,qty=count},function(nextState)
            local current,reason=d.inventory(nextState,owner,true,options.now());if not current then return false,reason end
            local ok,err
            if operation=='AddItem' then ok,err=d.add(nextState,current,name,count,meta or {}) else ok,err=d.remove(current,name,count,meta) end
            if ok and key then nextState.receipts[key]={signature=signature,at=options.now()} end
            return ok,err
        end)
    end
    -- Desde otro recurso, FiveM entrega la funcion como referencia invocable (tabla con __call), no como 'function'.
    local function callable(value)
        if type(value)=='function' then return true end
        local meta=type(value)=='table' and getmetatable(value)
        return type(meta)=='table' and meta.__call~=nil
    end
    function service.register(caller,name,callback)
        if not OSItems[name] or OSItems[name].builtinUse or not permitted(caller,'useItems',name) or not callable(callback) or usable[name] then return false end
        usable[name]={resource=caller,fn=callback};return true
    end
    function service.resourceStopped(resource)
        for name,entry in pairs(usable) do if entry.resource==resource then usable[name]=nil end end
        if resource==c.Identity.Resource then sessions={};confirmations={} end
    end
    return service
end
