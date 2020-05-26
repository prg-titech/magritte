from util import as_dashed
from table import Table, TableEntry
from value import *
from symbol import sym
from debug import debug, set_debug
from status import Success, Fail
import os

intrinsics = Table()

################## instruction implementations #############
def intrinsic(fn):
    intrinsic_name = as_dashed(fn.__name__)
    def wrapper(frame, args):
        debug(0, [':', '@!'+intrinsic.name] + [a.s() for a in args])
        return fn(frame, args)

    # make sure the name is stored as a symbol
    sym(intrinsic_name)

    intrinsic = Intrinsic(intrinsic_name, wrapper)
    intrinsics.register(intrinsic)
    return intrinsic

@intrinsic
def add(frame, args):
    total = 0
    for arg in args:
        total += arg.as_number(frame)

    frame.put([Int(total)])

@intrinsic
def mul(frame, args):
    product = 1
    for arg in args:
        product *= arg.as_number(frame)

    frame.put([Int(product)])

@intrinsic
def get(frame, args):
    # we can't block, so we have to specify a place to write
    # the value to when it's ready. eventually this will be
    # a collector.
    frame.get(frame.env.get_output(0))

@intrinsic
def take(frame, args):
    assert isinstance(args[0], Value)
    count = args[0].as_number(frame)
    frame.env.get_input(0).channelable.read(frame.proc, count, frame.env.get_output(0))

@intrinsic
def for_(frame, args):
    for vec in args:
        if not isinstance(vec, Vector): frame.fail(tagged('not-a-vector', vec))
        frame.put(vec.values)

@intrinsic
def stdout(frame, args):
    try:
        parent_frame = frame.proc.frames[len(frame.proc.frames)-2]
    except IndexError:
        parent_frame = frame

    frame.push(parent_frame.env.get_output(0))

@intrinsic
def fail(frame, args):
    frame.set_status(Fail(args[0]))
    frame.proc.pop()

@intrinsic
def crash(frame, args):
    frame.crash(Fail(args[0]))

@intrinsic
def make_channel(frame, args):
    frame.put([frame.proc.machine.make_channel()])

@intrinsic
def str_(frame, args):
    out = ''
    for arg in args:
        out += arg.s()

    frame.put([String(out)])

@intrinsic
def eq(frame, args):
    if args[0].eq(args[1]):
        frame.set_status(Success())
    else:
        frame.set_status(Fail(String('not-eq')))

@intrinsic
def len_(frame, args):
    vec = args[0]
    if isinstance(vec, Vector):
        frame.put([Int(len(vec.values))])
    else:
        frame.fail(tagged('not-a-vector', vec))
        return

@intrinsic
def getenv(frame, args):
    key = args[0]
    assert isinstance(key, String)
    try:
        frame.put([String(os.environ[key.value])])
        frame.set_status(Success())
    except KeyError:
        frame.set_status(Fail(String('no-key')))

@intrinsic
def vm_debug(frame, args):
    level = args[0].as_number(frame)

    debug(0, ['-- setting debug: ', str(level)])
    set_debug(level)
    debug(0, ['-- done setting debug: ', str(level)])
