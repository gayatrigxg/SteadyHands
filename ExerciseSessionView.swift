import SwiftUI
import PencilKit

struct ExerciseSessionView: View {
    
    let exerciseName: String
    let duration: Int
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var settings: AppSettings
    
    @State private var canvasView = PKCanvasView()
    
    @State private var timeRemaining: Int = 0
    @State private var timer: Timer?
    
    @State private var strokesDrawn: Int = 0
    
    // Adaptive Assist
    @State private var adaptiveAssistLevel: CGFloat = 0.5
    @State private var tremorDetected: Bool = false
    @State private var tremorSeverity: Float = 0
    
    // Session Samples
    @State private var tremorSamples: [Float] = []
    @State private var frequencySamples: [Float] = []
    @State private var assistSamples: [Float] = []
    
    var body: some View {
        
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                header
                
                ZStack {
                    
                    SteadyCanvas(
                        canvasView: $canvasView,
                        smoothingEnabled: settings.smoothingEnabled,
                        shapeRecognitionEnabled: false,
                        snapManager: ShapeSnapManager(),
                        assistLevel: adaptiveAssistLevel,
                        showGhostOverlay: true,
                        showToolPicker: true,      // ✅ ADD THIS
                        onStrokeAdded: handleStroke
                    )

                    .background(Color.white)
                    .cornerRadius(20)
                    
                    tremorOverlay
                }
                .padding(20)
            }
        }
        .onAppear {
            timeRemaining = duration
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    // MARK: Header
    
    private var header: some View {
        HStack {
            
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Text(exerciseName)
                .font(.system(size: 16, weight: .semibold))
            
            Spacer()
            
            Text("\(timeRemaining)s")
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundColor(timeRemaining <= 5 ? .red : .gray)
        }
        .padding(.horizontal, 20)
        .padding(.top, 50)
        .padding(.bottom, 10)
    }
    
    // MARK: Tremor Overlay
    
    private var tremorOverlay: some View {
        VStack {
            Spacer()
            
            HStack {
                
                if tremorDetected {
                    Label(
                        "Tremor \(Int(tremorSeverity * 100))%",
                        systemImage: "waveform.path.ecg"
                    )
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(10)
                }
                
                Spacer()
                
                Label(
                    "Assist \(Int(adaptiveAssistLevel * 100))%",
                    systemImage: "slider.horizontal.3"
                )
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.purple.opacity(0.15))
                .cornerRadius(10)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: Stroke Handling
    
    private func handleStroke() {
        
        strokesDrawn += 1
        
        guard let stroke = canvasView.drawing.strokes.last else { return }
        guard let result = TremorAnalyzer.analyze(stroke: stroke) else { return }
        
        tremorDetected = result.isTremorDetected
        tremorSeverity = result.tremorStrength
        
        tremorSamples.append(result.tremorStrength)
        frequencySamples.append(result.dominantFrequency)
        assistSamples.append(Float(adaptiveAssistLevel))
        
        adjustAssist(basedOn: result)
    }
    
    // MARK: Adaptive Assist
    
    private func adjustAssist(basedOn result: TremorAnalysisResult) {
        
        if result.isTremorDetected {
            let boost = CGFloat(min(result.tremorStrength * 2, 0.4))
            adaptiveAssistLevel = min(1.0, adaptiveAssistLevel + boost)
        } else {
            adaptiveAssistLevel = max(0.2, adaptiveAssistLevel - 0.05)
        }
    }
    
    // MARK: Timer (FIXED FOR SWIFT 6)
    
    private func startTimer() {
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            
            DispatchQueue.main.async {
                
                if timeRemaining > 0 {
                    timeRemaining -= 1
                } else {
                    finishSession()
                }
            }
        }
    }
    
    // MARK: Finish Session
    
    private func finishSession() {
        
        timer?.invalidate()
        
        let avgTremor = tremorSamples.isEmpty ? 0 :
            tremorSamples.reduce(0, +) / Float(tremorSamples.count)
        
        let avgFreq = frequencySamples.isEmpty ? 0 :
            frequencySamples.reduce(0, +) / Float(frequencySamples.count)
        
        let avgAssist = assistSamples.isEmpty ? 0 :
            assistSamples.reduce(0, +) / Float(assistSamples.count)
        
        let stabilityScore = Int(max(0, min(100, 100 - avgTremor * 100)))
        
        let session = DrawingSession(
            date: Date(),
            strokeCount: strokesDrawn,
            avgStability: stabilityScore,
            avgPressure: 50,
            avgRhythm: 50,
            avgTremorStrength: avgTremor,
            avgDominantFrequency: avgFreq,
            avgAssistUsed: avgAssist
        )
        
        settings.sessions.insert(session, at: 0)
        settings.totalStrokes += strokesDrawn
        
        dismiss()
    }

}
