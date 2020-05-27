from rpython.rlib.objectmodel import we_are_translated
import os

class Debugger(object):
    def __init__(self):
        self.fd = -1
        self.level = -1
        self.fname = None

    def should_debug(self, level):
        return level <= self.level

    def setup(self):
        if self.fname: self.open_file()

    def open_file(self):
        self.fd = os.open(self.fname, os.O_WRONLY | os.O_CREAT, 0o777)

    def debug(self, level, parts):
        assert isinstance(level, int)

        if self.should_debug(level) and self.fd > 0:
            os.write(self.fd, ' '.join(parts) + '\n')

debugger = Debugger()
debug_enabled = True

try:
    debug_option = os.environ['MAGRITTE_DEBUG']
    should_debug = True

    if debug_option in ['1', 'stdout']:
        debugger.fd = 1 # stdout
    elif debug_option in ['2', 'stderr']:
        debugger.fd = 2
    elif debug_option in ['off', 'none', '0']:
        debug_enabled = False
    else:
        debugger.fname = debug_option

except KeyError:
    debug_enabled = False

def debug(level, parts):
    if not debug_enabled: return
    debugger.debug(level, parts)

def set_debug(level):
    if not debug_enabled: return
    debugger.level = level

def disable_debug():
    if not debug_enabled: return
    debugger.level = -1

def open_debug_file(fname):
    debugger.fname = fname
    debugger.open_file()

def open_shell(frame, args):
    if we_are_translated():
        vm_debugger_rpython(frame, args)
    else:
        vm_debugger_dynamic(frame, args)

def vm_debugger_rpython(frame, args):
    print 'vm_debugger not available in compiled mode'

def vm_debugger_dynamic(frame, args):
    """NOT_RPYTHON"""
    import code

    code.interact(local=dict(globals(), **locals()))
