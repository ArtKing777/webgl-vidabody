


# host = location?.host or ''
# if /\.pearsoncmg\.com$|pearsoncmg-com\.vidabody\.com$/.test(host)
#     if window.vidabody_app_path and /^http/.test(window.vidabody_app_path)
#         host = window.vidabody_app_path.split('/')[2]
#     SERVER_BASE = "https://#{host}/server/"
#     ASSETS_BASE = "https://#{host}/assetver/"
#     window.is_pearson = true
#     window.hide_tour_list = window.vidabody_app_path?


SERVER_BASE = '/server/'
ASSETS_BASE = '/assetver/'

ASSETS_VERSION = 'dev'
if window.is_pearson
    ASSETS_VERSION = '49'

# For storage in tours
ASSETS_VERSION_NAME = ASSETS_VERSION

# If localhost, grab assets from localhost, with a different origin for testing
host = location?.host.split(':')[0]
if host == 'localhost'
    ASSETS_BASE = "http://127.0.0.1:#{location.port}/vb1/assetver/"
else if host == '127.0.0.1'
    ASSETS_BASE = "http://localhost:#{location.port}/vb1/assetver/"

# If dev assets, grab them from build
else if ASSETS_VERSION == 'dev'
    build_number = location.pathname.replace(/\/*$/,'').split('/').pop()
    ASSETS_VERSION_NAME = 'dev'+build_number
    ASSETS_BASE = 'assetver/'

# See client_dev
if /^#options=/.test(location?.hash)
    sessionStorage.options = location.hash[9...].replace(/%22/g,'"')
    if history.replaceState then history.replaceState('','','#') else location.hash = ''

is_live_server = false
if sessionStorage?.options
    options = JSON.parse decodeURIComponent sessionStorage.options
    if options.server
        SERVER_BASE = options.server
    if options.assetver
        ASSETS_VERSION = options.assetver
        # For debug server in blender plugin
        if /^http:/.test options.assetver
            ASSETS_BASE = ''
            is_live_server = true

# In production, this path should use static routes instead of node.js
FILE_SERVER_DOWNLOAD_API = SERVER_BASE+'files/' # files/<file hash>

SEARCH_API = SERVER_BASE+'search/'
UPLOAD_API = SERVER_BASE+'upload'
UPLOAD_SETTINGS_API = SERVER_BASE + 'upload_settings'
AUTH_URL = SERVER_BASE+'users/'
REGISTER_API = AUTH_URL+'register'
LOGIN_API = AUTH_URL+'login'
GETINFO_API = AUTH_URL+'getinfo'

USE_PHYSICS = false

if not window?.vidabody_app_path?
    window?.vidabody_app_path = ''


window?.Module = {TOTAL_MEMORY: 128 * 1048576} # 128 mb for ammo.js
window?.MYOU_PARAMS =
    total_size: 26775095
    debug: not window?.vidabody_app_path
    live_server: is_live_server
    data_dir: ASSETS_BASE + ASSETS_VERSION + '/'
    scripts_dir: vidabody_app_path
    inital_scene: "Scene"
    load_physics_engine: USE_PHYSICS
    on_no_s3tc_support: ->
        require('../views/error_screens').show_webgl_failed_error()
        # alert "Sorry, your graphic drivers don't have support for compressed textures."
    on_context_lost: -> require('../views/error_screens').show_context_lost_error()
    on_context_restored: -> require('../views/error_screens').hide_context_lost_error()
    on_webgl_failed: -> require('../views/error_screens').show_webgl_failed_error()
    on_init_physics_error: -> require('../views/error_screens').show_low_memory_error()
    
    no_mipmaps: !!(options?.no_mipmaps)
    no_s3tc: !!(options?.no_s3tc) or navigator.userAgent.toString().indexOf('Edge/1')!=-1 or !!window.no_s3tc
    
        
exports.SERVER_BASE = SERVER_BASE
exports.ASSETS_VERSION = ASSETS_VERSION
exports.ASSETS_BASE = ASSETS_BASE
exports.FILE_SERVER_DOWNLOAD_API = FILE_SERVER_DOWNLOAD_API
