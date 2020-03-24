import sys # NOT RPYTHON
import os
from rpython.rlib.objectmodel import enforceargs
import rpython.rtyper.lltypesystem.lltype as lltype
from table import Table
from util import as_dashed, map_int
from value import *
from load import load
from proc import Proc, Frame
from debug import DEBUG
from channel import *
from base import base_env
from symbol import symbol_table
from code import label_table

############# channels ##################

############# parsing the compiled file ###############
stdin_fn = sys.stdin.readline
def load_stdin():
    return load(stdin_fn)

class FileLoader(object):
    def __init__(self, filename):
        self.filename = filename

        fd = -1
        try:
            fd = os.open(filename, os.O_RDONLY, 0o777)
            self.contents = os.read(fd, 0xFFFFFFF).split("\n")
        finally:
            os.close(fd)

        self.index = -1

    def get_line(self):
        self.index += 1
        return self.contents[self.index]

################## machine ####################
class Machine(object):
    def __init__(self):
        self.procs = Table()
        self.channels = Table()

    def make_channel(self):
        return self.channels.register(Channel())

    def load_file(self, filename):
        load(self, FileLoader(filename))

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
            else:
                moved += 1
                proc.step()

        for channel in self.channels.table:
            print 'start resolve'
            assert isinstance(channel, Channel)
            channel.resolve()

        if moved == 0 and waiting > 0: raise Deadlock
        if moved == 0: raise Done

machine = Machine()
