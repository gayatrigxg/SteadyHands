import SwiftUI

struct ProgressCard: View {
    
    let title: String
    let value: Int
    let trend: Int
    let color: Color
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 10) {
            
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.textSecondary)
            
            Text("\(value)%")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.textPrimary)
            
            HStack(spacing: 4) {
                
                Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(trend >= 0 ? .metricGreen : .metricRed)
                
                Text("\(abs(trend))%")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(trend >= 0 ? .metricGreen : .metricRed)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 4)
    }
}
