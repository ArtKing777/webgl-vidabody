# 1 chmod +x test.sh
# 2 run server/main.coffee
clear
# test.js does not work with hashbang for some reason
../node_modules/.bin/slimerjs test.js
# uncomment to create 'expected' screenshots
#../node_modules/.bin/slimerjs test.js expected
