from value import *
from debug import debug

class Interrupt(object): pass

class Close(Interrupt):
    def __init__(self, channel, is_input):
        self.channel = channel
        self.is_input = is_input

    def s(self):
        direction = 'read' if self.is_input else 'write'
        return '<close:%s %s>' % (self.channel.s(), direction)

class Blocker(object):
    proc = None

    def is_done(self): return True
    def s(self): raise NotImplementedError

class Receiver(Blocker):
    def __init__(self, proc, count, into):
        self.proc = proc
        self.into = into
        self.count = count

    def receive(self, val):
        if debug(): print 'receiving', val.s(), 'into', self.into.s()
        self.into.channelable.write(self.proc, val)
        self.count -= 1
        if debug(): print 'remaining', self.count, self.is_done()
        if self.is_done(): self.proc.try_set_running()

    def is_done(self):
        return self.count <= 0

    def s(self):
        return '<receiver/%d@%s into:%s>' % (self.count, self.proc.s(), self.into.s())


class Sender(Blocker):
    def __init__(self, proc, values):
        self.proc = proc
        self.values = values
        self.index = 0

    def next_val(self):
        # [jneen] nice thought, but this array might be still in use!
        # if we take this approach we have to be sure we copy stuff. should
        # see if that makes a perf difference.
        # (out, self.values[self.index]) = (self.values[self.index], None)
        out = self.values[self.index]

        self.index += 1
        return out

    def current_val(self):
        return self.values[self.index]

    def is_done(self):
        return self.index >= len(self.values)

    def send(self, receiver):
        if debug(): print 'sending', self.s()

        receiver.receive(self.next_val())
        if debug(): print 'sender is_done()', self.is_done()
        if self.is_done(): self.proc.try_set_running()

    def s(self):
        out = ['<sender@', self.proc.s()]
        for i in range(self.index, len(self.values)):
            out.append(' ')
            out.append(self.values[i].s())

        out.append('>')
        return ''.join(out)


class Channel(Value):
    INIT = 0
    OPEN = 1
    CLOSED = 2

    def __init__(self):
        self.writers = []
        self.readers = []
        self.reader_count = 0
        self.writer_count = 0
        self.senders = []
        self.receivers = []
        self.state = Channel.INIT
        self.channelable = Channel.Impl(self)

    def s(self):
        return '<channel%d %d/%d:%s>' % (self.id, self.reader_count, self.writer_count, self.state_name())

    def typeof(self): return 'channel'

    def resolve(self): return self.channelable.resolve()

    def state_name(self):
        if self.state == Channel.INIT: return 'init'
        if self.state == Channel.OPEN: return 'open'
        if self.state == Channel.CLOSED: return 'closed'
        assert False, 'no such state'

    def is_closed(self): return self.state == Channel.CLOSED
    def is_open(self): return self.state != Channel.CLOSED

    def check_for_close(self):
        # set up the initial state if we've got readers or writers
        if self.state == Channel.INIT and self.reader_count > 0 and self.writer_count > 0:
            self.state = Channel.OPEN
            return False

        if self.state != Channel.OPEN: return False

        if debug(): print 'check_for_close', self.s()
        if self.reader_count > 0 and self.writer_count > 0: return False

        if debug(): print 'closing', self.s()
        self.state = Channel.CLOSED

        for blocker in self.senders:
            blocker.proc.interrupt(Close(self, True))

        for blocker in self.receivers:
            blocker.proc.interrupt(Close(self, False))

        return True

    def resolve(self):
        while self.senders and self.receivers:
            (sender, receiver) = (self.senders.pop(0), self.receivers.pop(0))

            sender.send(receiver)

            if not sender.is_done(): self.senders.insert(0, sender)
            if not receiver.is_done(): self.receivers.insert(0, receiver)

        assert (not self.senders) or (not self.receivers)

        return self.check_for_close()

    @impl
    class Impl(Channelable):
        def read(self, proc, count, into):
            if self.is_closed(): return proc.interrupt(Close(self, True))
            self.receivers.append(Receiver(proc, count, into))
            proc.set_waiting()

        def write_all(self, proc, vals):
            if self.is_closed(): return proc.interrupt(Close(self, False))
            self.senders.append(Sender(proc, vals))
            proc.set_waiting()

        def add_writer(self, frame):
            if debug(): print '-- add_writer', self.s(), frame.s()
            self.writer_count += 1

        def add_reader(self, frame):
            if debug(): print '-- add_reader', self.s(), frame.s()
            self.reader_count += 1

        def rm_writer(self, frame):
            if self.is_closed(): return
            if debug(): print 'rm_writer', self.s(), frame.s(), ' '.join([s.s() for s in self.senders]), ' '.join([r.s() for r in self.receivers])
            self.writer_count -= 1

        def rm_reader(self, frame):
            if self.is_closed(): return
            if debug(): print 'rm_reader', self.s(), frame.s(), ' '.join([s.s() for s in self.senders]), ' '.join([r.s() for r in self.receivers])
            self.reader_count -= 1


class Streamer(Value):
    @impl
    class Channel(Channelable):
        def write_all(self, proc, vals):
            self.fn(proc, vals)

    def __init__(self, fn):
        self.fn = fn
        self.channelable = Streamer.Channel(self)

    def s(self):
        return '<streamer>'

    def typeof(self): return 'streamer'

