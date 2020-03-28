import os
from rpython.rlib.rposix import execv

def spawn(program, args):
    pid = os.fork()
    if pid == 0:
        # the forked process
        execv(program, [program] + args)
    else:
        os.waitpid(pid, 0)

def entry_point(argv):
    spawn('/usr/bin/echo', ['hello', 'world'])
    print 'done!'
    return 0

def target(*args):
    return entry_point
