# -*- coding: utf-8 -*- 
import os
import socket
import linecache
import sys
import pygame
import math
import time

from beeprint import pp

from threading import Thread
from multiprocessing import Process,Pipe

import lisp

PORT_NUMBER = 8080

DT = pygame.time.Clock().tick(40)   # fps in ms,eg:50

KeyLog = {}
GameShellKeys = {}
GameShellKeys["left"]  = pygame.K_LEFT
GameShellKeys["right"] = pygame.K_RIGHT
GameShellKeys["up"]    = pygame.K_UP
GameShellKeys["down"]  = pygame.K_DOWN
GameShellKeys["u"]     = pygame.K_u  ## GamePad X
GameShellKeys["i"]     = pygame.K_i  ## GamePad Y
GameShellKeys["return"] = pygame.K_RETURN ##GamePad start
GameShellKeys["escape"] = pygame.K_ESCAPE ##GamePad menu


def PrintException():
    exc_type, exc_obj, tb = sys.exc_info()
    f = tb.tb_frame
    lineno = tb.tb_lineno
    filename = f.f_code.co_filename
    linecache.checkcache(filename)
    line = linecache.getline(filename, lineno, f.f_globals)
    print 'EXCEPTION IN ({}, LINE {} "{}"): {}'.format(filename, lineno, line.strip(), exc_obj)


class Pico8(object):
    Width = 128
    Height  = 128

    version = 8

    gfx_surface = None
    gfx_matrix = None
    map_surface = None
    map_matrix = None

    spriteflags =  None
    CanvasHWND = None
    HWND       = None
    bg_color = (0,0,0,0)
    Font = None
    
    Resource = {}   
    palette = [
        pygame.Color(0,0,0,255),
        pygame.Color(29,43,83,255),
        pygame.Color(126,37,83,255),
        pygame.Color(0,135,81,255),
        pygame.Color(171,82,54,255),
        pygame.Color(95,87,79,255),
        pygame.Color(194,195,199,255),
        pygame.Color(255,241,232,255),
        pygame.Color(255,0,77,255),
        pygame.Color(255,163,0,255),
        pygame.Color(255,240,36,255),
        pygame.Color(0,231,86,255),
        pygame.Color(41,173,255,255),
        pygame.Color(131,118,156,255),
        pygame.Color(255,119,168,255),
        pygame.Color(255,204,170,255)]

    draw_palette = []
    draw_palette_colors = []
    display_palette = []
    pal_transparent = []
    
    cliprect= None
    pen_color = 1
    _cursor = [0,0]
    _camera_dx = 0 ## shake
    _camera_dy = 0
    
    memory = {}
    _palette_modified = False
    
    uptime = None ## when pico8 is up
    
    _CurrentCanvas = None

    def __init__(self):
        self.uptime = time.time()

        self.DisplayCanvas = pygame.Surface((self.Width,self.Height),0,8) ## last one,blit to the screen,display_palette

        self.DrawCanvas    = pygame.Surface((self.Width,self.Height),0,8) ##       no alpha, draw_palette  

        self.gfx_surface = pygame.Surface((self.Width,self.Height),0,24) #sprite_sheet

        self.map_matrix  = [0 for x in range(64*128)]
        

        self.DisplayCanvas.set_palette(self.palette)
        self.DrawCanvas.set_palette(self.palette)
        
