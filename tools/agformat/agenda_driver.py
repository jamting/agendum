# SPDX-License-Identifier: AGPL-3.0-only
r"""Drive Lotus Agenda headlessly in DOSBox Staging (research tool, not part of Agendum).

DOSBox Staging 0.83+ runs without a window (SDL_VIDEODRIVER=dummy) and has a
REST API ([webserver] webserver_enabled=true): GET /api/v1/memory/<addr>/<len>
reads emulated memory, PUT /api/v1/memory/<addr> with {"data": base64} writes
it. The text screen is read from B800:0000; keys are typed by writing
scan/ASCII words into the BIOS keyboard buffer (0040:001E-003D).

Set AGENDA_DOS_ROOT to a directory that holds a COPY of Agenda as
APPS/AGENDA (it is mounted as C:). Example:

    import agenda_driver as d
    d.start("AGENDA TEST")          # opens or creates C:\APPS\AGENDA\TEST.AG
    d.keys("Call Bob tomorrow", "ENTER")
    d.show()                        # print the screen
    d.keys("F10", "q"); d.stop()    # quit; TEST.AG is now in its saved layout

See DRIVING_AGENDA.md (this directory) for what works and what to watch out for,
and docs/plans/archive/AGENDA_FILE_FORMAT_LOG.md for how it was used.
"""
import urllib.request, json, time, subprocess, os, re, base64
S=os.environ.get("AGENDA_DOS_ROOT", os.path.join(os.path.dirname(os.path.abspath(__file__)), "dos"))
U="http://127.0.0.1:8765/api/v1/memory"
DOSBOX="/Applications/DOSBox Staging.app/Contents/MacOS/dosbox"
def _http(req, tries=5):
    # the DOSBox web server occasionally stalls a request; time out and retry
    for i in range(tries):
        try: return urllib.request.urlopen(req, timeout=5).read()
        except (TimeoutError, OSError) as e:
            if i == tries - 1: raise
            time.sleep(0.3)
def rd(addr,n): return _http(f"{U}/{addr:#x}/{n}")
def wr(addr,data):
    r=urllib.request.Request(f"{U}/{addr:#x}",data=json.dumps({"data":base64.b64encode(bytes(data)).decode()}).encode(),method="PUT",headers={"Content-Type":"application/json"})
    _http(r)
def screen():
    d=rd(0xB8000,4000)
    return [''.join(chr(d[(r*80+c)*2]) if 32<=d[(r*80+c)*2]<127 else ('#' if d[(r*80+c)*2]>=128 else ' ') for c in range(80)).rstrip() for r in range(25)]
def show(): print('\n'.join(f"{i:2d}|{l}" for i,l in enumerate(screen())))
# each key's scan code: a keyboard row's first code plus the key's place in
# it (an earlier version rebound the row's code as it went, so the codes added
# up: SC['r'] was U's, and every ALT-letter built from it the wrong key)
SC={c:start+i for start,row in [(0x02,"1234567890-="),(0x10,"qwertyuiop[]"),(0x1E,"asdfghjkl;'`"),(0x2B,"\\zxcvbnm,./")] for i,c in enumerate(row)}
# ALT with a digit, - or = has codes of its own in the BIOS (0x78-0x83)
ALT_SC={c:0x78+i for i,c in enumerate("1234567890-=")}
SH={'!':'1','@':'2','#':'3','$':'4','%':'5','^':'6','&':'7','*':'8','(':'9',')':'0','_':'-','+':'=','{':'[','}':']',':':';','"':"'",'~':'`','|':'\\','<':',','>':'.','?':'/'}
NAMED={'ENTER':0x1C0D,'ESC':0x011B,'TAB':0x0F09,'BS':0x0E08,'UP':0x4800,'DOWN':0x5000,'LEFT':0x4B00,'RIGHT':0x4D00,
 'INS':0x5200,'DEL':0x5300,'HOME':0x4700,'END':0x4F00,'PGUP':0x4900,'PGDN':0x5100,'SPACE':0x3920,'STAB':0x0F00,'CEND':0x7500,'CHOME':0x7700}
for i in range(10):
    NAMED[f'F{i+1}']=(0x3B+i)<<8; NAMED[f'SF{i+1}']=(0x54+i)<<8; NAMED[f'CF{i+1}']=(0x5E+i)<<8; NAMED[f'AF{i+1}']=(0x68+i)<<8
def code(ch):
    if ch==' ': return 0x3920
    if ch in SC: return SC[ch]<<8|ord(ch)
    if ch.lower() in SC and ch.isupper(): return SC[ch.lower()]<<8|ord(ch)
    if ch in SH: return SC[SH[ch]]<<8|ord(ch)
    raise ValueError(ch)
def push(w):
    # wait for room in BIOS buffer (0040:001E..003D)
    for _ in range(200):
        h,t=[int.from_bytes(rd(a,2),'little') for a in (0x41A,0x41C)]
        nt=t+2
        if nt>=0x3E: nt=0x1E
        if nt!=h: break
        time.sleep(0.02)
    wr(0x400+t,w.to_bytes(2,'little')); wr(0x41C,nt.to_bytes(2,'little'))
def alive(): return proc is None or proc.poll() is None
def idle(timeout=10):
    """wait until keyboard buffer is empty and screen is stable"""
    t0=time.time(); last=None; stable=0
    while time.time()-t0<timeout:
      try:
        h,t=[int.from_bytes(rd(a,2),'little') for a in (0x41A,0x41C)]
        s=rd(0xB8000,4000)
        if h==t and s==last: stable+=1
        else: stable=0
        if stable>=2: return
        last=s; time.sleep(0.06)
      except Exception: return
