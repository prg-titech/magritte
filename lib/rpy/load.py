from table import Table, Label
from inst import inst_type_table, Inst
from value import *
from util import map_int
from debug import DEBUG
from const import const_table
from code import inst_table, label_table, register_label
from symbol import symbol_table, sym

def unescape(s):
    return s.replace('\\n', '\n').replace('\\\\', '\\')

def parse_constant(arr):
    stack = []
    for el in arr:
        if el[0] == '"': stack.append(String(unescape(el[1:])))
        # elif el[0] == '+': stack.append(Float(float(el[1:])))
        elif el[0] == '#': stack.append(Int(int(el[1:])))
        elif el[0] == '[':
            count = int(el[1:])
            vals = [None] * count
            for i in range(0, count): vals[i] = stack.pop()
            stack.append(Vector(vals))
        # elif el[0] == '{':
        #     count = int(el[1:])
        #     env = Env()
        #     for i in range(0, count):
        #         key = stack.pop()
        #         assert isinstance(key, String)
        #         val = stack.pop()
        #         env.let(machine.symbol_table.sym(key).id, val)
        #     stack.append(env)
    assert len(stack) == 1, arr
    return stack[0]

def load(machine, loader):
    offsets = {
        'sym': len(symbol_table),
        'const': len(const_table),
        'label': len(label_table),
        'inst': len(inst_table),
    }

    # constants block
    num_constants = int(loader.get_line().split(' ')[0])
    for _ in range(0, num_constants):
        const_table.register(parse_constant(loader.get_line().split(' ')))

    # symbols block
    num_symbols = int(loader.get_line().split(' ')[0])
    for _ in range(0, num_symbols):
        sym(loader.get_line().split(' ')[0])

    num_labels = int(loader.get_line().split(' ')[0])
    for _ in range(0, num_labels):
        parts = loader.get_line().split(' ')
        name = parts[0]
        addr = int(parts[1])
        trace = None
        if len(parts) > 2: trace = parts[2]
        label = Label(name, addr, trace)
        register_label(label)

    num_insts = int(loader.get_line().split(' ')[0])
    for _ in range(0, num_insts):
        parts = loader.get_line().split(' ')
        inst_type = inst_type_table.get(parts[1])
        raw_args = map_int(parts[2:])
        args = inst_type.reindex(raw_args, offsets)
        inst_table.register(Inst(inst_type.id, args))

