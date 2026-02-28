import Foundation
import PencilKit

class ShapeSnapManager: ObservableObject {
    
    @Published var pendingSuggestion: ShapeRecognizer.ShapeMatch?
    @Published var pendingStrokeIndex: Int?
    
    var hasPendingSuggestion: Bool {
        pendingSuggestion != nil
    }
    
    func evaluate(stroke: PKStroke, atIndex index: Int, enabled: Bool) {
        guard enabled else { return }
        
        if let match = ShapeRecognizer.recognize(from: stroke) {
            pendingSuggestion = match
            pendingStrokeIndex = index
        }
    }
    
    func acceptAndClear() {
        clear()
    }
    
    func clear() {
        pendingSuggestion = nil
        pendingStrokeIndex = nil
    }
}
