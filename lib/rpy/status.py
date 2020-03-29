from value import *

class Status(Value):
    def is_success(self):
        return True

class Success(Status):
    def __init__(self):
        pass

    def s(self):
        return '<success>'

class Fail(Status):
    def __init__(self, reason):
        self.reason = reason

    def is_success(self):
        return False

    def s(self):
        return '<fail %s>' % self.reason.s()
