var WebpackDevServer = require('webpack-dev-server')
var webpack = require('webpack')

var config = require('./webpack.config.js')
config.plugins = [
    new webpack.DefinePlugin({
        "process.env": {
            NODE_ENV: '"development"'
        },
        "VIDA_BODY_BUILD_DATE": JSON.stringify((Date()+'').split('(')[0])
    }),
    new webpack.HotModuleReplacementPlugin(),
    new webpack.NoErrorsPlugin()//,
    // new webpack.SourceMapDevToolPlugin(
    //     'bundle.js.map', null,
    //     "[absolute-resource-path]", "[absolute-resource-path]")
]

config.devtool = 'inline-source-map';

config.entry.unshift(
    'webpack-dev-server/client?http://127.0.0.1:8087',
    'webpack/hot/only-dev-server'
)

var server = new WebpackDevServer(webpack(config), {
    contentBase: __dirname + "/../build",
    hot: true,
    lazy: false,
    watchDelay: 300,
    stats: { colors: true },
    headers: { "Access-Control-Allow-Origin": "*" }
})

// temporary hack while we use make
var exec = require('child_process').exec;
server.app.use(/\//, function(req, res, next){
    console.log('running make')
    var command = 'make -C ' + __dirname + '/.. scripts copy_static >&2';
    exec(command, function(err, stdout, stderr) {
      if (err) {
        console.error('Error while running command');
        console.error('"' + command + '"');
        res.statusCode = 500
        return res.end(stderr);
      }
      next();
    });
})
server.app._router.stack.unshift(server.app._router.stack.pop())

server.app.use(/.*\.css/, function(req, res, next){
    console.log('rebuilding styles')
    exec('make -C ' + __dirname + '/.. styles >&2', function(err, stdout, stderr) {
      if (err) {
        res.statusCode = 500
        return res.end(stderr);
      }
      next();
    });
})
server.app._router.stack.unshift(server.app._router.stack.pop())


server.listen(8087, 'localhost', function() {})
