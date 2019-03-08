local api = {}

local host, port = "127.0.0.1", 8080
local socket = require("socket")
local tcp = assert(socket.tcp())

tcp:connect(host, port);

local function safe_tcp_send(data)
	local ret,msg
	local ret2
	
	ret,msg = tcp:send(data)
	if(ret ~= nil) then
		ret2 = tcp:receive("*l")
		return ret2
	else
		print("exiting...",msg)
		os.exit()
	end
end

function api.sleep(sec)
    socket.select(nil, nil, sec)
end


function api.print(str,x,y,col)
	local thing = string.format("(api.print \"%s\" %d %d %d)\n",str,x,y,col)
	safe_tcp_send(thing)
end

function api.cls(frame)
	local thing = string.format("(api.cls %d)\n",frame)
	safe_tcp_send(thing)
end

function api.flip()
	local thing = string.format("(api.flip)\n")
	safe_tcp_send(thing)
end

return api
