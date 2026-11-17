fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'OSCAR / OS Inventory'
description 'Inventario standalone de desarrollo con NUI tecla I y persistencia'
version '0.2.0'
shared_scripts { 'shared/items.lua', 'shared/food.lua', 'shared/weapons.lua', 'shared/keys.lua', 'shared/jobs_items.lua' }
server_scripts {
 'config/server.lua', 'config/authorization.lua', 'server/lib/util.lua',
 'server/storage/codec.lua', 'server/storage/resource_files.lua', 'server/storage/json.lua',
 'config/shops.lua', 'server/identity.lua', 'server/domain.lua', 'server/store.lua', 'server/service.lua', 'server/panel_track.lua',
 'server/admin_access.lua', 'server/admin_section.lua', 'server/main.lua'
}
client_scripts { 'config/client.lua', 'config/shops.lua', 'client/controller.lua', 'client/look.lua', 'client/hotbar.lua', 'client/weapons.lua', 'client/shop.lua', 'client/swipe.lua', 'client/main.lua' }
ui_page 'web/index.html'
files { 'web/index.html', 'web/style.css', 'web/app.js', 'web/icons.svg', 'data/.gitkeep' }
