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

class Receiver(Blocker):
    def __init__(self, proc, count, into):
        self.proc = proc
        self.into = into
        self.count = count

    def receive(self, val):
        if debug(): print 'receiving', val, 'into', self.into
        self.into.write(self.proc, val)
        self.count -= 1
        if debug(): print 'remaining', self.count, self.is_done()
        if self.is_done(): self.proc.set_running()

    def is_done(self):
        return self.count <= 0

class Sender(Blocker):
    def __init__(self, proc, values):
        self.proc = proc
        self.values = values
        self.index = 0

    def next_val(self):
        (out, self.values[self.index]) = (self.values[self.index], None)
        self.index += 1
        return out

    def current_val(self):
        return self.values[self.index]

    def is_done(self):
        return self.index >= len(self.values)

    def send(self, receiver):
        if debug(): print 'sending', self.values, self.index, self.current_val()
        receiver.receive(self.next_val())
        if debug(): print 'sender is_done()', self.is_done()
        if self.is_done(): self.proc.set_running()

class Channel(Channelable):
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

    def state_name(self):
        if self.state == Channel.INIT: return 'init'
        if self.state == Channel.OPEN: return 'open'
        if self.state == Channel.CLOSED: return 'closed'
        assert False, 'no such state'

    def s(self):
        return '<channel %d/%d:%s>' % (self.reader_count, self.writer_count, self.state_name())

    def is_closed(self): return self.state == Channel.CLOSED
    def is_open(self): return self.state != Channel.CLOSED

    def read(self, proc, count, into):
        if self.is_closed(): return proc.interrupt(Close(self, True))
        self.receivers.append(Receiver(proc, count, into))
        proc.set_waiting()

    def write_all(self, proc, vals):
        if self.is_closed(): return proc.interrupt(Close(self, False))
        self.senders.append(Sender(proc, vals))
        proc.set_waiting()

    def resolve(self):
        while self.senders and self.receivers:
            (sender, receiver) = (self.senders.pop(0), self.receivers.pop(0))

            sender.send(receiver)

            if not sender.is_done(): self.senders.insert(0, sender)
            if not receiver.is_done(): self.receivers.insert(0, receiver)

        assert (not self.senders) or (not self.receivers)

        return self.check_for_close()

    def add_writer(self, frame):
        self.writer_count += 1
        self.writers.append(frame)

    def add_reader(self, frame):
        self.reader_count += 1
        self.readers.append(frame)

    def rm_writer(self, frame):
        if self.is_closed(): return
        self.writer_count -= 1
        self.writers.remove(frame)

    def rm_reader(self, frame):
        if self.is_closed(): return
        self.reader_count -= 1
        self.readers.remove(frame)

    def check_for_close(self):
        # set up the initial state if we've got readers or writers
        if self.state == Channel.INIT and self.reader_count > 0 and self.writer_count > 0:
            self.state = Channel.OPEN
            return False

        if self.state != Channel.OPEN: return False

        if self.reader_count > 0 and self.writer_count > 0: return False

        if debug(): print 'closing', self.id
        self.state = Channel.CLOSED

        for frame in self.readers:
            frame.proc.interrupt(Close(self, True))

        for frame in self.writers:
            frame.proc.interrupt(Close(self, False))

        return True


class Streamer(Channelable):
    def __init__(self, fn):
        self.fn = fn

    def write_all(self, proc, vals):
        self.fn(proc, vals)

    def s(self):
        return '<streamer>'

