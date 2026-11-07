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
test('Manifest paths and all Lua syntax remain valid for the inventory',function()
    for _,file in ipairs(__files) do assert(loadfile('/repo/'..file),file) end
    local env={fx_version=function(v) assert(v=='cerulean') end,game=function(v) assert(v=='gta5') end,lua54=function() end,author=function() end,description=function() end,
        version=function(v) assert(v=='0.1.0') end,shared_scripts=function(files) for _,file in ipairs(files) do assert(loadfile('/repo/'..file)) end end,
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

print(('Inventory authorization: %d passed, %d failed'):format(total-failures,failures));__failures=failures
