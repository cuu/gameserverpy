require 'strict'
--local api = require 'libpico8_unix_socket'
local api = require 'libpico8'

log = print

local function setfenv(fn, env)
  local i = 1
  while true do
    local name = debug.getupvalue(fn, i)
    if name == "_ENV" then
      debug.upvaluejoin(fn, i, (function()
        return env
      end), 1)
      break
    elseif not name then
      break
    end

    i = i + 1
  end

  return fn
end

local function getfenv(fn)
  local i = 1
  while true do
    local name, val = debug.getupvalue(fn, i)
    if name == "_ENV" then
      return val
    elseif not name then
      break
    end
    i = i + 1
  end
end

function new_sandbox()
  return {

    clip=api.clip,
    pget=api.pget,
    pset=api.pset,

    fget=api.fget,    
    fset=api.fset,

    flip=api.flip,
    print=api.print,
    printh=log,
    cursor=api.cursor,
    color=api.color,
    cls=api.cls,
    camera=api.camera,
    circ=api.circ,
    circfill=api.circfill,
    line=api.line,
    rect=api.rect,
    rectfill=api.rectfill,
    
    pal=api.pal,
    palt=api.palt,
    spr=api.spr,
    sspr=api.sspr,
    add=api.add,
    del=api.del,
    foreach=api.foreach,
    count=api.count,
    all=api.all,
    btn=api.btn,
    btnp=api.btnp,
    sfx=api.sfx,
    music=api.music,
    
    mget=api.mget,
    mset=api.mset,
    map=api.map,

    max=api.max,
    min=api.min,
    mid=api.mid,
    flr=api.flr,
    cos=api.cos,
    sin=api.sin,
    atan2=api.atan2,
    sqrt=api.sqrt,
    abs=api.abs,
    rnd=api.rnd,
    srand=api.srand,
    sgn=api.sgn,
    band=api.band,
    bor=api.bor,
    bxor=api.bxor,
    bnot=api.bnot,
    shl=api.shl,
    shr=api.shr,
    exit=api.shutdown,
    shutdown=api.shutdown,
    sub=api.sub,
    stat=api.stat,
    time = api.time, 
		reboot = api.reboot,
		printh = api.printh,
		tostr  = api.tostr,
    mapdraw = api.map,
		run    = api.run,
		string = string

   }
end


local frames = 0
local frame_time = 1/api.pico8.fps
	
function draw(cart)
	
	while true do


		if cart._update then cart._update() end
		if cart._update60 then cart._update60() end

		if cart._draw   then cart._draw() end
		
		--api.sleep(frame_time/30)
		api.flip()
		frames= frames+1
	end

end

function api.run()
	local cart = new_sandbox()
	local ok,f,e = pcall(load,api.loaded_code)
  if not ok or f==nil then
    log('=======8<========')
    log(api.loaded_code)
    log('=======>8========')
    error('Error loading lua: '..tostring(e))
  else
		local result
		setfenv(f,cart)
    ok,result = pcall(f)
    if not ok then
      error('Error running lua: '..tostring(result))
    else
      log('lua completed')
    end

		if cart._init then cart._init() end
		
		draw(cart)
  end
end

function main(file)
	api.load_p8_text(file)
	
	api.run()

end

if #arg > 1 then
	main(arg[2])
else
	log("No arguments")
	log(arg[0])
end

