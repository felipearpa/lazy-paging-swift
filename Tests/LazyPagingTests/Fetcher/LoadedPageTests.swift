import Testing
@testable import LazyPaging

@Suite("LoadedPage")
struct LoadedPageTests {
    @Test("given inputs when initialised then fields are stored")
    func given_inputs_when_initialised_then_fieldsAreStored() {
        let page = LoadedPage<Int, TestItem>(
            items: [TestItem(id: 1)],
            previousKey: 0,
            nextKey: 2
        )
        #expect(page.items.count == 1)
        #expect(page.previousKey == 0)
        #expect(page.nextKey == 2)
    }
}
