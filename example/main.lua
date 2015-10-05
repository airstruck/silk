-- instantiate server
local server = require 'silk.server' { address = 'localhost', port = 8080 }

-- use static file server plugin
server:plug(require 'silk.plugin.static' {
    webroot = '/files/', -- plugin will process if URI begins with this
    fileroot = '/static/', -- path for love.filesystem to look in
})

-- use active lua pages
server:plug(require 'silk.plugin.active' {
    webroot = '/page/', -- plugin will process if URI begins with this
    fileroot = '/active/', -- path for love.filesystem to look in
})

-- default response via custom plugin
-- (example, this happens anyway if plugins can't process request)
server:plug(function (request, response)
    response.status = '404 Not Found'
    response.header['Content-Type'] = 'text/plain'
    response:write('Resource unavailable.')
end)

-- handle requests
function love.update (dt)
    server:update()
end
