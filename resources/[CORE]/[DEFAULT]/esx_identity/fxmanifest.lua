fx_version 'adamant'

game 'gta5'

description 'ESX Identity'
lua54 'yes'
version '1.9.4'

shared_scripts {
	'@jlegacy/imports.lua',
	'@jlegacy/locale.lua',
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'locales/*.lua',
	'config.lua',
	'server/main.lua'
}

client_scripts {
	'locales/*.lua',
	'config.lua',
	'client/main.lua'
}

ui_page 'html/index.html'

files {
	'html/index.html',
	'html/js/script.js',
	'html/css/style.css',
}

dependency 'jlegacy'