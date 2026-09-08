from std.collections import List


struct Box[T: Copyable & Deinitable](Copyable, Movable, Deinitable):
    """Heap cell for recursive generated records.

    One-element `List` is the indirection. A raw pointer cell double-frees
    on copy in Mojo 1.0; the list owns a single heap `T`.
    """

    var _items: List[Self.T]

    def __init__(out self, var value: Self.T):
        self._items = List[Self.T]()
        self._items.append(value^)

    def __getitem__(self) -> Self.T:
        return self._items[0].copy()
