//
//  L10n.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 27.09.2026.
//

import Foundation
import Resolver

enum L10n {

    // MARK: - Common

    enum Common {
        static var error: String { text("common.error") }
        static var okButton: String { text("common.ok") }
        static var cancel: String { text("common.cancel") }
        static var delete: String { text("common.delete") }
        static var apply: String { text("common.apply") }
        static var searchPlaceholder: String { text("common.search_placeholder") }

        static func durationHMS(hours: Int, minutes: Int, seconds: Int) -> String {
            String(format: text("common.duration.hms"), hours, minutes, seconds)
        }

        static func durationMS(minutes: Int, seconds: Int) -> String {
            String(format: text("common.duration.ms"), minutes, seconds)
        }
    }

    // MARK: - Tab

    enum Tab {
        static var `import`: String { text("tab.import") }
        static var discover: String { text("tab.discover") }
        static var library: String { text("tab.library") }
        static var settings: String { text("tab.settings") }
    }

    // MARK: - TabsMode

    enum TabsMode {
        static var all: String { text("tabs.mode.all") }
        static var `import`: String { text("tabs.mode.import") }
    }

    // MARK: - Settings

    enum Settings {
        static var title: String { text("settings.title") }
        static var appearance: String { text("settings.section.appearance") }
        static var playback: String { text("settings.section.playback") }
        static var about: String { text("settings.section.about") }

        static var theme: String { text("settings.theme") }
        static var themeSystem: String { text("settings.theme.system") }
        static var themeLight: String { text("settings.theme.light") }
        static var themeDark: String { text("settings.theme.dark") }

        static var language: String { text("settings.language") }
        static var languageSystem: String { text("settings.language.system") }

        static var defaultTab: String { text("settings.default_tab") }
        static var visibleTabs: String { text("settings.visible_tabs") }
        static var sleepTimer: String { text("settings.sleep_timer") }
        static var sleepTimerOff: String { text("settings.sleep_timer.off") }
        static var sleepTimerHint: String { text("settings.sleep_timer.hint") }
        static var sleepTimerHoursLabel: String { text("settings.sleep_timer.hours_label") }
        static var sleepTimerMinutesLabel: String { text("settings.sleep_timer.minutes_label") }
        static var sleepTimerCancel: String { text("settings.sleep_timer.cancel") }
        static var sleepTimerStart: String { text("settings.sleep_timer.start") }

        static func sleepTimerHours(_ value: Int) -> String {
            String(format: text("settings.sleep_timer.hours"), value)
        }

        static func sleepTimerMinutes(_ value: Int) -> String {
            String(format: text("settings.sleep_timer.minutes"), value)
        }

        static var appInfo: String { text("settings.app_info") }
        static var aboutTitle: String { text("settings.about.title") }
        static var license: String { text("settings.about.license") }
        static var shareFeedback: String { text("settings.about.share_feedback") }
        static var share: String { text("settings.about.share") }
        static var privacy: String { text("settings.about.privacy") }
        static var terms: String { text("settings.about.terms") }
        static var version: String { text("settings.about.version") }
        static var shareMessage: String { text("settings.share.message") }
    }

    // MARK: - Import

    enum Import {
        static var library: String { text("import.section.library") }
        static var sources: String { text("import.section.sources") }
        static var emptyTitle: String { text("import.empty.title") }
        static var emptyMessage: String { text("import.empty.message") }
        static var editSections: String { text("import.empty.edit_sections") }
        static var noTracks: String { text("import.empty.no_tracks") }
        static var sourcesMessage: String { text("import.empty.sources_message") }
        static var addFolder: String { text("import.add_folder") }
        static var addingTracks: String { text("import.progress.title") }

        static func progressCount(_ completed: Int, _ total: Int) -> String {
            String(format: text("import.progress.count"), completed, total)
        }

        static var deleteFolderTitle: String { text("import.delete_folder.title") }
        static var deleteFolderMessage: String { text("import.delete_folder.message") }
        static var downloadsSource: String { text("import.source.downloads") }
    }

    // MARK: - Library

    enum Library {
        static var albums: String { text("library.item.albums") }
        static var artists: String { text("library.item.artists") }
        static var tracks: String { text("library.item.tracks") }
        static var playlists: String { text("library.item.playlists") }

