from rpython.rlib.objectmodel import we_are_translated
import os

should_debug = False
debug_fd = -1

try:
    debug_option = os.environ['MAG_DEBUG_TO']
    should_debug = True

    if debug_option in ['1', 'stdout']:
        debug_fd = 1 # stdout
    elif debug_option in ['2', 'stderr']:
        debug_fd = 2
    else:
        debug_fd = os.open(debug_option, os.O_WRONLY | os.CREAT, 0o777)
except KeyError:
    should_debug = False

def debug(level, parts):
    assert isinstance(level, int)

    if should_debug:
        os.write(debug_fd, ' '.join(parts))