def keys(*ks,delay=0.03):
    """each arg: a named key like 'F10', 'ALT-x', 'CTRL-x' or a literal string ('t:text')"""
    for k in ks:
        if k in NAMED: push(NAMED[k]); idle()
        elif k.startswith('ALT-'): c=k[4:].lower(); push(ALT_SC.get(c, SC[c])<<8); idle()
        elif k.startswith('CTRL-'): c=k[5:].lower(); push(SC[c]<<8|(ord(c)-96))
        else:
            for ch in k: push(code(ch)); time.sleep(delay)
        time.sleep(delay)
    idle()
def wait_for(pat,timeout=20):
    t0=time.time()
    while time.time()-t0<timeout:
        if any(re.search(pat,l) for l in screen()): return True
        time.sleep(0.2)
    show(); raise TimeoutError(pat)
proc=None
def start(cmd="AGENDA"):
    global proc
    conf=f"""[webserver]
webserver_enabled=true
webserver_port=8765
[dosbox]
memsize=16
[cpu]
cycles=max
[mixer]
nosound=true
[speaker]
pcspeaker=false
[autoexec]
mount c {S}
c:
cd \\APPS\\AGENDA
{cmd}
exit
"""
    open(os.path.join(S,"run.conf"),"w").write(conf)
    env=dict(os.environ,SDL_VIDEODRIVER="dummy",SDL_AUDIODRIVER="dummy")
    proc=subprocess.Popen([DOSBOX,"--noprimaryconf","--nolocalconf","-conf",os.path.join(S,"run.conf")],stdout=open(os.path.join(S,"run.log"),"w"),stderr=subprocess.STDOUT,env=env)
    for _ in range(100):
        try: rd(0x400,2); break
        except Exception: time.sleep(0.1)
    time.sleep(1.5)
def stop(timeout=15):
    try: proc.wait(timeout)
    except subprocess.TimeoutExpired: proc.kill(); proc.wait()

import shutil
AG=os.path.join(S,"APPS","AGENDA")
def fresh(name,base):
    """copy the .AG file `base` to C:\\APPS\\AGENDA\\<name>.AG and open it"""
    shutil.copy(base,os.path.join(AG,name+".AG"))
    start(f"AGENDA {name}")
def save():
    keys('F10','f','s'); keys('ENTER')
def quit():
    keys('F10','q'); stop()
def attrs():
    d=rd(0xB8000,4000)
    return [d[(r*80+6)*2+1] for r in range(25)]
def attr_at(r,c):
    return rd(0xB8000+(r*80+c)*2+1,1)[0]
def select(text,key=None,maxn=40):
    if key is None:
        try: return select(text,'DOWN',maxn)
        except RuntimeError: return select(text,'UP',maxn*2)
    """press key until the row containing text is highlighted (its attr differs from most rows)"""
    for _ in range(maxn):
        sc=screen()
        for r,l in enumerate(sc):
            if r<2 or text not in l: continue
            c=l.index(text)
            a=attr_at(r,c)
            # highlighted: its attribute differs from every other non-blank row in the same column
            others=[attr_at(rr,c) for rr in range(2,23) if rr!=r and sc[rr][c:c+1].strip()]
            if others and all(a!=o for o in others): return True
        keys(key)
    raise RuntimeError('not found '+text)

# --- settings boxes and saving (see DRIVING_AGENDA.md) -----------------------
def current_label(attr=0x3f):
    """The label of the current field in a settings box: drawn with attribute 0x3F."""
    m=rd(0xB8000,4000); out=[]
    for r in range(1,23):
        s="".join(chr(m[(r*80+c)*2]) for c in range(80) if m[(r*80+c)*2+1]==attr)
        if s.strip(): out.append(s.strip())
    return " | ".join(out)
def current_row(attr=0x3f):
    m=rd(0xB8000,4000)
    for r in range(1,23):
        if any(m[(r*80+c)*2+1]==attr and m[(r*80+c)*2]>32 for c in range(80)): return r
def goto(label,key="DOWN",maxn=24):
    """Move to the box field whose label contains `label`: down the left column, then the right."""
    want=label.lower()
    def here(): return want in current_label().lower()
    if here(): return
    for side in (None,"RIGHT","RIGHT","LEFT","LEFT"):
        if side: keys(side)
        seen=[]
        for _ in range(maxn):
            if here(): return
            cl=(current_label(),current_row())
            if seen.count(cl)>=2: break
            seen.append(cl); keys(key)
    show(); raise RuntimeError("field not found: "+label+" (at "+current_label()+")")
def setf(label,presses=1,key="SPACE"):
    """Go to a field and press SPACE (cycle a choice) `presses` times."""
    goto(label)
    for _ in range(presses): keys(key)
def in_view(): return screen()[1].strip().startswith("View:")
def home():
    """ESC until the main view shows (cancels any open box or menu)."""
    for _ in range(6):
        if in_view(): return
        keys("ESC"); idle()
    raise RuntimeError("cannot get back to the view")
def robust_save():
    """File Save without quitting, checking the screen after each key (keys are occasionally lost)."""
    for attempt in range(4):
        home()
        keys("F10"); idle()
        if not screen()[0].strip().startswith("File"): continue
        keys("f"); idle()
        if not screen()[0].strip().startswith("Retrieve"): continue
        keys("s"); idle()
        if not any("Save File" in l for l in screen()): continue
        keys("ENTER"); idle()
        if in_view(): return
    raise RuntimeError("save failed")
