import Foundation
import PencilKit
import UIKit

// MARK: - Demo Artwork Seeder
// Seeds two hand-crafted PKDrawing artworks into GalleryStore on first launch.
// Triggered from GalleryStore.seedDemoArtworksIfNeeded().

enum DemoArtworkSeeder {

    static func seed(into gallery: GalleryStore) {
        let key = "demoArtworksSeeded_v2"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        // Insert oldest first so newest appears at front
        let mountain = makeMountainScenery()
        let tree     = makeAbstractTree()

        // Append in reverse order so they display left→right as: mountain, tree
        gallery.save(tree)
        gallery.save(mountain)
    }

    // MARK: - Drawing 1: Mountain Scenery at Dusk

    private static func makeMountainScenery() -> SavedArtwork {
        var strokes: [PKStroke] = []

        // Sky gradient bands — soft horizontal sweeps
        let skyColors: [(UIColor, CGFloat)] = [
            (UIColor(red: 0.15, green: 0.08, blue: 0.25, alpha: 0.85), 20),
            (UIColor(red: 0.30, green: 0.12, blue: 0.40, alpha: 0.75), 50),
            (UIColor(red: 0.55, green: 0.22, blue: 0.45, alpha: 0.65), 80),
            (UIColor(red: 0.85, green: 0.40, blue: 0.30, alpha: 0.60), 110),
            (UIColor(red: 0.96, green: 0.65, blue: 0.25, alpha: 0.55), 135),
        ]
        for (color, yPos) in skyColors {
            strokes.append(horizontalBand(y: yPos, width: 640, color: color, lineWidth: 40))
        }

        // Moon — small circle top right
        strokes.append(circle(cx: 540, cy: 55, radius: 22,
                               color: UIColor(red: 0.97, green: 0.95, blue: 0.82, alpha: 0.95),
                               lineWidth: 44))

        // Back mountain range — large, dark purple
        strokes.append(mountainSilhouette(
            points: [(0, 300), (80, 190), (160, 240), (240, 140), (330, 200),
                     (420, 120), (500, 175), (580, 200), (640, 260), (640, 340), (0, 340)],
            color: UIColor(red: 0.18, green: 0.10, blue: 0.28, alpha: 0.92),
            lineWidth: 3))

        // Mid mountain — slightly lighter
        strokes.append(mountainSilhouette(
            points: [(0, 330), (60, 255), (140, 290), (220, 210), (300, 260),
                     (380, 195), (460, 240), (540, 215), (620, 270), (640, 300), (640, 360), (0, 360)],
            color: UIColor(red: 0.22, green: 0.14, blue: 0.35, alpha: 0.88),
            lineWidth: 3))

        // Foreground ridge — darkest
        strokes.append(mountainSilhouette(
            points: [(0, 370), (100, 310), (200, 340), (300, 295), (400, 330),
                     (500, 305), (600, 340), (640, 360), (640, 420), (0, 420)],
            color: UIColor(red: 0.10, green: 0.07, blue: 0.18, alpha: 0.95),
            lineWidth: 3))

        // Ground / dark valley fill
        strokes.append(rect(x: 0, y: 390, width: 640, height: 100,
                             color: UIColor(red: 0.07, green: 0.05, blue: 0.12, alpha: 1.0),
                             lineWidth: 110))

        // Reflection pool — horizontal shimmer strokes
        let shimmerColors: [UIColor] = [
            UIColor(red: 0.85, green: 0.40, blue: 0.30, alpha: 0.35),
            UIColor(red: 0.55, green: 0.22, blue: 0.45, alpha: 0.25),
            UIColor(red: 0.96, green: 0.65, blue: 0.25, alpha: 0.20),
        ]
        for (i, c) in shimmerColors.enumerated() {
            let y = 415.0 + CGFloat(i) * 8
            strokes.append(horizontalBand(y: y, width: 320, color: c, lineWidth: 4, offsetX: 160))
        }

        // Stars — tiny bright dots scattered in sky
        let starPositions: [(CGFloat, CGFloat)] = [
            (45, 25), (130, 18), (200, 38), (290, 15), (370, 28),
            (460, 20), (510, 42), (600, 16), (88, 55), (320, 48)
        ]
        for (sx, sy) in starPositions {
            strokes.append(dot(cx: sx, cy: sy, radius: 2.5,
                               color: UIColor(red: 1, green: 0.97, blue: 0.88, alpha: 0.9)))
        }

        // Pine trees silhouette foreground left
        for i in 0..<5 {
            let bx = CGFloat(30 + i * 28)
            strokes.append(pineTree(baseX: bx, baseY: 400, height: CGFloat(55 + i % 2 * 12),
                                    color: UIColor(red: 0.06, green: 0.04, blue: 0.10, alpha: 1.0)))
        }
        // Pine trees right
        for i in 0..<4 {
            let bx = CGFloat(500 + i * 32)
            strokes.append(pineTree(baseX: bx, baseY: 400, height: CGFloat(50 + i % 2 * 15),
                                    color: UIColor(red: 0.06, green: 0.04, blue: 0.10, alpha: 1.0)))
        }

        let drawing = PKDrawing(strokes: strokes)
        return SavedArtwork(
            title: "Dusk Over the Range",
            date: Date().addingTimeInterval(-86400 * 3),
            stabilityScore: 91,
            pressureScore: 88,
            rhythmScore: 85,
            strokeCount: strokes.count,
            drawing: drawing
        )
    }

