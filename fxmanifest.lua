fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'OSCAR / OS Inventory'
description 'Inventario standalone de desarrollo con NUI F2 y persistencia'
version '0.1.0'
shared_scripts { 'shared/items.lua' }
server_scripts {
 'config/server.lua', 'config/authorization.lua', 'server/lib/util.lua',
 'server/storage/codec.lua', 'server/storage/resource_files.lua', 'server/storage/json.lua',
 'server/identity.lua', 'server/domain.lua', 'server/store.lua', 'server/service.lua',
 'server/admin_access.lua', 'server/main.lua'
}
client_scripts { 'config/client.lua', 'client/controller.lua', 'client/main.lua' }
ui_page 'web/index.html'
files { 'web/index.html', 'web/style.css', 'web/app.js', 'web/icons.svg', 'data/.gitkeep' }
