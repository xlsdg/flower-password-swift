import CoreGraphics

public enum PanelPlacement {
    /// Top-left origin (AppKit screen coordinates, y up) that keeps a panel
    /// inside `visible`. Right and bottom edges are applied first so the left
    /// and top clamps win when the work area is smaller than the panel.
    public static func clampedTopLeft(_ topLeft: CGPoint, size: CGSize, in visible: CGRect) -> CGPoint {
        var point = topLeft
        point.x = min(point.x, visible.maxX - size.width)
        point.y = max(point.y, visible.minY + size.height)
        point.x = max(point.x, visible.minX)
        point.y = min(point.y, visible.maxY)
        return point
    }
}
