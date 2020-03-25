from value import *
from symbol import revsym

MAX_CHANNELS = 8
class Env(Value):
    def __init__(self, parent=None):
        assert parent is None or isinstance(parent, Env)
        self.parent = parent
        self.inputs = [None] * MAX_CHANNELS
        self.outputs = [None] * MAX_CHANNELS
        self.dict = {}

    def as_dict(self):
        out = {}
        for (k, v) in self.dict.iteritems():
            out[revsym(k)] = v.ref_get()

        return out

    def __repr__(self):
        return '<env %s>' % repr(self.as_dict())

    def __str__(self):
        return repr(self)

    def extend(self):
        return Env(self)

    def merge(self, other):
        assert isinstance(other, Env)

        # copy the *refs* here
        for (k, v) in other.dict.iteritems():
            self.dict[k] = v

    def get_input(self, i):
        return self.inputs[i] or (self.parent and self.parent.get_input(i))

    def has_input(self, ch):
        if ch in self.inputs: return True
        if not self.parent: return False
        return self.parent.has_input(ch)

    def has_output(self, ch):
        if ch in self.inputs: return True
        if not self.parent: return False
        return self.parent.has_input(ch)

    def has_channel(self, is_input, channel):
        if is_input: return self.has_input(channel)
        else: return self.has_output(channel)

    def get_output(self, i):
        return self.outputs[i] or (self.parent and self.parent.get_output(i))

    def set_input(self, i, ch):
        assert isinstance(ch, Channelable)
        self.inputs[i] = ch

    def set_output(self, i, ch):
        assert isinstance(ch, Channelable)
        self.outputs[i] = ch

    def each_input(self, fn, *a):
        for i in range(0, MAX_CHANNELS):
            input = self.get_input(i)
            if not input: return
            fn(input, *a)

    def each_output(self, fn, *a):
        for i in range(0, MAX_CHANNELS):
            output = self.get_output(i)
            if not output: return
            fn(output, *a)

    def lookup_ref(self, key):
        try:
            return self.dict[key]
        except KeyError:
            if self.parent:
                return self.parent.lookup_ref(key)
            else:
                raise

    def let(self, key, val):
        self.dict[key] = Ref(val)

    def get(self, key):
        return self.lookup_ref(key).ref_get()

    def mut(self, key, val):
        return self.lookup_ref(key).ref_set(val)

