local api = {}

local host, port = "127.0.0.1", 8080
local socket = require("socket")
local tcp = assert(socket.tcp())


tcp:connect(host, port);

function api.sleep(sec)
    socket.select(nil, nil, sec)
end


function api.print(str,x,y,col)
	local thing = string.format("(api.print \"%s\" %d %d %d)\n",str,x,y,col)
	tcp:send(thing)
	tcp:receive("*l")
end

function api.cls(frame)
	local thing = string.format("(api.cls %d)\n",frame)
	tcp:send(thing)
	tcp:receive("*l")
end

function api.flip()
	local thing = string.format("(api.flip)\n")
	tcp:send(thing)
	tcp:receive("*l")
end

return api
