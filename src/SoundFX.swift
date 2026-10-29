// More of buddy's voice: tantrums, explosions, tummy trouble and game tones.

import Foundation

extension Synth {
    func growl() {
        play([Note(f0: 140, f1: 110, dur: 0.35, wave: .square, vol: 0.16), Note(f0: 120, f1: 90, dur: 0.3, wave: .square, vol: 0.16)])
    }

    func devilLaugh() {
        play((0..<5).map { k in
            let f = 520 - Double(k) * 40
            return Note(f0: f, f1: f * 0.8, dur: 0.11, wave: .square, vol: 0.18, gap: 0.05)
        } + [Note(f0: 300, f1: 160, dur: 0.4, wave: .square, vol: 0.18)])
    }

    func transform() {
        play([Note(f0: 200, f1: 900, dur: 0.5, wave: .triangle, vol: 0.3), Note(f0: 90, f1: 60, dur: 0.6, wave: .square, vol: 0.2)])
    }

    func fuse() { play([Note(f0: 3000, f1: 2500, dur: 0.25, wave: .noise, vol: 0.06)]) }

    func boom(big: Bool = false) {
        play([Note(f0: 90, f1: 30, dur: big ? 0.9 : 0.6, wave: .noise, vol: big ? 0.6 : 0.45),
              Note(f0: 70, f1: 25, dur: 0.01, wave: .sine, vol: 0)])
        play([Note(f0: 120, f1: 35, dur: big ? 0.8 : 0.5, wave: .sine, vol: 0.55)])
    }

    func fizzle() { play([Note(f0: 1800, f1: 400, dur: 0.35, wave: .noise, vol: 0.12)]) }

    func calmDown() { play([Note(f0: 880, f1: 440, dur: 0.5, wave: .sine, vol: 0.25), Note(f0: 523, f1: 523, dur: 0.12, gap: 0.04), Note(f0: 784, f1: 784, dur: 0.3)]) }

    func burp() { play([Note(f0: 110, f1: 70, dur: 0.35, wave: .square, vol: 0.2)]) }

    func hurl() {
        play([Note(f0: 300, f1: 140, dur: 0.18, wave: .square, vol: 0.15, gap: 0.05), Note(f0: 200, f1: 80, dur: 0.4, wave: .noise, vol: 0.25)])
    }

    func heal() { play([523, 659, 784, 1047, 1568].map { Note(f0: $0, f1: $0 * 1.02, dur: 0.07, wave: .sine, vol: 0.3) }) }

    func honk() {
        play([Note(f0: 330, f1: 320, dur: 0.18, wave: .square, vol: 0.25, gap: 0.04), Note(f0: 330, f1: 300, dur: 0.28, wave: .square, vol: 0.25)])
    }

    func boing() { play([Note(f0: 180, f1: 620, dur: 0.12, wave: .triangle, vol: 0.35), Note(f0: 620, f1: 260, dur: 0.25, wave: .triangle, vol: 0.3)]) }

    func sneeze() {
        play([Note(f0: 600, f1: 900, dur: 0.35, wave: .sine, vol: 0.18, gap: 0.08), Note(f0: 4000, f1: 1500, dur: 0.18, wave: .noise, vol: 0.3)])
    }

    func whistle() {
        play([784, 988, 880, 1175, 988].map { Note(f0: $0 * 1.5, f1: $0 * 1.52, dur: 0.16, wave: .sine, vol: 0.18, gap: 0.02) })
    }

    func thud() { play([Note(f0: 140, f1: 60, dur: 0.12, wave: .sine, vol: 0.5)]) }

    /// The four Copycat pads, a cheerful major chord.
    func pad(_ i: Int, long: Bool = false) {
        let f = [392.0, 523.0, 659.0, 784.0][i]
        play([Note(f0: f, f1: f, dur: long ? 0.45 : 0.3, wave: .triangle, vol: 0.4)])
    }

    func buzz() { play([Note(f0: 110, f1: 100, dur: 0.6, wave: .square, vol: 0.2)]) }
}
