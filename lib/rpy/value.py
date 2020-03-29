from table import TableEntry
from symbol import sym
from debug import debug
from code import labels_by_addr

from rpython.rlib.rarithmetic import r_uint, intmask

class Done(Exception): pass
class Deadlock(Exception): pass

def tagged(tag, *values):
    values = list(values)
    values.insert(0, String(tag))
    return Vector(values)

class Crash(Exception):
    def __init__(self, status):
        self.status = status

def impl(klass):
    """NOT_RPYTHON"""
    import copy


    def init_fn(self, value): self._ = value

    def hack_method(name, method, impl_name):
        setattr(klass, impl_name, staticmethod(method))
        setattr(klass, name, lambda self, *a: getattr(self, impl_name)(self._, *a))

    for (name, method) in dict(klass.__dict__).iteritems():
        if name[0] == '_': continue
        hack_method(name, method, '_impl_'+name)

    setattr(klass, '__init__', init_fn)

    return klass

class Invokable(object):
    def invoke(self, frame, arguments): raise NotImplementedError

class Channelable(object):
    def write_all(self, proc, vals): raise NotImplementedError
    def read(self, proc, count, into): raise NotImplementedError
    def write(self, proc, val): return self.write_all(proc, [val])

    def add_writer(self, frame): pass
    def add_reader(self, frame): pass
    def rm_writer(self, frame): pass
    def rm_reader(self, frame): pass

class Value(TableEntry):
    name = None
    invokable = None
    channelable = None

    def as_number(self, frame):
        frame.fail(tagged('not a number', self))

    def s(self):
        raise NotImplementedError

    def typeof(self):
        raise NotImplementedError

class String(Value):
    @impl
    class Invoke(Invokable):
        def invoke(self, frame, args):
            invokee = None
            symbol = sym(self.value)
            try:
                invokee = frame.env.get(symbol)
            except KeyError:
                raise frame.fail(tagged('no-such-function', self))

            if invokee.invokable:
                invokee.invokable.invoke(frame, args)
            else:
                frame.fail(tagged('not-invokable', invokee))

    def __init__(self, string):
        self.value = string
        self.invokable = String.Invoke(self)

    def s(self): return self.value
    def typeof(self): return 'string'

    def as_number(self, frame):
        try:
            return int(self.value)
        except ValueError:
            frame.fail(tagged('not-a-number', self))

class Int(Value):
    def __init__(self, value):
        assert isinstance(value, int)
        self.value = value

    def as_number(self, frame):
        return self.value

    def s(self): return str(self.value)
    def typeof(self): return 'int'

class Collection(Value):
    def s(self):
        out = ['<collection']
        for value in self.values:
            out.append(' ')
            out.append(value.s())
        out.append('>')

        return ''.join(out)

    def typeof(self): return 'collection'

class Vector(Value):
    @impl
    class Invoke(Invokable):
        def invoke(self, frame, args):
            values = self.values

            if len(values) == 0:
                frame.fail_str('empty invoke')

            invokable = values[0].invokable
            if not invokable: frame.fail(tagged('bad-invoke', values[0]))

            new_args = Vector(self.values[1:] + args.values)
            invokable.invoke(frame, new_args)

    @impl
    class Channel(Channelable):
        def write_all(self, proc, values): self.push_all(values)


    def __init__(self, values):
        self.values = values
        self.invokable = Vector.Invoke(self)
        self.channelable = Vector.Channel(self)

    def push(self, value):
        assert value is not None
        self.values.append(value)

    def push_all(self, values):
        for v in values: self.push(v)

    def s(self):
        out = ['[']
        not_first = False
        for val in self.values:
            if not_first: out.append(' ')
            not_first = True

            if debug() and val is None:
                out.append('None')
            else:
                out.append(val.s())

        out.append(']')
        return ''.join(out)

    def typeof(self): return 'vector'

class Ref(Value):
    def __init__(self, value):
        assert value is not None
        self.value = value

    def ref_get(self): return self.value
    def ref_set(self, value):
        assert value is not None
        self.value = value

    def s(self):
        return '<ref %s>' % self.value.s()

    def typeof(self): return 'ref'

class Function(Value):
    @impl
    class Invoke(Invokable):
        def invoke(self, frame, collection):
            if debug(): print '()', self.label().s()
            new_env = frame.env.extend().merge(self.env)
            new_frame = frame.proc.frame(new_env, self.addr)
            new_frame.push(collection)

    def __init__(self, env, addr):
        self.env = env
        self.addr = addr
        self.invokable = Function.Invoke(self)

    def label(self):
        return labels_by_addr[self.addr]

    def s(self):
        return '<function '+self.label().s()+'>'

    def typeof(self): return 'function'

class Intrinsic(Value):
    @impl
    class Invoke(Invokable):
        def invoke(self, frame, collection):
            self.fn(frame, collection.values)

    def __init__(self, name, fn):
        self.name = name
        self.fn = fn
        self.invokable = Intrinsic.Invoke(self)

    def s(self):
        return '@!'+self.name

    def typeof(self): return 'intrinsic'

