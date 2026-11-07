OSInventory.Client={}
function OSInventory.Client.new(options)
    local current,pending,sequence,request,generation=nil,nil,0,0,0
    local visible,refreshQueued=false,false
    local controller={}
    function controller.isOpen() return visible end
    function controller.close()
        generation=generation+1;current=nil;visible=false;refreshQueued=false
        local waiting=pending;pending=nil
        if waiting and waiting.callback then waiting.callback({ok=false,error='Inventario cerrado.'}) end
        options.hide();options.close()
    end
    local function send(event,packet,callback)
        if pending then return false end
        request=request+1;local id=request;local version=generation
        pending={id=id,callback=callback,event=event}
        options.send(event,id,packet)
        options.schedule(OSInventory.ClientConfig.RpcMilliseconds,function()
            if generation~=version or not pending or pending.id~=id then return end
            options.notify('El servidor no respondio; inventario cerrado para liberar controles.')
            controller.close()
        end)
        return true
    end
    function controller.toggle()
        if visible or pending then controller.close();return end
        if not options.canOpen() then options.notify('No puedes abrir el inventario ahora.');return end
        send('open',nil,function(response)
            if not response.ok then options.notify(response.error or 'No se pudo abrir.');return end
            if not options.canOpen() then controller.close();return end
            current=response.token;sequence=response.sequence;visible=true;options.show(response.inventory)
        end)
    end
    function controller.action(op,args,callback)
        if not visible or not current or pending then callback({ok=false,error='Inventario ocupado o cerrado.'});return end
        sequence=sequence+1
        send('request',{token=current,sequence=sequence,op=op,args=args},function(response)
            if response.close then controller.close() end
            if visible and response.inventory then options.update(response.inventory) end
            callback(response)
        end)
    end
    function controller.refresh()
        if not visible then return end
        if pending then refreshQueued=true;return end
        controller.action('refresh',{},function() end)
    end
    function controller.response(id,response)
        if not pending or pending.id~=id or type(response)~='table' then return end
        local callback=pending.callback;pending=nil;callback(response)
        if refreshQueued and not pending then refreshQueued=false;controller.refresh() end
    end
    return controller
end
