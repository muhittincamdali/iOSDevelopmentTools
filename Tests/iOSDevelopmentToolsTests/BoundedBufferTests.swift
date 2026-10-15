import Testing
@testable import iOSDevelopmentTools

@Suite("Bounded buffer")
struct BoundedBufferTests {
    @Test("Appending past the capacity drops the oldest elements")
    func overwrite() {
        var buffer = BoundedBuffer<Int>(capacity: 3)
        (1...8).forEach { buffer.append($0) }
        #expect(buffer.elements == [6, 7, 8])
        #expect(buffer.count == 3)
    }

    @Test("Capacity changes keep the newest elements in order", arguments: [1, 2, 4, 10])
    func resize(newCapacity: Int) {
        var buffer = BoundedBuffer<Int>(capacity: 4)
        (1...6).forEach { buffer.append($0) }
        buffer.setCapacity(newCapacity)
        #expect(buffer.elements == Array([3, 4, 5, 6].suffix(newCapacity)))
        buffer.append(7)
        #expect(buffer.elements.last == 7)
        #expect(buffer.count == min(newCapacity, 5))
    }

    @Test("A capacity below one becomes one")
    func minimumCapacity() {
        var buffer = BoundedBuffer<String>(capacity: -5)
        #expect(buffer.capacity == 1)
        buffer.append("a")
        buffer.append("b")
        #expect(buffer.elements == ["b"])
        buffer.setCapacity(0)
        #expect(buffer.capacity == 1)
    }

    @Test("Elements can be found and changed in place")
    func modify() {
        var buffer = BoundedBuffer<Int>(capacity: 2)
        [1, 2, 3].forEach { buffer.append($0) }
        #expect(buffer.modifyFirst(where: { $0 == 3 }) { $0 = 30 })
        #expect(!buffer.modifyFirst(where: { $0 == 1 }) { $0 = 10 })
        #expect(buffer.elements == [2, 30])
        #expect(buffer.first { $0 > 2 } == 30)
        buffer.removeAll()
        #expect(buffer.isEmpty)
    }
}
