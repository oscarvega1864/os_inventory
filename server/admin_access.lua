OSInventoryAdminAccess={}
function OSInventoryAdminAccess.new(options)
    return function(source)
        if type(source)~='number' or source%1~=0 or source<0 or source>2147483647 then return false end
        if source==0 then return true end
        local native=options.ace(source,options.permission)
        if native==true or native==1 then return true end
        if not options.resource then return false end
        local ok,allowed=pcall(function()
            if options.state(options.resource)~='started' then return false end
            return options.delegate(options.resource,source,options.permission)
        end)
        return ok and allowed==true
    end
end