#        self.DrawCanvas.set_colorkey(0)

        self.spriteflags = [0 for x in range(256)]
        for i in range(16):
            self.draw_palette.append(i)
            self.draw_palette_colors.append(  self.palette[i] )

            if i == 0:
                self.pal_transparent.append(0)
            else:
                self.pal_transparent.append(1)

            self.display_palette.append(self.palette[i])
        
        self.Font = pygame.font.Font("PICO-8.ttf",4)
        
        for i in range(4):
            self.memory[0x5f20+i] = 0
        
        self.sync_draw_pal()
 
    def sync_draw_pal(self):
        for i in range(16):
            self.draw_palette_colors[i] = self.palette[ self.draw_palette[i] ]

    def set_gff(self): # red=1, orange=2, yellow=4, green=8, blue=16, purple=32, pink=64, peach=128
        if "gff" not in self.Resource:
            return

        sprite = 0
        data = self.Resource["gff"]
        data_array = data.split("\n")
        if len(data_array) % 2 == 0:
            for rowpixel in data_array:
                if self.version <= 2:
                    for i in range(0,len(rowpixel)):
                        v = int(rowpixel[i],16)
                        self.spriteflags[sprite] = v 
                        sprite+=1
                else:                    
                    for i in range(0,len(rowpixel),2):
                        v = int(rowpixel[i]+rowpixel[i+1],16)

                        if sprite > 255:
                            break

                        self.spriteflags[sprite] = v 
                        sprite+=1
        else:
            print("gff array length error ", len(data_array))                 

        print("spriteflags:", sprite)

    def set_map(self):
        col = 0
        row = 0
        if "map" not in self.Resource:
            return

        tiles = 0
        mapdata = self.Resource["map"]
        mapdata_array = mapdata.split("\n")
        for rowpixel in mapdata_array:
            for i in range(0,len(rowpixel),2):
                v = int(rowpixel[i]+rowpixel[i+1],16)
                self.map_matrix[row+col*64] = v
                tiles +=1
                col = col + 1
                if col == self.Width:
                    col = 0
                    row = row + 1
        

        print("set_map ",tiles)

    def set_shared_map(self):
        shared = 0
        if self.version > 3:
            tx = 0
            ty = 32
            for sy in range(64,128):
                for sx in range(0,128,2):
                    col1 = self.gfx_surface.get_at((sx,sy))
                    lo = int(math.floor(col1.r/16))
                    col2 = self.gfx_surface.get_at((sx+1,sy))
                    hi = int(math.floor(col2.r/16))
                
                    v = (hi << 4 ) | lo
                    #print(ty,tx)
                    self.map_matrix[ty+tx*64] = v
                    
                    shared  = shared + 1
                    tx = tx + 1
                    if tx == 128:
                        tx = 0
                        ty = ty + 1

        print("map shared: ", shared) ## 128*32 = 4096


    def set_gfx(self):
        col = 0
        row = 0
        if "gfx" not in self.Resource:
            return

        gfxdata = self.Resource["gfx"]
        gfxdata.strip()
        gfxdata_arrays = gfxdata.split("\n")
        for rowpixel in gfxdata_arrays:
            if len(rowpixel) > 10:
                for digi in rowpixel:
                    v = int(digi,16)
