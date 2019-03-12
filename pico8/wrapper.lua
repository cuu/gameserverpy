require 'strict'
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
		print=api.print,
		cls  = api.cls,
		sleep = api.sleep,
		flip  = api.flip,
		btn   = api.btn,
    spr   = api.spr,
    map   = api.map
	}
end


local frames = 0
local frame_time = 1/api.pico8.fps
	
function draw(cart)
	
	while true do
		if cart._update then cart._update() end
		if cart._draw   then cart._draw() end
	
		--api.sleep(frame_time/30)
		api.flip()
		frames= frames+1
	end

end

function main(file)
	api.load_p8_text(file)

	local cart = new_sandbox()
	local ok,f,e = pcall(load,api.loaded_code)
  if not ok or f==nil then
    log('=======8<========')
    log(loaded_code)
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

if #arg > 1 then
	main(arg[2])
else
	log("No arguments")
	log(arg[0])
end