        static var unitAlbum: String { text("library.unit.album") }
        static var unitAlbums: String { text("library.unit.albums") }
        static var unitArtist: String { text("library.unit.artist") }
        static var unitArtists: String { text("library.unit.artists") }
        static var unitTrack: String { text("library.unit.track") }
        static var unitTracks: String { text("library.unit.tracks") }
        static var unitPlaylist: String { text("library.unit.playlist") }
        static var unitPlaylists: String { text("library.unit.playlists") }

        static func tracksCount(_ count: Int) -> String {
            String(format: text("library.unit.tracks_count"), count)
        }

        static var segmentAlbums: String { text("library.segment.albums") }
        static var segmentTracks: String { text("library.segment.tracks") }
        static var emptySuffix: String { text("library.empty.suffix") }

        static func emptyTracks(_ item: String) -> String {
            String(format: text("library.empty.tracks"), item)
        }

        static var emptyPlaylistsPrefix: String { text("library.empty.playlists_prefix") }
        static var emptyPlaylistsSuffix: String { text("library.empty.playlists_suffix") }
        static var artistNotFound: String { text("library.artist.not_found") }
        static var artistUnavailable: String { text("library.artist.unavailable") }
        static var fallbackArtist: String { text("library.fallback.artist") }
        static var fallbackAlbum: String { text("library.fallback.album") }
        static var coversTitle: String { text("library.covers.title") }

        static func coversPage(current: Int, total: Int) -> String {
            String(format: text("library.covers.page"), current, total)
        }

        static var filterActive: String { text("library.filter.active") }
        static var filterDownloaded: String { text("library.filter.downloaded") }
        static var suffixDownloaded: String { text("library.section.suffix.downloaded") }
        static var suffixInProgress: String { text("library.section.suffix.in_progress") }
        static var playlistDownloaded: String { text("library.playlist.downloaded") }
        static var playlistNew: String { text("library.playlist.new") }
    }

    // MARK: - Discover

    enum Discover {
        static var removeActive: String { text("discover.menu.remove_active") }
        static var removePaused: String { text("discover.menu.remove_paused") }
        static var featured: String { text("discover.section.featured") }
        static var popular: String { text("discover.section.popular") }
        static var search: String { text("discover.section.search") }
        static var recents: String { text("discover.section.recents") }
        static var all: String { text("discover.section.all") }
        static var imported: String { text("discover.section.imported") }
        static var paginationEnd: String { text("discover.pagination.end") }
    }

    // MARK: - Genre

    enum Genre {
        static var all: String { text("genre.all") }
        static var pop: String { text("genre.pop") }
        static var rock: String { text("genre.rock") }
        static var jazz: String { text("genre.jazz") }
        static var classic: String { text("genre.classic") }
        static var electronic: String { text("genre.electronic") }
    }

    // MARK: - Player

    enum Player {
        static var emptyTitle: String { text("player.empty.title") }
        static var emptyMessage: String { text("player.empty.message") }
        static var `repeat`: String { text("player.repeat") }
        static var repeatOff: String { text("player.repeat.off") }
        static var repeatAll: String { text("player.repeat.all") }
        static var repeatOne: String { text("player.repeat.one") }
        static var shuffle: String { text("player.shuffle") }
        static var queue: String { text("player.queue") }
        static var speaker: String { text("player.route.speaker") }
        static var formatAudio: String { text("player.format.audio") }

        static func formatBit(_ value: Int) -> String {
            String(format: text("player.format.bit"), value)
        }

        static func formatKbps(_ value: Int) -> String {
            String(format: text("player.format.kbps"), value)
        }

        static func formatKhz(_ value: Int) -> String {
            String(format: text("player.format.khz"), value)
        }
    }

    // MARK: - Track

    enum Track {
        static var editTags: String { text("track.menu.edit_tags") }
        static var deleteFromPlaylist: String { text("track.menu.delete_from_playlist") }
        static var deleteFromDevice: String { text("track.menu.delete_from_device") }
        static var a11yStartDownload: String { text("track.a11y.start_download") }
        static var a11yCancelDownload: String { text("track.a11y.cancel_download") }
        static var a11yPauseDownload: String { text("track.a11y.pause_download") }
        static var a11yResumeDownload: String { text("track.a11y.resume_download") }
        static var a11yDelete: String { text("track.a11y.delete") }
        static var a11yRetry: String { text("track.a11y.retry") }
    }

    // MARK: - Paywall

