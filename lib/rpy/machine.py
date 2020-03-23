import sys

DEBUG = False

############ meta utility #############
def as_dashed(name):
    name = name.replace('_', '-')

    # for things like `return` which can't be method names in python
    if name[-1] == '-': return name[:-1]
    else: return name


############### tables ################
class Table(object):
    def __init__(self):
        self.table = []
        self.rev_table = {}

    def register(self, entry):
        assert isinstance(entry, TableEntry)
        entry.id = len(self)
        self.table.append(entry)
        if entry.name:
            self.rev_table[entry.name] = entry
        return entry

    def get(self, name):
        return self.rev_table[name]

    def __len__(self):
        return len(self.table)

    def lookup(self, idx):
        try:
            return self.table[idx]
        except IndexError:
            print 'no index', idx
            raise

class LabelTable(Table):
    def __init__(self):
        super(LabelTable, self).__init__()
        self.by_addr = {}

    def register(self, label):
        assert isinstance(label, Label)
        self.by_addr[label.addr] = label
        return super(LabelTable, self).register(label)

class SymbolTable(Table):
    def sym(self, string):
        assert isinstance(string, str)
        try:
            return self.rev_table[string]
        except KeyError:
            return self.register(Symbol(string))

    def revsym(self, idx):
        assert isinstance(idx, int)

        return self.rev_table[idx]

############## table entries ##############
class TableEntry(object):
    id = -1
    name = None

    def __init__(*a):
        raise NotImplementedError

class Label(TableEntry):
    def __init__(self, name, addr, trace):
        assert isinstance(addr, int)
        self.id = -1
        self.name = name
        self.addr = addr
        self.trace = trace

class Inst(TableEntry):
    name = None

    def __init__(self, inst_id, arguments):
        self.inst_id = inst_id
        assert isinstance(arguments, list)
        self.arguments = arguments

    def type(self):
        return inst_type_table.lookup(self.inst_id)

class Symbol(TableEntry):
    def __init__(self, string):
        self.id = -1
        self.name = string

class InstType(TableEntry):
    def __init__(self, name, static_types, in_types, out_types, doc):
        self.name = name
        self.static_types = static_types
        self.in_types = in_types
        self.out_types = out_types

    def reindex(self, arr, offsets):
        for (i, tname) in enumerate(self.static_types):
            if tname:
                try:
                    arr[i] += offsets[tname]
                except IndexError:
                    print 'oops', self.name, arr, offsets, tname
                    raise

        return arr

symbol_table = SymbolTable()
label_table = LabelTable()
const_table = Table()
inst_table = Table()
inst_type_table = Table()

################# values #################

class Value(TableEntry):
    name = None
    pass

class Invokable(Value):
    def invoke(self, frame, args): raise NotImplementedError

class Channelable(Value):
    def write_all(self, proc, vals):
        raise NotImplementedError

    def read(self, proc, count, into):
        raise NotImplementedError

    def write(self, proc, val):
        return self.write_all(proc, [val])

class String(Invokable):
    def __init__(self, string):
        self.value = string

    def __repr__(self): return self.value

    def invoke(self, frame, args):
        invokee = None
        symbol = symbol_table.sym(self.value).id
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

    def __repr__(self): return str(self.value)

class Collection(Value):
    def __init__(self):
        self.values = []

    def push(self, value):
        self.values.append(value)

    def push_all(self, values):
        for v in values: self.push(v)

def Vector(Invokable):
    def __init__(self, values):
        self.values = values

    def invoke(self, frame, args):
        if len(self.values) == 0:
            return frame.crash('empty invoke')

        if isinstance(Invokable, self.values[0]):
            self.values[0].invoke(frame, self.values[1:].concat(args))

class Ref(Value):
    def __init__(self, value):
        self.value = value

    def get(self): return self.value
    def set(self, value): self.value = value

class Env(Value):
    def __init__(self, parent=None):
        self.parent = parent
        self.inputs = [None] * 8
        self.outputs = [None] * 8
        self.dict = {}

    def extend(self):
        return Env(self)

    def get_input(self, i):
        return self.inputs[i] or self.parent.get_input(i)

    def get_output(self, i):
        return self.outputs[i] or self.parent.get_output(i)

    def set_input(self, i, ch):
        self.inputs[i] = ch

    def set_output(self, i, ch):
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
        return self.lookup_ref(key).get()

    def mut(self, key, val):
        return self.lookup_ref(key).set(val)

