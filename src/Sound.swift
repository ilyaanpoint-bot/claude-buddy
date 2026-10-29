// Tiny synthesizer: every buddy sound is generated on the fly, no audio files.

import AVFoundation

final class Synth {
    static let shared = Synth()

    enum Wave { case sine, square, triangle, noise }

    struct Note {
        var f0: Double
        var f1: Double
        var dur: Double
        var wave: Wave = .sine
        var vol: Double = 0.45
        var gap: Double = 0
    }

    var muted = UserDefaults.standard.bool(forKey: "muted") {
        didSet { UserDefaults.standard.set(muted, forKey: "muted") }
    }

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!

    private init() {
        for _ in 0..<6 {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: engine.mainMixerNode, format: format)
            players.append(p)
        }
        engine.mainMixerNode.outputVolume = 0.45
        try? engine.start()
    }

    func play(_ notes: [Note]) {
        guard !muted, !notes.isEmpty else { return }
        if !engine.isRunning { try? engine.start() }
        let sr = 44100.0
        let total = notes.reduce(0) { $0 + $1.dur + $1.gap }
        let frames = AVAudioFrameCount(total * sr) + 1
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames), let out = buf.floatChannelData?[0] else { return }
        buf.frameLength = frames
        var i = 0
        for n in notes {
            let count = Int(n.dur * sr)
            var phase = 0.0
            for k in 0..<count {
                let x = Double(k) / Double(count)
                phase += (n.f0 + (n.f1 - n.f0) * x) / sr
                let p = phase - floor(phase)
                let s: Double
                switch n.wave {
                case .sine: s = sin(2 * .pi * p)
                case .square: s = p < 0.5 ? 0.55 : -0.55
                case .triangle: s = 4 * abs(p - 0.5) - 1
                case .noise: s = Double.random(in: -1...1)
                }
                let env = min(1, x * 25) * pow(1 - x, 1.4)
                out[i] = Float(s * env * n.vol)
                i += 1
            }
            for _ in 0..<Int(n.gap * sr) { out[i] = 0; i += 1 }
        }
        while i < Int(frames) { out[i] = 0; i += 1 }
        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        player.scheduleBuffer(buf, at: nil, options: .interrupts)
        player.play()
    }

    private func arp(_ freqs: [Double], dur: Double, wave: Wave = .triangle, vol: Double = 0.4, last: Double? = nil) -> [Note] {
        freqs.enumerated().map { i, f in
            Note(f0: f, f1: f, dur: i == freqs.count - 1 ? (last ?? dur) : dur, wave: wave, vol: vol)
        }
    }

    // MARK: The buddy's voice and effects

    func chirp(pitch: Double = 1) { play([Note(f0: 700 * pitch, f1: 1300 * pitch, dur: 0.09)]) }

    func giggle(pitch: Double = 1) {
        play([900, 1000, 1150].map { Note(f0: $0 * pitch, f1: $0 * 1.3 * pitch, dur: 0.06, gap: 0.025) })
    }

    /// Animal-Crossing-style babble, one blip per few letters.
    func babble(_ text: String, pitch: Double = 1) {
        let n = max(2, min(9, text.count / 3))
        play((0..<n).map { _ in
            let f = 380 * pitch * Double.random(in: 0.85...1.25)
            return Note(f0: f, f1: f * Double.random(in: 0.9...1.15), dur: 0.05, wave: .square, vol: 0.13, gap: 0.022)
        })
    }

    func done(pitch: Double = 1) { play(arp([523, 659, 784, 1047].map { $0 * pitch }, dur: 0.09, last: 0.3)) }

    func levelUp() {
        play(arp([523, 659, 784, 1047, 1319, 1568], dur: 0.07, wave: .square, vol: 0.18)
             + [Note(f0: 2093, f1: 2093, dur: 0.45, wave: .triangle, vol: 0.35)])
    }

    func unlock() { play(arp([1568, 2093, 2637], dur: 0.06, vol: 0.3, last: 0.25)) }

    func chomp() {
        play((0..<3).flatMap { _ in [Note(f0: 220, f1: 140, dur: 0.05, wave: .noise, vol: 0.25),
                                     Note(f0: 180, f1: 120, dur: 0.04, wave: .sine, vol: 0.3, gap: 0.06)] })
    }

    func dizzy() {
        play([Note(f0: 900, f1: 500, dur: 0.18, wave: .triangle), Note(f0: 750, f1: 420, dur: 0.18, wave: .triangle),
              Note(f0: 620, f1: 300, dur: 0.3, wave: .triangle)])
    }

    func boop() {
        play([Note(f0: 660, f1: 660, dur: 0.12, wave: .square, vol: 0.2, gap: 0.05),
              Note(f0: 520, f1: 520, dur: 0.16, wave: .square, vol: 0.2)])
    }

    func grumble() {
        play([Note(f0: 230, f1: 190, dur: 0.14, wave: .square, vol: 0.12, gap: 0.04),
              Note(f0: 210, f1: 160, dur: 0.2, wave: .square, vol: 0.12)])
    }

    func yawn() { play([Note(f0: 500, f1: 260, dur: 0.6, wave: .sine, vol: 0.25)]) }
    func pop() { play([Note(f0: 380, f1: 950, dur: 0.05, vol: 0.35)]) }
    func whee() { play([Note(f0: 500, f1: 1600, dur: 0.35, wave: .triangle, vol: 0.3)]) }
    func scream() { play([Note(f0: 1400, f1: 1900, dur: 0.12, wave: .square, vol: 0.15), Note(f0: 1900, f1: 900, dur: 0.3, wave: .square, vol: 0.15)]) }
    func catchBug(golden: Bool) { play([Note(f0: golden ? 1200 : 800, f1: golden ? 2400 : 1400, dur: 0.07, wave: .square, vol: 0.15)]) }
    func ouch() { play([Note(f0: 300, f1: 120, dur: 0.18, wave: .square, vol: 0.18)]) }
    func gameOver() { play(arp([784, 659, 523, 392], dur: 0.12, last: 0.35)) }
    func meow() { play([Note(f0: 700, f1: 1100, dur: 0.12, wave: .triangle, vol: 0.25), Note(f0: 1100, f1: 600, dur: 0.22, wave: .triangle, vol: 0.25)]) }
}
