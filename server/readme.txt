Install node.js and use this command to install the dependencies:

    npm install
    sudo npm install -g coffe-script
    # For debugging
    sudo npm install -g node-inspector

Read the wiki for instructions on PostgreSQL and change the username/password.

Run:

    coffee main.coffee
    # Add "#server=http://127.0.0.1:7654/" to the app url without quotes

Debug:
    
    # Run node-inspector if not running already
    node-inspector &
    # Run compiled sources so they have source maps
    coffee -cm *.coffee && node --debug main.js
    # or --debug-brk to start paused
    # then go to http://127.0.0.1:8080/debug?port=5858
