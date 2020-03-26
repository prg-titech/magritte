from table import TableEntry
from actions import inst_actions
from debug import DEBUG
from inst import inst_type_table
from value import *
from channel import Channel, Close
from env import Env
from code import labels_by_addr, inst_table

class Proc(TableEntry):
    INIT = 0
    RUNNING = 1
    WAITING = 2
    DONE = 3
    TERMINATED = 4

    def set_init(self): self.state = Proc.INIT
    def set_running(self): self.state = Proc.RUNNING
    def set_waiting(self): self.state = Proc.WAITING
    def set_done(self): self.state = Proc.DONE
    def set_terminated(self): self.state = Proc.TERMINATED

    def __init__(self, machine):
        self.state = Proc.INIT
        self.machine = machine
        self.frames = []
        self.interrupts = []

    def frame(self, env, addr):
        if DEBUG: print '--', self.id, labels_by_addr[addr].name
        assert isinstance(addr, int)
        frame = Frame(self, env, addr)
        self.frames.append(frame)
        frame.setup()
        return frame

    def current_frame(self):
        return self.frames[len(self.frames)-1]

    def pop(self):
        top = self.frames.pop()
        top.cleanup()

    def step(self):
        # IMPORTANT: only check interrupts when we're waiting!
        if self.state == Proc.WAITING and self.check_interrupts(): return

        self.state = Proc.RUNNING
        return self.current_frame().step()

    def check_interrupts(self):
        if not self.interrupts: return
        interrupt = self.interrupts.pop(0)

        # unwind the stack until the channel goes out of scope
        if isinstance(interrupt, Close):
            while self.frames and self.has_channel(interrupt.is_input, interrupt.channel):
                if DEBUG: print 'unwind!'
                self.pop()

    def has_channel(self, is_input, channel):
        return self.current_frame().env.has_channel(is_input, channel)

    def interrupt(self, interrupt):
        if DEBUG: print 'interrupt', interrupt.s()
        self.interrupts.append(interrupt)
        self.state = Proc.RUNNING


class Frame(object):
    def crash(self, message):
        raise Crash(message)

    def __init__(self, proc, env, addr):
        assert isinstance(env, Env)
        assert isinstance(addr, int)
        self.proc = proc
        self.env = env
        self.pc = self.addr = addr
        self.stack = []

    def s(self):
        out = ['<frame']
        out.append(str(self.proc.id))
        out.append('(')
        out.append(self.label_name())
        out.append(':')
        out.append(str(self.addr))
        for el in self.stack:
            out.append(' ')
            out.append(el.s())

        out.append('>')
        return ''.join(out)

    def __str__(self):
        return self.s()

    def setup(self):
        self.env.each_input(register_as_input, self)
        self.env.each_output(register_as_output, self)

    def cleanup(self):
        if DEBUG: print 'cleanup', self
        self.env.each_input(deregister_as_input, self)
        self.env.each_output(deregister_as_output, self)

    def push(self, val):
        if val is None: raise Crash('pushing None onto the stack')
        self.stack.append(val)

    def pop(self):
        if not self.stack: raise Crash('empty stack!')
        val = self.stack.pop()
        assert isinstance(val, Value)
        return val

    def pop_number(self):
        return self.pop().as_number()

    def pop_string(self, message='not a string: %s'):
        val = self.pop()
        if not isinstance(val, String): raise Crash(message % val.s())
        return val.value

    def pop_env(self, message='not an env: %s'):
        val = self.pop()
        if not isinstance(val, Env): raise Crash(message % val.s())
        return val

    def pop_ref(self, message='not a ref: %s'):
        val = self.pop()
        if not isinstance(val, Ref): raise Crash(message % val.s())
        return val

    def pop_channel(self, message='not a channel: %s'):
        val = self.pop()
        if not isinstance(val, Channel): raise Crash(message % val.s())
        return val

    def pop_vec(self, message='not a vector: %s'):
        val = self.pop()
        if not isinstance(val, Vector): raise Crash(message % val.s())
        return val

    def top_collection(self, message='not a collection: %s'):
        val = self.top()
        if not isinstance(val, Collection): raise Crash(message % val.s())
        return val

    def pop_collection(self, message='not a collection: %s'):
        val = self.top_collection(message)
        self.pop()
        return val

    def top(self):
        return self.stack[len(self.stack)-1]

    def put(self, vals):
        if DEBUG: print 'put', self.env.get_output(0), vals
        self.env.get_output(0).write_all(self.proc, vals)

    def get(self, into, n=1):
        self.env.get_input(0).read(self.proc, n, into)

    def label_name(self):
        return labels_by_addr[self.addr].name

    # @enforceargs(None, lltype.Signed, lltype.Array(lltype.Signed))
    def run_inst_action(self, inst_id, static_args):
        if DEBUG:
            print '+', self.proc.id, inst_type_table.lookup(inst_id).name, static_args

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

    def current_inst(self):
        return inst_table.lookup(self.pc)

def register_as_input(ch, frame): ch.add_reader(frame)
def register_as_output(ch, frame): ch.add_writer(frame)
def deregister_as_input(ch, frame): ch.rm_reader(frame)
def deregister_as_output(ch, frame): ch.rm_writer(frame)

