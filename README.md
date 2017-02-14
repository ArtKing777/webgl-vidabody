What are all these folders and files:


client
    client side sources

doc
    eventually there might be something here

pipeline_scripts
    scripts used for importing/converting/exporting/packing scenes, meshes and
    textures; some are used within blender using the script run_pipeline_script

server
    server side sources (check this folder for its own readme)

static_app_files
    various stuff needed for client side (images, fonts, libs)

utils
    scripts that don't fit anywhere else

Makefile
    Once you check out this branch, and download assets subfolder (from Seafile
    server), you can run 'make pack' command to create the build.
    
    Following builds that do not require new assets could be done by pulling from
    git and running 'make' command. The result is build folder that can be copied
    to or specified as local web server root for testing the application.

wercker.yml
    Settings file for wercker.com
