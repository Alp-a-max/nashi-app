import Foundation

/// Pure screen metrics let the notch panel be placed consistently and tested without AppKit.
public struct NotchScreenMetrics {
    public let frame: CGRect
    public let visibleFrame: CGRect
    public let safeAreaTop: CGFloat
    public let auxiliaryTopLeftArea: CGRect?
    public let auxiliaryTopRightArea: CGRect?

    public init(frame: CGRect, visibleFrame: CGRect, safeAreaTop: CGFloat,
                auxiliaryTopLeftArea: CGRect?, auxiliaryTopRightArea: CGRect?) {
        self.frame=frame
        self.visibleFrame=visibleFrame
        self.safeAreaTop=safeAreaTop
        self.auxiliaryTopLeftArea=auxiliaryTopLeftArea
        self.auxiliaryTopRightArea=auxiliaryTopRightArea
    }
}

public struct NotchPanelPlacement: Equatable {
    public let frame: CGRect
    public let isNotched: Bool
    public let notchWidth: CGFloat
}

public enum NotchPanelGeometry {
    /// A notched Mac anchors the panel to the bottom of its camera housing. Other displays
    /// use the visible-frame top, which sits just below the menu bar.
    public static func placement(on screen: NotchScreenMetrics, size: CGSize,
                                 fallbackTopInset: CGFloat = 6) -> NotchPanelPlacement {
        let left=screen.auxiliaryTopLeftArea
        let right=screen.auxiliaryTopRightArea
        let validLeft=left.map(isUsable) ?? false
        let validRight=right.map(isUsable) ?? false
        let gap: CGFloat
        if let left, let right, validLeft, validRight, screen.safeAreaTop > 0, right.minX > left.maxX {
            gap=right.minX-left.maxX
        } else {
            gap=0
        }
        let isNotched=gap > 0
        let width=min(max(1,size.width),max(1,screen.frame.width-16))
        let height=max(1,size.height)
        let top=isNotched ? screen.frame.maxY-screen.safeAreaTop : screen.visibleFrame.maxY-max(0,fallbackTopInset)
        let frame=CGRect(x:screen.frame.midX-width/2,y:top-height,width:width,height:height)
        return NotchPanelPlacement(frame:frame,isNotched:isNotched,notchWidth:gap)
    }

    private static func isUsable(_ rect: CGRect) -> Bool {
        !rect.isNull && !rect.isInfinite && rect.width.isFinite && rect.height.isFinite && rect.width > 0 && rect.height > 0
    }
}

/// State shared by the AppKit panel and pure tests. The caller applies the 250 ms delay;
/// this value decides whether the delayed collapse is still valid when it fires.
public enum NotchInteractionPolicy {
    public static let collapseDelayMilliseconds=250
}

public struct NotchInteractionState: Equatable {
    public private(set) var isExpanded=false
    public private(set) var pointerInside=false
    public private(set) var dragging=false

    public init() {}
    public var mayCollapse: Bool { !pointerInside && !dragging }

    public mutating func expand() { isExpanded=true }

    public mutating func collapse() { isExpanded=false }

    public mutating func pointerEntered() {
        pointerInside=true
        isExpanded=true
    }

    public mutating func pointerExited() { pointerInside=false }

    public mutating func draggingEntered() {
        dragging=true
        isExpanded=true
    }

    public mutating func draggingEnded() { dragging=false }

    public mutating func collapseIfAllowed() -> Bool {
        guard mayCollapse else { return false }
        isExpanded=false
        return true
    }
}

public enum NotchDropShelfTargets {
    /// Keep format chips identical to the existing conversion wheel's compatibility rules.
    public static func formats(for input: URL) -> [String] {
        FeatureCatalog.formats(for:[input])
    }
}
