
x = 0
y = 0
c = 8
 
function _update()
  if (btn(0) and x > 0) x -= 1
  if (btn(1) and x < 127) x += 1
  if (btn(2) and y > 0) y -= 1
  if (btn(3) and y < 127) y += 1
  if (btn(4) and c > 1) c -= 1
  if (btn(5) and c < 15) c += 1

end
 
function _draw()
  cls()
--  circfill(x, y, 10, c)
	print("haha",x,y,c)
end
