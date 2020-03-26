from rpython.rlib.objectmodel import we_are_translated

def debug(level=0):
    return not we_are_translated()
