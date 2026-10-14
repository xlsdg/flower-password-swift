import CoreGraphics
import Testing

@testable import FlowerPasswordDomain

@Suite("PanelPlacement")
struct PanelPlacementTests {
    private let size = CGSize(width: 300, height: 334)
    private let visible = CGRect(x: 0, y: 0, width: 1440, height: 900)

    @Test("leaves a position that already fits untouched")
    func fits() {
        let point = PanelPlacement.clampedTopLeft(CGPoint(x: 500, y: 700), size: size, in: visible)
        #expect(point == CGPoint(x: 500, y: 700))
    }

    @Test("pulls the panel in from the right and bottom edges")
    func rightAndBottom() {
        let point = PanelPlacement.clampedTopLeft(CGPoint(x: 1400, y: 100), size: size, in: visible)
        #expect(point == CGPoint(x: 1140, y: 334))
    }

    @Test("pulls the panel in from the left and top edges")
    func leftAndTop() {
        let point = PanelPlacement.clampedTopLeft(CGPoint(x: -50, y: 1200), size: size, in: visible)
        #expect(point == CGPoint(x: 0, y: 900))
    }

    @Test("the left and top clamps win when the work area is too small")
    func tinyArea() {
        let tiny = CGRect(x: 10, y: 20, width: 100, height: 100)
        let point = PanelPlacement.clampedTopLeft(CGPoint(x: 500, y: 500), size: size, in: tiny)
        #expect(point == CGPoint(x: 10, y: 120))
    }
}
