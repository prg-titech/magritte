from env import Env
from status import Status, Success, Fail
from labels import labels_by_addr, inst_table
from inst import inst_type_table, InstType
from debug import debug
from load import arg_as_str
from actions import inst_actions
from value import *

################# frame #####################
# This class represents a stack frame inside
# a single process. It contains a program
# counter which points to the current
# instruction, and an environment holding the
# variables in its local scope.
#
# The frame also represents the main API for
# intrinsics and instructions (actions) to
# change the state of the machine - the
# current frame is always passed in to their
# implementations.
#
# see env.py for environments
# see proc.py for the process
# see actions.py and intrinsic.py for
#     the use of many of these methods

class Frame(object):
    def crash(self, message):
        assert isinstance(message, Status)
        raise Crash(message)

    def fail(self, reason):
        raise Crash(Fail(reason))

    def fail_str(self, reason_str):
        raise Crash(Fail(String(reason_str)))

    def add_compensation(self, addr, is_unconditional):
        debug(0, ['-- add-compensation', self.s(), labels_by_addr[addr].name, str(is_unconditional)])
        self.compensations.append((addr, is_unconditional))

    def __init__(self, proc, env, addr):
        assert isinstance(env, Env)
        assert isinstance(addr, int)
        self.proc = proc
        self.env = env
        self.pc = self.addr = addr
        self.stack = []
        self.compensations = []

    def s(self):
        out = ['<frame/']
        out.append(str(self.proc.id))
        out.append('@')
        out.append(self.label_name())
        out.append(':')
        out.append(str(self.pc - self.addr))
        for el in self.stack:
            out.append(' ')
            out.append(el.s())

        if self.compensations:
            out.append(' %% ')
            out.append(str(len(self.compensations)))

        out.append('>')
        return ''.join(out)

    def __str__(self):
        return self.s()

    def setup(self):
        self.env.each_input(register_as_input, self)
        self.env.each_output(register_as_output, self)

    def set_status(self, status):
        debug(0, ['-- set status', status.s()])
        self.proc.status = status

    def cleanup(self):
        debug(0, ['-- cleanup', self.s()])
        self.env.each_input(deregister_as_input, self)
        self.env.each_output(deregister_as_output, self)
        is_success = self.proc.status.is_success()
        self.proc.last_cleaned.append(self)

    def push(self, val):
        assert val is not None, 'pushing None onto the stack'

        self.stack.append(val)

    def pop(self):
        if not self.stack: raise Crash(Fail(String('empty-stack')))
        val = self.stack.pop()
        assert isinstance(val, Value)
        return val

    def pop_number(self):
        return self.pop().as_number(self)

    def pop_string(self, message='not-a-string'):
        val = self.pop()
        if not isinstance(val, String): self.fail(tagged(message, val))
        return val.value

    def pop_status(self, message='not-a-status'):
        val = self.pop()
        if not isinstance(val, Status): self.fail(tagged(message, val))
        return val

    def pop_env(self, message='not-an-env'):
        val = self.pop()
        if not isinstance(val, Env): self.fail(tagged(message, val))
        return val

    def pop_ref(self, message='not-a-ref'):
        val = self.pop()
        if not isinstance(val, Ref): self.fail(tagged(message, val))
        return val

    def pop_channel(self, message='not-a-channel'):
        val = self.pop()
        if not val.channelable: self.fail(tagged(message, val))
        return val

    def pop_vec(self, message='not-a-vector'):
        val = self.pop()
        if not isinstance(val, Vector): self.fail(tagged(message, val))
        return val

    def top_vec(self, message='not-a-vector'):
        val = self.top()
        if not isinstance(val, Vector): self.fail(tagged(message, val))
        return val

    def top(self):
        return self.stack[len(self.stack)-1]

    def put(self, vals):
        debug(0, ['-- put', self.env.get_output(0).s()] + [v.s() for v in vals])
        self.env.get_output(0).channelable.write_all(self.proc, vals)

    def get(self, into, n=1):
        self.env.get_input(0).channelable.read(self.proc, n, into)

    def label_name(self):
        return labels_by_addr[self.addr].name

    # @enforceargs(None, lltype.Signed, lltype.Array(lltype.Signed))
    def run_inst_action(self, inst_id, static_args):
        inst_type = inst_type_table.lookup(inst_id)
        debug(0, ['+', inst_type.name] +
                 [arg_as_str(inst_type, i, arg) for (i, arg) in enumerate(static_args)])

        action = inst_actions[inst_id]
        if not action:
            raise NotImplementedError('action for: '+inst_type_table.lookup(inst_id).name)

        for arg in static_args:
            assert isinstance(arg, int)

        action(self, static_args)

    def step(self):
        inst = self.current_inst()
        self.pc += 1
        self.state = self.run_inst_action(inst.inst_id, inst.arguments)
        return self.state

    def should_eliminate(self):
        return self.current_inst().inst_id == InstType.RETURN

    def current_inst(self):
        return inst_table.lookup(self.pc)

def register_as_input(ch, frame): ch.channelable.add_reader(frame)
def register_as_output(ch, frame): ch.channelable.add_writer(frame)
def deregister_as_input(ch, frame): ch.channelable.rm_reader(frame)
def deregister_as_output(ch, frame): ch.channelable.rm_writer(frame)