#                    index = int( math.floor( ((v*16.0)/256.0)*16.0 ) )
                    self.gfx_surface.set_at((col,row),(v*16,v*16,v*16,255))
                    col+=1
                    if col == 128:
                        col = 0
                        row += 1

        self.set_shared_map()
    
    def spr(self,n,x,y,w,h,flip_x,flip_y):
         
        idx = math.floor(n % 16)
        idy = math.floor(n/16)

        start_x = int(idx*8)
        start_y = int(idy*8)
        _w = w*8
        _h = h*8
        _sw = _w
        _sh = _h

        if start_x >= self.Width or start_y >= self.Height:
            return

        if start_x + _w > self.Width:
            _sw = self.Width - start_x

        if start_y + _h > self.Height:
            _sh = self.Height - start_y
        
        if _sw == 0 or _sh == 0:
            return
        
        
        gfx_piece = pygame.Surface((_sw,_sh),0,8) 
        gfx_piece.set_palette(self.draw_palette_colors)
        
        gfx_piece.set_colorkey(0)
 
        for _x in range(_sw):
            for _y in range(_sh):
                col = self.gfx_surface.get_at((start_x+_x,start_y+_y))
                v = int(col.r/16.0)

                gfx_piece.set_at((_x,_y), self.draw_palette[v])
        

 
        xflip = False
        yflip = False
        if flip_x > 0:
            xfilp = True
        if flip_y > 0:
            yflip = True

        gfx_piece = pygame.transform.flip(gfx_piece,xflip,yflip)

        for i in range(16):
            if self.pal_transparent[i] == 0:
                gfx_piece.set_colorkey(i)
        
        self.DrawCanvas.blit(gfx_piece,(x,y))

    def sspr(self,sx,sy,sw,sh,dx,dy,dw,dh,flip_x,flip_y):
        if sx + sw > self.Width:
            sw = self.Width - sx

        if sy + sh > self.Height:
            sh = self.Height - sy
        
        if sw <= 0 or sh <= 0:
            return

        gfx_piece = pygame.Surface((sw,sh),0,8) 
        gfx_piece.set_palette(self.draw_palette_colors)
 
        for _x in range(sw):
            for _y in range(sh):
                col = self.gfx_surface.get_at((sx+_x,sy+_y))
                v = int(col.r/16.0)
                gfx_piece.set_at((_x,_y), self.draw_palette[v])

        xflip = False
        yflip = False
        if flip_x > 0:
            xflip = True
        if flip_y > 0:
            yflip = True

        gfx_piece = pygame.transform.flip(gfx_piece,xflip,yflip)
        
        if dw != sw or dh != sh:
            gfx_piece = pygame.transform.scale( gfx_piece,dw,dh)
        
        gfx_piece.set_palette(self.draw_palette_colors)
        
        for i in range(16):
            if self.pal_transparent[i] == 0:
                gfx_piece.set_colorkey(i)
        
        self.DrawCanvas.blit(gfx_piece,(dx,dy))

    def draw_map(self,n,x,y):
        idx = n % 16
        idy = n / 16
        start_x = idx*8
        start_y = idy*8

        w_ = 8
        h_ = 8 

        gfx_piece = pygame.Surface((w_,h_),0,8) 
        gfx_piece.set_palette(self.draw_palette_colors)
        gfx_piece.set_colorkey(0)
 
        for _x in range(w_):
            for _y in range(h_):
                col = self.gfx_surface.get_at((start_x+_x,start_y+_y))
                v = int(col.r/16.0)

                gfx_piece.set_at((_x,_y), self.draw_palette[v])
         
        self.DrawCanvas.blit(gfx_piece,(x,y))

    def map(self,cel_x,cel_y,sx,sy,cel_w,cel_h,bitmask):
        for y in range(0,cel_h):
            for x in range(0,cel_w):
                addr = cel_y + y + (cel_x+x)*64
                if addr < 8192:
                    v = self.map_matrix[addr]
                    if v > 0:
                        if bitmask == None or bitmask == 0:
                            self.draw_map(v,sx+x*8,sy+y*8)
                        else:
                            if (self.spriteflags[v] & bitmask) != 0:
                                self.draw_map(v,sx+x*8,sy+y*8)
                else:
                    print("addr >= 8192", addr)
    
    def mget(self,x,y):
        if  y > 63 or x < 0 or x > 127 or y < 0:
            return "0"
        
        return str( self.map_matrix[ y + x *64 ] )
        
    def mset(self,x,y,v):
        if x >= 0 and x < 128 and y >= 0 and y < 64: 
            self.map_matrix[ y + x*64] = v

        return "OK" 

    def color(self,c=None):
        if c == None:
            return self.pen_color
        
        c = int(c)

        if c < 15 and c >=0:
            self.pen_color = c

    def cls(self,color_index=None):
        if color_index == None:
            self.DrawCanvas.fill(0)

        elif color_index >=0 and color_index < 16:
            self.DrawCanvas.fill(self.draw_palette[color_index])
        
        self._cursor=[0,0]
 
    def flip(self):
        if self.HWND != None:

            blit_rect = (self._camera_dx,self._camera_dy)
            window_surface = pygame.display.get_surface()
            window_w = window_surface.get_width()
            window_h = window_surface.get_height()

            self.DisplayCanvas.fill((3,5,10,255))
            self.DisplayCanvas.fill((0,0,0,0))
            self.DisplayCanvas.set_palette(self.draw_palette_colors)  
            self.DisplayCanvas.blit(self.DrawCanvas,blit_rect)

            if window_w > self.Width and window_h > self.Height:
                bigger_border = window_w 
                if bigger_border > window_h:
                    bigger_border = window_h
                
                _blit_x = (window_w - bigger_border)/2
                _blit_y = (window_h - bigger_border)/2

                bigger = pygame.transform.scale(self.DisplayCanvas,(bigger_border,bigger_border))
                self.HWND.blit(bigger,(_blit_x,_blit_y))
            else:
                self.HWND.blit(self.DisplayCanvas,(0,0))

            self.DrawCanvas.fill((0,0,0,255))
            
            self.cliprect = None               
            self._camera_dx = 0
            self._camera_dy = 0

    def Print(self,text,x,y,c=None):
        self.color(c) 
        if x == None:
            x = self._cursor[0]
            y = self._cursor[1]
            self._cursor[1] += 6
        
        if x != None and y != None:
            self._cursor[0] = x
            self._cursor[1] = y
 
        imgText = self.Font.render(text,False, self.draw_palette_colors[ self.draw_palette[ self.pen_color]])
        imgText.set_colorkey(0)
        self.DrawCanvas.blit(imgText,(x,y))

    def pset(self,x,y,c=0):
        if c > 15:
            return
        print(x,y,c)
        if x >=0 and x < self.Width and y >=0 and y < self.Height:
            color = self.draw_palette[c]
            self.DrawCanvas.set_at((x,y),color)
 
    
    def pget(self,x,y):
        
        if x >=0 and x < self.Width and y >=0 and y < self.Height:
            return self.DrawCanvas.get_at((x,y))
        else:
            return 0
    

    def clip(self,x,y,w,h):
        if x == None:
            self.cliprect = None
        else:    
            self.cliprect = pygame.Rect(x,y,w,h)
         
        self.DisplayCanvas.set_clip(self.cliprect)

    def restore_clip(self):
        self.DisplayCanvas.set_clip(self.cliprect)
    

    def restore_camera(self,x,y):
        
        self._camera_dx = x
        self._camera_dy = y
 
    def cursor(self,x,y):
        self._cursor = [x,y]

    
    def rect(self,x0,y0,x1,y1,col=None):
        self.color(col)
        rect_ = pygame.Rect(x0+1,y0+1,x1-x0,y1-y0)
        pygame.draw.rect(self.DrawCanvas, self.draw_palette[self.pen_color], rect_,1)
    
    def rectfill(self,x0,y0,x1,y1, col=None):
        self.color(col)

        w = (x1-x0)+1
        h = (y1-y0)+1

        if w < 0:
            w = -w
            x0 = x0-w

        if h < 0:
            h = -h
            y0=y0-h
        
         
        rect_ = pygame.Rect(x0,y0,w,h)
        pygame.draw.rect(self.DrawCanvas, self.draw_palette[self.pen_color], rect_)
    
    def circ(self,ox,oy,r,col=None):
        self.color(col)
        r = math.floor(r)
        pygame.draw.circle(self.DrawCanvas, self.draw_palette[self.pen_color],(ox,oy),r,1)

    def circfill(self,cx,cy,r,col=None):
        self.color(col)

        pygame.draw.circle(self.DrawCanvas,self.draw_palette[self.pen_color],(cx,cy),r,0)

    
    def line(self,x0,y0,x1,y1,col=None):
        self.color(col)
        pygame.draw.line(self.DrawCanvas,self.draw_palette[self.pen_color],(x0,y0),(x1,y1),1)

    
    def music(self,fade_len=None,channel_mask=None):
        pass

    def sfx(self,channel =None,offset=None):
        pass
    
    def time(self):
        curr_time = time.time()
        
        return int( curr_time - self.uptime)

    def palt(self,c=None,t=None):
        if c == None:
            for i in range(16):
                if i == 0:
                    self.pal_transparent[i] = 0
                else:
                    self.pal_transparent[i] = 1

        else:
            c = c % 16
            if t == 1:
                self.pal_transparent[c] = 0
            else:
                self.pal_transparent[c] = 1
        
 
    def pal(self,c0=None,c1=None,p=None):
        if c0 ==None:
            if self._palette_modified == False:
                return
            for i in range(16):
                self.draw_palette[i] = i
                self.display_palette[i] = self.palette[i]
            
            self.palt()

            self.sync_draw_pal()

            self.DisplayCanvas.set_palette(self.display_palette)
            self.DrawCanvas.set_palette(self.draw_palette_colors)
            
            self._palette_modified = False

        elif p == 1 and c1 != None:
            c0 = c0 % 16
            c1 = c1 % 16
            self.display_palette[c0] = self.palette[c1]
            self._palette_modified = True

            self.DisplayCanvas.set_palette(self.display_palette)
        elif c1 != None and p == 0:
            c0 = c0 % 16
            c1 = c1 % 16
            self.draw_palette[c0] = c1
            self._palette_modified = True

            self.sync_draw_pal()

            self.DrawCanvas.set_palette(self.draw_palette_colors)
 

    def fget(self,n,f=None):
        if f != None:
            if n > 255:
                return "0"
            
            ret = self.spriteflags[n] & (1 << f)
            return str(ret)
        else:
            if n < 255:
                return str(self.spriteflags[n])
            else:
                return "0"
    
    def reboot(self):
        self.uptime = time.time()
    
    def printh(self,text,filename=None,overwrite=None):
        print(text)

