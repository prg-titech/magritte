from env import Env
from util import as_dashed
from symbol import sym
from channel import Streamer
from value import *

base_env = Env()

def global_out(proc, vals):
    for val in vals:
        print repr(val)

base_env.set_output(0, Streamer(global_out))


################## instruction implementations #############
def builtin(fn):
    # use the @! prefix which is only available when the parser has
    # allow_intrinsics set (i.e. only usable in prelude and other controlled
    # places).
    builtin_name = '@!' + as_dashed(fn.__name__)
    base_env.let(sym(builtin_name), Builtin(fn))

@builtin
def add(frame, args):
    total = 0
    for arg in args:
        total += arg.as_number()

    frame.put([Int(total)])

@builtin
def put(frame, args):
    frame.put(args)

@builtin
def get(frame, args):
    # we can't block, so we have to specify a place to write
    # the value to when it's ready. eventually this will be
    # a collector.
    frame.get(frame.env.get_output(0))

@builtin
def take(frame, args):
    assert isinstance(args[0], Value)
    count = args[0].as_number()
    frame.env.get_input(0).pipe(count, frame.env.get_output(1))

@builtin
def for_(frame, args):
    vec = args[0]
    if not isinstance(Vector, vec): return frame.crash('not a vector')
    frame.put(vec.values)

@builtin
def stdout(frame, args):
    try:
        parent_frame = frame.proc.frames[len(frame.proc.frames)-2]
    except IndexError:
        parent_frame = frame

    frame.push(parent_frame.env.get_output(0))
