require 'strict'
local api = require 'libpico8'

local loaded_code = nil
log = print

local function read_file(path)
    local file = io.open(path, "rb") -- r read mode and b binary mode
    if not file then return nil end
    local content = file:read "*a" -- *a or *all reads the whole file
    file:close()
    return content
end

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
		flip  = api.flip
	}
end


function load_lua_file(file)
	local lua
	lua = read_file(file)

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
	
	return lua
end
	
function main(file)
	loaded_code = load_lua_file(file)

	local cart = new_sandbox()
	local ok,f,e = pcall(load,loaded_code)
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
  end
	
end

if #arg > 1 then
	main(arg[2])
else
	log("No arguments")
	log(arg[0])
end

