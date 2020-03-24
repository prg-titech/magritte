class Table(object):
    def __init__(self):
        self.table = []
        self.rev_table = {}

    def register(self, entry):
        assert isinstance(entry, TableEntry)
        entry.id = len(self)
        self.table.append(entry)
        if entry.name:
            self.rev_table[entry.name] = entry
        return entry

    def get(self, name):
        return self.rev_table[name]

    def __len__(self):
        return len(self.table)

    def lookup(self, idx):
        try:
            return self.table[idx]
        except IndexError:
            print 'no index', idx
            raise

class TableEntry(object):
    id = -1
    name = None

    def __init__(*a):
        raise NotImplementedError

class Label(TableEntry):
    def __init__(self, name, addr, trace):
        assert isinstance(addr, int)
        self.id = -1
        self.name = name
        self.addr = addr
        self.trace = trace

