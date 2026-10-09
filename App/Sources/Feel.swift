import AVFoundation
import UIKit

/// Haptics and sound in one place. Every interaction in the app goes through here.
enum Feel {
    static var sound = true
    static var haptics = true

    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let note = UINotificationFeedbackGenerator()
    private static let select = UISelectionFeedbackGenerator()

    static func tap() {
        if haptics { light.impactOccurred(intensity: 0.7) }
        Synth.shared.play(.tap)
    }

    static func key() {
        if haptics { soft.impactOccurred(intensity: 0.8) }
        Synth.shared.play(.key)
    }

    static func tick() {
        if haptics { select.selectionChanged() }
    }

    static func flip() {
        if haptics { rigid.impactOccurred(intensity: 0.6) }
        Synth.shared.play(.flip)
    }

    static func correct(combo: Int = 0) {
        if haptics { rigid.impactOccurred(intensity: min(1, 0.55 + Double(combo) * 0.08)) }
        Synth.shared.play(.correct)
    }

    static func wrong() {
        if haptics { note.notificationOccurred(.error) }
        Synth.shared.play(.wrong)
    }

    static func capture() {
        if haptics {
            heavy.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { rigid.impactOccurred(intensity: 0.8) }
        }
        Synth.shared.play(.capture)
    }

    static func win() {
        if haptics {
            note.notificationOccurred(.success)
            for i in 1...3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15 * Double(i)) { heavy.impactOccurred(intensity: 1 - 0.2 * Double(i)) }
            }
        }
        Synth.shared.play(.win)
    }

    static func lose() {
        if haptics { note.notificationOccurred(.warning) }
        Synth.shared.play(.lose)
    }

    /// Heartbeat when the opponent is close to the finish.
    static func pressure() {
        if haptics { heavy.impactOccurred(intensity: 0.5) }
    }
}

/// Small sine synth: effects are pre-rendered once and played through a pool of nodes.
final class Synth {
    static let shared = Synth()

    enum Sfx: CaseIterable { case tap, key, flip, correct, wrong, capture, win, lose }

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var next = 0
    private let rate: Double = 44_100
    private let format: AVAudioFormat
    private var buffers: [Sfx: AVAudioPCMBuffer] = [:]

    private init() {
        format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)!
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        for _ in 0..<6 {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: engine.mainMixerNode, format: format)
            players.append(p)
        }
        for s in Sfx.allCases { buffers[s] = render(s) }
        NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            self?.start()
        }
    }

    private func start() {
        if !engine.isRunning { try? engine.start() }
        guard engine.isRunning else { return }
        players.forEach { if !$0.isPlaying { $0.play() } }
    }

    func play(_ s: Sfx) {
        guard Feel.sound, let buf = buffers[s] else { return }
        start()
        guard engine.isRunning else { return }
        let p = players[next]
        next = (next + 1) % players.count
        p.scheduleBuffer(buf, at: nil, options: .interrupts)
        if !p.isPlaying { p.play() }
    }

    private struct Note { var f: Double; var at: Double; var dur: Double; var vol: Double; var glide = 1.0 }

    private func notes(_ s: Sfx) -> [Note] {
        switch s {
        case .tap: [Note(f: 1200, at: 0, dur: 0.035, vol: 0.06)]
        case .key: [Note(f: 900, at: 0, dur: 0.04, vol: 0.07, glide: 0.8)]
        case .flip: [Note(f: 500, at: 0, dur: 0.12, vol: 0.08, glide: 1.8)]
        case .correct: [Note(f: 784, at: 0, dur: 0.12, vol: 0.16), Note(f: 1175, at: 0.07, dur: 0.22, vol: 0.16)]
        case .wrong: [Note(f: 220, at: 0, dur: 0.22, vol: 0.2, glide: 0.7)]
        case .capture: [Note(f: 659, at: 0, dur: 0.12, vol: 0.14), Note(f: 880, at: 0.08, dur: 0.12, vol: 0.14),
                        Note(f: 1319, at: 0.16, dur: 0.35, vol: 0.16)]
        case .win: [Note(f: 523, at: 0, dur: 0.14, vol: 0.15), Note(f: 659, at: 0.12, dur: 0.14, vol: 0.15),
                    Note(f: 784, at: 0.24, dur: 0.14, vol: 0.15), Note(f: 1047, at: 0.36, dur: 0.5, vol: 0.18)]
        case .lose: [Note(f: 392, at: 0, dur: 0.2, vol: 0.14), Note(f: 311, at: 0.18, dur: 0.4, vol: 0.14, glide: 0.9)]
        }
    }

    private func render(_ s: Sfx) -> AVAudioPCMBuffer {
        let ns = notes(s)
        let total = (ns.map { $0.at + $0.dur }.max() ?? 0.1) + 0.02
        let frames = AVAudioFrameCount(total * rate)
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buf.frameLength = frames
        let out = buf.floatChannelData![0]
        for i in 0..<Int(frames) { out[i] = 0 }
        for n in ns {
            let s0 = Int(n.at * rate), len = Int(n.dur * rate)
            var phase = 0.0
            for k in 0..<len where s0 + k < Int(frames) {
                let t = Double(k) / Double(len)
                phase += 2 * .pi * n.f * pow(n.glide, t) / rate
                let env = min(1, Double(k) / (0.004 * rate)) * exp(-5 * t)
                // a touch of the octave makes it sound like a soft marimba
                out[s0 + k] += Float((sin(phase) + 0.25 * sin(2 * phase)) * n.vol * env)
            }
        }
        return buf
    }
}
