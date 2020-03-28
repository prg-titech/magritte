import os
from rpython.rlib.rposix import execv
from debug import debug

def spawn(program, args):
    pid = os.fork()
    if pid == 0:
        # the forked process
        execv(program, [program] + args)
    else:
        os.waitpid(pid, 0)
