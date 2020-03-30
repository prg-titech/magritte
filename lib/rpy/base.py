from env import Env
from util import as_dashed
from symbol import sym
from channel import Streamer
from value import *
from debug import debug

base_env = Env()

def global_out(proc, vals):
    for val in vals:
        debug(0, ['==== GLOBAL_OUT ====', val.s()])
        print val.s()

base_env.set_output(0, Streamer(global_out))


