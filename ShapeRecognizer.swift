import Foundation
import PencilKit

struct ShapeRecognizer {
    
    enum ShapeType {
        case line
        case circle
        
        var icon: String {
            switch self {
            case .line: return "minus"
            case .circle: return "circle"
            }
        }
        
        var displayName: String {
            switch self {
            case .line: return "Line"
            case .circle: return "Circle"
            }
        }
    }
    
    struct ShapeMatch {
        let type: ShapeType
        let correctedPath: PKStrokePath
    }
    
    static func recognize(from stroke: PKStroke) -> ShapeMatch? {
        let path = stroke.path
        let count = path.count
        guard count > 5 else { return nil }
        
        let first = path[0].location
        let last = path[count - 1].location
        
        let dx = last.x - first.x
        let dy = last.y - first.y
        let distance = hypot(dx, dy)
        
        // LINE DETECTION
        if distance > 40 {
            var maxDeviation: CGFloat = 0
            
            for i in 1..<(count - 1) {
                let point = path[i].location
                let deviation = perpendicularDistance(point, first, last)
                maxDeviation = max(maxDeviation, deviation)
            }
            
            if maxDeviation < 10 {
                return ShapeMatch(
                    type: .line,
                    correctedPath: makeStraightPath(from: path)
                )
            }
        }
        
        // CIRCLE DETECTION
        if hypot(first.x - last.x, first.y - last.y) < 25 {
            return ShapeMatch(
                type: .circle,
                correctedPath: makeCirclePath(from: path)
            )
        }
        
        return nil
    }
    
    static func perpendicularDistance(_ point: CGPoint, _ start: CGPoint, _ end: CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSq = dx * dx + dy * dy
        if lengthSq < 0.001 { return 0 }
        let t = ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSq
        let proj = CGPoint(x: start.x + t * dx, y: start.y + t * dy)
        return hypot(point.x - proj.x, point.y - proj.y)
    }
    
    static func makeStraightPath(from path: PKStrokePath) -> PKStrokePath {
        let first = path[0]
        let last = path[path.count - 1]
        
        return PKStrokePath(controlPoints: [first, last], creationDate: path.creationDate)
    }
    
    static func makeCirclePath(from path: PKStrokePath) -> PKStrokePath {
        let points = (0..<path.count).map { path[$0].location }
        
        let centerX = points.map { $0.x }.reduce(0, +) / CGFloat(points.count)
        let centerY = points.map { $0.y }.reduce(0, +) / CGFloat(points.count)
        let center = CGPoint(x: centerX, y: centerY)
        
        let radius = points.map { hypot($0.x - center.x, $0.y - center.y) }.reduce(0, +) / CGFloat(points.count)
        
        let circlePoints = stride(from: 0, through: 2 * CGFloat.pi, by: CGFloat.pi / 16).map { angle -> PKStrokePoint in
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)
            return PKStrokePoint(
                location: CGPoint(x: x, y: y),
                timeOffset: 0,
                size: path[0].size,
                opacity: path[0].opacity,
                force: path[0].force,
                azimuth: path[0].azimuth,
                altitude: path[0].altitude
            )
        }
        
        return PKStrokePath(controlPoints: circlePoints, creationDate: path.creationDate)
    }
}
