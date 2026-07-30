//
//  WaveformServicing.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 30.07.2026.
//

import Foundation

protocol WaveformServicing: AnyObject {
    static func makeWaveform(from url: URL, targetPeaks: Int) -> Waveform?
}