class PygameThread(lisp.Lisper):
    Width = 640
    Height = 480
    Inited = False

    DT = pygame.time.Clock().tick(30)
    font1 = None
    font2 = None
    bg_color = pygame.Color(0,0,0)
   
    OffsetX = 0
    OffsetY = 0

    State = "draw" ## draw,res
    Resource = ""

    ConsoleType = "pico8"
    Pico8 = None

    frames = 0
    
    def get_arg(self,index,env,args,force_format=None):
        if index > len(args)-1:
            if force_format != None:
                if force_format== "int":
                    return 0
                elif force_format == "str":
                    return ""
            else:
                return None
        
        a = args[index].eval(env)
        if force_format != None:
            if force_format== "int":
                return int(a)
            elif force_format == "str":
                return str(a)
        else:
            return a
        
    def res(self,env,args):
        res_type = args[0].eval(env)
        self.Resource = res_type
        self.State = "res"
        return "OK"

    def res_done(self,env,args):

        if self.ConsoleType == "pico8":
            self.Pico8.set_gfx()
            self.Pico8.set_gff()
            self.Pico8.set_map()

        self.State = "draw"

        return "OK"

    def setpico8(self,env,args):
        version = args[0].eval(env)
        self.Pico8.version = int(version)
        self.ConsoleType = "pico8"
        print(self.ConsoleType, " is ",self.Pico8.version)

        return "OK"

    def __init__(self):
        lisp.Lisper.__init__(self) 
 
        self.intern('print', lisp.SyntaxObject(self.draw_print))
        self.intern('cls', lisp.SyntaxObject(self.cls))
        self.intern('flip', lisp.SyntaxObject(self.flip))
        self.intern('btn', lisp.SyntaxObject(self.btn))
        self.intern('btnp', lisp.SyntaxObject(self.btnp))

        self.intern('scroll', lisp.SyntaxObject(self.scroll))

        self.intern('spr', lisp.SyntaxObject(self.spr))
        self.intern('map', lisp.SyntaxObject(self.map))

        self.intern('mget', lisp.SyntaxObject(self.mget))
        self.intern('mset', lisp.SyntaxObject(self.mset))

        self.intern('color', lisp.SyntaxObject(self.color))

        
        self.intern('rect',     lisp.SyntaxObject(self.rect))
        self.intern('rectfill', lisp.SyntaxObject(self.rectfill))
        self.intern('circ',     lisp.SyntaxObject(self.circ))
        self.intern('circfill', lisp.SyntaxObject(self.circfill))

        self.intern('time', lisp.SyntaxObject(self.time))

        self.intern('pal', lisp.SyntaxObject(self.pal))
        self.intern('palt', lisp.SyntaxObject(self.palt))

        self.intern('clip', lisp.SyntaxObject(self.clip))

        self.intern('fget', lisp.SyntaxObject(self.fget))
        self.intern('reboot', lisp.SyntaxObject(self.fget))
        self.intern('printh', lisp.SyntaxObject(self.printh))
        self.intern('pset', lisp.SyntaxObject(self.pset))

        self.intern('restore_camera', lisp.SyntaxObject(self.restore_camera))

        self.intern('res', lisp.SyntaxObject(self.res))
        self.intern('res.done', lisp.SyntaxObject(self.res_done))

        self.intern('pico8', lisp.SyntaxObject(self.setpico8))

    def reset(self):
        self.OffsetX = 0
        self.OffsetY = 0

    def scroll(self,dy):
        self.OffsetY+=dy

    def draw_print(self,env,args):
        if len(args) < 3:
            return
        assert self.Inited== True,"Not inited"
 
        text  = self.get_arg(0,env,args,"str")
        x     = self.get_arg(1,env,args)
        y     = self.get_arg(2,env,args)
        c     = self.get_arg(3,env,args)
        
        if x != None:
            x = int(x)
        if y != None:
            y = int(y)
         
        self.Pico8.Print(text, x,y,c)

        return "OK"

    def cls(self,env,args):
        assert self.Inited== True,"Not inited"
        
        frame = 0
        ans = 0
        if len(args) > 0:
            ans = self.get_arg(0,env,args,"int")
            frame = int(ans)
            self.Pico8.cls(frame)
        else:
            self.Pico8.cls()

        return "OK"
    
    def flip(self,env,args):
        if self.frames == 0:
            self.prev_time = time.time()

        if self.ConsoleType == "pico8":
            self.Pico8.flip()
        
        pygame.display.update()

        self.frames+=1

        self.curr_time = time.time()
        if self.curr_time - self.prev_time >=10.0:
            fps = self.frames /10
            print("fps is: ",fps)
            self.frames = 0
            self.prev_time = self.curr_time

        return "OK"
    
    def btn(self,env,args):
        assert self.Inited== True,"Not inited"
        if len(args) < 2:
            return "FALSE"
        
        keycode_string = args[0].eval(env)
        player_idx     = args[1].eval(env)
        if keycode_string in GameShellKeys: 
            keycode = GameShellKeys[keycode_string]      
            if keycode in KeyLog and  KeyLog[keycode] >= 0:
                return "TRUE"
        
        
        return "FALSE"
   
    def btnp(self,env,args):
        keycode_string = args[0].eval(env)
        player_idx     = args[1].eval(env)
        if keycode_string in GameShellKeys: 
            keycode = GameShellKeys[keycode_string]
            if keycode in KeyLog:
                v = KeyLog[keycode]
                if (v == 0 or (v >= 12 and v % 4 == 0)):
                    return "TRUE"
       
        return "FALSE"

    def pset(self,env,args):
        assert self.Inited== True,"Not inited"
        if len(args) < 3:
            return "Error,pset args"
       
        x = self.get_arg(0,env,args,"int")
        y = self.get_arg(1,env,args,"int")
        v = self.get_arg(2,env,args,"int")

        self.Pico8.pset(x,y,v)
        
        return "OK"

    def map(self,env,args):
        if len(args) < 6:
            return "Error ,draw_spr args "
        cel_x   = int(args[0].eval(env))
        cel_y   = int(args[1].eval(env))
        sx      = int(args[2].eval(env))
        sy      = int(args[3].eval(env))
        cel_w   = int(args[4].eval(env))
        cel_h   = int(args[5].eval(env))
        bitmask = int(args[6].eval(env))

        if self.ConsoleType == "pico8":
            self.Pico8.map(cel_x,cel_y,sx,sy,cel_w,cel_h,bitmask)

        return "OK"

    def spr(self,env,args):
        if len(args) < 7:
            return "Error ,draw_spr args "
        n      = self.get_arg(0,env,args,"int") 
        x      = self.get_arg(1,env,args,"int")
        y      = self.get_arg(2,env,args,"int")
        w      = self.get_arg(3,env,args,"int")
        h      = self.get_arg(4,env,args,"int")
        flip_x = self.get_arg(5,env,args,"int")
        flip_y = self.get_arg(6,env,args,"int")
        
        if self.ConsoleType == "pico8":
            self.Pico8.spr(n,x,y,w,h,flip_x,flip_y)

        return "OK"

    def rect(self,env,args):
        x0 = args[0].eval(env)
        y0 = args[1].eval(env)
        x1 = args[2].eval(env)
        y1 = args[3].eval(env)

        if len(args) > 4:
            col = args[4].eval(env)
            self.Pico8.rect(x0,y0,x1,y1,col)
        else:
            self.Pico8.rect(x0,y0,x1,y1)
        
        return "OK"

    def rectfill(self,env,args):
        x0 =  self.get_arg(0,env,args,"int")
        y0 =  self.get_arg(1,env,args,"int")
        x1 =  self.get_arg(2,env,args,"int")
        y1 =  self.get_arg(3,env,args,"int")
        col = self.get_arg(4,env,args,"int")

        self.Pico8.rectfill(x0,y0,x1,y1,col)
        
        
        return "OK"

    def circ(self,env,args):
        ox = args[0].eval(env)
        oy = args[1].eval(env)
        r  = args[2].eval(env)
        if len(args) > 3:
            col = self.get_arg(3,env,args,"int")
            self.Pico8.circ(ox,oy,r,col)
        else:
            self.Pico8.circ(ox,oy,r)
        
        return "OK"

    def circfill(self,env,args):
        cx = self.get_arg(0,env,args,"int")
        cy = self.get_arg(1,env,args,"int")
        r  = self.get_arg(2,env,args,"int")
        
        col= self.get_arg(3,env,args,"int")
        
        if len(args)> 3:
            self.Pico8.circfill(cx,cy,r,col)
        else:
            self.Pico8.circfill(cx,cy,r)

        return "OK"

    def line(self,env,args):
        x0 = args[0].eval(env)
        y0 = args[1].eval(env)
        x1 = args[2].eval(env)
        y1 = args[3].eval(env)

        if len(args) > 4:
            col = self.get_arg(4,env,args,"int")
            self.Pico8.line(x0,y0,x1,y1,col)
        else:
            self.Pico8.line(x0,y0,x1,y1)
        
        return "OK"

    def mget(self,env,args):
        x = args[0].eval(env)
        y = args[1].eval(env)

        return self.Pico8.mget(x,y)
    
    def mset(self,env,args):
        x = args[0].eval(env)
        y = args[1].eval(env)
        v = args[2].eval(env)

        self.Pico8.mset(x,y,v)
        return "OK"

    def pget(self,env,args):
        x = args[0].eval(env)
        y = args[1].eval(env)

        return self.Pico8.pget(x,y)

    def time(self,env,args):
        return str(self.Pico8.time())
    
    def color(self,env,args):
        c = self.get_arg(0,env,args)
        self.Pico8.color(c)
        
        return "OK"

    def pal(self,env,args):
        c0 = self.get_arg(0,env,args)
        c1 = self.get_arg(1,env,args)
        p  = self.get_arg(2,env,args)
        self.Pico8.pal(c0,c1,p)

        return "OK"

    def palt(self,env,args):
        c = self.get_arg(0,env,args)
        t = self.get_arg(1,env,args)
        
        if c == None: 
            self.Pico8.palt()
        else:
            self.Pico8.palt(int(c),int(t))
        return "OK"
   
    def fget(self,env,args):
        n = self.get_arg(0,env,args,"int")
        f = self.get_arg(1,env,args)
        if f == None:
            return self.Pico8.fget(n)
        else:
            return self.Pico8.fget(n,int(f))


    def reboot(self,env,args):
        self.Pico8.reboot()
        return "OK"
    
    def clip(self,env,args):
        x = self.get_arg(0,env,args)
        if x == None:
            self.Pico8.clip()
        else:
            x = int(x)
            y = self.get_arg(1,env,args,"int")
            w = self.get_arg(1,env,args,"int")
            h = self.get_arg(1,env,args,"int")
            self.Pico8.clip(x,y,w,h)

        return "OK"
    
    def restore_camera(self,env,args):
        x = self.get_arg(1,env,args,"int")
        y = self.get_arg(1,env,args,"int")
        self.Pico8.restore_camera(x,y)
        
        return "OK"

    def printh(self,env,args):
        text = self.get_arg(0,env,args)
        self.Pico8.printh(text)
        
         
    def print_text(self,font,x,y,text,color=(255,255,255)):
        imgText = font.render(text,False,color)
        if self.Screen.get_locked() == False:
            self.Screen.blit(imgText,(int(x)+self.OffsetX,int(y)+self.OffsetY))

    def init_window(self):
        if self.Inited == False:
            if not pygame.display.get_init():
                pygame.display.init()
            if not pygame.font.get_init():
                pygame.font.init()

            self.font1=pygame.font.Font(None,25)
            self.font2=pygame.font.Font(None,200)
       
            self.Inited = True

        SCREEN_SIZE = (self.Width,self.Height)
        self.bg_color = pygame.Color(0,0,0)
        self.Screen = pygame.display.set_mode(SCREEN_SIZE,0,32)
        pygame.event.set_allowed(None)
        pygame.event.set_allowed([pygame.KEYDOWN,pygame.KEYUP])
        
        self.Pico8 = Pico8()
        self.Pico8.HWND = self.Screen
        
        
    def quit_window(self):
        print("quiting...")
        self.child_conn.send("QUIT")
        self.Inited = False
        self.Screen = None
        pygame.quit()

    def read_data_thread(self):
        while self.Inited:

            data = self.child_conn.recv()

            if self.State == "draw":
