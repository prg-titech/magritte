from rpython.rlib.objectmodel import enforceargs
import rpython.rtyper.lltypesystem.lltype as lltype
from inst import inst_type_table, InstType
from util import as_dashed
from value import *
from debug import DEBUG
from const import const_table

inst_actions = [None] * len(inst_type_table)
inst_action_sig = enforceargs(None, lltype.Array(lltype.Signed))
def inst_action(fn):
    """NOT_RPYTHON"""
    inst_type = as_dashed(fn.__name__)

    inst_id = inst_type_table.get(inst_type).id
    # inst_actions[inst_id] = inst_action_sig(fn)
    inst_actions[inst_id] = fn

    return fn

@inst_action
def pop(frame, args):
    frame.stack.pop()

@inst_action
def swap(frame, args):
    x = frame.pop()
    y = frame.pop()
    frame.push(x)
    frame.push(y)

@inst_action
def frame(frame, args):
    env = frame.pop_env()
    addr = args[0]
    frame.proc.frame(env, addr)

@inst_action
def spawn(frame, args):
    addr = args[0]
    env = frame.pop_env()
    frame.proc.machine.spawn(env, addr)

@inst_action
def collection(frame, args):
    frame.push(Collection())

@inst_action
def const(frame, args):
    frame.push(const_table.lookup(args[0]))

@inst_action
def collect(frame, args):
    value = frame.pop()
    collection = frame.top_collection()
    collection.push(value)


@inst_action
def index(frame, args):
    idx = args[0]
    source = frame.pop()

    if isinstance(source, Collection):
        frame.push(source.values[idx])
    elif isinstance(source, Vector):
        frame.push(source.values[idx])
    else:
        frame.crash('not indexable')

@inst_action
def current_env(frame, args):
    frame.push(frame.env)

@inst_action
def let(frame, args):
    val = frame.pop()
    env = frame.pop()
    sym = args[0]
    env.let(sym, val)

@inst_action
def vector(frame, args):
    collection = frame.pop_collection()
    frame.push(Vector(collection.values))

@inst_action
def env(frame, args):
    frame.push(Env())

@inst_action
def jump(frame, args):
    frame.pc = args[0]

@inst_action
def return_(frame, args):
    frame.proc.frames.pop()
    if DEBUG: print 'after-return', frame.proc.frames
    if not frame.proc.frames:
        frame.proc.set_done()

@inst_action
def invoke(frame, args):
    collection = frame.pop_collection()
    if not collection.values:
        raise Crash('empty invocation')

    # tail elim
    if frame.current_inst().id == InstType.RETURN:
        frame.proc.frames.pop()

    collection.values[0].invoke(frame, collection.values[1:])

@inst_action
def closure(frame, args):
    addr = args[0]
    env = frame.pop_env()
    frame.push(Function(env, addr))

@inst_action
def env_collect(frame, args):
    env = frame.pop_env()
    collection = frame.pop_collection()
    env.set_output(0, collection)
    frame.push(collection)
    frame.push(env)

@inst_action
def env_extend(frame, args):
    env = frame.pop_env()
    frame.push(env.extend())

@inst_action
def channel(frame, args):
    frame.push(frame.proc.machine.make_channel())

@inst_action
def env_pipe(frame, args):
    channel = frame.pop_channel()
    env = frame.pop_env()
    producer = env.extend()
    producer.set_output(0, channel)
    consumer = env.extend()
    consumer.set_input(0, channel)
    frame.push(consumer)
    frame.push(producer)
