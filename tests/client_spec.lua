local test=InventoryTest.test
local function fixture()
    OSInventory=OSInventory or {};dofile('/repo/config/client.lua');dofile('/repo/client/controller.lua')
    local f={timers={},sent={},shown=0,hidden=0,closed=0,can=true,notifications=0}
    f.controller=OSInventory.Client.new({schedule=function(_,fn) f.timers[#f.timers+1]=fn end,canOpen=function() return f.can end,
        notify=function() f.notifications=f.notifications+1 end,hide=function() f.hidden=f.hidden+1 end,close=function() f.closed=f.closed+1 end,
        show=function() f.shown=f.shown+1 end,update=function() end,send=function(event,id,packet) f.sent[#f.sent+1]={event=event,id=id,packet=packet} end})
    function f.respond(response) f.controller.response(f.sent[#f.sent].id,response) end
    return f
end
test('NUI focus is acquired only after a valid server response and incompatible focus is respected',function()
    local f=fixture();f.can=false;f.controller.toggle();assert(#f.sent==0)
    f.can=true;f.controller.toggle();assert(not f.controller.isOpen() and f.shown==0)
    f.respond({ok=true,token='server',sequence=0,inventory={}});assert(f.controller.isOpen() and f.shown==1)
    f.controller.toggle();assert(not f.controller.isOpen() and f.hidden==1)
end)
test('Timeout, close and late responses cannot leave NUI open or reapply a completed action',function()
    local f=fixture();f.controller.toggle();f.timers[1]();assert(not f.controller.isOpen() and f.hidden==1)
    f.respond({ok=true,token='late',sequence=0,inventory={}});assert(f.shown==0)
    f.controller.toggle();f.respond({ok=true,token='new',sequence=0,inventory={}})
    local calls=0;f.controller.action('move',{},function(r) calls=calls+1;assert(not r.ok) end)
    f.controller.close();f.respond({ok=true,inventory={}});assert(calls==1 and not f.controller.isOpen())
end)
test('One pending client action enforces sequencing and server invalidation queues one refresh',function()
    local f=fixture();f.controller.toggle();f.respond({ok=true,token='t',sequence=0,inventory={}})
    f.controller.action('move',{},function() end);assert(f.sent[#f.sent].packet.sequence==1)
    local denied=false;f.controller.action('use',{},function(r) denied=not r.ok end);assert(denied)
    f.controller.refresh();f.respond({ok=true,inventory={}});assert(f.sent[#f.sent].packet.op=='refresh' and f.sent[#f.sent].packet.sequence==2)
end)
test('Actual client wiring owns focus only after server authorization and releases it on ESC callback and stop',function()
    local f={focus=false,net={},commands={},events={},nui={},sent={},messages={},threads={}}
    GetCurrentResourceName=function() return 'os_inventory' end
    GetGameTimer=function() return 1000 end
    GetResourceState=function() return 'started' end
    NetworkIsSessionStarted=function() return true end
    PlayerPedId=function() return 1 end
    IsEntityDead=function() return false end
    IsPauseMenuActive=function() return false end
    IsNuiFocused=function() return f.focus end
    SetNuiFocus=function(mouse,keyboard) assert(mouse==keyboard);f.focus=mouse end
    SendNUIMessage=function(data) f.messages[#f.messages+1]=data end
    SetTimeout=function() end
    TriggerServerEvent=function(name,...) f.sent[#f.sent+1]={name=name,args={...}} end
    TriggerEvent=function() end
    RegisterCommand=function(name,fn) f.commands[name]=fn end
    RegisterKeyMapping=function(name,_,kind,key) f.keys=f.keys or {};f.keys[name]=key;assert(kind=='keyboard' and ((name=='inventario' and key=='I') or name=='accesorapido'..key)) end
    IsPedInAnyVehicle=function() return false end;GetEntityModel=function() return 7 end
    GetPedDrawableVariation=function() return 0 end;GetPedPropIndex=function() return -1 end
    GetOffsetFromEntityInWorldCoords=function() return {x=0,y=0,z=0} end
    CreateCamWithParams=function() f.camera=true;return 5 end;PointCamAtCoord=function() end;SetCamActive=function() end
    RenderScriptCams=function(on) f.rendering=on end;DestroyCam=function() f.camera=false end
    RegisterNetEvent=function(name,fn) f.net[name]=fn end
    RegisterNUICallback=function(name,fn) f.nui[name]=fn end
    AddEventHandler=function(name,fn) f.events[name]=fn end
    CreateThread=function(fn) f.threads[#f.threads+1]=fn end
    dofile('/repo/client/look.lua');dofile('/repo/client/hotbar.lua');dofile('/repo/client/main.lua')
    for slot=1,6 do assert(f.keys['accesorapido'..slot]==tostring(slot) and f.commands['accesorapido'..slot]) end
    f.focus=true;f.commands.inventario();assert(#f.sent==0)
    f.focus=false;f.commands.inventario();local request=f.sent[#f.sent];assert(request.name=='osinventory:open' and not f.focus)
    source=2;f.net['osinventory:response'](request.args[1],{ok=true,token='bad',sequence=0,inventory={}});assert(not f.focus)
    source=65535;f.net['osinventory:response'](request.args[1],{ok=true,token='server',sequence=0,inventory={}});assert(f.focus)
    assert(f.camera and f.rendering and f.messages[#f.messages].type=='open' and #f.messages[#f.messages].accessories==6)
    f.nui.close({},function(r) assert(r.ok) end);assert(not f.focus and f.sent[#f.sent].name=='osinventory:close')
    assert(not f.camera and not f.rendering)
    f.commands.inventario();request=f.sent[#f.sent];source=65535;f.net['osinventory:response'](request.args[1],{ok=true,token='next',sequence=0,inventory={}})
    f.events.onClientResourceStop('os_inventory');assert(not f.focus)
end)
