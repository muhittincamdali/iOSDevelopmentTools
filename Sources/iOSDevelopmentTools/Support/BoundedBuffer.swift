/// A first-in, first-out buffer that keeps at most `capacity` elements: appending to a full
/// buffer overwrites the oldest element in constant time.
struct BoundedBuffer<Element> {
    private var storage: [Element] = []
    /// Index of the oldest element once the buffer is full.
    private var head = 0
    private(set) var capacity: Int

    init(capacity: Int) {
        self.capacity = max(capacity, 1)
    }

    var count: Int { storage.count }
    var isEmpty: Bool { storage.isEmpty }

    /// The elements, oldest first.
    var elements: [Element] {
        head == 0 ? storage : Array(storage[head...]) + storage[..<head]
    }

    mutating func append(_ element: Element) {
        if storage.count < capacity {
            storage.append(element)
        } else {
            storage[head] = element
            head = (head + 1) % capacity
        }
    }

    /// Changes the capacity; when it shrinks, the oldest elements are dropped.
    mutating func setCapacity(_ newCapacity: Int) {
        let newCapacity = max(newCapacity, 1)
        var ordered = elements
        if ordered.count > newCapacity { ordered.removeFirst(ordered.count - newCapacity) }
        storage = ordered
        head = 0
        capacity = newCapacity
    }

    mutating func removeAll() {
        storage.removeAll()
        head = 0
    }

    /// The first element that matches, searching in storage order.
    func first(where predicate: (Element) -> Bool) -> Element? {
        storage.first(where: predicate)
    }

    /// Changes the first element that matches; `false` when none does.
    @discardableResult
    mutating func modifyFirst(where predicate: (Element) -> Bool, _ change: (inout Element) -> Void) -> Bool {
        guard let index = storage.firstIndex(where: predicate) else { return false }
        change(&storage[index])
        return true
    }
}

extension BoundedBuffer: Sendable where Element: Sendable {}
