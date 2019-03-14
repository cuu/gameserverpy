
local host, port = "127.0.0.1", 8080
local socket = require("socket")
local tcp = assert(socket.tcp())

tcp:connect(host, port);
tcp:settimeout(5)

function safe_format(formatstring,...)
        return string.format(formatstring.."\n",...)
end

function safe_tcp_send(data)
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


while true do

	local ret = safe_tcp_send("(draw.flip)\n")
	print(ret)

end

