import CoreGraphics
import Testing

@testable import FlowerPasswordDomain

@Suite("PanelLayout")
struct PanelLayoutTests {
    private let width: CGFloat = 300

    private var measurements: PanelLayout.Measurements {
        PanelLayout.Measurements(
            titleHeight: 26, hintPasswordHeight: 15, hintKeyHeight: 15,
            websiteLabelSize: CGSize(width: 90, height: 16), websiteLabelTextWidth: 84,
            websiteButtonSize: CGSize(width: 140, height: 15), websiteButtonTextWidth: 132)
    }

    private func frames() -> PanelLayout.Frames {
        PanelLayout.place(width: width, measurements: measurements)
    }

    @Test("lays every row inside the panel's padded width")
    func fitsThePanel() {
        let frames = frames()
        let all = [
            frames.title, frames.password, frames.key, frames.generate, frames.prefix,
            frames.suffix, frames.hintPassword, frames.hintKey, frames.websiteLabel,
        ]
        for frame in all {
            #expect(frame.minX >= PanelLayout.Metrics.pad)
            #expect(frame.maxX <= width - PanelLayout.Metrics.pad)
            #expect(frame.width > 0)
            #expect(frame.height > 0)
        }
        #expect(frames.close.maxX == width - PanelLayout.Metrics.pad)
    }

    @Test("keeps the close button vertically centered in the title row")
    func closeButtonCentered() {
        let frames = frames()
        #expect(frames.close.midY == frames.title.midY)
        #expect(frames.close.height == PanelLayout.Metrics.closeSize)
    }

    @Test("stacks rows top-down with even spacing and no overlap")
    func stacking() {
        let frames = frames()
        let pad = PanelLayout.Metrics.pad
        let spacing = PanelLayout.Metrics.spacing
        #expect(frames.title.minY == pad)
        #expect(frames.password.minY == frames.title.maxY + spacing)
        #expect(frames.key.minY == frames.password.maxY + spacing)
        #expect(frames.generate.minY == frames.key.maxY + spacing)
        #expect(frames.prefix.minY == frames.generate.maxY + spacing)
        #expect(frames.hintPassword.minY == frames.prefix.maxY + spacing)
        #expect(frames.hintKey.minY == frames.hintPassword.maxY + spacing)
        #expect(frames.websiteLabel.minY == frames.hintKey.maxY + spacing)
    }

    @Test("joins the generate button and the length select with a hairline")
    func generateAndLength() {
        let frames = frames()
        #expect(frames.length.width == PanelLayout.Metrics.lengthWidth)
        #expect(frames.generate.maxX == frames.length.minX)
        #expect(frames.lengthDivider.minX == frames.generate.maxX)
        #expect(frames.lengthDivider.width == 1)
        #expect(frames.lengthDivider.height == frames.length.height)
    }

    @Test("overlaps the prefix and suffix borders by exactly one point")
    func splitFieldsOverlap() {
        let frames = frames()
        #expect(frames.suffix.minX == frames.prefix.maxX - PanelLayout.Metrics.splitOverlap)
    }

    @Test("aligns the link title with the end of the label text")
    func linkAlignment() {
        let frames = frames()
        let pad = PanelLayout.Metrics.pad
        // 84pt of label text starting at the cell's center offset, minus the
        // button cell's own left padding.
        let expectedX = pad + ceil((90 + 84) / 2 - (140 - 132) / 2)
        #expect(frames.websiteButton.minX == expectedX)
        #expect(frames.websiteButton.maxX <= width - pad)
    }

    @Test("clamps the link width so a long label cannot overflow the panel")
    func linkWidthClamped() {
        let long = PanelLayout.Measurements(
            titleHeight: 26, hintPasswordHeight: 15, hintKeyHeight: 15,
            websiteLabelSize: CGSize(width: 250, height: 16), websiteLabelTextWidth: 244,
            websiteButtonSize: CGSize(width: 140, height: 15), websiteButtonTextWidth: 132)
        let frames = PanelLayout.place(width: width, measurements: long)
        #expect(frames.websiteButton.maxX <= width - PanelLayout.Metrics.pad)
    }

    @Test("centers a field inside its row with a 6pt inset")
    func fieldFrame() {
        let container = CGRect(x: 0, y: 0, width: 280, height: 32)
        let frame = PanelLayout.fieldFrame(in: container, fieldHeight: 17.2)
        #expect(frame.height == 18)
        #expect(frame.minX == PanelLayout.Metrics.fieldInset)
        #expect(frame.width == 280 - PanelLayout.Metrics.fieldInset * 2)
        #expect(frame.midY == container.midY)
    }
}
