// Turns a raw simulator recording into an App Store app preview:
// trims, scales/crops to 886x1920 @30fps H.264, and lays the ambient pad
// under it as the audio track.
// Run: swift Tools/make-preview.swift in.mov out.mp4 <startSec> <durationSec> [audio.wav]
import AVFoundation
import Foundation

let args = CommandLine.arguments
let inputURL = URL(fileURLWithPath: args[1])
let outputURL = URL(fileURLWithPath: args[2])
let start = Double(args[3])!
let duration = Double(args[4])!
let audioPath = args.count > 5 ? args[5] : nil

let asset = AVAsset(url: inputURL)
guard let videoTrack = asset.tracks(withMediaType: .video).first else {
    fatalError("no video track in \(inputURL.path)")
}

let comp = AVMutableComposition()
let vTrack = comp.addMutableTrack(withMediaType: .video,
                                  preferredTrackID: kCMPersistentTrackID_Invalid)!
let range = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600),
                        duration: CMTime(seconds: duration, preferredTimescale: 600))
try! vTrack.insertTimeRange(range, of: videoTrack, at: .zero)

if let audioPath {
    let audioAsset = AVAsset(url: URL(fileURLWithPath: audioPath))
    if let source = audioAsset.tracks(withMediaType: .audio).first {
        let aTrack = comp.addMutableTrack(withMediaType: .audio,
                                          preferredTrackID: kCMPersistentTrackID_Invalid)!
        var cursor = CMTime.zero
        let total = CMTime(seconds: duration, preferredTimescale: 600)
        while cursor < total {
            let chunk = CMTimeMinimum(audioAsset.duration, CMTimeSubtract(total, cursor))
            try! aTrack.insertTimeRange(CMTimeRange(start: .zero, duration: chunk),
                                        of: source, at: cursor)
            cursor = CMTimeAdd(cursor, chunk)
        }
    }
}

let target = CGSize(width: 886, height: 1920)
let natural = videoTrack.naturalSize
let scale = max(target.width / natural.width, target.height / natural.height)
let tx = (target.width - natural.width * scale) / 2
let ty = (target.height - natural.height * scale) / 2

let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: vTrack)
layerInstruction.setTransform(
    CGAffineTransform(scaleX: scale, y: scale)
        .concatenating(CGAffineTransform(translationX: tx, y: ty)),
    at: .zero)
let instruction = AVMutableVideoCompositionInstruction()
instruction.timeRange = CMTimeRange(start: .zero,
                                    duration: CMTime(seconds: duration, preferredTimescale: 600))
instruction.layerInstructions = [layerInstruction]
let videoComp = AVMutableVideoComposition()
videoComp.renderSize = target
videoComp.frameDuration = CMTime(value: 1, timescale: 30)
videoComp.instructions = [instruction]

let export = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetHighestQuality)!
export.outputURL = outputURL
export.outputFileType = .mp4
export.videoComposition = videoComp
try? FileManager.default.removeItem(at: outputURL)
let sema = DispatchSemaphore(value: 0)
export.exportAsynchronously { sema.signal() }
sema.wait()
if export.status == .completed {
    print("wrote \(outputURL.lastPathComponent) \(Int(target.width))x\(Int(target.height))")
} else {
    print("export failed: \(String(describing: export.error))")
    exit(1)
}
