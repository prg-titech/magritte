from value import *
from symbol import revsym

class Env(Value):
    def __init__(self, parent=None):
        assert parent is None or isinstance(parent, Env)
        self.parent = parent
        self.inputs = [None] * 8
        self.outputs = [None] * 8
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

    def get_output(self, i):
        return self.outputs[i] or (self.parent and self.parent.get_output(i))

    def set_input(self, i, ch):
        assert isinstance(ch, Channelable)
        self.inputs[i] = ch

    def set_output(self, i, ch):
        print 'set_output', ch
        assert isinstance(ch, Channelable)
        self.outputs[i] = ch

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

