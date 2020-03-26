from table import TableEntry
from symbol import sym
from debug import debug
from code import labels_by_addr

class Crash(Exception): pass
class Done(Exception): pass
class Deadlock(Exception): pass

class Value(TableEntry):
    name = None
    pass

    def as_number(self):
        raise Crash('not a number: '+self.s())

    def s(self):
        raise NotImplementedError

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

    def s(self): return self.value

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
            frame.crash('not invokable: '+invokee.s())

class Int(Value):
    def __init__(self, value):
        self.value = value

    def as_number(self):
        return self.value

    def s(self): return str(self.value)

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

    def s(self):
        out = ['<collection']
        for value in self.values:
            out.append(' ')
            out.append(value.s())
        out.append('>')

        return ''.join(out)

class Vector(Invokable):
    def __init__(self, values):
        self.values = values

    def invoke(self, frame, args):
        if len(self.values) == 0:
            raise Crash('empty invoke')

        if not isinstance(self.values[0], Invokable): raise Crash('not invokable: %s' % self.values[0].s())
        new_args = Collection()
        new_args.values = self.values[1:]
        new_args.values.extend(args.values)
        self.values[0].invoke(frame, new_args)


    def s(self):
        out = ['<vec']
        for val in self.values:
            out.append(' ')
            out.append(val.s())

        out.append('>')
        return ''.join(out)

class Ref(Value):
    def __init__(self, value):
        self.value = value

    def ref_get(self): return self.value
    def ref_set(self, value): self.value = value

    def s(self):
        return '<ref %s>' % self.value

class Function(Invokable):
    def __init__(self, env, addr):
        self.env = env
        self.addr = addr

    def label(self):
        return labels_by_addr[self.addr]

    def invoke(self, frame, collection):
        if debug(): print '()', self.label().s()
        new_env = frame.env.extend().merge(self.env)
        new_frame = frame.proc.frame(new_env, self.addr)
        new_frame.push(collection)

    def s(self):
        return '<function '+self.label().s()+'>'

class Intrinsic(Invokable):
    def __init__(self, name, fn):
        self.name = name
        self.fn = fn

    def invoke(self, frame, collection):
        self.fn(frame, collection.values)

    def s(self):
        return '@!'+self.name

