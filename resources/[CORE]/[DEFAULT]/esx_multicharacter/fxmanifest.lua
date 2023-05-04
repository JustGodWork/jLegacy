fx_version 'cerulean'
game 'gta5'
author 'ESX-Framework - Linden - KASH'
description 'Official Multicharacter System For ESX Legacy'
version '1.9.4'
lua54 'yes'

dependencies {'jlegacy', 'esx_context', 'esx_identity', 'esx_skin'}

shared_scripts {'@jlegacy/imports.lua', '@jlegacy/locale.lua', 'locales/*.lua', 'config.lua'}

server_scripts {'@oxmysql/lib/MySQL.lua', 'server/*.lua'}

client_scripts {'client/*.lua'}

ui_page {'html/ui.html'}

files {'html/ui.html', 'html/css/main.css', 'html/js/app.js', 'html/locales/*.js'}
