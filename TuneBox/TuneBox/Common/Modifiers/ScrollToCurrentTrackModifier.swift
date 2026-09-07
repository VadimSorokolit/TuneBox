//
//  ScrollToCurrentTrackModifier.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 07.09.2026.
//

import SwiftUI

private struct ScrollToCurrentTrackModifier<Trigger: Hashable>: ViewModifier {

    let trackID: String?
    let trackIDs: Set<String>
    let trigger: Trigger
    let animated: Bool

    @State private var isReady = false

    private var needsInitialScroll: Bool {
        guard let trackID else { return false }
        return trackIDs.contains(trackID)
    }

    func body(content: Content) -> some View {
        ScrollViewReader { proxy in
            content
                .opacity(needsInitialScroll && isReady == false ? 0 : 1)
                .task(id: trigger) {
                    isReady = false

                    guard let trackID, trackIDs.contains(trackID) else {
                        isReady = true
                        return
                    }

                    // Wait one frame so LazyVStack registers row ids.
                    await Task.yield()

                    let scroll = {
                        proxy.scrollTo(trackID, anchor: .center)
                    }

                    if animated {
                        withAnimation(.easeInOut(duration: 0.35), scroll)
                    } else {
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction, scroll)
                    }

                    isReady = true
                }
        }
    }
}

extension View {

    func scrollToCurrentTrackOnAppear(
        id trackID: String?,
        in tracks: [TrackEntity],
        trigger: some Hashable,
        animated: Bool = false
    ) -> some View {
        modifier(
            ScrollToCurrentTrackModifier(
                trackID: trackID,
                trackIDs: Set(tracks.map(\.id)),
                trigger: trigger,
                animated: animated
            )
        )
    }

    func scrollToCurrentTrackOnAppear(
        id trackID: String?,
        trackIDs: some Sequence<String>,
        trigger: some Hashable,
        animated: Bool = false
    ) -> some View {
        modifier(
            ScrollToCurrentTrackModifier(
                trackID: trackID,
                trackIDs: Set(trackIDs),
                trigger: trigger,
                animated: animated
            )
        )
    }
}
