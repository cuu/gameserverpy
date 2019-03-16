log = print
local api = { loaded_code = nil }
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
}

local server = require("server")

api.pico8 = pico8 

function api.color(c)
  c = c and math.floor(c) or 0 
  assert(c >= 0 and c <= 16,string.format('c is %s',c))
  server.color(c)

--  love.graphics.setColor(c*16,0,0,255)
end

function api.pset(x,y,c)
  if not c then return end 

  server.pset(x,y,c)

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
  server.print(str,x,y,col)		
end

function api.cursor(x,y)
  server.cursor(x,y)
end


function api.cls(frame)
	frame = frame or 0
	server.cls(frame)
end

function api.flip()
	server.flip()
end

function api.btn(i,p)
	local thing
	local ret

	if type(i) == 'number' then
		p = p or 0
		if __keymap[p] and __keymap[p][i] then
				ret = server.btn( __keymap[p][i],p)
				if ret == "TRUE" then
					return true
				else 
					return false
				end
		end
	end
	
	return false
	
end

function api.btnp(i,p)
	local thing
	local ret

	if type(i) == 'number' then
		p = p or 0
		if __keymap[p] and __keymap[p][i] then
				ret = server.btnp( __keymap[p][i],p)
				if ret == "TRUE" then
					return true
				else 
					return false
				end
		end
	end
	
	return false
	
end

function api.mget(x,y)
	local ret = server.mget(x,y)
	return tonumber(ret)
end

function api.mset(x,y,v)
	server.mset(x,y,v)
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
api.abs = math.abs

function api.sgn(x)
  if x < 0 then 
    return -1
  else 
    return 1
  end  
end

api.sub = string.sub

function api.rnd(x)
	x = math.floor(x)
	return math.random(0, x)
end
function api.srand(seed)
	seed = seed or 0

	if seed == 0 then
		seed = 1
	end

	return math.randomseed(seed)
end

function api.shutdown()
	server.down()
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

  server.send_pico8_version(version)

  server.send_resource("gfx",gfxdata)
  server.send_resource("gff",gffdata)
  server.send_resource("sfx",sfxdata)
  server.send_resource("map",mapdata)
  server.send_resource("music",musicdata)

  server.send_resource_done()

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
 
  if flip_x == true then
    flip_x = 1
  end

  if flip_x == false then
    flip_x = 0
  end

  if flip_y == true then
    flip_y = 1
  end

  if flip_y == false then
    flip_y = 0
  end

  server.spr(n,x,y,w,h,flip_x,flip_y)

end

function api.sspr(sx,sy,sw,sh,dx,dy,dw,dh,flip_x,flip_y)
  sx = sx or 0
  sy = sy or 0
  sw = sw or 0
  sh = sh or 0
  dw = dw or sw
  dh = dh or sh
  dx = dx or 0
  dy = dy or 0
  flip_x = flip_x or 0
  flip_y = flip_y or 0

  if flip_x == true then
    flip_x = 1
  end

  if flip_x == false then
    flip_x = 0
  end

  if flip_y == true then
    flip_y = 1
  end

  if flip_y == false then
    flip_y = 0
  end


  server.sspr(sx,sy,sw,sh,dx,dy,dw,dh,flip_x,flip_y)
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

  server.map(cel_x,cel_y,sx,sy,cel_w,cel_h,bitmask)

end

function api.add(a,v)
  if a == nil then 
    warning('add to nil')
    return
  end  
  table.insert(a,v)
end

function api.del(a,dv)
  if a == nil then 
    warning('del from nil')
    return
  end  
  for i,v in ipairs(a) do
    if v==dv then 
      table.remove(a,i)
    end  
  end  
end

function warning(msg)
  log(debug.traceback('WARNING: '..msg,3))
end

function api.foreach(a,f)
  if not a then 
    warning('foreach got a nil value')
    return
  end  
  for i,v in ipairs(a) do
    f(v) 
  end  
end

function api.count(a)
  return #a
end

function api.all(a)
  local i = 0
  local n = #a
  return function()
    i = i + 1
    if i <= n then return a[i] end
  end
end


function api.camera()
end

function api.rect(x0,y0,x1,y1,col)
  if col == nil then
  	server.rect(x0,y0,x1,y1)
  else
  	server.rect(x0,y0,x1,y1,col)
  end

end

function api.rectfill(x0,y0,x1,y1,col)
  if col == nil then
    server.rectfill(x0,y0,x1,y1)
  else
    server.rectfill(x0,y0,x1,y1,col)
  end
end

function api.circ(x0,y0,x1,y1,col)
  if col == nil then
    server.circ(x0,y0,x1,y1)
  else
    server.circ(x0,y0,x1,y1,col)
  end
end

function api.circfill(x0,y0,x1,y1,col)
  if col == nil then
    server.circfill(x0,y0,x1,y1)
  else
    server.circfill(x0,y0,x1,y1,col)
  end
end

function api.line(x0,y0,x1,y1,col)
  if col == nil then
    server.line(x0,y0,x1,y1)
  else
    server.line(x0,y0,x1,y1,col)
  end
end
function api.time()
  ret = server.time()
  return tonumber(ret)
end

function api.pal(c0,c1,p)
    server.pal(c0,c1,p)
end

function api.palt(c,t)
  if type(c) ~= 'number' then
   server.palt()
  else
   t = t or false
   server.palt(c,t)
  end
end  

function api.fget(n,f)
  if n == nil then return nil end
  server.fget(n,f)
end 

function api.music(n,fade_len,channel_mask)

end

function api.sfx(n,channel,offset)

end

return api
