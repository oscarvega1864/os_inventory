-- Vista del personaje al abrir el inventario (camara con el personaje a la izquierda) y accesorios que se
-- quitan o se ponen desde el inventario: mascara, sombrero, gafas, pendientes, reloj y pulsera. Lo quitado se
-- recuerda para volver a ponerlo igual; al cambiar de modelo se olvida.
OSInventory=OSInventory or {}
OSInventory.Look={}
local ACCESSORIES={
    {id='mask',label='Mascara',component=1},{id='hat',label='Sombrero',prop=0},{id='glasses',label='Gafas',prop=1},
    {id='ears',label='Pendientes',prop=2},{id='watch',label='Reloj',prop=6},{id='bracelet',label='Pulsera',prop=7}
}
local removed,removedModel,cam={},nil,nil

local function worn(ped,a)
    if a.component then return GetPedDrawableVariation(ped,a.component)~=0 end
    return GetPedPropIndex(ped,a.prop)~=-1
end
function OSInventory.Look.accessories()
    local ped=PlayerPedId()
    if GetEntityModel(ped)~=removedModel then removed={};removedModel=GetEntityModel(ped) end
    local list={}
    for _,a in ipairs(ACCESSORIES) do
        local on=worn(ped,a)
        list[#list+1]={id=a.id,label=a.label,worn=on,available=on or removed[a.id]~=nil}
    end
    return list
end
function OSInventory.Look.toggle(id)
    local ped=PlayerPedId()
    for _,a in ipairs(ACCESSORIES) do
        if a.id==id then
            if worn(ped,a) then
                if a.component then
                    removed[id]={GetPedDrawableVariation(ped,a.component),GetPedTextureVariation(ped,a.component),GetPedPaletteVariation(ped,a.component)}
                    SetPedComponentVariation(ped,a.component,0,0,0)
                else
                    removed[id]={GetPedPropIndex(ped,a.prop),GetPedPropTextureIndex(ped,a.prop)}
                    ClearPedProp(ped,a.prop)
                end
            elseif removed[id] then
                local saved=removed[id];removed[id]=nil
                if a.component then SetPedComponentVariation(ped,a.component,saved[1],saved[2],saved[3])
                else SetPedPropIndex(ped,a.prop,saved[1],saved[2],true) end
            end
            return
        end
    end
end
function OSInventory.Look.start()
    if not OSInventory.ClientConfig.Camera or cam then return end
    local ped=PlayerPedId()
    if IsPedInAnyVehicle(ped,false) or IsEntityDead(ped) then return end
    -- Camara delante del personaje, apuntando a un punto a su lado: el personaje queda a la izquierda.
    local from=GetOffsetFromEntityInWorldCoords(ped,0.35,2.7,0.35)
    local at=GetOffsetFromEntityInWorldCoords(ped,-0.95,0.0,0.05)
    cam=CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA',from.x,from.y,from.z,0.0,0.0,0.0,45.0,false,2)
    PointCamAtCoord(cam,at.x,at.y,at.z)
    SetCamActive(cam,true)
    RenderScriptCams(true,true,350,true,true)
end
function OSInventory.Look.stop()
    if not cam then return end
    RenderScriptCams(false,true,300,true,true)
    DestroyCam(cam,false)
    cam=nil
end
