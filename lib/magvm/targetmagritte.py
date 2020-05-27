from machine import machine
from base import base_env
from load import load_file, precompile_and_load_file, prefixed
from debug import debugger, debug
from rpython.rlib.objectmodel import we_are_translated
import os

####### main target ##########################
# This is the main target file for compilation by RPython.
# The whole program will start at the `entry_point` function.

def run_file(filename):
    load_file(filename)
    machine.spawn_label(base_env, 'main')
    machine.run()
    return 0

def run_prelude():
    main = precompile_and_load_file(prefixed('/lib/mag/prelude.mag'))
    machine.spawn(base_env, main.addr)

def usage():
    print "TODO: usage"

def entry_point(argv):
    debugger.setup()
    if we_are_translated():
        debug(0, ['== starting magvm in native mode =='])
    else:
        debug(0, ['== starting magvm in interpreted mode =='])

    filename = None

    while argv:
        arg = argv.pop(0)
        if arg == '-f':
            filename = argv.pop(0)
        elif arg == '-h':
            usage()
        else:
            filename = arg

    if filename is None:
        usage()
        return 1

    run_prelude()
    return run_file(filename)

def target(*args):
    return entry_point

if __name__ == '__main__':
    import sys
    entry_point(sys.argv)
