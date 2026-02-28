import SwiftUI
import PencilKit

struct TremorHeatmapOverlay: View {
    
    let stroke: PKStroke?
    
    var body: some View {
        
        Canvas { context, size in
            
            guard let stroke = stroke else { return }
            
            let path = stroke.path
            guard path.count > 4 else { return }
            
            let points = (0..<path.count).map { path[$0].location }
            
            for i in 2..<(points.count - 2) {
                
                let prev = points[i - 2]
                let next = points[i + 2]
                let current = points[i]
                
                let deviation = MotorAnalysisEngine.perpendicularDistance(
                    point: current,
                    lineStart: prev,
                    lineEnd: next
                )
                
                let intensity = min(1.0, deviation / 8.0)
                
                let heatColor = Color.red.opacity(Double(intensity) * 0.6)
                
                let circle = Path(
                    ellipseIn: CGRect(
                        x: current.x - 6,
                        y: current.y - 6,
                        width: 12,
                        height: 12
                    )
                )
                
                context.fill(circle, with: .color(heatColor))
            }
        }
        .allowsHitTesting(false)
    }
}
