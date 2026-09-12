from std.collections import List


struct IndentStack(Copyable, Movable):
    """Reserved indent stack. Not a heap frame per nesting level."""

    var levels: List[Int]

    def __init__(out self):
        self.levels = List[Int](capacity=16)

    def push(mut self, col: Int):
        self.levels.append(col)

    def pop(mut self):
        if len(self.levels) > 0:
            _ = self.levels.pop()

    def current(self) -> Int:
        var n = len(self.levels)
        if n == 0:
            return 0
        return self.levels[n - 1]

    def depth(self) -> Int:
        return len(self.levels)
