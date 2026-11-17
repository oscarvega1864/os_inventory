-- Objetos de EMS y policia. El botiquin lo gasta un medico de servicio al reanimar (os_life); la venda se usa para
-- curarse un poco (se consume y os_life cura); las esposas las necesita un policia de servicio para esposar (os_police).
local function item(name, label, weight, stack, description, category, icon, consume)
    OSInventoryItem(name, label, weight, stack, description, category, icon, consume and { builtinUse = 'consume' } or nil)
end
item('botiquin', 'Botiquin', 1.2, 5, 'Material de urgencias. Un medico de servicio lo gasta al reanimar a alguien inconsciente.', 'medico', 'box')
item('venda', 'Venda', 0.05, 20, 'Usar para curar una herida leve (recupera algo de salud).', 'medico', 'box', true)
item('esposas', 'Esposas', 0.4, 2, 'Para esposar a un detenido. Solo policia de servicio.', 'policia', 'tool')
