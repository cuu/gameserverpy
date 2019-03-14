# -*- coding: utf-8 -*- 
import time
import pygame
from pygame.locals import *
from sys import exit

from threading import Thread
from multiprocessing import Process,Pipe
import base64 
import socket
import sys

import lisp


parent_conn, child_conn = Pipe()

class PygameThread(lisp.Lisper):

    def __init__(self):
        lisp.Lisper.__init__(self)
        self.intern('draw.flip', lisp.SyntaxObject(self.draw_flip))
   
    def draw_flip(self,env,args):
        pygame.display.flip()
        return "OK"

def reader_thread(child_conn):
    reader = PygameThread()
    while True:
        data = child_conn.recv()
        ret = reader.evalstring(data)
        child_conn.send(ret)


def midRect(x,y,width,height,canWidth,canHeight):
    return pygame.Rect(min(canWidth,x-width/2),min(canHeight,y-height/2),width,height)

def DrawText(text, x,y,width,height,canWidth,canHeight,fontObj):# text for content,fontObj for pygame.font.Font
    _w = 0
    _tp = len(text)

    for idx,t in enumerate(fontObj.metrics(text)):
        _w = _w + t[1] - t[0]
        if _w > icon_width:
            _tp = idx
            break
    width = _w #recalc the width of text
    if width > icon_width: ##Label width max is icon width
        width = icon_width

    if _tp < len(text):##cut the text to fit width
        text = text[0:_tp]

    screen.blit(fontObj.render(text,True,(83,83,83)),midRect(x,y,width,height,canWidth,canHeight))

     
def init_pygame():
    #pygame.init()
    if not pygame.display.get_init():
        pygame.display.init()
    if not pygame.font.get_init():
        pygame.font.init()

init_pygame()
Width = 320
Height = 240
SCREEN_SIZE = (Width,Height)
bg_color = pygame.Color(255,255,255)
screen = pygame.display.set_mode(SCREEN_SIZE, 0, 32)
 
font = pygame.font.Font("PICO-8.ttf",8);
font_height = font.get_linesize()

icon_width  = 80
icon_height = 80
pygame.event.set_allowed(None) 
pygame.event.set_allowed([pygame.KEYDOWN,pygame.KEYUP])

if pygame.image.get_extended() == False:
    print("This pygame does not support PNG")
    exit()

#bs_b64 = __import__("blueselector_b64")

## 先显示 ,产生b64,pipe到 blueselector_b64.py
#image_surf = pygame.image.load("blueselector.png").convert_alpha() #convert_alpha for png,others just convert()
#print(base64.b64encode(pygame.image.tostring(image_surf,"RGBA")))

bs_b64 = __import__("blueselector_b64")

#clk_b64 = __import__("createby_clockworkpi")
# 再 从blueselector_b64 从 __import__ 出来,decode 
image_surf = pygame.image.frombuffer(base64.b64decode(bs_b64.blueselector),(92,92),"RGBA")
#image_surf2 = pygame.image.frombuffer(base64.b64decode(clk_b64.createby_clockworkpi_b64 ),(320,240),"RGBA")

x = 31
y = 64
step = 9
dx = 1 
dy = 1
frames = 0
prev_time = time.time()
target_fps = 60.0
title = "pygame test"
clock = pygame.time.Clock()
total_time = time.time()
skip = 0
def _update():
    global x,y,dx,dy,step

    x+=step
    y+=step
    

    if x < 1 or x > 256:
        step *= -1
    elif y < 1 or y > 193:
        step *= -1


def _draw():
    global total_time,screen,frames,x,y,icon_width,icon_height,font

    _update()
    screen.fill( bg_color )
    DrawText("this is a test",x,y,80,8,320,240,font)
    DrawText("this is a test2",x,y+8,80,8,320,240,font)
    DrawText("this is a test3",x,y+16,80,8,320,240,font)
    DrawText("this is a test4",x,y+24,80,8,320,240,font)
    DrawText("this is a test4",x,y+32,80,8,320,240,font)
    DrawText("this is a test4",x,y+40,80,8,320,240,font)
    DrawText("this is a test4",x,y+48,80,8,320,240,font)
    DrawText("this is a test4",x,y+56,80,8,320,240,font)
    DrawText("this is a test4",x,y+64,80,8,320,240,font)
    DrawText("this is a test4",x,y+72,80,8,320,240,font)

    screen.blit(image_surf,(x,y,icon_width,icon_height))
    curr_time = time.time() #s   
    frames+=1

    if curr_time - total_time >= 10:
        fps = frames / 10
        print(fps)
        frames = 0
        total_time = curr_time


sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
server_address = ('0.0.0.0', 8080)
sock.bind(server_address)
print >>sys.stderr, 'starting up on %s port %s' % sock.getsockname()
sock.listen(1)

_draw()

segment_length = 1024

t = Thread(target=reader_thread,args=(child_conn,))
t.start()

try:
    while True:

        connection, client_address = sock.accept()
        try:
            while True:
                data = connection.recv(segment_length)
                if data:
                    parent_conn.send(data[8:])
                    ret = parent_conn.recv()
                    _draw()
                    connection.sendall(str(ret)+"\n")
                else:
                    break
        finally:
            connection.close()

except KeyboardInterrupt:
    print '^C received, shutting down the web server'
    pygame.quit()
    parent_conn.close()
    child_conn.close()

    sock.close()
    exit()

         
 
    

