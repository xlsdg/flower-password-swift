import CoreGraphics

/// Top-down geometry for the fixed-size panel form. Raw AppKit measurements
/// go in, ceiled frames come out; the view only assigns them.
public enum PanelLayout {
    public enum Metrics {
        public static let pad: CGFloat = 10
        public static let spacing: CGFloat = 10
        public static let rowHeight: CGFloat = 32
        public static let fieldInset: CGFloat = 6
        public static let closeSize: CGFloat = 16
        public static let lengthWidth: CGFloat = 64
        /// The two middle borders overlap by this much to read as one hairline.
        public static let splitOverlap: CGFloat = 1
    }

    /// Text measurements the view reads from its own cells, in AppKit's
    /// unbounded-text sense (`cellSize` / `cellSize(forBounds:)`).
    public struct Measurements: Sendable {
        public var titleHeight: CGFloat
        public var hintPasswordHeight: CGFloat
        public var hintKeyHeight: CGFloat
        public var websiteLabelSize: CGSize
        public var websiteLabelTextWidth: CGFloat
        public var websiteButtonSize: CGSize
        public var websiteButtonTextWidth: CGFloat

        public init(
            titleHeight: CGFloat, hintPasswordHeight: CGFloat, hintKeyHeight: CGFloat,
            websiteLabelSize: CGSize, websiteLabelTextWidth: CGFloat,
            websiteButtonSize: CGSize, websiteButtonTextWidth: CGFloat
        ) {
            self.titleHeight = titleHeight
            self.hintPasswordHeight = hintPasswordHeight
            self.hintKeyHeight = hintKeyHeight
            self.websiteLabelSize = websiteLabelSize
            self.websiteLabelTextWidth = websiteLabelTextWidth
            self.websiteButtonSize = websiteButtonSize
            self.websiteButtonTextWidth = websiteButtonTextWidth
        }
    }

    public struct Frames: Sendable {
        public var title: CGRect
        public var close: CGRect
        public var password: CGRect
        public var key: CGRect
        public var generate: CGRect
        public var length: CGRect
        public var lengthDivider: CGRect
        public var prefix: CGRect
        public var suffix: CGRect
        public var hintPassword: CGRect
        public var hintKey: CGRect
        public var websiteLabel: CGRect
        public var websiteButton: CGRect
    }

    /// Stacks the rows top-down from the panel's top edge, so the caller's
    /// view must be flipped.
    public static func place(width panelWidth: CGFloat, measurements: Measurements) -> Frames {
        let pad = Metrics.pad
        let spacing = Metrics.spacing
        let rowHeight = Metrics.rowHeight
        let width = panelWidth - pad * 2
        var y = pad

        let titleHeight = ceil(measurements.titleHeight)
        let title = CGRect(x: pad, y: y, width: width - Metrics.closeSize - 4, height: titleHeight)
        let close = CGRect(
            x: pad + width - Metrics.closeSize,
            y: y + (titleHeight - Metrics.closeSize) / 2,
            width: Metrics.closeSize, height: Metrics.closeSize)
        y += titleHeight + spacing

        let password = CGRect(x: pad, y: y, width: width, height: rowHeight)
        y += rowHeight + spacing
        let key = CGRect(x: pad, y: y, width: width, height: rowHeight)
        y += rowHeight + spacing

        let generateWidth = width - Metrics.lengthWidth
        let generate = CGRect(x: pad, y: y, width: generateWidth, height: rowHeight)
        let length = CGRect(
            x: pad + generateWidth, y: y, width: Metrics.lengthWidth, height: rowHeight)
        // Hairline divider between the button and the length select.
        let divider = CGRect(x: pad + generateWidth, y: y, width: 1, height: rowHeight)
        y += rowHeight + spacing

        let splitWidth = (width + Metrics.splitOverlap) / 2
        let prefix = CGRect(x: pad, y: y, width: splitWidth, height: rowHeight)
        let suffix = CGRect(
            x: pad + splitWidth - Metrics.splitOverlap, y: y, width: splitWidth, height: rowHeight)
        y += rowHeight + spacing

        let hintPassword = CGRect(
            x: pad, y: y, width: width, height: ceil(measurements.hintPasswordHeight))
        y += hintPassword.height + spacing
        let hintKey = CGRect(x: pad, y: y, width: width, height: ceil(measurements.hintKeyHeight))
        y += hintKey.height + spacing

        let labelSize = measurements.websiteLabelSize
        let buttonSize = measurements.websiteButtonSize
        // Both cells pad their text; align the link's title with where the
        // label's text ends, as if the two were one line of inline text.
        let labelTextEnd =
            (labelSize.width + measurements.websiteLabelTextWidth) / 2
        let linkPadding = (buttonSize.width - measurements.websiteButtonTextWidth) / 2
        let linkX = ceil(labelTextEnd - linkPadding)
        let websiteLabel = CGRect(
            x: pad, y: y, width: ceil(labelSize.width), height: ceil(labelSize.height))
        let websiteButton = CGRect(
            x: pad + linkX, y: y, width: min(ceil(buttonSize.width), width - linkX),
            height: ceil(labelSize.height))

        return Frames(
            title: title, close: close, password: password, key: key, generate: generate,
            length: length, lengthDivider: divider, prefix: prefix, suffix: suffix,
            hintPassword: hintPassword, hintKey: hintKey, websiteLabel: websiteLabel,
            websiteButton: websiteButton)
    }

    /// Vertically centers a single-line field inside its row, inset by `Metrics.fieldInset`.
    public static func fieldFrame(in container: CGRect, fieldHeight: CGFloat) -> CGRect {
        let height = ceil(fieldHeight)
        return CGRect(
            x: Metrics.fieldInset, y: (container.height - height) / 2,
            width: container.width - Metrics.fieldInset * 2, height: height)
    }
}
