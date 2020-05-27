from table import TableEntry
from inst import inst_type_table, InstType
from channel import Channel, Close
from labels import labels_by_addr, inst_table
from status import Status, Success, Fail
from util import print_list_s
from frame import Frame
from debug import debug
from value import *

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
        if self.state == Proc.WAITING:
            debug(0, ['try_set_running: set to running', self.s()])
            self.set_running()
        else:
            debug(0, ['try_set_running: not waiting', self.s()])

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

    def frame(self, env, addr, tail_elim=True):
        debug(0, ['--', str(self.id), labels_by_addr[addr].name])
        assert isinstance(addr, int)

        # must setup before tail eliminating so the number of registered
        # channels doesn't go to zero from tail elim
        frame = Frame(self, env, addr)
        frame.setup()

        if tail_elim:
            eliminated = self.tail_eliminate()
            if eliminated:
                frame.env = eliminated.env.merge(env)
                for comp in eliminated.compensations:
                    frame.compensations.append(comp)

        self.frames.append(frame)
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
        # if not self.frames:
        #     debug(0, ['-- out of frames', self.s()])
        #     self.set_done()

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
        else:
            debug(0, ['still has frames!', self.s()])


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

