fx_version 'adamant'

game 'gta5'

description 'ESX Skin'

version '1.9.4'
lua54 'yes'
shared_script '@jlegacy/imports.lua'

server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'@jlegacy/locale.lua',
	'locales/*.lua',
	'config.lua',
	'server/main.lua'
}

client_scripts {
	'@jlegacy/locale.lua',
	'locales/*.lua',
	'config.lua',
	'client/main.lua'
}

dependencies {
	'jlegacy',
	'skinchanger'
}