    enum Paywall {
        static var statusUnlock: String { text("paywall.status.unlock") }
        static var statusLifetimeActive: String { text("paywall.status.lifetime_active") }

        static func statusSubscriptionUntil(_ date: String) -> String {
            String(format: text("paywall.status.subscription_until"), date)
        }

        static var statusPremiumActive: String { text("paywall.status.premium_active") }

        static func statusTrialEnds(_ date: String) -> String {
            String(format: text("paywall.status.trial_ends"), date)
        }

        static func statusTrialEnded(_ date: String) -> String {
            String(format: text("paywall.status.trial_ended"), date)
        }

        static var headerLifetime: String { text("paywall.header.lifetime") }
        static var headerPremium: String { text("paywall.header.premium") }
        static var headerPurchase: String { text("paywall.header.purchase") }
        static var thanks: String { text("paywall.thanks") }
        static var subtitleUnlock: String { text("paywall.subtitle.unlock") }
        static var productLifetime: String { text("paywall.product.lifetime") }
        static var productMonthly: String { text("paywall.product.monthly") }
        static var everyMonth: String { text("paywall.period.every_month") }
        static var restore: String { text("paywall.restore") }
        static var terms: String { text("paywall.terms") }
        static var privacy: String { text("paywall.privacy") }

        static func disclosureBase(price: String) -> String {
            String(format: text("paywall.disclosure.base"), price)
        }

        static var disclosureManage: String { text("paywall.disclosure.manage") }
    }

    // MARK: - Feedback

    enum Feedback {
        static var title: String { text("feedback.title") }
        static var prompt: String { text("feedback.prompt") }
        static var unhappy: String { text("feedback.rating.unhappy") }
        static var meh: String { text("feedback.rating.meh") }
        static var okay: String { text("feedback.rating.okay") }
        static var happy: String { text("feedback.rating.happy") }
        static var veryHappy: String { text("feedback.rating.very_happy") }
        static var loveIt: String { text("feedback.rating.love_it") }
        static var placeholder: String { text("feedback.placeholder") }
        static var send: String { text("feedback.send") }
        static var thanks: String { text("feedback.thanks") }
        static var thanksMessage: String { text("feedback.thanks_message") }
        static var sendError: String { text("feedback.error.send") }
    }

    // MARK: - Error

    enum Error {
        static var noInternet: String { text("error.api.no_internet") }

        static func network(_ detail: String) -> String {
            String(format: text("error.api.network"), detail)
        }

        static func decoding(_ detail: String) -> String {
            String(format: text("error.api.decoding"), detail)
        }

        static func encoding(_ detail: String) -> String {
            String(format: text("error.api.encoding"), detail)
        }

        static func serverCode(_ code: Int) -> String {
            String(format: text("error.api.server_code"), code)
        }

        static var invalidURL: String { text("error.api.invalid_url") }
        static var notFound: String { text("error.api.not_found") }
        static var missingContentLength: String { text("error.api.missing_content_length") }
        static var invalidContentLength: String { text("error.api.invalid_content_length") }
        static var unknown: String { text("error.api.unknown") }
        static var serverUnavailable: String { text("error.api.server_unavailable") }
        static var fileUnavailable: String { text("error.file.unavailable") }

        static func notEnoughSpace(required: Double, available: Double) -> String {
            String(format: text("error.file.not_enough_space"), required, available)
        }

        static var reservedPlaylist: String { text("error.storage.reserved_playlist") }
        static var playlistExists: String { text("error.storage.playlist_exists") }
        static var storageNotEnoughSpace: String { text("error.storage.not_enough_space") }

        static func reservedPolicy(_ reserved: String) -> String {
            String(format: text("error.storage.reserved_policy"), reserved)
        }

        static var playlistEmptyTitle: String { text("error.playlist.empty_title") }
        static var playlistSameTitle: String { text("error.playlist.same_title") }
        static var sourceNetworkUnavailable: String { text("error.source.network_unavailable") }
        static var sourceAccessDenied: String { text("error.source.access_denied") }
        static var sourceBookmarkInvalid: String { text("error.source.bookmark_invalid") }
    }

    // MARK: - Methods. Private

    private static func text(_ key: String) -> String {
        holder.languageVM.localizedString(key)
    }

    // MARK: - Properties. Private

    private static let holder = Holder()

    // MARK: - Objects. Private

    private struct Holder {
        @Injected var languageVM: LanguageManaging
    }
}
