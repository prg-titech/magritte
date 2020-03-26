from env import Env
from util import as_dashed
from symbol import sym
from channel import Streamer
from value import *
from debug import DEBUG

base_env = Env()

def global_out(proc, vals):
    for val in vals:
        if DEBUG: print '==== GLOBAL_OUT ====', repr(val)
        print repr(val)

base_env.set_output(0, Streamer(global_out))


