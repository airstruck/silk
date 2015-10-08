return function (config)
    config = config or {}
    config.webroot = config.webroot or '/'
    config.fileroot = config.fileroot or '/'
    config.extension = config.extension or '.lua.html'
    config.cache = config.cache or false
    config.code = config.code or '<%?lua(.-)%?>'
    config.echo = config.echo or '<%?=(.-)%?>'

    local read = love.filesystem.read
    local isFile = love.filesystem.isFile
    local isDirectory = love.filesystem.isDirectory

    local cache = {}

    return function (request, response)

        if not request.uri:match('^' .. config.webroot) then
            return false
        end

        local function throw (message)
            response.status = '500 Internal Server Error'
            response.header['Content-Type'] = 'text/plain'
            response:write(message)
            return
        end

        local filename = request.path:gsub('^' .. config.webroot,
            config.fileroot)

        if config.cache and cache[filename] then
            xpcall(function ()
                cache[filename](request, response)
            end, throw)
            return
        end

        if isDirectory(filename) then
            if not request.path:match '/$' then
                response.status = '302 Redirect'
                response.header['Location'] = request.uri .. '/'
                return
            end
            filename = filename .. 'index' .. config.extension
        end

        if not filename:match(config.extension .. '$') then
            return false
        end

        if not isFile(filename) then
            return false
        end

        xpcall(function ()
            local data = read(filename)
            local open = '\nresponse:write[============[\n'
            local close = ']============]\n'
            local script = 'local request,response=...' .. open .. data
                :gsub(config.echo, close .. 'response:write(%1)' .. open)
                :gsub(config.code, close .. '%1' .. open) .. close
            if config.cache then
                cache[filename] = loadstring(script)
                cache[filename](request, response)
            else
                loadstring(script)(request, response)
            end
        end, throw)

        response.status = response.status or '200 Success'
        response.header['Content-Type'] = response.header['Content-Type'] or
            'text/html'
    end
end