#                print("the data is ", data)

                ret = self.evalstring(data) ## every api must have a return content
                self.child_conn.send(ret)

            else:
                self.child_conn.send("OK")
                print("receiving resource",self.Resource,"...")
                if data.find("(res.over)") >= 0:
                    print(data)
                    self.State="draw"
                else:

                    if self.ConsoleType == "pico8":
                        if self.Resource in self.Pico8.Resource:
                            self.Pico8.Resource[self.Resource] += data
                        else:
                            self.Pico8.Resource[self.Resource] = data


    def eventloop(self):
        global DT,KeyLog
        try:
            while self.Inited: 
                event = pygame.event.poll()

                if event.type == pygame.QUIT:
                    return
    
                if event.type == pygame.KEYDOWN:
                    if event.key in KeyLog:
                        KeyLog[event.key] +=1
                    else:
                        KeyLog[event.key] = 1

                    if event.key == pygame.K_p:
                        self.Screen.fill((255,255,255))
                        self.print_text(self.font1,40,30,"Let see!")
                        pygame.display.update()
                    if event.key == pygame.K_ESCAPE or event.key == pygame.K_q:
                        #print("quit ....")
                        return             
                if event.type == pygame.KEYUP: 
                     KeyLog[event.key] = -1
                
    #            pygame.time.delay(self.DT)
                pygame.time.delay(DT)
        finally:
            self.quit_window()

