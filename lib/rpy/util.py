def print_list_s(tag, vals):
    print tag,
    for v in vals: print v.s(),
    print


def as_dashed(name):
    name = name.replace('_', '-')

    # for things like `return` which can't be method names in python
    if name[-1] == '-': return name[:-1]
    else: return name

# normal map isn't rpython
def map(fn, arr):
    out = [None] * len(arr)
    for (i, e) in enumerate(arr):
        out[i] = fn(e)
    return out

def map_int(arr):
    out = [0] * len(arr)
    for (i, e) in enumerate(arr):
        out[i] = int(e)
    return out

