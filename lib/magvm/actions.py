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
from status import Success, Fail

inst_actions = [None] * len(inst_type_table)
inst_action_sig = enforceargs(None, lltype.Array(lltype.Signed))

def inst_action(fn):
    """NOT_RPYTHON"""
    inst_type = as_dashed(fn.__name__)
    debug(0, ['-- inst_type', inst_type])

    inst_id = inst_type_table.get(inst_type).id
    # inst_actions[inst_id] = inst_action_sig(fn)
    inst_actions[inst_id] = fn

    return fn


################## actions! #################
# These functions implement the instructions
# of the vm, and are run by a Frame whenever
# it encounters the corresponding instruction.
#
# see inst.py for descriptions of these.
# see frame.py, specifically the .step() method
#     to see how they're called.

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
    debug(0, ['-- dup', frame.s()])
    frame.push(frame.top())

@inst_action
def frame(frame, args):
    env = frame.pop_env()
    addr = args[0]
    debug(0, ['-- frame', env.s()])
    frame.proc.frame(env, addr)

@inst_action
def spawn(frame, args):
    addr = args[0]
    env = frame.pop_env()
    new_proc = frame.proc.machine.spawn(env, addr)
    debug(0, ['-- spawn', env.s(), new_proc.s()])

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
    source = frame.pop_vec()
    frame.push(source.values[idx])

@inst_action
def current_env(frame, args):
    frame.push(frame.env)

@inst_action
def let(frame, args):
    val = frame.pop()
    env = frame.pop()
    sym = args[0]
    debug(0, [revsym(sym), '=', val.s()])
    env.let(sym, val)

@inst_action
def env(frame, args):
    frame.push(Env())

@inst_action
def ref(frame, args):
    env = frame.pop_env()
    try:
        frame.push(env.lookup_ref(args[0]))
    except KeyError:
        frame.fail(tagged('missing-key', env, String(revsym(args[0]))))

@inst_action
def dynamic_ref(frame, args):
    debug(0, [frame.s()])
    lookup = frame.pop_string()
    env = frame.pop_env()
    debug(0, ['-- dynamic-ref lookup:', lookup, env.s()])

    try:
        frame.push(env.lookup_ref(sym(lookup)))
    except KeyError:
        ref = env.let(sym(lookup), placeholder)
        frame.push(ref)

@inst_action
def ref_get(frame, args):
    ref = frame.pop_ref()
    val = ref.ref_get()

    if val == placeholder:
        frame.fail(tagged('uninitialized-ref', ref))

    frame.push(val)

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

    debug(0, ['-- jumpne', lhs.s(), rhs.s()])

    # TODO: define equality properly!
    if lhs.s() == rhs.s(): return

    frame.pc = args[0]

@inst_action
def jumplt(frame, args):
    limit = frame.pop_number()
    val = frame.pop_number()

    debug(0, ['-- jumplt', str(val), '<', str(limit)])

    if val < limit:
        frame.pc = args[0]

@inst_action
def return_(frame, args):
    proc = frame.proc
    proc.pop()
    debug(0, ['-- returned', proc.s()])

    for (addr, is_unconditional) in frame.compensations:
        debug(0, ['-- ret-comp', ('(run!)' if is_unconditional else '(skip)'), labels_by_addr[addr].name])
        if is_unconditional: proc.frame(frame.env, addr)

    if not proc.frames:
        proc.set_done()

@inst_action
def invoke(frame, args):
    collection = frame.pop_vec()
    if not collection.values:
        frame.fail_str('empty-invocation')

    debug(0, ['-- invoke', collection.s()])

    # tail elim is handled in proc.py
    # if frame.current_inst().id == InstType.RETURN:
    #     frame.proc.frames.pop()

    invokee = collection.values.pop(0)
    if not invokee.invokable: frame.fail(tagged('not-invokable', invokee))

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
def wait_for_close(frame, args):
    collection = frame.top_vec()
    if collection.is_closed: return

    frame.proc.machine.channels.register(collection)
    collection.wait_for_close(frame.proc)
    debug(0, ['-- wait-for-close', collection.s(), frame.proc.s()])

@inst_action
def env_extend(frame, args):
    env = frame.pop_env()
    frame.push(env.extend())

@inst_action
def env_unhinge(frame, args):
    env = frame.pop_env()
    frame.push(env.unhinge())

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
    debug(0, ['-- pipe %s | %s' % (producer.s(), consumer.s())])
    frame.push(consumer)
    frame.push(producer)

@inst_action
def env_set_input(frame, args):
    idx = args[0]
    inp = frame.pop_channel()
    env = frame.pop_env()
    env.set_input(idx, inp)

@inst_action
def env_set_output(frame, args):
    idx = args[0]
    outp = frame.pop_channel()
    env = frame.pop_env()
    env.set_output(idx, outp)

@inst_action
def intrinsic(frame, args):
    try:
        builtin = intrinsics.lookup(args[0])
        frame.push(builtin)
    except IndexError:
        frame.fail(tagged('unknown-intrinsic', String(revsym(args[0]))))

@inst_action
def rest(frame, args):
    size = args[0]
    source = frame.pop_vec()
    assert size < len(source.values)
    assert size >= 0
    frame.push(Vector(source.values[size:]))

@inst_action
def size(frame, args):
    source = frame.pop_vec()
    frame.push(Int(len(source.values)))

@inst_action
def typeof(frame, args):
    val = frame.pop()
    frame.push(String(val.typeof()))

@inst_action
def crash(frame, args):
    reason = frame.pop()
    debug(0, ['-- crash: ', frame.proc.s(), reason.s()])
    raise Crash(reason)

@inst_action
def clear(frame, args):
    if len(frame.stack) > 1:
        frame.stack.pop(len(frame.stack) - 1)
    debug(0, ['-- clear', frame.s()])

@inst_action
def last_status(frame, args):
    frame.push(frame.proc.status)

@inst_action
def jumpfail(frame, args):
    status = frame.pop_status()
    debug(0, ['-- jumpfail', status.s()])
    if not status.is_success():
        frame.pc = args[0]

@inst_action
def compensate(frame, args):
    is_unconditional = (args[1] == 1)
    frame.add_compensation(args[0], is_unconditional)
