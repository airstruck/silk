return function (config)
    config = config or {}
    config.webroot = config.webroot or '/'
    config.fileroot = config.fileroot or '/'
    config.mime = config.mime or {}

    local mime = config.mime
    mime.html = mime.html or 'text/html'
    mime.css = mime.css or 'text/css'
    mime.js = mime.js or 'text/javascript'
    mime.png = mime.png or 'image/png'
    -- TODO: add more common mime types here

    local read = love.filesystem.read
    local isFile = love.filesystem.isFile
    local isDirectory = love.filesystem.isDirectory
    local getLastModified = love.filesystem.getLastModified

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

        if isDirectory(filename) then
            if not request.path:match '/$' then
                response.status = '302 Redirect'
                response.header['Location'] = request.uri .. '/'
                return
            end
            filename = filename .. 'index.html'
        end

        if not isFile(filename) then
            return false
        end

        local etag = tostring(getLastModified(filename))
        if request.header['If-None-Match'] == etag then
            response.status = '304 Not Modified'
            return
        end

        local data
        xpcall(function ()
            data = read(filename)
        end, throw)

        local mimetype = mime[filename:match '[^.]*$'] or 'text/plain'

        response.status = '200 Success'
        response.header['Content-Type'] = mimetype
        response.header['Cache-Control'] = 'private'
        response.header['Etag'] = etag
        response:write(data)
    end
end