def start_pygame(parent,child):
    api = PygameThread()
    api.init_window()
    api.child_conn = child
    api.parent_conn = parent 
    t = Thread(target=api.read_data_thread)
    t.start()
    api.eventloop()

def recv_all2(socket,seg_length):
    ret = ""
    data = None
    seg = seg_length

    data = socket.recv(seg)
    ret = ""

    if data:
        length = len(data)
        if length > 8:
            length_header = data[0:8]
            datalen = int(length_header,10)

            if datalen == (length - 8):
                return data[8:]
            elif datalen > (length -8):
                ret = data[8:]
                data_left = datalen - length - 8
                while True:
                    if data_left >= seg:
                        data2 = socket.recv(seg)
                        data_left = data_left - len(data)
                    elif data_left > 0 and data_left < seg:
                        data2 = socket.recv(data_left)

                    if not data2 or data_left == 0:
                        if len(ret) == datalen:
                            return ret
                        else:
                            return None

                    ret += data2
                    if len(ret) >= datalen:
                        break

    return ret

def recv_all(socket,package_length):
    ret = ""
    data = None
    seg = 4096

    data_left = package_length

    if package_length < seg:
        data_left = package_length

    while True:
        #print("data_left: ",data_left,package_length)
        if data_left >= seg:
            data = socket.recv(seg)
            data_left = data_left - len(data)
        elif data_left > 0 and data_left < seg:
            data = socket.recv(data_left)


        if not data or data_left == 0:
            if len(ret) == package_length:
                return ret
            else:
                return None

        ret += data
        if len(ret) >= package_length:
            break

    return ret