class Function(Invokable):
    def __init__(self, env, addr):
        self.env = env
        self.addr = addr

    def invoke(self, frame, args):
        new_env = frame.env.expand().merge(self.env)
        frame.proc.frame(new_env, self.addr)

class Builtin(Invokable):
    def __init__(self, fn):
        self.fn = fn

    def invoke(self, frame, args):
        self.fn(frame, args)

base_env = Env()

############# channels ##################

class Blocker(object):
    proc = None

    def is_done(self): return True

class Receiver(Blocker):
    def __init__(self, proc, into, count):
        self.proc = proc
        self.into = into
        self.count = count

    def receive(self, val):
        self.into.append(val)
        self.count -= 1
        if self.is_done(): self.proc.state = proc.RUNNING

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
        receiver.receive(self.next_val())
        if self.is_done(): self.proc.state = Proc.RUNNING

class Channel(Channelable):
    INIT = 0
    OPEN = 1
    CLOSED = 2

    def __init__(self):
        self.reader_count = 0
        self.writer_count = 0
        self.senders = []
        self.receivers = []
        self.state = Channel.INIT

    def is_closed(self): return self.state == Channel.CLOSED

    def read(self, proc, count, into):
        if self.is_closed(): return proc.interrupt(self)
        self.receivers.append(Receiver(proc, count, into))
        proc.state = Proc.WAITING

    def write_all(self, proc, vals):
        if self.is_closed(): return proc.interrupt(self)
        self.senders.append(Sender(proc, vals))
        proc.state = Proc.WAITING

    def resolve(self):
        while self.senders and self.receivers:
            (sender, reciever) = (self.senders.pop(0), self.receivers.pop(0))

            sender.send(receiver)

            if not sender.is_done(): self.senders.insert(0, sender)
            if not receiver.is_done(): self.receivers.insert(0, receiver)

class Streamer(Channelable):
    def __init__(self, fn):
        self.fn = fn

    def write_all(self, proc, vals):
        self.fn(proc, vals)

def global_out(proc, vals):
    for val in vals:
        print repr(val)

base_env.set_output(0, Streamer(global_out))


############# parsing the compiled file ###############
def unescape(s):
    return s.replace('\\n', '\n').replace('\\\\', '\\')

def parse_constant(arr):
    stack = []
    for el in arr:
        if el[0] == '"': stack.append(String(unescape(el[1:])))
        elif el[0] == '+': stack.append(Float(float(el[1:])))
        elif el[0] == '#': stack.append(Int(int(el[1:])))
        elif el[0] == '[':
            count = int(el[1:])
            vals = [None] * count
            for i in range(0, count): vals[i] = stack.pop()
            stack.append(Vector(vals))
        elif el[0] == '{':
            count = int(el[1:])
            d = {}
            for i in range(0, count):
                key = stack.pop()
                assert isinstance(key, String)
                val = stack.pop()
                d[key] = val
            stack.append(Env(d))
    assert len(stack) == 1, arr
    return stack[0]

def compute_offsets():
    return {
        'sym': len(symbol_table),
        'const': len(const_table),
        'label': len(label_table),
        'inst': len(inst_table),
    }

def load(get_raw_line):
    get_line = lambda: get_raw_line().strip()

    offsets = compute_offsets()

    # constants block
    num_constants = int(get_line().split(' ')[0])
    for _ in range(0, num_constants):
        const_table.register(parse_constant(get_line().split(' ')))

    # symbols block
    num_symbols = int(get_line().split(' ')[0])
    for _ in range(0, num_symbols):
        symbol_table.sym(get_line().split(' ')[0])

    num_labels = int(get_line().split(' ')[0])
    for _ in range(0, num_labels):
        parts = get_line().split(' ')
        name = parts[0]
        addr = int(parts[1])
        trace = None
        if len(parts) > 2: trace = parts[2]
        label_table.register(Label(name, addr, trace))

    num_insts = int(get_line().split(' ')[0])
    for _ in range(0, num_insts):
        parts = get_line().split(' ')
        inst_type = inst_type_table.get(parts[1])
        raw_args = map(int, parts[2:])
        args = inst_type.reindex(raw_args, offsets)
        inst_table.register(Inst(inst_type.id, args))

def load_stdin():
    return load(sys.stdin.readline)


