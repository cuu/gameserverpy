import socket
import sys
import pygame
from threading import Thread
from multiprocessing import Process,Pipe

import lisp

PORT_NUMBER = 8080

DT = pygame.time.Clock().tick(40)   # fps in ms,eg:50

class PygameThread(lisp.Lisper):
    Width = 320
    Height = 240
    Inited = False

    DT = pygame.time.Clock().tick(30)
    font1 = None
    font2 = None
    bg_color = pygame.Color(255,255,255)
   
    def __init__(self):
        lisp.Lisper.__init__(self) 
        self.intern('api.print', lisp.SyntaxObject(self.api_print))
        self.intern('api.cls', lisp.SyntaxObject(self.api_cls))
        self.intern('api.flip', lisp.SyntaxObject(self.api_flip))
  
    def api_print(self,env,args):
        if len(args) < 3:
            return
        assert self.Inited== True,"Not inited"
 
        text  = args[0].eval(env)
        x     = args[1].eval(env)
        y     = args[2].eval(env)
        color = (10,0,0)
        #print("api_print")
        imgText = self.font1.render(text,True,color)

        if self.Screen.get_locked() == False:
            self.Screen.blit(imgText,(int(x),int(y)))

        return "OK"

    def api_cls(self,env,args):
        assert self.Inited== True,"Not inited"
        
        frame = 1
        ans = 0
        if len(args) > 0:
            ans = args[0].eval(env)
        
        frame = ans
        self.Screen.fill(self.bg_color) 
        #print("api_cls")
        return "OK"
    
    def api_flip(self,env,args):
        self.Screen.lock()
        pygame.display.flip()
        self.Screen.unlock()
        return "OK"
         
    def print_text(self,font,x,y,text,color=(255,255,255)):
        imgText = font.render(text,True,color)
        if self.Screen.get_locked() == False:
            self.Screen.blit(imgText,(x,y))

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
        self.bg_color = pygame.Color(255,255,255)
        self.Screen = pygame.display.set_mode(SCREEN_SIZE, 0, 32)
        pygame.event.set_allowed(None)
        pygame.event.set_allowed([pygame.KEYDOWN,pygame.KEYUP])
    
    
    def quit_window(self):
        self.Inited = False
        self.Screen = None
        pygame.quit()

    def read_data_thread(self):
        while self.Inited:
            data = self.child_conn.recv()
            ret = self.evalstring(data) ## every api must have a return content
            self.child_conn.send(ret)

    def run(self):
        global DT
        try:
            while self.Inited: 
                event = pygame.event.poll()

                if event.type == pygame.QUIT:
                    return
    
                if event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_p:
                        self.Screen.fill((255,255,255))
                        self.print_text(self.font1,40,30,"Let see!")
                        pygame.display.update()
                    if event.key == pygame.K_ESCAPE or event.key == pygame.K_q:
                        print("quit ....")
                        return             
            
    #            pygame.time.delay(self.DT)
                pygame.time.delay(DT)
        finally:
            self.quit_window()

def start_pygame(child):
    api = PygameThread()
    api.init_window()
    api.child_conn = child
 
    t = Thread(target=api.read_data_thread)
    t.start()

    api.run()

def start_tcp_server():
    pygame_is_running = False
    pygame_process = None
    parent_conn, child_conn = Pipe()
    
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        server_address = ('0.0.0.0', PORT_NUMBER)
        sock.bind(server_address)
        print >>sys.stderr, 'starting up on %s port %s' % sock.getsockname()
        
        sock.listen(1)
        while True:
            print >>sys.stderr, 'waiting for a connection'
            connection, client_address = sock.accept()
            #connection.settimeout(2)
            try:
                print >>sys.stderr, 'client connected:', client_address
                while True:
                    data = connection.recv(512) # the line length
                    #print >>sys.stderr, 'received "%s"' % data
                    data = data.strip()
                    if data:
                        try:
                            if pygame_is_running == False:
                                pygame_process = Process(target=start_pygame,args=(child_conn,))
                                pygame_process.start()
                                pygame_is_running = True
                            
                            if pygame_is_running == True:
                                parent_conn.send(data)
                                if parent_conn.poll(1):
                                    ret = parent_conn.recv()                
                                    connection.sendall(ret+"\n")
                                else:
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
                    else:
                        break
            finally:
                connection.close()

    except KeyboardInterrupt:
        print '^C received, shutting down the web server'
        sock.close()
        exit()



start_tcp_server()

