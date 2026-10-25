fx_version 'cerulean'
game {'gta5'}

author 'vezironi'
description ''

scriptname 'hype-vendingmachine'
version '1.0.0'

dependencies {
    'ox_lib',
}

shared_scripts {
    '@ox_lib/init.lua',
    'shared/utils.lua',
    'shared/main.lua',
    'config/config.lua',
}

client_scripts {
    'client/*.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua',
}

escrow_ignore {
    'config/*.lua',
    'shared/*.lua',
    'server/*.lua',
    'install/*.sql',
    'locales/*.json',
}

files {
    'config/*.lua',
    'shared/*.lua',
    'web/dist/*.*',
    'web/dist/**/*.*',
    'locales/*.json',
}

ui_page 'web/dist/index.html'

lua54 'yes'
use_experimental_fxv2_oal 'yes'