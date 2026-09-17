//
//  CoverImageLoader.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 14.09.2026.
//

import UIKit
import MediaPlayer
import SDWebImage

enum CoverImageLoader {

    static func applyNowPlayingArtwork(from path: String?) {
        self.cancelCurrentLoad()
        self.loadGeneration += 1
        let generation = self.loadGeneration

        guard MPNowPlayingInfoCenter.default().nowPlayingInfo != nil else { return }

        guard let url = self.imageURL(for: path) else {
            self.updateArtwork(nil)
            return
        }

        if url.isFileURL {
            self.loadLocalImage(from: url, generation: generation)
        } else {
            self.loadRemoteImage(from: url, generation: generation)
        }
    }

    private static var loadGeneration = 0
    private static var currentLoad: Task<Void, Never>?
    private static var currentOperation: (any SDWebImageOperation)?

    private static func imageURL(for path: String?) -> URL? {
        guard let path, path.isNotEmpty else { return nil }

        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            return URL(string: path)
        }

        return AudioMetadataService.coverURL(for: path)
    }

    private static func loadLocalImage(from url: URL, generation: Int) {
        self.currentLoad = Task.detached(priority: .userInitiated) {
            let image = UIImage(contentsOfFile: url.path)

            await MainActor.run {
                guard Task.isCancelled.isFalse else { return }
                guard generation == self.loadGeneration else { return }
                self.updateArtwork(image)
            }
        }
    }

    private static func loadRemoteImage(from url: URL, generation: Int) {
        self.currentOperation = SDWebImageManager.shared.loadImage(
            with: url,
            options: [.highPriority, .retryFailed],
            progress: nil
        ) { image, _, _, _, finished, _ in
            guard finished else { return }

            DispatchQueue.main.async {
                guard generation == self.loadGeneration else { return }
                self.updateArtwork(image)
            }
        }
    }

    private static func cancelCurrentLoad() {
        self.currentLoad?.cancel()
        self.currentLoad = nil
        self.currentOperation?.cancel()
        self.currentOperation = nil
    }

    private static func updateArtwork(_ image: UIImage?) {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }

        if let image {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in
                image
            }
        } else {
            info.removeValue(forKey: MPMediaItemPropertyArtwork)
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
