//
//  ScrollToCurrentTrackModifier.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 07.09.2026.
//

import SwiftUI

private struct ScrollToCurrentTrackModifier<Trigger: Hashable>: ViewModifier {

    let trackID: String?
    let orderedTrackIDs: [String]
    let trigger: Trigger
    let followsTrackChanges: Bool
    let animatedRequest: Int

    @State private var isReady = false

    private var trackIDSet: Set<String> {
        Set(orderedTrackIDs)
    }

    private var needsInitialScroll: Bool {
        guard let trackID else { return false }
        return trackIDSet.contains(trackID)
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
                    guard let newID, trackIDSet.contains(newID) else { return }

                    scroll(proxy: proxy, to: newID, animated: true)
                }
                .onChange(of: animatedRequest) { _, _ in
                    guard isReady else { return }
                    guard let trackID, trackIDSet.contains(trackID) else { return }

                    Task { @MainActor in
                        await Task.yield()
                        scroll(proxy: proxy, to: trackID, animated: true)
                    }
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

        guard let trackID, trackIDSet.contains(trackID) else {
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
        let anchor = Self.anchor(for: trackID, in: orderedTrackIDs)
        let action = {
            proxy.scrollTo(trackID, anchor: anchor)
        }

        if animated {
            // `.smooth` is a spring and overshoots. At the list bound that
            // rubber-bands, so "Show" on a last track ended with a hitch.
            withAnimation(.easeInOut(duration: 0.4), action)
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction, action)
        }
    }

    /// `.center` is often unreachable for the first/last rows, and SwiftUI
    /// then eases into the clamped offset — that is the hitch at the end.
    /// Pin those rows to a reachable edge so the animation can finish cleanly.
    private static func anchor(
        for trackID: String,
        in orderedTrackIDs: [String]
    ) -> UnitPoint {
        guard let index = orderedTrackIDs.firstIndex(of: trackID) else {
            return .center
        }

        let lastIndex = orderedTrackIDs.count - 1
        let distanceFromEnd = lastIndex - index

        if index == 0 {
            return .top
        }

        if distanceFromEnd == 0 {
            return .bottom
        }

        if index == 1 {
            return UnitPoint(x: 0.5, y: 0.3)
        }

        if distanceFromEnd <= 2 {
            return UnitPoint(x: 0.5, y: 0.82)
        }

        return .center
    }
}

extension View {

    func scrollToCurrentTrackOnAppear(
        id trackID: String?,
        in tracks: [TrackEntity],
        trigger: some Hashable,
        followsTrackChanges: Bool = true,
        animatedRequest: Int = 0
    ) -> some View {
        modifier(
            ScrollToCurrentTrackModifier(
                trackID: trackID,
                orderedTrackIDs: tracks.map(\.id),
                trigger: trigger,
                followsTrackChanges: followsTrackChanges,
                animatedRequest: animatedRequest
            )
        )
    }

    func scrollToCurrentTrackOnAppear(
        id trackID: String?,
        trackIDs: some Sequence<String>,
        trigger: some Hashable,
        followsTrackChanges: Bool = true,
        animatedRequest: Int = 0
    ) -> some View {
        modifier(
            ScrollToCurrentTrackModifier(
                trackID: trackID,
                orderedTrackIDs: Array(trackIDs),
                trigger: trigger,
                followsTrackChanges: followsTrackChanges,
                animatedRequest: animatedRequest
            )
        )
    }
}
