from machine import machine
from base import base_env
from load import load
import os

def run_file(filename):
    fd = -1

    try:
        fd = os.open(filename, os.O_RDONLY, 0o777)
        load(fd)
    finally:
        os.close(fd)

    machine.spawn_label(base_env, 'main')
    machine.run()
    return 0


def usage():
    print "TODO: usage"

def entry_point(argv):
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

    return run_file(filename)

def target(*args):
    return entry_point

if __name__ == '__main__':
    import sys
    entry_point(sys.argv)
