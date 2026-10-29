fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 't0_pressurewasher'
author 'Tiago'
description 'Standalone pressure washer addon weapon for ox_inventory'
version '1.0.0'

dependencies { 'ox_lib', 'ox_inventory' }

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/remote.lua',
    'client/refill.lua',
}

server_scripts {
    'server/main.lua',
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
    'web/images/pressure_washer.png',
    'data/weapons.meta',
    'data/weaponanimations.meta',
    'data/weaponarchetypes.meta',
}

-- Addon weapon WEAPON_PRESSUREWASHER (rifle handling, no damage, no real shot).
data_file 'WEAPONINFO_FILE' 'data/weapons.meta'
data_file 'WEAPON_ANIMATIONS_FILE' 'data/weaponanimations.meta'
data_file 'WEAPON_METADATA_FILE' 'data/weaponarchetypes.meta'