class Done(Exception): pass
class Deadlock(Exception): pass

################## machine ####################
class Machine(object):
    def __init__(self):
        self.procs = Table()
        self.channels = Table()

    def spawn_label(self, env, label):
        self.spawn(env, label_table.get(label).addr)

    def spawn(self, env, addr):
        proc = Proc(self)
        self.procs.register(proc)
        proc.frame(env, addr)

    def run(self):
        if DEBUG: print 'run!'
        try:
            while True: self.step()
        except Done:
            return self.procs

        assert False # impossible

    def step(self):
        moved = 0
        waiting = 0

        for proc in self.procs.table:
            if not proc: continue
            if proc.state == Proc.DONE: continue

            if proc.state == Proc.WAITING: waiting += 1
            else: moved += 1

            proc.step()

        for channel in self.channels.table:
            channel.resolve()

        if moved == 0 and waiting > 0: raise Deadlock
        if moved == 0: raise Done

class Crash(Exception): pass

class Proc(TableEntry):
    INIT = 0
    RUNNING = 1
    WAITING = 2
    DONE = 3
    TERMINATED = 4

    def __init__(self, machine):
        self.state = Proc.INIT
        self.machine = machine
        self.frames = []

    def frame(self, env, addr):
        if DEBUG: print '--', label_table.by_addr[addr].name
        assert isinstance(addr, int)
        self.frames.append(Frame(self, env, addr))

    def current_frame(self):
        return self.frames[len(self.frames)-1]

    def step(self):
        self.state = Proc.RUNNING
        return self.current_frame().step()

class Frame(object):
    def __init__(self, proc, env, addr):
        assert isinstance(addr, int)
        self.proc = proc
        self.env = env
        self.pc = self.addr = addr
        self.stack = []

    def __repr__(self):
        return '<frame(%s:%d) %s>' % (self.label_name(), self.addr, repr(self.stack))

    def __str__(self):
        return repr(self)

    def push(self, val):
        self.stack.append(val)

    def pop(self):
        return self.stack.pop()

    def pop_number(self):
        return self.pop().as_number()

    def pop_string(self, message='not a string: %s'):
        val = self.pop()
        if not isinstance(val, String): raise Crash(message % repr(val))
        return val.value

    def pop_env(self, message='not an env: %s'):
        val = self.pop()
        if not isinstance(val, Env): raise Crash(message % repr(val))
        return val

    def top_collection(self, message='not a collection: %s'):
        val = self.top()
        if not isinstance(val, Collection): raise Crash(message % repr(val))
        return val

    def pop_collection(self, message='not a collection: %s'):
        val = self.top_collection(message)
        self.pop()
        return val

    def top(self):
        return self.stack[len(self.stack)-1]

    def put(self, vals):
        self.env.get_output(0).write_all(self, vals)

    def label_name(self):
        return label_table.by_addr[self.addr].name

    def run_inst_action(self, inst_id, static_args):
        if DEBUG:
            print '+', inst_type_table.lookup(inst_id).name, static_args

        action = inst_actions[inst_id]
        if not action:
            raise NotImplementedError('action for: '+inst_type_table.lookup(inst_id).name)

        action(self, static_args)

    def step(self):
        inst = self.current_inst()
        self.pc += 1
        self.state = self.run_inst_action(inst.inst_id, inst.arguments)
        return self.state

    def current_inst(self):
        return inst_table.lookup(self.pc)

def entry_point():
    load_stdin()
    machine = Machine()
    machine.spawn_label(base_env, 'main')
    machine.run()

############ instructions ##########

def mkinst(name, *a):
    t = InstType(name, *a)
    inst_type_table.register(t)

    screaming_name = name.upper().replace('-', '_')
    setattr(Inst, screaming_name, t.id)


# jumps and spawns
mkinst('frame', ['inst'], ['env'], [], 'start a new frame')
mkinst('return', [], [], [], 'pop a frame off the stack')
mkinst('spawn', ['inst'], ['env'], [], 'spawn a new process')
mkinst('jump', ['inst'], [], [], 'jump')
mkinst('jumpne', ['inst'], [None, None], [], 'jump if not equal')
mkinst('invoke', [], ['collection'], [], 'invoke a collection')
mkinst('jumpfail', ['inst'], ['status'], [], 'jump if the last status is a failure')

