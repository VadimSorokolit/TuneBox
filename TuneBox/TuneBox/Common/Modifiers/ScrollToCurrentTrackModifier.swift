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
    let followsTrackChanges: Bool

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
                    await scrollToCurrentTrack(
                        proxy: proxy,
                        animated: false,
                        prepareAppearance: true
                    )
                }
                .onChange(of: trackID) { _, newID in
                    guard followsTrackChanges, isReady else { return }
                    guard let newID, trackIDs.contains(newID) else { return }

                    scroll(proxy: proxy, to: newID, animated: true)
                }
        }
    }

    // MARK: - Methods. Private

    @MainActor
    private func scrollToCurrentTrack(
        proxy: ScrollViewProxy,
        animated: Bool,
        prepareAppearance: Bool
    ) async {
        if prepareAppearance {
            isReady = false
        }

        guard let trackID, trackIDs.contains(trackID) else {
            isReady = true
            return
        }

        // Wait one frame so LazyVStack / List can register row ids.
        await Task.yield()

        scroll(proxy: proxy, to: trackID, animated: animated)
        isReady = true
    }

    private func scroll(
        proxy: ScrollViewProxy,
        to trackID: String,
        animated: Bool
    ) {
        let action = {
            proxy.scrollTo(trackID, anchor: .center)
        }

        if animated {
            withAnimation(.smooth(duration: 0.4), action)
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction, action)
        }
    }
}

extension View {

    func scrollToCurrentTrackOnAppear(
        id trackID: String?,
        in tracks: [TrackEntity],
        trigger: some Hashable,
        followsTrackChanges: Bool = true
    ) -> some View {
        modifier(
            ScrollToCurrentTrackModifier(
                trackID: trackID,
                trackIDs: Set(tracks.map(\.id)),
                trigger: trigger,
                followsTrackChanges: followsTrackChanges
            )
        )
    }

    func scrollToCurrentTrackOnAppear(
        id trackID: String?,
        trackIDs: some Sequence<String>,
        trigger: some Hashable,
        followsTrackChanges: Bool = true
    ) -> some View {
        modifier(
            ScrollToCurrentTrackModifier(
                trackID: trackID,
                trackIDs: Set(trackIDs),
                trigger: trigger,
                followsTrackChanges: followsTrackChanges
            )
        )
    }
}