def start_tcp_server():
    pygame_is_running = False
    pygame_process = None
    parent_conn, child_conn = Pipe()
    
    segment_length = 4096

    try:

        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        server_address = ('0.0.0.0', PORT_NUMBER)
        sock.bind(server_address)
        print >>sys.stderr, 'starting up on %s port %s' % sock.getsockname()
        sock.listen(1)

#        if os.path.exists("/tmp/gs"):
#            os.remove("/tmp/gs")
#        print("Opening socket.../tmp/gs")
#        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
#        sock.bind("/tmp/gs")
#        sock.listen(1)

        while True:
            print >>sys.stderr, 'waiting for a connection'
            connection, client_address = sock.accept()
            connection.settimeout(10)
            try:
                print >>sys.stderr, 'client connected:', client_address
                while True:
                    data = recv_all2(connection,segment_length)

                    if data:
                        data.strip()
                        try:
                            if pygame_is_running == False:
                                pygame_process = Process(target=start_pygame,args=(parent_conn,child_conn))
                                pygame_process.start()
                                pygame_is_running = True
                            
                            if pygame_is_running == True:
                                #print("sending...")
                                try:
                                    parent_conn.send(data)
                                    ret = parent_conn.recv()
                                    if ret=="QUIT":
                                        pygame_is_running = False
                                        connection.sendall("OK\n")
                                        connection.close()
                                        parent_conn.close()
                                        child_conn.close()
                                        parent_conn, child_conn = Pipe()

                                        break

                                    else:
                                        connection.sendall(str(ret)+"\n")

                                except Exception,e:
                                    PrintException()
                                    print("exception on pipe sending data: ",str(e))
                                    parent_conn.close()
                                    child_conn.close()
                                    
                                    pygame_is_running = False
                                    parent_conn, child_conn = Pipe()
                                    
                                    connection.sendall("OK\n") ##tell the client to continue
                                    connection.close()
                                    break
                        except Exception,e:
                            print(str(e))
                            connection.sendall("Error:"+str(e))
                            break
                    else:
                        break

            finally:
                connection.close()

    except KeyboardInterrupt:
        print '^C received, shutting down the web server'
        sock.close()
        exit()



start_tcp_server()

