local test,base=InventoryTest.test,InventoryTest.fixture
local function fixture()
    local f=base();f.commands={};f.net={};f.events={};f.exports={};f.messages={}
    GetCurrentResourceName=function() return 'os_inventory' end
    GetInvokingResource=function() return f.origin end
    GetResourceState=function(name) return name=='os_devtools' and f.provider and 'started' or 'stopped' end
    GetPlayerName=function(src) return f.connected[src] and 'Identical visible name' end
    GetPlayerIdentifiers=function(src) return {'license:'..string.rep(src==1 and 'a' or 'b',40)} end
    GetPlayerPed=function(src) return f.connected[src] and src+100 or 0 end
    DoesEntityExist=function(ped) return f.connected[ped-100]==true end
    GetEntityHealth=function() return 200 end
    GetEntityCoords=function(ped) return f.position[ped-100] end
    GetPlayerRoutingBucket=function(src) return f.position[src].bucket end
    IsPlayerAceAllowed=function(src,permission) assert(permission=='osinventory.admin');return f.admin[src] and 1 or 0 end
    RegisterCommand=function(name,fn) f.commands[name]=fn end
    RegisterNetEvent=function(name,fn) f.net[name]=fn end
    AddEventHandler=function(name,fn) f.events[name]=fn end
    TriggerClientEvent=function(name,src,...) f.messages[#f.messages+1]={name=name,src=src,args={...}} end
    exports=setmetatable({os_devtools={GetActiveCharacter=function(_,src) local p=f.identity.active(src);return p and {characterId=p.characterId,alias=p.alias,connected=true} end,
        ResolveCharacter=function(_,query) local p=f.identity.resolve(query);return p and {characterId=p.characterId,alias=p.alias} end,
        HasOscarPermission=function(_,src,permission) return src==2 and permission=='osinventory.admin' and f.delegated==true end}},
        {__call=function(_,name,fn) f.exports[name]=fn end})
    dofile('/repo/config/authorization.lua');dofile('/repo/server/admin_access.lua');dofile('/repo/server/main.lua');f.events.onResourceStart('os_inventory')
    function f.countNative(src,name) f.origin='os_inventory';return f.exports.GetItemCount(string.format('oschar_%010d',src),name) end
    return f
end
test('Actual commands enforce ACE zero, delegation and live revocation; console remains usable',function()
    local f=fixture();local before=f.writes
    for _,name in ipairs({'giveitem','removeitem','clearinventory','inspectinventory'}) do f.commands[name](2,{'1','agua','1'}) end
    assert(f.writes==before)
    f.commands.giveitem(1,{'2','agua','4'});assert(f.countNative(2,'agua')==4)
    f.delegated=true;f.commands.removeitem(2,{'2','agua','1'});assert(f.countNative(2,'agua')==3)
    f.delegated=false;f.commands.removeitem(2,{'2','agua','1'});assert(f.countNative(2,'agua')==3)
    f.commands.giveitem(0,{'2','agua','2'});assert(f.countNative(2,'agua')==5)
    f.commands.clearinventory(1,{'2'});assert(f.countNative(2,'agua')==5)
    f.commands.clearinventory(1,{'2','CONFIRMAR'});assert(f.countNative(2,'agua')==0)
end)
test('Actual network request uses private token, revision and server-derived owner; old unguarded move is removed',function()
    local f=fixture();f.commands.giveitem(1,{'2','agua','4'});source=2;f.net['osinventory:open'](1)
    local opened=f.messages[#f.messages].args[2];assert(opened.ok)
    local packet={token=opened.token,sequence=1,op='drop',args={revision=opened.inventory.revision,slot=1,expected=opened.inventory.slots['1'].id,count=2}}
    f.net['osinventory:request'](2,packet);assert(f.countNative(2,'agua')==2)
    f.net['osinventory:request'](3,packet);assert(f.countNative(2,'agua')==2)
    assert(not f.net['osinventory:move'] and not f.net['osinventory:grantAdmin'])
    f.origin='unknown';assert(not f.exports.AddItem('oschar_0000000002','agua',100))
end)
test('Character-change and provider-stop events invalidate active network sessions',function()
    local f=fixture();source=2;f.net['osinventory:open'](1);local opened=f.messages[#f.messages].args[2]
    f.events['osdev:characterChanged'](2);f.net['osinventory:request'](2,{token=opened.token,sequence=1,op='refresh',args={}})
    assert(f.messages[#f.messages].args[2].close)
    f.net['osinventory:open'](3);f.events.onResourceStop('os_devtools');assert(f.messages[#f.messages].name=='osinventory:forceClose')
end)
test('Player command transfers across multiple stacks in one journal mutation and rejects distant targets',function()
    local f=fixture();f.commands.giveitem(1,{'1','agua','25'});f.commands.daritem(1,{'2','agua','23'})
    assert(f.countNative(1,'agua')==2 and f.countNative(2,'agua')==23)
    f.commands.daritem(2,{'3','agua','1'});assert(f.countNative(2,'agua')==23)
end)
