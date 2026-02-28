import Foundation

struct SessionInsightGenerator {
    
    static func generate(
        stability: Int,
        tremor: Float,
        assist: Float,
        previousStability: Int?
    ) -> String {
        
        var insight = ""
        
        if let previous = previousStability {
            
            let delta = stability - previous
            
            if delta > 5 {
                insight = "Your stability improved noticeably this session."
            } else if delta < -5 {
                insight = "Today was a bit more challenging than your last session."
            } else {
                insight = "Your stability remained consistent compared to last time."
            }
            
        } else {
            insight = "This is your first recorded session."
        }
        
        if tremor < 0.2 {
            insight += " Tremor activity stayed minimal."
        } else if tremor < 0.4 {
            insight += " Mild tremor patterns were detected."
        } else {
            insight += " Higher tremor activity was detected."
        }
        
        if assist < 0.4 {
            insight += " You relied little on assist."
        } else if assist < 0.7 {
            insight += " Assist provided moderate support."
        } else {
            insight += " Assist was heavily engaged."
        }
        
        return insight
    }
}