    // MARK: - Drawing 2: Abstract Ink Tree

    private static func makeAbstractTree() -> SavedArtwork {
        var strokes: [PKStroke] = []

        // Background wash — warm cream
        strokes.append(rect(x: 0, y: 0, width: 640, height: 480,
                             color: UIColor(red: 0.97, green: 0.94, blue: 0.87, alpha: 1.0),
                             lineWidth: 520))

        // Subtle background fog circles
        for (cx, cy, r, a) in [(320.0, 240.0, 180.0, 0.07),
                                (200.0, 300.0, 120.0, 0.05),
                                (450.0, 200.0, 100.0, 0.04)] as [(CGFloat,CGFloat,CGFloat,CGFloat)] {
            strokes.append(circle(cx: cx, cy: cy, radius: r,
                                   color: UIColor(red: 0.75, green: 0.62, blue: 0.48, alpha: a),
                                   lineWidth: r * 2.1))
        }

        // Ground shadow
        strokes.append(horizontalBand(y: 410, width: 260, color: UIColor(red: 0.55, green: 0.38, blue: 0.22, alpha: 0.12),
                                       lineWidth: 28, offsetX: 190))

        // Main trunk — thick, dark ink, tapers upward
        let trunkPoints: [(CGFloat, CGFloat)] = [
            (310, 420), (312, 380), (316, 330), (318, 285),
            (315, 240), (312, 200), (310, 160)
        ]
        strokes.append(inkStroke(points: trunkPoints,
                                  color: UIColor(red: 0.13, green: 0.09, blue: 0.05, alpha: 0.95),
                                  startWidth: 18, endWidth: 7))

        // Left main branch
        strokes.append(inkStroke(
            points: [(315, 240), (280, 215), (248, 195), (220, 178), (195, 162)],
            color: UIColor(red: 0.16, green: 0.11, blue: 0.06, alpha: 0.90),
            startWidth: 9, endWidth: 4))

        // Right main branch
        strokes.append(inkStroke(
            points: [(313, 220), (345, 198), (375, 182), (405, 168), (435, 158)],
            color: UIColor(red: 0.16, green: 0.11, blue: 0.06, alpha: 0.90),
            startWidth: 9, endWidth: 4))

        // Upper left branch
        strokes.append(inkStroke(
            points: [(312, 195), (290, 172), (270, 155), (250, 140)],
            color: UIColor(red: 0.18, green: 0.12, blue: 0.07, alpha: 0.85),
            startWidth: 6, endWidth: 3))

        // Upper right branch
        strokes.append(inkStroke(
            points: [(311, 185), (335, 162), (358, 145), (380, 132)],
            color: UIColor(red: 0.18, green: 0.12, blue: 0.07, alpha: 0.85),
            startWidth: 6, endWidth: 3))

        // Crown foliage — ink splatters / loose clusters
        let foliageClusters: [(CGFloat, CGFloat, CGFloat, UIColor)] = [
            (310, 140, 48, UIColor(red: 0.12, green: 0.30, blue: 0.14, alpha: 0.82)),
            (270, 155, 38, UIColor(red: 0.15, green: 0.35, blue: 0.16, alpha: 0.75)),
            (355, 148, 40, UIColor(red: 0.10, green: 0.28, blue: 0.12, alpha: 0.78)),
            (235, 175, 30, UIColor(red: 0.18, green: 0.38, blue: 0.18, alpha: 0.65)),
            (395, 162, 32, UIColor(red: 0.13, green: 0.32, blue: 0.14, alpha: 0.70)),
            (295, 120, 28, UIColor(red: 0.10, green: 0.26, blue: 0.12, alpha: 0.72)),
            (330, 115, 26, UIColor(red: 0.14, green: 0.33, blue: 0.15, alpha: 0.68)),
            (250, 142, 22, UIColor(red: 0.16, green: 0.36, blue: 0.16, alpha: 0.60)),
            (375, 135, 24, UIColor(red: 0.12, green: 0.30, blue: 0.13, alpha: 0.65)),
            (318, 100, 20, UIColor(red: 0.09, green: 0.24, blue: 0.11, alpha: 0.70)),
        ]
        for (cx, cy, r, color) in foliageClusters {
            strokes.append(circle(cx: cx, cy: cy, radius: r, color: color, lineWidth: r * 2.2))
        }

        // Fallen leaves on ground — small ellipse dots
        let leafData: [(CGFloat, CGFloat, UIColor)] = [
            (230, 418, UIColor(red: 0.72, green: 0.35, blue: 0.12, alpha: 0.75)),
            (270, 422, UIColor(red: 0.65, green: 0.42, blue: 0.15, alpha: 0.65)),
            (355, 415, UIColor(red: 0.68, green: 0.30, blue: 0.10, alpha: 0.70)),
            (390, 420, UIColor(red: 0.75, green: 0.45, blue: 0.18, alpha: 0.60)),
            (420, 416, UIColor(red: 0.60, green: 0.28, blue: 0.08, alpha: 0.72)),
            (210, 425, UIColor(red: 0.55, green: 0.38, blue: 0.12, alpha: 0.55)),
        ]
        for (lx, ly, lc) in leafData {
            strokes.append(dot(cx: lx, cy: ly, radius: 5, color: lc))
        }

        // Ink drips — thin vertical lines below some branches (artistic detail)
        for (dx, dy) in [(220.0, 195.0), (435.0, 168.0), (380.0, 138.0)] as [(CGFloat,CGFloat)] {
            strokes.append(inkStroke(
                points: [(dx, dy), (dx + 2, dy + 18), (dx + 1, dy + 32)],
                color: UIColor(red: 0.12, green: 0.09, blue: 0.06, alpha: 0.30),
                startWidth: 2, endWidth: 1))
        }

        // Artist seal — small red circle bottom right (traditional ink art touch)
        strokes.append(circle(cx: 560, cy: 440, radius: 12,
                               color: UIColor(red: 0.78, green: 0.12, blue: 0.08, alpha: 0.85),
                               lineWidth: 24))

        let drawing = PKDrawing(strokes: strokes)
        return SavedArtwork(
            title: "Ink Tree No. 7",
            date: Date().addingTimeInterval(-86400),
            stabilityScore: 87,
            pressureScore: 92,
            rhythmScore: 89,
            strokeCount: strokes.count,
            drawing: drawing
        )
    }

