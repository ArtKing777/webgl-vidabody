'use strict'

var webpack = require('webpack')

module.exports = {
    context: __dirname,
    cache: true,
    debug: true,
    entry: [
        __dirname + '/client_main.coffee',
    ],
    stats: {
        colors: true,
        reasons: true
    },
    module: {
        loaders: [{
            test: /\.coffee$/,
            loaders: [
                // Install react-hot-loader for reloading react components
                // 'react-hot',
                'coffee-loader',
                'source-map-loader'
            ]
        }]
    },
    resolve: {
        // Not necessary after we remove old_modules
        extensions: ["", ".webpack.js", ".web.js", ".js", ".coffee"]
    },
    output: {
        path: __dirname + '/../build/',
        filename: "dragonfly.js",
        library: "VidaBody"
    },
    plugins: [
        new webpack.optimize.OccurrenceOrderPlugin(),
        new webpack.optimize.DedupePlugin(),
        new webpack.optimize.UglifyJsPlugin({
            compress: {
                screw_ie8: true, // React doesn't support IE8
                warnings: false
            },
            mangle: {
                screw_ie8: true
            },
            output: {
                comments: false,
                screw_ie8: true
            }
        }),
        // new webpack.optimize.UglifyJsPlugin(),
        new webpack.BannerPlugin([
            "/**",
            " * VidaBody",
            " *",
            " * Copyright 2015, VidaSystems, Inc.",
            " * All rights reserved.",
            " *",
            " * This application makes use of third-party, open source modules.",
            " * The full licenses for all third-party modules is available in the CREDITS file.",
            " */"
        ].join("\n"), {
            raw: true
        }),
        new webpack.DefinePlugin({
            "process.env": {
                NODE_ENV: '"production"'
            },
            "VIDA_BODY_BUILD_DATE": JSON.stringify((Date() + '').split(
                '(')[0])
        })
    ],
    node: {
        Buffer: true,
    },
}
