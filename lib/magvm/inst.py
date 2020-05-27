from table import Table, TableEntry
from symbol import revsym
from intrinsic import intrinsics

class InstType(TableEntry):
    def __init__(self, name, static_types, in_types, out_types, doc):
        self.name = name
        self.static_types = static_types
        self.in_types = in_types
        self.out_types = out_types

    # important step for loading more than one file: re-index all references
    # to constants and addresses relative to the global table.
    def reindex(self, arr, offsets, symbol_translation):
        for (i, tname) in enumerate(self.static_types):
            if tname:
                # special case for symbols - we have to re-use
                # existing symbol ids, so the translation has to
                # be done manually
                if tname == 'sym':
                    arr[i] = symbol_translation[arr[i]]
                    continue

                # special case for intrinsics, which are a static table
                if tname == 'intrinsic':
                    intrinsic_name = revsym(symbol_translation[arr[i]])
                    new_id = intrinsics.get(intrinsic_name).id
                    arr[i] = intrinsics.get(intrinsic_name).id
                    continue

                arr[i] += offsets[tname]

        return arr

class Inst(TableEntry):
    name = None

    def __init__(self, inst_id, arguments):
        for a in arguments:
            assert isinstance(a, int)
            assert a >= 0

        self.inst_id = inst_id
        assert isinstance(arguments, list)
        self.arguments = arguments

    def type(self):
        return inst_type_table.lookup(self.inst_id)

inst_type_table = Table()
def mkinst(name, *a):
    t = InstType(name, *a)
    inst_type_table.register(t)

    screaming_name = name.upper().replace('-', '_')
    setattr(InstType, screaming_name, t.id)

# jumps and spawns
mkinst('frame', ['inst'], ['env'], [], 'start a new frame')
mkinst('return', [], [], [], 'pop a frame off the stack')
mkinst('spawn', ['inst'], ['env'], [], 'spawn a new process')
mkinst('jump', ['inst'], [], [], 'jump')
mkinst('jumpne', ['inst'], [None, None], [], 'jump if not equal')
mkinst('jumplt', ['inst'], ['int', 'int'], [], 'jump if less than')
mkinst('invoke', [], ['collection'], [], 'invoke a collection')
mkinst('jumpfail', ['inst'], ['status'], [], 'jump if the last status is a failure')

# vectors and collections
mkinst('collection', [], [], ['collection'], 'start a collection')
mkinst('index', [None], ['vec', 'idx'], [], 'index a vector')
mkinst('collect', [], ['collection', None], ['collection'], 'collect a single value into a collection')
mkinst('vector', [], ['collection'], ['vec'], 'make a new vector')
mkinst('typeof', [], [None], ['str'], 'get the type of a value')

# environments and refs
mkinst('env', [], [], ['env'], 'make a new env')
mkinst('current-env', [], [], ['env'], 'load the current environment')
mkinst('ref', ['sym'], ['env'], ['ref'], 'load a ref from a collection')
mkinst('ref-get', [], ['ref'], [None], 'load a value from a ref')
mkinst('ref-set', [], ['ref', None], [], 'write a value to a ref')
mkinst('dynamic-ref', [], ['env', 'string'], [None], 'dynamically look up a ref')
mkinst('env-extend', [], ['env'], ['env'], 'extend an environment')
mkinst('env-collect', [], ['collection', 'env'], ['collection', 'env'], 'set up an environment to write to a collection')
mkinst('env-pipe', [None, None], ['env', 'channel'], ['env', 'env'], 'make a producer and a consumer env from a channel')
mkinst('env-merge', [], ['env', 'env'], ['env'], 'merge an env into another (mutates first)')
mkinst('env-unhinge', [], ['env'], ['env'], 'unhinge an env from its parent')
mkinst('let', ['sym'], ['env', None], [], 'make a new binding in an env')

# tables
mkinst('const', ['const'], [], [None], 'load a constant')

# stack manip
mkinst('swap', [], [None, None], [None, None], 'swap')
mkinst('dup', [], [None], [None, None], 'dup')
mkinst('pop', [], [None], [], 'pop')

# functions
mkinst('closure', ['inst'], ['env'], ['closure'], 'make a new closure')
mkinst('last-status', [], [], ['status'], 'load the last status')
mkinst('intrinsic', ['intrinsic'], [], ['intrinsic'], 'load an intrinsic fn')

# channels
mkinst('channel', [], [], ['channel'], 'make a new channel')
mkinst('env-set-output', [None], ['env', 'channel'], [], 'set the output on an env')
mkinst('env-set-input', [None], ['env', 'channel'], [], 'set the input on an env')
mkinst('crash', [], ['string'], [], 'crash')
mkinst('rest', [None], ['collection'], [], 'get the remaining elements of a collection')

mkinst('noop', ['sym'], [], [], 'do nothing. debugging tool for the compiler')
mkinst('clear', [], [], [], 'flush the value stack down to one element (used in pattern matching)')
mkinst('size', [], ['vector'], ['int'], 'get the size of a vector or collection')

mkinst('compensate', ['inst', None], [], [], 'register a compensation')
mkinst('wait-for-close', [], ['vector'], ['vector'], 'wait for the writers of a vector to exit')
