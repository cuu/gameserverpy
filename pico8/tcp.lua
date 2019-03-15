
local TCP = {}

local host, port = "127.0.0.1", 8080
local socket = require("socket")
local tcp = assert(socket.tcp())

function TCP.connect()
  tcp:connect(host, port);
  tcp:settimeout(5)
 
end


function TCP.send(data)
  local ret,msg
  local ret2
  -- print("safe_tcp_send data is " ,data ,#data)
  if #data == 0 then 
    print("data is zero",data)
    return
  end

  local datalength = string.format("%08d",#data)
  data = datalength..data

  ret,msg = tcp:send(data)
  if(ret ~= nil) then
      ret2 = tcp:receive("*l")
      return ret2
    else
      print("exiting...",msg)
      os.exit()
  end
  
end

function safe_tcp_send_old(data)
	local ret,msg
	local ret2
	-- print("safe_tcp_send data is " ,data ,#data)
  if #data == 0 then 
    print("data is zero",data)
    return
  end

  local datalength = string.format("%08d",#data)

  ret,msg = tcp:send(datalength)
  if ret ~= nil then
      ret,msg = tcp:receive("*l")
      if ret == nil then
        print("data length header error",ret,msg)
        os.exit()
      end
  end

	ret,msg = tcp:send(data)

	if(ret ~= nil) then
	  	ret2 = tcp:receive("*l")
	    return ret2
	  else
	   	print("exiting...",msg)
	    os.exit()
	end
  
end


return TCP



