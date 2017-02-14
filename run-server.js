#!/usr/bin/env node

[ // ];node $0;exit # This will run if you accidentally run me with 'sh'
]

require(__dirname+'/node_modules/iced-coffee-script/register');
// API server
require(__dirname+'/server/main');
// client dev server (webpack)
require(__dirname+'/client/devserver');
