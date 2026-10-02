from std.collections import List


struct Box[T: Copyable & Deinitable](Copyable, Movable, Deinitable):
    """Heap cell so a generated struct can name itself."""

    var _items: List[Self.T]

    def __init__(out self, var value: Self.T):
        self._items = List[Self.T]()
        self._items.append(value^)

    def __getitem__(self) -> Self.T:
        return self._items[0].copy()
