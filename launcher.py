# Minimal x64 Windows launcher. Use RIP-relative references into a single section.
import struct
from pathlib import Path
p=lambda fmt,*v:struct.pack('<'+fmt,*v)
s=bytearray(2048)
def put(i,b): s[i:i+len(b)]=b
r=lambda i:4096+i
imports=['GetModuleFileNameW','SetCurrentDirectoryW','WinExec','ExitProcess']
put(256,p('5I',r(336),0,0,r(320),r(384)))
put(320,b'KERNEL32.dll\0')
for i,name in enumerate(imports):
    j=448+32*i
    put(j,b'\0\0'+name.encode()+b'\0')
    for pos in (336,384):put(pos+8*i,p('Q',r(j)))
cmd=b'powershell.exe -NoProfile -STA -NoExit -File ".\\Sync.ps1"\0'
put(600,cmd)
c=bytearray()
def op(h):c.extend(bytes.fromhex(h))
def rip(h,target):
    op(h);c.extend(p('i',target-len(c)-4))
def call(i):rip('ff15',384+8*i)
op('4883ec28 31c9');rip('488d15',2048);op('41b8 ff7f0000');call(0)
op('85c0');zero=len(c);op('7400')
rip('488d0d',2048);op('488d1441')
loop=len(c);op('4883ea02 66833a5c');op('75');c.append((loop-len(c)-1)%256)
op('66c7020000');call(1);op('85c0');fail=len(c);op('7400')
rip('488d0d',600);op('ba01000000');call(2)
end=len(c);op('31c9');call(3)
c[zero+1]=end-zero-2;c[fail+1]=end-fail-2
put(0,c)
dos=bytearray(128);dos[:2]=b'MZ';dos[60:64]=p('I',128)
h=b'PE\0\0'+p('HHIIIHH',0x8664,1,0,0,0,240,0x23)
opt=p('HBBIIIIIQII',523,1,0,2048,2048,0,4096,4096,0x140000000,4096,512)
opt+=p('6H4I2H4Q2I',6,0,0,0,6,0,0,0x12000,512,0,2,0x100,1<<20,4096,1<<20,4096,0,16)
opt+=p('4I',0,0,r(256),40)+bytes(112)
section=b'.main\0\0\0'+p('8I',67584,4096,2048,512,0,0,0,0xe0000060)
Path('Client/ModSync.exe').write_bytes((dos+h+opt+section).ljust(512,b'\0')+s)
