//
//  AVAudioMix+Varispeed.swift
//  SJSAssetExportSession
//
//  Created by Sami Samhuri on 2026-11-27.
//

import AVFoundation

extension AVAudioMix {
    /// The same mix with `.varispeed` cleared from every track that sets it, or the mix itself
    /// when none does.
    ///
    /// Photos sets varispeed on the audio of slo-mo videos. Reading a cut of a second or less
    /// from the slowed part of one with that mix never finishes.
    func withoutVarispeed() -> AVAudioMix {
        guard inputParameters.contains(where: { $0.audioTimePitchAlgorithm == .varispeed }) else {
            return self
        }

        let mix = AVMutableAudioMix()
        mix.inputParameters = inputParameters.map { parameters in
            guard parameters.audioTimePitchAlgorithm == .varispeed,
                  let copy = parameters.mutableCopy() as? AVMutableAudioMixInputParameters
            else {
                return parameters
            }
            copy.audioTimePitchAlgorithm = nil
            return copy
        }
        return mix
    }
}
