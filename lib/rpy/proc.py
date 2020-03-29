from table import TableEntry
from actions import inst_actions
from debug import debug
from inst import inst_type_table, InstType
from value import *
from channel import Channel, Close
from env import Env
from code import labels_by_addr, inst_table
from load import arg_as_str
from status import Status, Success, Fail

class Proc(TableEntry):
    INIT = 0
    RUNNING = 1
    WAITING = 2
    INTERRUPTED = 3
    DONE = 4
    TERMINATED = 5

    def set_init(self): self.state = Proc.INIT
    def set_running(self): self.state = Proc.RUNNING
    def set_waiting(self): self.state = Proc.WAITING
    def set_interrupted(self): self.state = Proc.INTERRUPTED
    def set_done(self): self.state = Proc.DONE
    def set_terminated(self): self.state = Proc.TERMINATED

    # important: a channel will set a successful write to "running". but
    # if that write pipes into a closed channel it will properly get set to
    # INTERRUPTED and we want to avoid overriding that.
    def try_set_running(self):
        if self.state == Proc.INTERRUPTED:
            if debug(): print 'try_set_running: already interrupted', self.s()
        else:
            if debug(): print 'try_set_running: set to running', self.s()
            self.set_running()

    def state_name(self):
        if self.state == Proc.INIT: return 'init'
        if self.state == Proc.RUNNING: return 'running'
        if self.state == Proc.WAITING: return 'waiting'
        if self.state == Proc.INTERRUPTED: return 'interrupted'
        if self.state == Proc.DONE: return 'done'
        if self.state == Proc.TERMINATED: return 'terminated'
        assert False

    def is_running(self):
        return self.state in [Proc.INIT, Proc.RUNNING, Proc.INTERRUPTED]

    def __init__(self, machine):
        self.state = Proc.INIT
        self.machine = machine
        self.frames = []
        self.interrupts = []

    def frame(self, env, addr):
        if debug(): print '--', self.id, labels_by_addr[addr].name
        assert isinstance(addr, int)
        eliminated = self.tail_eliminate()

        if eliminated:
            env = eliminated.env.merge(env)

        frame = Frame(self, env, addr)
        self.frames.append(frame)
        frame.setup()
        return frame

    def tail_eliminate(self):
        out = None

        # don't tail eliminate the root frame, for Reasons.
        # the root frame might have the global env and we really don't want
        # to mess with that env
        if len(self.frames) <= 1: return

        while len(self.frames) > 1 and self.current_frame().should_eliminate():
            if debug(): print 'tail eliminating %s' % self.current_frame().s()
            out = self.pop()

        if debug() and out: print 'after elimination', self.s()

        return out

    def current_frame(self):
        return self.frames[len(self.frames)-1]

    def pop(self):
        top = self.frames.pop()
        top.cleanup()
        return top

    def step(self):
        if debug():
            print '=== step %s ===' % self.s()
            if self.frames:
                env = self.current_frame().env
                print 'env:', env.s()
                print 'in:', env.get_input(0) and env.get_input(0).s()
                print 'out:', env.get_output(0) and env.get_output(0).s()


        try:
            while self.frames and self.is_running():
                # IMPORTANT: only check interrupts when we're waiting!
                if self.state == Proc.INTERRUPTED and self.check_interrupts(): return

                self.state = Proc.RUNNING
                self.current_frame().step()
        except Crash as e:
            self.status = e.status

        if not self.frames:
            if debug(): print 'out of frames', self.s()
            self.state = Proc.DONE


    def check_interrupts(self):
        if debug(): print 'check_interrupts', self.s()
        if not self.interrupts: return False

        interrupt = self.interrupts.pop(0)
        if debug(): print 'interrupted:', interrupt.s()

        # unwind the stack until the channel goes out of scope
        if isinstance(interrupt, Close):
            if debug(): print 'channel closed', interrupt.s()
            if debug(): print 'env:', self.current_frame().env.s()
            if debug(): print 'has channel?', self.has_channel(not interrupt.is_input, interrupt.channel)

            while self.frames and self.has_channel(not interrupt.is_input, interrupt.channel):
                if debug(): print 'unwind!'
                self.pop()

            if self.frames:
                self.state = Proc.RUNNING
            else:
                self.state = Proc.DONE
        else:
            # TODO: status types
            self.state = Proc.TERMINATED

        return True

    def has_channel(self, is_input, channel):
        return self.current_frame().env.has_channel(is_input, channel)

    def interrupt(self, interrupt):
        if debug(): print 'interrupt', self.s(), interrupt.s()
        self.interrupts.append(interrupt)
        self.state = Proc.INTERRUPTED

    def s(self):
        out = ['<proc', str(self.id), ':', self.state_name()]
        for frame in self.frames:
            out.append(' ')
            out.append(frame.s())

        out.append('>')
        return ''.join(out)

class Frame(object):
    def crash(self, message):
        assert isinstance(message, Status)
        raise Crash(message)

    def fail(self, reason):
        raise Crash(Fail(reason))

    def fail_str(self, reason_str):
        raise Crash(Fail(String(reason_str)))

    def __init__(self, proc, env, addr):
        assert isinstance(env, Env)
        assert isinstance(addr, int)
        self.proc = proc
        self.env = env
        self.pc = self.addr = addr
        self.stack = []

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

        out.append('>')
        return ''.join(out)

    def __str__(self):
        return self.s()

    def setup(self):
        self.env.each_input(register_as_input, self)
        self.env.each_output(register_as_output, self)

    def cleanup(self):
        if debug(): print 'cleanup', self
        self.env.each_input(deregister_as_input, self)
        self.env.each_output(deregister_as_output, self)

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
        if not isinstance(val, Channel): self.fail(tagged(message, val))
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
        if debug(): print 'put', self.env.get_output(0).s(), ' '.join(v.s() for v in vals)
        self.env.get_output(0).channelable.write_all(self.proc, vals)

    def get(self, into, n=1):
        self.env.get_input(0).channelable.read(self.proc, n, into)

    def label_name(self):
        return labels_by_addr[self.addr].name

    # @enforceargs(None, lltype.Signed, lltype.Array(lltype.Signed))
    def run_inst_action(self, inst_id, static_args):
        if debug():
            inst_type = inst_type_table.lookup(inst_id)
            msg = ['+ ']
            msg.append(inst_type.name)
            for (i, arg) in enumerate(static_args):
                msg.append(' ')
                msg.append(arg_as_str(inst_type, i, arg))

            print ''.join(msg)

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

