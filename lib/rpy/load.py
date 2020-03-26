from table import Table, Label
from inst import inst_type_table, Inst
from value import *
from util import map_int
from debug import debug
from const import const_table
from code import inst_table, label_table, register_label
from symbol import symbol_table, sym
import os

from rpython.rlib.rstruct.runpack import runpack

def unescape(s):
    return s.replace('\\n', '\n').replace('\\\\', '\\')

def read_int(fd):
    out = runpack('i', os.read(fd, 4))
    assert out >= 0 # unsigned
    return out

def read_str(fd):
    length = read_int(fd)
    return os.read(fd, length)

def read_constant(fd):
    typechar = os.read(fd, 1)
    if typechar == '"': return String(read_str(fd))
    if typechar == '#': return Int(read_int(fd))
    assert False, 'unexpected typechar %s' % typechar

def load(fd):
    offsets = {
        'const': len(const_table),
        'label': len(label_table),
        'inst': len(inst_table),
    }

    # constants block
    num_constants = read_int(fd)
    for _ in range(0, num_constants):
        const = read_constant(fd)
        const_table.register(const)

    # symbols block
    num_symbols = read_int(fd)
    symbol_translation = [0] * num_symbols
    for i in range(0, num_symbols):
        val = read_str(fd)
        symbol_translation[i] = sym(val)

    num_labels = read_int(fd)
    for _ in range(0, num_labels):
        name = read_str(fd)
        addr = read_int(fd)
        trace = None
        has_trace = read_int(fd)
        trace = None
        if has_trace == 1: trace = read_str(fd)
        label = Label(name, addr, trace)
        register_label(label)

    num_insts = read_int(fd)
    for _ in range(0, num_insts):
        command = read_str(fd)
        num_args = read_int(fd)
        raw_args = [999] * num_args
        for i in range(0, num_args): raw_args[i] = read_int(fd)
        inst_type = inst_type_table.get(command)
        args = inst_type.reindex(raw_args, offsets, symbol_translation)
        inst_table.register(Inst(inst_type.id, args))

