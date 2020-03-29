import sys # NOT RPYTHON
import os
from rpython.rlib.objectmodel import enforceargs
import rpython.rtyper.lltypesystem.lltype as lltype
from table import Table
from util import as_dashed, map_int
from value import *
from proc import Proc, Frame
from debug import debug
from channel import *
from base import base_env
from symbol import symbol_table
from code import label_table
from rpython.rlib.jit import JitDriver, elidable

from random import shuffle

jit_driver = JitDriver(greens=['pc'], reds=['env', 'stack'])

################## machine ####################
class Machine(object):
    def __init__(self):
        self.procs = Table()
        self.channels = Table()

    def make_channel(self):
        return self.channels.register(Channel())

    def spawn_label(self, env, label):
        return self.spawn(env, label_table.get(label).addr)

    def spawn(self, env, addr):
        proc = Proc(self)
        self.procs.register(proc)
        proc.frame(env, addr)
        return proc

    def run(self):
        if debug(): print 'run!'
        try:
            while True: self.step()
        except Done:
            return self.procs

        assert False # impossible

    def step(self):
        if debug(): print '%%%%% PHASE: step %%%%%'
        for proc in self.procs.table:
            if not proc: continue
            if proc.state == Proc.DONE: continue

            if proc.is_running():
                jit_driver.jit_merge_point(
                    pc=proc.current_frame().pc,
                    stack=proc.frames,
                    env=proc.current_frame().env
                )

                proc.step()

        if debug(): print '%%%%% PHASE: resolve %%%%%'
        for channel in self.channels.table:
            if debug(): print '+', channel.s()
            assert isinstance(channel, Channel)
            channel.resolve()

        if debug():
            print '%%%%% PHASE: check %%%%%'
            for p in self.procs.table: print p.s()

        running = 0
        waiting = 0
        for proc in self.procs.table:
            if proc.is_running():
                # if debug(): print '> ', proc.id, 'running'
                running += 1
            elif proc.state == Proc.WAITING:
                # if debug(): print '> ', proc.id, 'waiting'
                waiting += 1

        if running == 0 and waiting > 0: raise Deadlock
        if running == 0: raise Done

machine = Machine()