# vectors and collections
mkinst('collection', [], [], ['collection'], 'start a collection')
mkinst('index', [], ['vec', 'idx'], [], 'index a vector')
mkinst('collect', [], ['collection', None], ['collection'], 'collect a single value into a collection')
mkinst('vector', [], ['collection'], ['vec'], 'make a new vector')

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

# channels
mkinst('channel', [], [], ['channel'], 'make a new channel')
mkinst('env-set-output', [None], ['env', 'channel'], [], 'set the output on an env')
mkinst('env-set-input', [None], ['env', 'channel'], [], 'set the input on an env')
mkinst('crash', [], ['string'], [], 'crash')

################## instruction implementations #############
inst_actions = [None] * len(inst_type_table)
def inst_action(fn):
    """NOT_RPYTHON"""
    inst_type = as_dashed(fn.__name__)

    inst_id = inst_type_table.get(inst_type).id
    inst_actions[inst_id] = fn
    return fn

class Actions:
    @inst_action
    def pop(frame, args):
        frame.stack.pop()

    @inst_action
    def swap(frame, args):
        x = frame.pop()
        y = frame.pop()
        frame.push(x)
        frame.push(y)

    @inst_action
    def frame(frame, args):
        env = frame.stack.pop()
        addr = args[0]
        frame.proc.frame(env, addr)

    @inst_action
    def collection(frame, args):
        frame.push(Collection())

    @inst_action
    def const(frame, args):
        frame.push(const_table.lookup(args[0]))

    @inst_action
    def collect(frame, args):
        value = frame.pop()
        collection = frame.top_collection()
        collection.push(value)


    @inst_action
    def index(frame, args):
        idx = args[0]
        source = frame.pop()

        if isinstance(source, Collection):
            frame.push(source.values[idx])
        elif isinstance(source, Vector):
            frame.push(source.values[idx])
        else:
            frame.crash('not indexable')

    @inst_action
    def current_env(frame, args):
        frame.push(frame.env)

    @inst_action
    def let(frame, args):
        val = frame.pop()
        env = frame.pop()
        sym = args[0]
        env.let(sym, val)

    @inst_action
    def vector(frame, args):
        collection = frame.pop_collection()
        frame.push(Vector(collection.values))

    @inst_action
    def env(frame, args):
        frame.push(Env())

    @inst_action
    def jump(frame, args):
        frame.pc = args[0]

    @inst_action
    def return_(frame, args):
        frame.proc.frames.pop()
        if DEBUG: print 'after-return', frame.proc.frames
        if not frame.proc.frames:
            frame.proc.state = Proc.DONE

    @inst_action
    def invoke(frame, args):
        collection = frame.pop_collection()
        if not collection.values:
            raise Crash('empty invocation')

        # tail elim
        if frame.current_inst().id == Inst.RETURN:
            frame.proc.frames.pop()

        collection.values[0].invoke(frame, collection.values[1:])

    @inst_action
    def closure(frame, args):
        addr = args[0]
        env = frame.pop_env()
        frame.push(Function(env, addr))

    @inst_action
    def env_collect(frame, args):
        env = frame.pop_env()
        collection = frame.pop_collection()
        env.set_output(0, collection)
        frame.push(collection)
        frame.push(env)

    @inst_action
    def env_extend(frame, args):
        env = frame.pop_env()
        frame.push(env.extend())

def builtin(fn):
    # use the @! prefix which is only available when the parser has
    # allow_intrinsics set (i.e. only usable in prelude and other controlled
    # places).
    builtin_name = '@!' + as_dashed(fn.__name__)
    base_env.let(symbol_table.sym(builtin_name).id, Builtin(fn))

class Builtins:
    @builtin
    def add(frame, args):
        total = 0
        for arg in args:
            total += arg.as_number(frame)

        frame.put([Number(total)])

    @builtin
    def put(frame, args):
        frame.put(args)

    @builtin
    def take(frame, args):
        count = args[0].as_number(frame)
        frame.get_input(0).pipe(count, frame.get_output(1))

    @builtin
    def for_(frame, args):
        vec = args[0]
        if not isinstance(Vector, vec): return frame.crash('not a vector')
        frame.put(vec.values)

    @builtin
    def stdout(frame, args):
        try:
            parent_frame = frame.proc.frames[len(frame.proc.frames)-2]
        except IndexError:
            parent_frame = frame

        frame.push(parent_frame.env.get_output(0))

if __name__ == '__main__':
    entry_point()
