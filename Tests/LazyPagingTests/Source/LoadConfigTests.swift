import Testing
@testable import LazyPaging

@Suite("LoadConfig")
struct LoadConfigTests {
    @Test("given inputs when initialised then fields are stored")
    func given_inputs_when_initialised_then_fieldsAreStored() {
        let config = LoadConfig<Int>(key: 7, kind: .append, loadSize: 30)
        #expect(config.key == 7)
        #expect(config.kind == .append)
        #expect(config.loadSize == 30)
    }

    @Test("given nil key when initialised then key is nil")
    func given_nilKey_when_initialised_then_keyIsNil() {
        let config = LoadConfig<Int>(key: nil, kind: .refresh, loadSize: 10)
        #expect(config.key == nil)
    }
}
