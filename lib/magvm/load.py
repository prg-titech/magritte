from table import Table, Label
from inst import inst_type_table, Inst
from value import *
from util import map_int
from debug import debug
from const import const_table
from labels import inst_table, label_table, register_label
from symbol import symbol_table, sym, revsym
from intrinsic import intrinsic, intrinsics
from base import base_env
from spawn import spawn
from status import Fail

import os

from rpython.rlib.rposix import spawnv
from rpython.rlib.rstruct.runpack import runpack

def prefixed(p):
    return os.environ['MAGRITTE_PREFIX'] + p

def unescape(s):
    return s.replace('\\n', '\n').replace('\\\\', '\\')

def read_int(fd):
    out = runpack('i', os.read(fd, 4))
    return out

def read_str(fd):
    length = read_int(fd)
    return os.read(fd, length)

def read_constant(fd):
    typechar = os.read(fd, 1)
    if typechar == '"': return String(read_str(fd))
    if typechar == '#': return Int(read_int(fd))
    assert False, 'unexpected typechar %s' % typechar

def load_fd(fd):
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
        addr = read_int(fd) + offsets['inst']
        trace = None
        has_trace = read_int(fd)
        trace = None
        if has_trace == 1: trace = read_str(fd)
        label = Label(name, addr, trace)
        register_label(label)

    num_insts = read_int(fd)
    for i in range(0, num_insts):
        command = read_str(fd)
        num_args = read_int(fd)
        raw_args = [999] * num_args
        for i in range(0, num_args): raw_args[i] = read_int(fd)
        inst_type = inst_type_table.get(command)
        args = inst_type.reindex(raw_args, offsets, symbol_translation)
        inst_table.register(Inst(inst_type.id, args))

def load_file(fname):
    fd = 0

    try:
        fd = os.open(fname, os.O_RDONLY, 0o777)
        load_fd(fd)
    finally:
        os.close(fd)

    label = label_table.get('main')
    debug(0, ['load!', fname, str(label.addr)])
    return label

def precompile_and_load_file(fname):
    precompile(fname)
    return load_file(fname + 'c')

def decomp_to_file(fname):
    fd = 0

    try:
        fd = os.open(fname, os.O_WRONLY | os.O_CREAT, 0o777)
        decomp_fd(fd)
    finally:
        os.close(fd)

def arg_as_str(inst_type, i, arg):
    arg_type = None
    try:
        arg_type = inst_type.static_types[i]
        if arg_type is None: return '#'+str(arg)
        if arg_type == 'inst': return '@'+labels_by_addr[arg].name
        if arg_type == 'const': return '+'+const_table.lookup(arg).s()
        if arg_type == 'sym': return ':'+revsym(arg)
        if arg_type == 'intrinsic': return '@!'+intrinsics.lookup(arg).name
    except KeyError as e:
        debug(0, ['no key:', inst_type.name, arg_type or '??', str(i), str(arg)])
    except IndexError as e:
        debug(0, ['no index:', inst_type.name, arg_type or '??', str(i), str(arg)])

    return '?%s' % str(arg)


def decomp_fd(fd):
    out = []

    out.append('==== symbols ====\n')
    for s in symbol_table.table:
        out.append('%d %s\n' % (s.id, s.name))

    out.append('\n')
    out.append('==== consts ====\n')
    for (i, c) in enumerate(const_table.table):
        out.append('%d %s\n' % (i, c.s()))

    out.append('==== labels ====\n')
    for (i, l) in enumerate(label_table.table):
        out.append('%d %s\n' % (i, l.s()))

    out.append('==== instructions ====\n')
    for (i, inst) in enumerate(inst_table.table):
        try:
            label = labels_by_addr[i]
            out.append("%s:" % label.name)
            if label.trace:
                out.append(" %s" % label.trace)
            out.append('\n')
        except KeyError:
            pass

        inst_type = inst.type()
        typename = inst_type.name
        out.append('  %d %s' % (i, typename))

        for (i, arg) in enumerate(inst.arguments):
            out.append(' %s' % arg_as_str(inst_type, i, arg))

        out.append('\n')

    os.write(fd, ''.join(out))

def _get_fname(args):
    assert len(args) == 1
    fname_obj = args[0]
    assert isinstance(fname_obj, String)
    fname = fname_obj.value
    assert fname is not None
    return fname

def precompile(fname):
    fnamec = fname + 'c'
    if os.path.exists(fnamec) and os.path.getmtime(fnamec) >= os.path.getmtime(fname): return

    mag_binary = prefixed('/bin/magc')

    debug(0, ['magc out of date, recompiling', mag_binary, fname])
    spawn(mag_binary, [fname])

@intrinsic
def load(frame, args):
    fname = _get_fname(args)

    if not os.path.exists(fname): fname = prefixed(fname)

    if not os.path.exists(fname):
        frame.fail(tagged('no-such-file', String(fname)))

    label = precompile_and_load_file(fname)

    frame.proc.frame(base_env, label.addr, tail_elim=False)

base_env.let(sym('load'), load)

@intrinsic
def decomp(frame, args):
    if len(args) == 0:
        decomp_fd(1) # stdout
    else:
        fname = _get_fname(args)
        decomp_to_file(fname)

