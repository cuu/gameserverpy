log = print
local api = { loaded_code = nil }

local draw = {}

local bit = require('bit')

api.band = bit.band
api.bor = bit.bor
api.bxor = bit.bxor
api.bnot = bit.bnot
api.shl = bit.lshift
api.shr = bit.rshift


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

api.pico8 = pico8 

local host = "/tmp/gs"
local socket = require("socket")
socket.unix =  require("socket.unix")

local tcp = assert(socket.unix())

assert(tcp:connect(host));
--tcp:settimeout(5)

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
	local thing = safe_format("(draw.flip)")
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

function draw.spr(n,x,y,w,h,flip_x,flip_y)
  local thing = safe_format("(draw.spr %d %d %d %d %d %d %d)", n,x,y,w,h,flip_x,flip_y)
  return safe_tcp_send(thing)

end

function draw.map(cel_x,cel_y,sx,sy,cel_w,cel_h,bitmask)
  local thing = safe_format("(draw.map %d %d %d %d %d %d %d)",cel_x,cel_y,sx,sy,cel_w,cel_h,bitmask)
  return safe_tcp_send(thing)
end

function send_pico8_version(version)
  local thing = safe_format("(pico8 %d)", version)
  safe_tcp_send(thing)
end

function send_resource_done()
  local thing = "(res.done)"

  safe_tcp_send(thing)

end

