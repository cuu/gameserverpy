
local bmp = {w=0,h=0,Data={}}

function bmp.newImageData(w,h)
  for y=0,h do
    for x=0,w do
      bmp.Data[x+y*w] = {0,0,0,0}
    end
  end
	bmp.w = w
	bmp.h = h

end

function bmp:getPixel(x,y)
	if x >= self.w then
		x = x - self.w
	end

	if x < 0 then
		x = x +self.w
	end

	if y >= self.h then
		y = y - self.h
	end
	
	if y < 0 then
		y = y + self.h
	end

  local address = x +y*self.w 
  return self.Data[address]
end

function bmp:setPixel(x,y,r,g,b,a)
	if x >= self.w then
		x = x - self.w
	end

	if x < 0 then
		x = x +self.w
	end

	if y >= self.h then
		y = y - self.h
	end
	
	if y < 0 then
		y = y + self.h
	end

  	local address = x +y*self.w 
	
	self.Data[address] = {r,g,b,a}
end




return bmp