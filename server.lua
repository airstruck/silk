local socket = require 'socket'

local tinsert = table.insert
local tremove = table.remove
local tconcat = table.concat

local function Request (client)
    local request = { header = {} }
    local data, status, part = client:receive()

    if status then
        print('error getting data from client: ' .. status)
        return
    end

    request.method, request.uri, request.protocol =
        data:match '^(%a+)%s+(.-)%s+(.*)$'

    request.path = request.uri:match '^[^?]+'
    request.query = request.uri:match '?(.+)$'

    while data ~= '' do
        data, status, part = client:receive()
        local k, v = data:match '^(.-):%s+(.*)$'
        if status then print ('error receiving headers: ' .. status) end
        if k and v then request.header[k] = v end
    end

    local len = tonumber(request.header['Content-Length'])

    if len and len > 0 then
        data, status, part = client:receive(len)
        if status then print ('error receiving body: ' .. status) end
        request.data = data
    end

    return request
end

local function Response (client)
    local isSent

    return {
        header = {},

        body = {},

        write = function (self, data)
            tinsert(self.body, data)
        end,

        send = function (self)
            if isSent then
                return
            end

            isSent = true

            if not self.status then
                self.status = '200 Success'
            end

            local head = { 'HTTP/1.0 ' .. self.status }
            local body = tconcat(self.body)

            for k, v in pairs(self.header) do
                tinsert(head, k .. ': ' .. v)
            end

            client:send(tconcat(head, '\n') ..
                '\nContent-Length: ' .. #body .. '\n\n' .. body)
        end,
    }
end

local Server = {}

function Server:plug (plugin)
    self.plugins[#self.plugins + 1] = plugin
end

function Server:process (request, response)
    for _, plugin in ipairs(self.plugins) do
        if plugin(request, response) ~= false then
            return true
        end
    end
end

function Server:handle (request, response)
    if not self:process(request, response) then
        response.status = '404 Not Found'
        response.header['Content-Type'] = 'text/plain'
        response:write('Resource unavailable.')
    end
end

function Server:update ()
    xpcall(
        function ()
            local timeout = self.timeout
            local clients = self.clients
            local client = self.socket:accept()

            if client then
                client:settimeout(timeout)
                tinsert(clients, client)
            end

            local selected, _, err = socket.select(clients, nil, timeout)
            if err and err ~= 'timeout' then
                print('error: ' .. err)
            end

            for i, client in ipairs(selected) do
                local request, response = Request(client), Response(client)
                if request and response then
                    self:handle(request, response)
                    response:send()
                end
                client:close()
                tremove(clients, i)
            end
        end,

        function (status)
            if not status:match 'interrupted!$' then
                print(status)
            end
        end
    )
end

return function (server)
    server = server or {}
    server.address = server.address or 'localhost'
    server.port = server.port or 8080
    server.timeout = server.timeout or 0.001
    server.plugins = server.plugins or {}
    server.clients = {}
    server.socket = socket.bind(server.address, server.port)
    server.socket:settimeout(server.timeout)
    return setmetatable(server, { __index = Server })
end