function send_resource(res_type,res_data)
  if res_data == nil or #res_data == 0  then 
    return 
  end

  local thing = safe_format("(res \"%s\")", res_type)

  safe_tcp_send(thing)

  thing = res_data
  local ret = safe_tcp_send(thing)
  if ret == nil then
    print("the ret of res_data is ", ret,res_type,#res_data)
  end

  thing = "(res.over)\n"
  ret = safe_tcp_send(thing)
  --print("the ret of res.over is ", ret)

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


local function read_file(path)
    local file = io.open(path, "rb") -- r read mode and b binary mode
    if not file then return nil end
    local content = file:read "*a" -- *a or *all reads the whole file
    local size = file:seek("end")
    file:close()
    return content,size
end

function api.load_p8_text(filename)
  log('Loading',filename)

  local lua = ''
  local gfxdata = nil
  local sfxdata = nil
  local gffdata = nil
  local musicdata = nil
  local mapdata = nil 

  pico8.map = {}
  local __pico_quads = {}
  for y=0,63 do
    pico8.map[y] = {}
    for x=0,127 do
      pico8.map[y][x] = 0
    end
  end
  -- __pico_spritesheet_data = bmp.newImageData(128,128)
  pico8.spriteflags = {}

  pico8.sfx = {}
  for i=0,63 do
    pico8.sfx[i] = {
      speed=16,
      loop_start=0,
      loop_end=0
    }
    for j=0,31 do
      pico8.sfx[i][j] = {0,0,0,0}
    end
  end
  pico8.music = {}
  for i=0,63 do
    pico8.music[i] = {
      loop = 0,
      [0] = 1,
      [1] = 2,
      [2] = 3,
      [3] = 4
    }
  end
  local eol_chars = '\n'
    -- read text p8 code file
  local data,size = read_file(filename)
  if not data or size == 0 then
    error(string.format('Unable to open %s',filename))
  end
  local header = 'pico-8 cartridge // http://www.pico-8.com\nversion '
  local start = data:find('pico%-8 cartridge // http://www.pico%-8.com\nversion ')
  if start == nil then
    header = 'pico-8 cartridge // http://www.pico-8.com\r\nversion '
    start = data:find('pico%-8 cartridge // http://www.pico%-8.com\r\nversion ')
    if start == nil then
      error('invalid cart')
    end
    eol_chars = '\r\n'
  else
    eol_chars = '\n'
  end

  local next_line = data:find(eol_chars,start+#header)
  local version_str = data:sub(start+#header,next_line-1)
  local version = tonumber(version_str)
  log('version',version)

  -- extract the lua
  local lua_start = data:find('__lua__') + 7 + #eol_chars
  local lua_end = data:find('__',lua_start)
  if lua_end == nil then
    lua_end = #data
  else
    lua_end = lua_end -2
  end

  lua = data:sub(lua_start,lua_end)

  local gfx_start = data:find('__gfx__') 
  if gfx_start ~= nil then 
    gfx_start = gfx_start + 7 + #eol_chars

    local gfx_end = data:find('__',gfx_start)
    if gfx_end == nil then 
      gfx_end = #data
    else
      gfx_end  = gfx_end - 2
    end

    gfxdata = data:sub(gfx_start,gfx_end)
  end 

      -- load the sprite flags
  local gff_start = data:find('__gff__') 
  if gff_start ~= nil then
    gff_start = gff_start + 7 + #eol_chars
    local gff_end = data:find('__',gff_start)
    if gff_end == nil then
      gff_end = #data
    else 
      gff_end = gff_end - 2
    end

    gffdata = data:sub(gff_start,gff_end)
  end
    -- convert the tile data to a table

  local map_start = data:find('__map__') 
  if map_start ~= nil then 
    map_start = map_start + 7 + #eol_chars

    local map_end = data:find('__',map_start)
    if map_end == nil then 
      map_end = #data
    else 
      map_end = map_end- 2
    end

    mapdata = data:sub(map_start,map_end)
  end

  local sfx_start = data:find('__sfx__') 
  if sfx_start ~= nil then 
    sfx_start = sfx_start + 7 + #eol_chars
    local sfx_end = data:find('__',sfx_start)
    if sfx_end == nil then 
      sfx_end = #data
    else
      sfx_end = sfx_end - 2
    end

    sfxdata = data:sub(sfx_start,sfx_end)
  end

  --assert(_sfx == 64) --- full is 64 lines



  local music_start = data:find('__music__') 
  if music_start ~= nil then
    music_start = music_start + 9 + #eol_chars
    local music_end = #data-#eol_chars
    musicdata = data:sub(music_start,music_end)

  end


  -- patch the lua
  lua = lua:gsub('!=','~=')
  -- rewrite shorthand if statements eg. if (not b) i=1 j=2
  lua = lua:gsub('if%s*(%b())%s*([^\n]*)\n',function(a,b)
    local nl = a:find('\n',nil,true)
    local th = b:find('%f[%w]then%f[%W]')
    local an = b:find('%f[%w]and%f[%W]')
    local o = b:find('%f[%w]or%f[%W]')
    local ce = b:find('--',nil,true)
    if not (nl or th or an or o) then
      if ce then
        local c,t = b:match("(.-)(%s-%-%-.*)")
        return 'if '..a:sub(2,-2)..' then '..c..' end'..t..'\n'
      else
        return 'if '..a:sub(2,-2)..' then '..b..' end\n'
      end
    end
  end)
  -- rewrite assignment operators
  lua = lua:gsub('(%S+)%s*([%+-%*/%%])=','%1 = %1 %2 ')

  log('finished loading cart',filename)

  api.loaded_code = lua

  send_pico8_version(version)

  send_resource("gfx",gfxdata)
  send_resource("gff",gffdata)
  send_resource("sfx",sfxdata)
  send_resource("map",mapdata)
  send_resource("music",musicdata)

  send_resource_done()

end

function api.spr(n,x,y,w,h,flip_x,flip_y)
  n = api.flr(n)
  n = api.flr(n)
  w = w or 1
  h = h or 1
  x = x or 0
  y = y or 0
  flip_x = flip_x or 0
  flip_y = flip_y or 0
  
  draw.spr(n,x,y,w,h,flip_x,flip_y)

end

function api.map(cel_x,cel_y,sx,sy,cel_w,cel_h,bitmask)
  cel_x = cel_x or 0
  cel_y = cel_y or 0

  cel_x = api.flr(cel_x)
  cel_y = api.flr(cel_y)
  sx = api.flr(sx)
  sy = api.flr(sy)
  cel_w = api.flr(cel_w)
  cel_h = api.flr(cel_h)

  bitmask = bitmask or 0

  draw.map(cel_x,cel_y,sx,sy,cel_w,cel_h,bitmask)

end

return api
