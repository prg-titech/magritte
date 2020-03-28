from rpython.rlib.objectmodel import enforceargs
import rpython.rtyper.lltypesystem.lltype as lltype
from inst import inst_type_table, InstType
from util import as_dashed
from value import *
from debug import debug
from const import const_table
from intrinsic import intrinsics
from env import Env
from symbol import revsym # error messages only

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
def noop(frame, args):
    pass

@inst_action
def swap(frame, args):
    x = frame.pop()
    y = frame.pop()
    frame.push(x)
    frame.push(y)

@inst_action
def dup(frame, args):
    if debug(): print '-- dup', frame.s()
    frame.push(frame.top())

@inst_action
def frame(frame, args):
    env = frame.pop_env()
    addr = args[0]
    if debug(): print '-- frame', env.s()
    frame.proc.frame(env, addr)

@inst_action
def spawn(frame, args):
    addr = args[0]
    env = frame.pop_env()
    new_proc = frame.proc.machine.spawn(env, addr)
    if debug(): print '-- spawn', env.s(), new_proc.s()

@inst_action
def collection(frame, args):
    frame.push(Vector([]))

@inst_action
def const(frame, args):
    frame.push(const_table.lookup(args[0]))

@inst_action
def collect(frame, args):
    value = frame.pop()
    collection = frame.top_vec()
    collection.push(value)


@inst_action
def index(frame, args):
    idx = args[0]
    source = frame.pop()

    if isinstance(source, Vector):
        frame.push(source.values[idx])
    else:
        if debug(): print source.s()
        if debug(): print 'frame: ', frame.s()
        frame.crash('not indexable')

@inst_action
def current_env(frame, args):
    frame.push(frame.env)

@inst_action
def let(frame, args):
    val = frame.pop()
    env = frame.pop()
    sym = args[0]
    if debug(): print revsym(sym), '=', val.s()
    env.let(sym, val)

@inst_action
def env(frame, args):
    frame.push(Env())

@inst_action
def ref(frame, args):
    env = frame.pop_env()
    ref = env.lookup_ref(args[0])
    frame.push(ref)

@inst_action
def ref_get(frame, args):
    ref = frame.pop_ref()
    frame.push(ref.ref_get())

@inst_action
def ref_set(frame, args):
    val = frame.pop()
    ref = frame.pop_ref()
    ref.ref_set(val)

@inst_action
def jump(frame, args):
    frame.pc = args[0]

@inst_action
def jumpne(frame, args):
    lhs = frame.pop()
    rhs = frame.pop()

    if debug(): print '-- jumpne', lhs.s(), rhs.s()

    # TODO: define equality properly!
    if lhs.s() == rhs.s(): return

    frame.pc = args[0]

@inst_action
def jumplt(frame, args):
    val = frame.pop_number()
    if val < args[0]:
        frame.pc = args[1]

@inst_action
def return_(frame, args):
    proc = frame.proc
    proc.pop()
    if debug(): print 'after-return', proc.s()
    if not proc.frames:
        proc.set_done()

@inst_action
def invoke(frame, args):
    collection = frame.pop_vec()
    if not collection.values:
        raise Crash('empty invocation')

    if debug(): print '-- invoke', collection.s()

    # tail elim
    if frame.current_inst().id == InstType.RETURN:
        frame.proc.frames.pop()

    invokee = collection.values.pop(0)
    if not invokee.invokable: raise Crash('cannot invoke %s' % invokee.s())

    invokee.invokable.invoke(frame, collection)

@inst_action
def closure(frame, args):
    addr = args[0]
    env = frame.pop_env()
    frame.push(Function(env, addr))

@inst_action
def env_collect(frame, args):
    env = frame.pop_env()
    collection = frame.pop_vec()
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
    if debug(): print '-- pipe %s | %s' % (producer, consumer)
    frame.push(consumer)
    frame.push(producer)

@inst_action
def intrinsic(frame, args):
    try:
        builtin = intrinsics.lookup(args[0])
        frame.push(builtin)
    except IndexError:
        frame.crash('unknown intrinsic: '+revsym(args[0]))

@inst_action
def rest(frame, args):
    size = args[0]
    assert size >= 0
    source = frame.pop()
    if isinstance(source, Vector):
        assert size <= len(source.values)
        frame.push(Vector(source.values[size:]))
    else:
        if debug(): print source.s()
        if debug(): print 'frame: ', frame.s()
        frame.crash('not indexable')

@inst_action
def size(frame, args):
    source = frame.pop()
    if isinstance(source, Vector):
        frame.push(Int(len(source.values)))
    else:
        if debug(): print source.s()
        if debug(): print 'frame: ', frame.s()
        frame.crash('not indexable')

@inst_action
def typeof(frame, args):
    val = frame.pop()
    frame.push(String(val.typeof()))

@inst_action
def crash(frame, args):
    if debug(): print '-- crash', frame.proc.s()
    raise Crash

@inst_action
def clear(frame, args):
    if len(frame.stack) > 1:
        frame.stack.pop(len(frame.stack) - 1)
    if debug(): print '-- clear', frame.s()
