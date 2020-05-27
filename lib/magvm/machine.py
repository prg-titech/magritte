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
from labels import label_table
from rpython.rlib.jit import JitDriver, elidable
from rpython.rlib.listsort import make_timsort_class

from random import shuffle

jit_driver = JitDriver(greens=['pc'], reds=['env', 'stack'])

################## machine ####################
# This class contains the main loop of the vm,
# and implements basic scheduling among a
# collection of Proc objects.
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
        debug(0, ['run!'])
        try:
            while True: self.step()
        except Done:
            return self.procs

        assert False # impossible

    def step(self):
        debug(0, ['%%%%% PHASE: step %%%%%'])
        sort = age_sort([p for p in self.procs.table])
        sort.sort()
        for proc in sort.list:
            if not proc: continue
            if proc.state == Proc.DONE: continue

            debug(0, ['-- running proc', proc.s()])
            if proc.is_running():
                proc.age += 1

                jit_driver.jit_merge_point(
                    pc=proc.current_frame().pc,
                    stack=proc.frames,
                    env=proc.current_frame().env
                )

                proc.step()

        debug(0, ['%%%%% PHASE: resolve %%%%%'])
        for channel in self.channels.table:
            debug(0, ['+', channel.s()])
            assert channel.channelable is not None
            channel.channelable.resolve()

        debug(0, ['%%%%% PHASE: check %%%%%'])
        for p in self.procs.table: debug(0, [p.s()])

        running = 0
        waiting = 0
        for proc in self.procs.table:
            if proc.is_running():
                running += 1
            elif proc.state == Proc.WAITING:
                waiting += 1

        if running == 0 and waiting > 0: raise Deadlock
        if running == 0: raise Done

machine = Machine()

age_sort = make_timsort_class(lt=lambda p, q: p.age < q.age)
