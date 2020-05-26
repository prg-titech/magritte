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

    def s(self):
        out = ['{ ']
        is_first = True
        for (k, v) in self.as_dict().iteritems():
            if not is_first: out.append('; ')
            is_first = False

            out.append('%s = %s' % (k, v.s()))

        inp = self.get_input(0)
        if inp: out.append('; in:%s' % inp.s())
        outp = self.get_output(0)
        if outp: out.append('; out:%s' % outp.s())

        out.append(' }')

        return ''.join(out)

    def __str__(self):
        return self.s()

    def extend(self):
        return Env(self)

    def unhinge(self):
        return Env(None).merge(self)

    def merge(self, other):
        assert isinstance(other, Env)

        # copy the *refs* here
        for (k, v) in other.dict.iteritems():
            self.dict[k] = v

        # TODO: all channels
        if other.get_input(0): self.set_input(0, other.get_input(0))
        if other.get_output(0): self.set_output(0, other.get_output(0))

        return self

    def get_input(self, i):
        return self.inputs[i] or (self.parent and self.parent.get_input(i))

    def has_input(self, ch):
        if ch in self.inputs: return True
        if not self.parent: return False
        return self.parent.has_input(ch)

    def has_output(self, ch):
        if ch in self.outputs: return True
        if not self.parent: return False
        return self.parent.has_output(ch)

    def has_channel(self, is_input, channel):
        if is_input: return self.has_input(channel)
        else: return self.has_output(channel)

    def get_output(self, i):
        return self.outputs[i] or (self.parent and self.parent.get_output(i))

    def set_input(self, i, ch):
        assert ch.channelable
        debug(0, ['set_input', self.s(), ch.s()])
        self.inputs[i] = ch

    def set_output(self, i, ch):
        assert ch.channelable
        debug(0, ['set_output', self.s(), ch.s()])
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
                raise KeyError(revsym(key))

    def let(self, key, val):
        r = Ref(val)
        self.dict[key] = r
        return r

    def get(self, key):
        return self.lookup_ref(key).ref_get()

    def mut(self, key, val):
        return self.lookup_ref(key).ref_set(val)

    def typeof(self): return 'env'
