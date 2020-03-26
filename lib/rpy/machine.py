import sys # NOT RPYTHON
import os
from rpython.rlib.objectmodel import enforceargs
import rpython.rtyper.lltypesystem.lltype as lltype
from table import Table
from util import as_dashed, map_int
from value import *
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
        for proc in self.procs.table:
            if not proc: continue
            if proc.state == Proc.DONE: continue

            if proc.state in [Proc.RUNNING, Proc.INIT]:
                proc.step()

        for channel in self.channels.table:
            assert isinstance(channel, Channel)
            channel.resolve()

        running = 0
        waiting = 0
        for proc in self.procs.table:
            if proc.state == Proc.RUNNING:
                # if DEBUG: print '> ', proc.id, 'running'
                running += 1
            elif proc.state == Proc.WAITING:
                # if DEBUG: print '> ', proc.id, 'waiting'
                waiting += 1


        if running == 0 and waiting > 0: raise Deadlock
        if running == 0: raise Done

machine = Machine()
