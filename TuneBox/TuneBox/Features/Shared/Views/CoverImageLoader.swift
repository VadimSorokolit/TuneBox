//
//  CoverImageLoader.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 14.09.2026.
//

import UIKit
import MediaPlayer

enum CoverImageLoader {

    static func applyNowPlayingArtwork(from path: String?) {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }

        if let image = self.image(for: path) {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in
                image
            }
        } else {
            info.removeValue(forKey: MPMediaItemPropertyArtwork)
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private static func image(for path: String?) -> UIImage? {
        guard let path, path.isNotEmpty else { return nil }

        if path.hasPrefix("http://") || path.hasPrefix("https://"),
           let url = URL(string: path),
           let data = try? Data(contentsOf: url) {
            return UIImage(data: data)
        }

        if let url = AudioMetadataService.coverURL(for: path),
           let data = try? Data(contentsOf: url) {
            return UIImage(data: data)
        }

        return nil
    }
}
