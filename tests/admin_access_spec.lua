dofile('/repo/config/authorization.lua');dofile('/repo/server/admin_access.lua')
local total,failures=0,0
local function test(name,run) total=total+1;local ok,err=pcall(run);if not ok then failures=failures+1 end;__report(name,ok,tostring(err)) end
local function adapter()
    local c={native=false,started=true,allowed=false,calls=0}
    c.check=OSInventoryAdminAccess.new({permission='osinventory.admin',resource='os_devtools',
        ace=function(source,permission) assert(permission=='osinventory.admin');return c.native end,
        state=function(resource) assert(resource=='os_devtools');return c.started and 'started' or 'stopped' end,
        delegate=function(resource,source,permission)
            assert(resource=='os_devtools' and source==2 and permission=='osinventory.admin');c.calls=c.calls+1
            if c.error then error('Unavailable export') end;return c.allowed
        end})
    return c
end
test('Manifest paths and all Lua syntax remain valid for the inventory pretest',function()
    for _,file in ipairs(__files) do assert(loadfile('/repo/'..file),file) end
    local env={fx_version=function(v) assert(v=='cerulean') end,game=function(v) assert(v=='gta5') end,lua54=function() end,author=function() end,description=function() end,
        version=function(v) assert(v=='0.1.0-pretest.1') end,shared_scripts=function(files) for _,file in ipairs(files) do assert(loadfile('/repo/'..file)) end end,
        server_scripts=function(files) for _,file in ipairs(files) do assert(loadfile('/repo/'..file)) end end,client_scripts=function(files) for _,file in ipairs(files) do assert(loadfile('/repo/'..file)) end end,
        ui_page=function() end,files=function() end}
    assert(loadfile('/repo/fxmanifest.lua','t',env))()
end)
test('Console and ACE true/1 work independently of the broker',function()
    local c=adapter();c.started=false;assert(c.check(0))
    c.native=true;assert(c.check(2));c.native=1;assert(c.check(2));assert(c.calls==0)
end)
test('ACE false/0 and invalid source types cannot authorize normal players',function()
    local c=adapter();c.started=false
    assert(not c.check(2));c.native=0;assert(not c.check(2))
    assert(not c.check('2') and not c.check(-1) and not c.check(1.5))
end)
test('Verified delegation is read on every operation and revocation/provider stop deny immediately',function()
    local c=adapter();assert(not c.check(2));c.allowed=true;assert(c.check(2))
    c.allowed=false;assert(not c.check(2));c.allowed=true;c.started=false;assert(not c.check(2));assert(c.calls==3)
end)
test('Missing exports and non-boolean approvals fail closed',function()
    local c=adapter();c.error=true;assert(not c.check(2));c.error=false
    for _,value in ipairs({0,1,'true'}) do c.allowed=value;assert(not c.check(2)) end
end)
test('The optional integration can be disabled',function()
    local check=OSInventoryAdminAccess.new({permission='osinventory.admin',resource=false,ace=function() return false end,
        state=function() error('Must not run') end,delegate=function() error('Must not run') end})
    assert(not check(2))
end)
local function fixture()
    local c={files={},commands={},events={},net={},exports={},messages={},writes=0,broker=true,approved=false,broken=false,nativeInteger=false,clock=1000}
    GetCurrentResourceName=function() return 'os_inventory' end
    GetResourceState=function(name) return name=='os_devtools' and c.broker and 'started' or 'stopped' end
    GetPlayerName=function(source) return (source==1 or source==2) and 'Same visible name' or nil end
    GetPlayers=function() return {'1','2'} end
    GetPlayerIdentifiers=function(source) return {'license:'..string.rep(source==1 and 'a' or 'b',40)} end
    IsPlayerAceAllowed=function(source,permission) assert(permission=='osinventory.admin');if c.nativeInteger then return source==1 and 1 or 0 end;return source==1 end
    RegisterCommand=function(name,fn) c.commands[name]=fn end
    RegisterNetEvent=function(name,fn) c.net[name]=fn end
    AddEventHandler=function(name,fn) c.events[name]=fn end
    TriggerClientEvent=function(name,source,...) assert(source>0);c.messages[#c.messages+1]={name=name,source=source,args={...}} end
    LoadResourceFile=function(_,file) return c.files[file] end
    SaveResourceFile=function(_,file,bytes,length) assert(length==#bytes);c.writes=c.writes+1;c.files[file]=bytes;return true end
    GetGameTimer=function() return c.clock end
    local namespace={}
    function namespace:HasOscarPermission(source,permission)
        assert(source==2 and permission=='osinventory.admin');if c.broken then error('Missing export') end;return c.approved
    end
    function namespace:GetCharacterId(source) return 'character_'..source end
    function namespace:GetCharacterByAlias(alias) return alias=='character_2' and alias or nil end
    exports=setmetatable({os_devtools=namespace},{__call=function(_,name,fn) c.exports[name]=fn end})
    dofile('/repo/config/authorization.lua');dofile('/repo/shared/items.lua');dofile('/repo/server/admin_access.lua');dofile('/repo/server/main.lua')
    c.events.onResourceStart('os_inventory')
    return c
end
test('Actual give/remove/inspect commands reject normal players, including native integer zero',function()
    local c=fixture();c.nativeInteger=true;local before=c.writes
    for _,name in ipairs({'giveitem','removeitem','inspectinventory'}) do c.commands[name](2,{'2','agua','1'}) end
    assert(c.writes==before and c.exports.GetItemCount('osdev:character_2','agua')==0)
end)
test('ACE admin and delegated inventory admin use the same guarded commands and existing inventory IDs',function()
    local c=fixture();c.commands.giveitem(1,{'2','agua','3'});assert(c.exports.GetItemCount('osdev:character_2','agua')==3)
    c.approved=true;c.commands.giveitem(2,{'2','agua','2'});assert(c.exports.GetItemCount('osdev:character_2','agua')==5)
    c.commands.removeitem(2,{'2','agua','1'});assert(c.exports.GetItemCount('osdev:character_2','agua')==4)
    c.commands.inspectinventory(2,{'2'});assert(c.messages[#c.messages].name=='osinventory:notify')
    c.approved=false;local before=c.writes;c.commands.removeitem(2,{'2','agua','1'});assert(c.writes==before and c.exports.GetItemCount('osdev:character_2','agua')==4)
end)
test('Broker failure cannot grant inventory mutations and personal inventory opening remains available',function()
    local c=fixture();c.broken=true;local before=c.writes;c.commands.giveitem(2,{'2','agua','1'});assert(c.writes==before)
    c.commands.inventario(2,{});assert(c.messages[#c.messages].name=='osinventory:toggle')
    assert(not c.net['osinventory:grantAdmin'] and not c.net['osinventory:setPermission'])
end)
print(('Inventory auth tests: %d | Passed: %d | Failed: %d'):format(total,total-failures,failures));__failures=failures