    // MARK: - Stroke Builders

    private static func makeInk(_ color: UIColor, width: CGFloat = 6) -> PKInk {
        PKInk(.pen, color: color)
    }

    private static func horizontalBand(y: CGFloat, width: CGFloat, color: UIColor,
                                        lineWidth: CGFloat, offsetX: CGFloat = 0) -> PKStroke {
        let pts = [
            PKStrokePoint(location: CGPoint(x: offsetX, y: y), timeOffset: 0,
                          size: CGSize(width: lineWidth, height: lineWidth),
                          opacity: 1, force: 1, azimuth: 0, altitude: 0.5),
            PKStrokePoint(location: CGPoint(x: offsetX + width, y: y), timeOffset: 0.1,
                          size: CGSize(width: lineWidth, height: lineWidth),
                          opacity: 1, force: 1, azimuth: 0, altitude: 0.5),
        ]
        return PKStroke(ink: makeInk(color, width: lineWidth),
                        path: PKStrokePath(controlPoints: pts, creationDate: Date()))
    }

    private static func rect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat,
                               color: UIColor, lineWidth: CGFloat) -> PKStroke {
        horizontalBand(y: y + height / 2, width: width, color: color, lineWidth: lineWidth, offsetX: x)
    }

    private static func circle(cx: CGFloat, cy: CGFloat, radius: CGFloat,
                                 color: UIColor, lineWidth: CGFloat) -> PKStroke {
        let steps = max(24, Int(radius * 2))
        var pts: [PKStrokePoint] = []
        for i in 0...steps {
            let angle = CGFloat(i) / CGFloat(steps) * .pi * 2
            let px = cx + cos(angle) * radius
            let py = cy + sin(angle) * radius
            pts.append(PKStrokePoint(
                location: CGPoint(x: px, y: py), timeOffset: Double(i) * 0.01,
                size: CGSize(width: lineWidth, height: lineWidth),
                opacity: 1, force: 1, azimuth: 0, altitude: 0.5))
        }
        return PKStroke(ink: makeInk(color, width: lineWidth),
                        path: PKStrokePath(controlPoints: pts, creationDate: Date()))
    }

    private static func dot(cx: CGFloat, cy: CGFloat, radius: CGFloat, color: UIColor) -> PKStroke {
        circle(cx: cx, cy: cy, radius: radius, color: color, lineWidth: radius * 2)
    }

    private static func mountainSilhouette(points: [(CGFloat, CGFloat)],
                                             color: UIColor, lineWidth: CGFloat) -> PKStroke {
        let pts = points.enumerated().map { i, p in
            PKStrokePoint(location: CGPoint(x: p.0, y: p.1), timeOffset: Double(i) * 0.05,
                          size: CGSize(width: lineWidth, height: lineWidth),
                          opacity: 1, force: 1, azimuth: 0, altitude: 0.5)
        }
        return PKStroke(ink: makeInk(color, width: lineWidth),
                        path: PKStrokePath(controlPoints: pts, creationDate: Date()))
    }

    private static func inkStroke(points: [(CGFloat, CGFloat)], color: UIColor,
                                   startWidth: CGFloat, endWidth: CGFloat) -> PKStroke {
        let count = points.count
        let pts = points.enumerated().map { i, p in
            let t = count > 1 ? CGFloat(i) / CGFloat(count - 1) : 0
            let w = startWidth + (endWidth - startWidth) * t
            return PKStrokePoint(
                location: CGPoint(x: p.0, y: p.1), timeOffset: Double(i) * 0.05,
                size: CGSize(width: w, height: w),
                opacity: 1, force: 1, azimuth: 0, altitude: 0.5)
        }
        return PKStroke(ink: makeInk(color, width: startWidth),
                        path: PKStrokePath(controlPoints: pts, creationDate: Date()))
    }

    private static func pineTree(baseX: CGFloat, baseY: CGFloat, height: CGFloat,
                                   color: UIColor) -> PKStroke {
        // Simple triangle outline for a pine silhouette
        let tip = (baseX, baseY - height)
        let bl  = (baseX - height * 0.28, baseY)
        let br  = (baseX + height * 0.28, baseY)
        let pts = [tip, bl, br, tip].enumerated().map { i, p in
            PKStrokePoint(location: CGPoint(x: p.0, y: p.1), timeOffset: Double(i) * 0.05,
                          size: CGSize(width: height * 0.56, height: height * 0.56),
                          opacity: 1, force: 1, azimuth: 0, altitude: 0.5)
        }
        return PKStroke(ink: makeInk(color, width: height * 0.56),
                        path: PKStrokePath(controlPoints: pts, creationDate: Date()))
    }
}
