import Foundation
import Testing

@testable import FlowerPasswordCore

private struct GoldenVector: Decodable {
    let password: String
    let key: String
    let length: Int
    let expected: String
}

@Suite("FlowerPassword algorithm")
struct FlowerPasswordTests {
    @Test("matches every golden vector from the reference implementation")
    func goldenVectors() throws {
        let url = try #require(
            Bundle.module.url(forResource: "golden_vectors", withExtension: "json")
        )
        let vectors = try JSONDecoder().decode([GoldenVector].self, from: Data(contentsOf: url))
        #expect(vectors.count >= 40)

        for vector in vectors {
            let result = try FlowerPassword.code(
                password: vector.password,
                key: vector.key,
                length: vector.length
            )
            #expect(
                result == vector.expected,
                "fpCode(\(vector.password), \(vector.key), \(vector.length))"
            )
        }
    }

    @Test("matches the algorithm's published example vectors")
    func publishedVectors() throws {
        #expect(try FlowerPassword.code(password: "password", key: "key") == "K3A2a66Bf88b628c")
        #expect(try FlowerPassword.code(password: "test", key: "github.com", length: 16) == "D04175F7A9c7Ab4a")
        #expect(try FlowerPassword.code(password: "123456", key: "taobao", length: 16) == "KfdDf77F7D64e5c0")
        #expect(try FlowerPassword.code(password: "12345", key: "site", length: 16) == "K05a62bfea0C1553")
    }

    @Test("rejects lengths outside 2...32", arguments: [-1, 0, 1, 33, 100])
    func invalidLength(_ length: Int) {
        #expect(throws: FlowerPassword.LengthError.outOfRange(length)) {
            try FlowerPassword.code(password: "password", key: "key", length: length)
        }
    }

    @Test("is deterministic and input-sensitive")
    func determinism() throws {
        let a = try FlowerPassword.code(password: "password", key: "key", length: 16)
        let b = try FlowerPassword.code(password: "password", key: "key", length: 16)
        #expect(a == b)
        #expect(try FlowerPassword.code(password: "password1", key: "key", length: 16) != a)
        #expect(try FlowerPassword.code(password: "password", key: "key1", length: 16) != a)
    }

    @Test("always starts with a letter and is alphanumeric")
    func composition() throws {
        for key in ["key", "site", "a", "naïve", "🔑"] {
            let code = try FlowerPassword.code(password: "12345", key: key, length: 16)
            #expect(code.first?.isLetter == true)
            #expect(code.allSatisfy { $0.isLetter || $0.isNumber })
            #expect(code.count == 16)
        }
    }
}
