local api = {}
local draw = {}

local __keymap = {
  [0] = {
    [0] = 'left',
    [1] = 'right',
    [2] = 'up',
    [3] = 'down',
    [4] = 'u',
    [5] = 'i',
    [6] = 'return',
    [7] = 'escape',
  }
}

local pico8 = {
  clip = nil, 
  fps = 30,
  screen = nil, 
  palette = {
    {0,0,0,255},
    {29,43,83,255},
    {126,37,83,255},
    {0,135,81,255},
    {171,82,54,255},
    {95,87,79,255},
    {194,195,199,255},
    {255,241,232,255},
    {255,0,77,255},
    {255,163,0,255},
    {255,240,36,255},
    {0,231,86,255},
    {41,173,255,255},
    {131,118,156,255},
    {255,119,168,255},
    {255,204,170,255}
  },
  color = nil, 
  spriteflags = {},
  map = {},
  audio_channels = {},
  sfx = {},
  music = {},
  current_music = nil, 
  cursor = {0, 0},
  camera_x = 0, 
  camera_y = 0, 
  draw_palette = {},
  display_palette = {},
  pal_transparent = {},
}


local host, port = "127.0.0.1", 8080
local socket = require("socket")
local tcp = assert(socket.tcp())

tcp:connect(host, port);
tcp:settimeout(0.5)

function safe_format(formatstring,...)	
	return string.format(formatstring.."\n",...)
end

function safe_tcp_send(data)
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

function draw.scroll(dy)
	dy = dy or 0
	local thing = safe_format("(draw.scroll %d)",dy)
	return safe_tcp_send(thing)
end

function draw.print(str,x,y,col)
	local thing = safe_format("(draw.print \"%s\" %d %d %d)",str,x,y,col)
	return safe_tcp_send(thing)

end

function draw.cls(frame)
	local thing = safe_format("(draw.cls %d)",frame)
	return safe_tcp_send(thing)

end

function draw.flip()
	local thing = safe_format("(api.flip)")
	return safe_tcp_send(thing)
end

function draw.point(x,y,r,g,b,a)
	local thing = safe_format("(draw.point  %d %d %d %d %d %d)",x,y,r,g,b,a)
	return safe_tcp_send(thing)
end

function draw.btn(codestr,playernumber)
	local thing = safe_format("(draw.btn \"%s\" %d)", codestr,playernumber)
	return safe_tcp_send(thing)
end

function api.sleep(sec)
    socket.select(nil, nil, sec)
end

function api.color(c)
  c = c and math.floor(c) or 0 
  assert(c >= 0 and c <= 16,string.format('c is %s',c))
  pico8.color = c

--  love.graphics.setColor(c*16,0,0,255)
end

function api.pset(x,y,c)
  if not c then return end 
  api.color(c)
  draw.point(math.floor(x),math.floor(y),c*16,0,0,255)
end


function api.print(str,x,y,col)
  if col then api.color(col) end 
  local canscroll = y==nil
  if y==nil then
    y = pico8.cursor[2]
    pico8.cursor[2] = pico8.cursor[2] + 6 
  end 
  if x==nil then
    x = pico8.cursor[1]
  end 
  if canscroll and y > 121 then
    local c = col or pico8.color
    draw.scroll(6)
    y = 120 
    api.rectfill(0,y,127,y+6,0)
    api.color(c)
    api.cursor(0, y+6)
  end 
	draw.print(str,x,y,col)		
end

function api.cursor(x,y)
  pico8.cursor = {x,y}
end


function api.cls(frame)
	frame = frame or 0
	draw.cls(frame)
end

function api.flip()
	draw.flip()
end

function api.btn(i,p)
	local thing
	local ret

	if type(i) == 'number' then
		p = p or 0
		if __keymap[p] and __keymap[p][i] then
				ret = draw.btn( __keymap[p][i],p)
				if ret == "TRUE" then
					return true
				else 
					return false
				end
		end
	end
	
	return false
	
end


function api.min(a,b)
  if a == nil or b == nil then 
    print('min a or b are nil returning 0')
    return 0
  end  
  return a < b and a or b 
end

function api.max(a,b)
  if a == nil or b == nil then 
    print('max a or b are nil returning 0')
    return 0
  end  
  return a > b and a or b 
end

function api.mid(x,y,z)
  x, y, z = x or 0, y or 0, z or 0 
  if x > y then x, y = y, x end
  return api.max(x, api.min(y, z))
end

assert(api.min(1, 2) == 1)
assert(api.min(2, 1) == 1)

assert(api.max(1, 2) == 2)
assert(api.max(2, 1) == 2)

assert(api.mid(1, 2, 3) == 2)
assert(api.mid(1, 3, 2) == 2)
assert(api.mid(2, 1, 3) == 2)
assert(api.mid(2, 3, 1) == 2)
assert(api.mid(3, 1, 2) == 2)
assert(api.mid(3, 2, 1) == 2)



api.flr = math.floor
function api.cos(x) return math.cos((x or 0)*(math.pi*2)) end
function api.sin(x) return math.sin(-(x or 0)*(math.pi*2)) end
function api.atan2(x,y) return (0.75 + math.atan2(x,y) / (math.pi * 2)) % 1.0 end

assert(api.atan2(1, 0) == 0)
assert(api.atan2(0,-1) == 0.25)
assert(api.atan2(-1,0) == 0.5) 
assert(api.atan2(0, 1) == 0.75)
api.sqrt = math.sqrt
function api.sgn(x)
  if x < 0 then 
    return -1
  else 
    return 1
  end  
end

api.sub = string.sub

function api.shutdown()
	os.exit()
end

function api.stat(x)
  return 0
end


return api
