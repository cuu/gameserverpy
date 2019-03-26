
TCP = require("tcp")

TCP.connect()

function safe_format(formatstring,...)	
	return string.format(formatstring.."\n",...)
end


local server = {}

function server.down()

end

function server.scroll(dy)
	dy = dy or 0
	local thing = safe_format("(scroll %d)",dy)
	return TCP.send(thing)
end

function server.print(str,x,y,col)
	local thing
	if x == nil then
		thing = safe_format("(print \"%s\")",str)
	end

	if x ~= nil and col == nil  then 
		thing = safe_format("(print \"%s\" %d %d)",str,math.floor(x),math.floor(y))
	end

	if x ~= nil and col ~= nil then
		thing = safe_format("(print \"%s\" %d %d %d)",str,math.floor(x),math.floor(y),math.floor(col))
	end

	return TCP.send(thing)

end

function server.cls(frame)
	local thing = safe_format("(cls %d)",frame)
	return TCP.send(thing)

end

function server.flip()
	local thing = safe_format("(flip)")
	return TCP.send(thing)
end

function server.btn(codestr,playernumber)
	local thing = safe_format("(btn \"%s\" %d)", codestr,playernumber)
	return TCP.send(thing)
end

function server.btnp(codestr,playernumber)
	local thing = safe_format("(btnp \"%s\" %d)", codestr,playernumber)
	return TCP.send(thing)
end

function server.sspr(sx,sy,sw,sh,dx,dy,dw,dh,flip_x,flip_y)
  local thing = safe_format("(sspr %d %d %d %d %d %d %d %d %d %d)", sx,sy,sw,sh,dx,dy,dw,dh,flip_x,flip_y)
  return TCP.send(thing)
end

function server.spr(n,x,y,w,h,flip_x,flip_y)
  local thing = safe_format("(spr %d %d %d %d %d %d %d)", n,x,y,w,h,flip_x,flip_y)
  return TCP.send(thing)

end

function server.map(cel_x,cel_y,sx,sy,cel_w,cel_h,bitmask)
  local thing = safe_format("(map %d %d %d %d %d %d %d)",cel_x,cel_y,sx,sy,cel_w,cel_h,bitmask)
  return TCP.send(thing)
end

function server.color(c)
  local thing = safe_format("(color %d)",c)
  return TCP.send(thing)
end

function server.pset(x,y,c)
  local thing = safe_format("(pset %d %d %d)",x,y,c)
  return TCP.send(thing)
end

function server.cursor(x,y)
  local thing = safe_format("(cursor %d %d %d)",x,y,c)
  return TCP.send(thing)
end

function server.mget(x,y)
 local thing = safe_format("(mget %d %d)",x,y)
 return TCP.send(thing)
end

function server.mset(x,y,v)
 local thing = safe_format("(mset %d %d %d)",x,y,v)
 TCP.send(thing)
end

function server.rect(x0,y0,x1,y1,col)
  local thing

  if col == nil then
    thing = safe_format("(rect %d %d %d %d)",x0,y0,x1,y1)
  else
    thing = safe_format("(rect %d %d %d %d %d)",x0,y0,x1,y1,col)
  end
  TCP.send(thing)
end

function server.rectfill(x0,y0,x1,y1,col)
  local thing
  x0 = math.floor(x0)
  y0 = math.floor(y0)
  x1 = math.floor(x1)
  y1 = math.floor(y1)

  if col == nil then
    thing = safe_format("(rectfill %d %d %d %d)",x0,y0,x1,y1)
  else
    col = math.floor(col)
    thing = safe_format("(rectfill %d %d %d %d %d)",x0,y0,x1,y1,col)
  end
  TCP.send(thing)
end

function server.circ(ox,oy,r,col)
  local thing
  ox = math.floor(ox)
  oy = math.floor(oy)
  r =  math.floor(r)

  if col == nil then
    thing = safe_format("(circ %d %d %d)",ox,oy,r)
  else
    col = math.floor(col)
    thing = safe_format("(circ %d %d %d %d)",ox,oy,r,col)
  end
  TCP.send(thing)
end

function server.circfill(cx,cy,r,col)
  local thing
  cx = math.floor(cx)
  cy = math.floor(cy)
  r = math.floor(r)

  if col == nil then
    thing = safe_format("(circfill %d %d %d)",cx,cy,r)
  else
    col = math.floor(col)
    thing = safe_format("(circfill %d %d %d %d)",cx,cy,r,col)
  end
  TCP.send(thing)
end

function server.line(x0,y0,x1,y1,col)
  local thing
  if col == nil then
    thing = safe_format("(line %d %d %d %d)",x0,y0,x1,y1)
  else
    thing = safe_format("(line %d %d %d %d %d)",x0,y0,x1,y1,col)
  end
end

function server.time()
  local thing = "(time)"
  return TCP.send(thing)
end

function server.pal(c0,c1,p)
  local thing
  if type(c0) ~= 'number' then
    thing="(pal)"
	end

  if c1 ~= nil then
    thing = safe_format("(pal %d %d %d)",c0,c1,p)
  end

  TCP.send(thing)

end

function server.palt(c,t)
  local thing
  if type(c) ~= 'number' then
   thing="(palt)"

  else
   t = t or false
   if t == true then
     thing = safe_format("(palt %d 1)",c)
   else
     thing = safe_format("(palt %d 0)",c)
   end
  end

  TCP.send(thing)

end

function server.fget(n,f)
  local thing
  if f == nil then
    thing = safe_format("(fget %d)",n)
  else
    thing = safe_format("(fget %d %d)",n,f)
  end
 	
	local ret = TCP.send(thing)
	
	return ret 
end

function server.reboot()
	local thing = "(reboot)"
	TCP.send(thing)
end

function server.clip(x,y,w,h)
	local thing
	if type(x) == 'number' then
		thing = safe_format("(clip %d %d %d %d)",x,y,w,h)
	else
		thing = "(clip)"
	end

	TCP.send(thing)

end

function server.restore_camera(x,y)
	local thing = safe_format("(restore_camera %d %d)",x,y)
	TCP.send(thing)
end


function server.printh(text)
	local thing = safe_format("(printh \"%s\")",text)
	TCP.send(thing)
end

function server.music(n,fade_len,channel_mask)

end
function server.sfx(n,channel,mask)
end

function server.send_pico8_version(version)
  local thing = safe_format("(pico8 %d)", version)
  TCP.send(thing)
end

function server.send_resource_done()
  local thing = "(res.done)"
  TCP.send(thing)

end

function server.send_resource(res_type,res_data)
  if res_data == nil or #res_data == 0  then 
    return 
  end

  local thing = safe_format("(res \"%s\")", res_type)

  TCP.send(thing)

  thing = res_data
  local ret = TCP.send(thing)
  if ret == nil then
    print("the ret of res_data is ", ret,res_type,#res_data)
  end

  thing = "(res.over)\n"
  ret = TCP.send(thing)
  --print("the ret of res.over is ", ret)

end



return server
