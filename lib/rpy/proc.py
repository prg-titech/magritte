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
from util import print_list_s

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
            debug(0, ['try_set_running: already interrupted', self.s()])
        else:
            debug(0, ['try_set_running: set to running', self.s()])
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
        self.status = Success()
        self.last_cleaned = []

    def frame(self, env, addr):
        debug(0, ['--', str(self.id), labels_by_addr[addr].name])
        assert isinstance(addr, int)
        eliminated = self.tail_eliminate()

        if eliminated:
            env = eliminated.env.merge(env)

        frame = Frame(self, env, addr)

        if eliminated:
            debug(0, ['-- saving compensations', frame.s()])
            for comp in eliminated.compensations:
                frame.compensations.append(comp)

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
            debug(0, ['-- tco', self.s()])
            out = self.pop()

        debug(0, ['-- post-tco', self.s()])

        return out

    def current_frame(self):
        return self.frames[len(self.frames)-1]

    def pop(self):
        top = self.frames.pop()
        top.cleanup()
        return top

    def step(self):
        debug(0, ['=== step %s ===' % self.s()])
        if self.frames:
            env = self.current_frame().env
            debug(0, ['env:', env.s()])
            debug(0, ['in:', env.get_input(0).s() if env.get_input(0) else '_'])
            debug(0, ['out:', env.get_output(0).s() if env.get_output(0) else '_'])

        try:
            while self.frames and self.is_running():
                # IMPORTANT: only check interrupts when we're waiting!
                if self.state == Proc.INTERRUPTED and self.check_interrupts(): return

                if self.last_cleaned:
                    debug(0, ['-- emptying last_cleaned'] +
                             [f.s() for f in self.last_cleaned])

                self.last_cleaned = []
                self.state = Proc.RUNNING
                self.current_frame().step()
        except Crash as e:
            print '-- crash', e.status.s()
            debug(0, ['-- crashed', self.s()])
            self.status = e.status
            self.state = Proc.TERMINATED

        if not self.frames:
            debug(0, ['out of frames', self.s()])
            self.state = Proc.DONE


    def check_interrupts(self):
        debug(0, ['check_interrupts', self.s()])
        if not self.interrupts: return False

        interrupt = self.interrupts.pop(0)
        debug(0, ['-- interrupted', self.s(), interrupt.s()])

        # unwind the stack until the channel goes out of scope
        if isinstance(interrupt, Close):
            debug(0, ['channel closed', interrupt.s()])
            debug(0, ['env:', self.current_frame().env.s()])
            debug(0, ['has channel?', str(self.has_channel(not interrupt.is_input, interrupt.channel))])

            while self.frames and self.has_channel(not interrupt.is_input, interrupt.channel):
                debug(0, ['unwind!'])
                self.pop()
        else:
            while self.frame:
                debug(0, ['unwind all!'])
                self.pop()

        debug(0, ['unwound'] + [f.s() for f in self.last_cleaned])
        for frame in self.last_cleaned:
            debug(0, ['-- compensating', frame.s(), str(len(frame.compensations))])
            for (addr, _) in frame.compensations:
                debug(0, ['-- unwind-comp', frame.s(), labels_by_addr[addr].name])
                self.frame(frame.env, addr)

        if self.frames:
            self.state = Proc.RUNNING
        else:
            self.state = Proc.DONE

        return True

    def has_channel(self, is_input, channel):
        return self.current_frame().env.has_channel(is_input, channel)

    def interrupt(self, interrupt):
        debug(0, ['interrupt', self.s(), interrupt.s()])
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
        debug(0, ['put', self.env.get_output(0).s()] + [v.s() for v in vals])
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

