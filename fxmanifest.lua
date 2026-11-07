fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'OSCAR / OS Inventory'
description 'Inventario standalone de desarrollo con NUI F2 y persistencia'
version '0.1.0-pretest.1'
shared_scripts { 'shared/items.lua' }
server_scripts { 'config/authorization.lua', 'server/admin_access.lua', 'server/main.lua' }
client_scripts { 'client/main.lua' }
ui_page 'html/index.html'
files { 'html/index.html', 'html/style.css', 'html/app.js' }
