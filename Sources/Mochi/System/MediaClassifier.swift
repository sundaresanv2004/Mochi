import Foundation

/// Works out what kind of thing is playing from what Now Playing says about it: the app, the title, the
/// artist (or channel), the album and the length. Nothing is looked up online and no permission is needed,
/// so it is a good guess rather than a certainty; when in doubt a browser's media counts as a video.
enum MediaClassifier {
    enum Kind: Equatable {
        case music      // a song: Spotify, Apple Music, YouTube Music, a music video
        case podcast    // a podcast or an audiobook: people talking
        case movie      // a film or a show: Netflix, Prime Video, the TV app, a video file
        case video      // anything else with pictures: YouTube and the like
    }

    static func kind(of s: NowPlaying.State) -> Kind {
        kind(app: s.app, title: s.title, artist: s.artist, album: s.album, duration: s.duration,
             video: s.video, audio: s.audio)
    }

    static func kind(app: String?, title: String?, artist: String?, album: String?, duration: Double?,
                     video: Bool = false, audio: Bool = false) -> Kind {
        let app = (app ?? "").lowercased()
        let title = (title ?? "").lowercased()
        let artist = (artist ?? "").lowercased()
        let hasAlbum = !(album ?? "").trimmingCharacters(in: .whitespaces).isEmpty
        let minutes = (duration ?? 0) / 60
        func appIs(_ keys: [String]) -> Bool { keys.contains { app.contains($0) } }

        // 1. Apps that only ever play one kind of thing.
        if appIs(podcastApps) { return .podcast }
        if appIs(movieApps) { return .movie }

        let talky = soundsLikePodcast(title: title, artist: artist)
        if appIs(musicApps) {
            // Music apps play podcasts too (Spotify): an episode, or something long without an album.
            return talky || (!hasAlbum && minutes >= 20) ? .podcast : .music
        }

        // 2. Browsers and anything else: go by what the item says about itself.
        if mentions(title + " " + artist, streamingServices) { return .movie }
        if talky { return .podcast }
        if hasAlbum || soundsLikeMusic(title: title, artist: artist) { return .music }
        if video || !audio {
            // A film or a whole episode is long; a clip isn't.
            return minutes >= 60 && artist.isEmpty ? .movie : .video
        }
        // The player says it is audio only (a native app we don't know): long talk or a song.
        return minutes >= 20 ? .podcast : .music
    }

    // MARK: Private browsing

    /// Browsers, for private-browsing reactions (each has its own icon for it, so the pet has its own act).
    enum Browser: Equatable {
        case chrome, firefox, safari, edge, other

        init?(app: String?) {
            let a = (app ?? "").lowercased()
            if a.contains("com.google.chrome") || a.contains("chromium") || a == "chrome" || a.hasPrefix("chrome.") { self = .chrome }
            else if a.contains("firefox") || a.contains("mozilla") || a.contains("308046b0af4a39cb") { self = .firefox }
            else if a.contains("com.apple.safari") || a.contains("safaritechnologypreview") { self = .safari }
            else if a.contains("com.microsoft.edge") || a.contains("msedge") { self = .edge }
            else if ["brave", "company.thebrowser", "opera", "vivaldi", "orion", "app.zen-browser", "duckduckgo", "sigmaos", "yandex"]
                        .contains(where: { a.contains($0) }) { self = .other }
            else { return nil }
        }
    }

    /// Something is playing in a private window. Browsers keep private media to themselves: instead of the
    /// real title they report a placeholder ("A site is playing media" in Chrome and other Chromium browsers)
    /// and no artist. That placeholder is the tell, so no permission is needed to notice it.
    static func isPrivate(app: String?, title: String?, artist: String?) -> Bool {
        guard Browser(app: app) != nil else { return false }
        let t = (title ?? "").lowercased().trimmingCharacters(in: .whitespaces)
        if privatePlaceholders.contains(where: { t == $0 || t.hasPrefix($0) }) { return true }
        // "<Something> is playing media / audio / a video", with nothing about who made it.
        let empty = (artist ?? "").trimmingCharacters(in: .whitespaces).isEmpty
        return empty && t.range(of: #"\bis playing (media|audio|video|a video|sound)\b"#, options: .regularExpression) != nil
    }

    static let privatePlaceholders = ["a site is playing media", "a site is playing audio", "a site is playing video",
                                      "this site is playing media", "a page is playing media", "media is playing"]

    // MARK: Clues

    static let podcastApps = ["com.apple.podcasts", "pocketcasts", "shiftyjelly", "overcast", "castro", "audible",
                              "com.apple.ibooks", "com.apple.books", "castbox", "podcast"]
    static let movieApps = ["com.apple.tv", "netflix", "com.amazon.aiv", "primevideo", "disney", "hbo", "com.wbd",
                            "hulu", "hotstar", "jiocinema", "crunchyroll", "plex", "infuse", "firecore", "iina",
                            "videolan", "vlc", "quicktime", "mpv", "movist", "elmedia",
                            "zunevideo", "potplayer", "mpc-hc", "mpc-be"]
    static let musicApps = ["spotify", "com.apple.music", "com.apple.itunes", "tidal", "deezer", "amazon.music",
                            "soundcloud", "pandora", "vox", "swinsian", "doppler", "qobuz", "jiosaavn", "gaana",
                            "zunemusic", "applemusicwin", "itunes.exe", "amazonmusic", "foobar2000", "musicbee", "aimp"]
    static let streamingServices = ["netflix", "prime video", "disney+", "hotstar", "hbo max", "| max", "hulu",
                                    "apple tv+", "crunchyroll", "jiocinema", "zee5", "sonyliv"]

    static func mentions(_ text: String, _ words: [String]) -> Bool { words.contains { text.contains($0) } }

    /// "Episode 12", "Ep. 4", "#231", "S2E5", "…Podcast", "audiobook", "Chapter 3".
    static func soundsLikePodcast(title: String, artist: String) -> Bool {
        if mentions(title + " " + artist, ["podcast", "episode", "audiobook", "chapter ", " ep.", " ep "]) { return true }
        if title.hasPrefix("ep") , title.dropFirst(2).trimmingCharacters(in: .punctuationCharacters.union(.whitespaces)).first?.isNumber == true { return true }
        if title.range(of: #"#\s?\d{1,4}\b"#, options: .regularExpression) != nil { return true }
        if title.range(of: #"\bs\d{1,2}\s?e\d{1,3}\b"#, options: .regularExpression) != nil { return true }
        return false
    }

    /// Music videos and songs uploaded to video sites.
    static func soundsLikeMusic(title: String, artist: String) -> Bool {
        if artist.hasSuffix(" - topic") || artist.hasSuffix("vevo") || artist.contains("records") || artist.contains("music") { return true }
        return mentions(title, ["official video", "official music video", "official audio", "music video", "lyric video",
                                "lyrics", "(audio)", "[audio]", "visualizer", " ft. ", " feat. ", "(feat", "remix",
                                "full song", "video song", "lyrical", "acoustic", "live session", "lofi", "lo-fi"])
    }
}
