from table import Table, TableEntry

class SymbolTable(Table):
    def sym(self, string):
        assert isinstance(string, str)
        try:
            return self.rev_table[string].id
        except KeyError:
            return self.register(Symbol(string)).id

    def revsym(self, idx):
        assert isinstance(idx, int)

        return self.table[idx].name

class Symbol(TableEntry):
    def __init__(self, string): self.name = string


symbol_table = SymbolTable()
sym = symbol_table.sym
revsym = symbol_table.revsym
