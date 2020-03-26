from table import TableEntry
from symbol import sym

class Crash(Exception): pass
class Done(Exception): pass
class Deadlock(Exception): pass

class Value(TableEntry):
    name = None
    pass

    def as_number(self):
        raise Crash('not a number: '+repr(self))

    def __repr__(self):
        raise NotImplementedError('repr: ', str(self))

class Invokable(Value):
    def invoke(self, frame, args): raise NotImplementedError

class Channelable(Value):
    def write_all(self, proc, vals):
        raise NotImplementedError

    def read(self, proc, count, into):
        raise NotImplementedError

    def write(self, proc, val):
        return self.write_all(proc, [val])

    def add_writer(self, frame): pass
    def add_reader(self, frame): pass
    def rm_writer(self, frame): pass
    def rm_reader(self, frame): pass


class String(Invokable):
    def __init__(self, string):
        self.value = string

    def __repr__(self): return self.value

    def invoke(self, frame, args):
        invokee = None
        symbol = sym(self.value)
        try:
            invokee = frame.env.get(symbol)
        except KeyError:
            raise Crash('no such function '+self.value)

        if isinstance(invokee, Invokable):
            invokee.invoke(frame, args)
        else:
            frame.crash('not invokable: '+repr(invokee))

class Int(Value):
    def __init__(self, value):
        self.value = value

    def as_number(self):
        return self.value

    def __repr__(self): return str(self.value)

class Collection(Channelable):
    def __init__(self):
        self.values = []

    def push(self, value):
        self.values.append(value)

    def push_all(self, values):
        for v in values: self.push(v)

    # Channelable
    def write_all(self, proc, values):
        self.push_all(values)

class Vector(Invokable):
    def __init__(self, values):
        self.values = values

    def invoke(self, frame, args):
        if len(self.values) == 0:
            return frame.crash('empty invoke')

        if isinstance(Invokable, self.values[0]):
            new_args = self.values[1:]
            new_args.extend(args)
            self.values[0].invoke(frame, new_args)

class Ref(Value):
    def __init__(self, value):
        self.value = value

    def ref_get(self): return self.value
    def ref_set(self, value): self.value = value

class Function(Invokable):
    def __init__(self, env, addr):
        self.env = env
        self.addr = addr

    def invoke(self, frame, args):
        new_env = frame.env.extend().merge(self.env)
        frame.proc.frame(new_env, self.addr)

class Intrinsic(Invokable):
    def __init__(self, fn):
        self.fn = fn

    def invoke(self, frame, args):
        self.fn(frame, args)

