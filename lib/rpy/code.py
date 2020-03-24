from table import Table

label_table = Table()
labels_by_addr = {}

def register_label(label):
    print 'register_label', label.name, label.addr
    label_table.register(label)
    labels_by_addr[label.addr] = label

def label_by_addr(addr):
    return labels_by_addr[addr].name

inst_table = Table()

register_inst = inst_table.register
