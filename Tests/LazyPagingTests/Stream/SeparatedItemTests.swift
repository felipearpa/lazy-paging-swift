import Testing
@testable import LazyPaging

@Suite("SeparatedItem")
struct SeparatedItemTests {
    private struct Separator: Identifiable, Hashable, Sendable {
        let id: Int
        let heading: String
    }

    @Test("given two item cases with equal payload when compared then they are equal")
    func given_twoItemCases_when_compared_then_equal() {
        let a = SeparatedItem<TestItem, Separator>.item(TestItem(id: 1))
        let b = SeparatedItem<TestItem, Separator>.item(TestItem(id: 1))
        #expect(a == b)
    }

    @Test("given item and separator when compared then they differ")
    func given_itemAndSeparator_when_compared_then_notEqual() {
        let a = SeparatedItem<TestItem, Separator>.item(TestItem(id: 1))
        let b = SeparatedItem<TestItem, Separator>.separator(Separator(id: 1, heading: "x"))
        #expect(a != b)
    }

    @Test("given item case when id is read then returns underlying item id")
    func given_itemCase_when_idRead_then_returnsItemId() {
        let sep = SeparatedItem<TestItem, Separator>.item(TestItem(id: 42))
        #expect(sep.id == 42)
    }

    @Test("given separator case when id is read then returns separator id")
    func given_separatorCase_when_idRead_then_returnsSeparatorId() {
        let sep = SeparatedItem<TestItem, Separator>.separator(Separator(id: 99, heading: "x"))
        #expect(sep.id == 99)
    }

    @Test("given equal values when hashed then hashes match")
    func given_equalValues_when_hashed_then_hashesMatch() {
        let a = SeparatedItem<TestItem, Separator>.item(TestItem(id: 1))
        let b = SeparatedItem<TestItem, Separator>.item(TestItem(id: 1))
        #expect(a.hashValue == b.hashValue)
    }
}
