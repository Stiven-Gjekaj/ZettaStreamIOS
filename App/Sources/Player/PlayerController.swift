import AVFoundation
import Combine
import SwiftUI
import UIKit
import VLCKit
import ZettaCore

/// One choice of a track in the options: no subtitles, a track of VLC, or a subtitle of an addon.
struct TrackChoice: Identifiable, Hashable {
    enum Kind: Hashable {
        case off
        case track(String)
        case addon(String)
    }

    let kind: Kind
    let label: String
    var id: Kind { kind }
}

/// Owns the VLC player and holds the state of the player screen.
///
/// Each new stream, each reconnect, and each change of the subtitle look gets a new VLC
/// player. VLC reads the look of the text when the player starts, and a new player also
/// keeps the events of the old stream away from the new one.
@MainActor
final class PlayerController: ObservableObject {
    static let seekStep = 10_000
    static let countdownLength = TimeInterval(Skip.countdownLength / 1000)
    private static let labelTime: TimeInterval = 8
    private static let overlayTime: TimeInterval = 4
    private static let messageTime: TimeInterval = 2.5
    /// While the viewer goes through the choices of the subtitle look, only the last one restarts the video.
    private static let lookSettle: Duration = .milliseconds(800)
    /// The time between two saves of the progress while the video plays.
    private static let saveInterval = 10
    private static let tick: Duration = .milliseconds(250)

    @Published private(set) var video: VideoPlayback?
    @Published private(set) var channels: [Channel] = []
    @Published private(set) var channelIndex = 0
    @Published private(set) var position = 0
    @Published private(set) var duration = 0
    @Published private(set) var playing = false
    @Published private(set) var buffering = true
    @Published private(set) var error: String?
    @Published private(set) var message: String?
    @Published private(set) var torrentText: String?
    @Published private(set) var skips: [SkipRange] = []
    /// The seconds before the next episode plays, or nil with no countdown.
    @Published private(set) var countdownLeft: Int?
    @Published private(set) var subtitleChoices: [TrackChoice] = []
    @Published private(set) var subtitleSelected: TrackChoice.Kind = .off
    @Published private(set) var audioChoices: [TrackChoice] = []
    @Published private(set) var audioSelected: TrackChoice.Kind?
    /// The subtitle delay is for this video only. The audio delay is in the settings.
    @Published private(set) var subtitleDelayMs = 0
    /// The blurred copy of the frame for the side bars, and the place of the picture on the screen.
    @Published private(set) var ambient: UIImage?
    @Published private(set) var videoRect: CGRect?
    @Published private(set) var pictureInPicturePossible = false
    @Published private(set) var pictureInPictureActive = false
    @Published private(set) var overlayVisible = true
    @Published private(set) var labelVisible = true
    @Published private(set) var settings = ViewerSettings()

    let surface = VideoSurface()

    private weak var app: AppModel?
    private var player: VLCMediaPlayer?
    private var bridge: PlayerEventBridge?
    /// The players that stop. Each one stays until VLC says that it stopped.
    private var retired: [Int: VLCMediaPlayer] = [:]
    private var generation = 0
    private let log = PlayerErrorLog()
    private var lookOptions: [String] = []
    private var observers: Set<AnyCancellable> = []
    private var loadTask: Task<Void, Never>?
    private var tickTask: Task<Void, Never>?
    private var lookTask: Task<Void, Never>?
    private var nextTask: Task<Void, Never>?
    private var current: (url: URL, headers: [String: String])?
    private var torrentHash: String?
    private var closed = false

    /// True after the first frame of this video played. Before it, a failed stream gives its place to the next best one.
    private var everReady = false
    /// True after the first frame of the current VLC player. Each new player gets the delays and the tracks again.
    private var playerReady = false
    /// True after the current VLC player stopped or failed.
    private var playerEnded = false
    private var pauseWhenReady = false
    /// The length that the current player gave.
    private var length = 0
    private var retries = 0
    /// The furthest position where the stream stopped with a fault.
    private var faultAt = 0
    /// The saved position. Another source can be shorter, so the player checks it when the length is known.
    private var resumeAt = 0
    private var skipTimesAsked = false
    private var autoSkipped = Set<Int>()
    private var countdownEnds: Date?
    private var countdownCancelled = false
    /// The next episode, found in the last minutes of this one: its video ID, and its playback or nil.
    private var preparedNext: (id: String, playback: VideoPlayback?)?
    private var preparing = false

    private var addonSubtitles: [(subtitle: Subtitle, label: String)] = []
    /// The VLC track of each addon subtitle that the player added, by the link of the subtitle.
    private var slaveTracks: [String: String] = [:]
    private var pendingSlaves: [String] = []
    private var wantedSubtitle: TrackChoice.Kind?
    private var wantedAudio: TrackChoice.Kind?

    private var labelUntil = Date().addingTimeInterval(PlayerController.labelTime)
    private var overlayUntil = Date().addingTimeInterval(PlayerController.overlayTime)
    private var messageUntil = Date()
    private var viewSize: CGSize = .zero
    private var ambientNeeded = false
    private var ambientShown: [UInt32] = []
    private var ambientCopied = false
    private var ticks = 0
    private var pictureInPicture: (any VLCPictureInPictureWindowControlling)?

    init(playback: Playback) {
        switch playback {
        case .video(let video): self.video = video
        case .live(let channels, let index):
            self.channels = channels
            channelIndex = index
        }
    }

    var isLive: Bool { video == nil }

    var title: String {
        if let video { return video.meta.name }
        return channels.indices.contains(channelIndex) ? channels[channelIndex].name : ""
    }

    /// The episode under the title, or the programmes that are on now and next for a channel.
    func subtitle(guide: Guide) -> String {
        if let video { return video.label != video.meta.name ? video.label : "" }
        guard channels.indices.contains(channelIndex) else { return "" }
        let (now, next) = guide.nowAndNext(channels[channelIndex].tvgId, now: Int64(Date().timeIntervalSince1970 * 1000))
        return [now.map { "Now: \($0.title)" }, next.map { "Next: \($0.title)" }].compactMap { $0 }.joined(separator: "   ")
    }

    var hasEpisodes: Bool { (video?.episodes.count ?? 0) > 1 || channels.count > 1 }

    var hasNext: Bool {
        guard let video else { return false }
        return Episodes.neighbour(video.episodes, of: video.videoId, step: 1) != nil
    }

    // MARK: Start and close

    func start(app: AppModel) {
        guard self.app == nil else { return }
        self.app = app
        settings = app.settings
        lookOptions = VLCOptions.subtitles(settings)
        prepareSubtitles()
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback)
        try? session.setActive(true)
        OrientationLock.lock(.landscape)
        surface.onSize = { [weak self] size in self?.layoutChanged(size) }
        surface.onPictureInPictureReady = { [weak self] controller in self?.pictureInPictureReady(controller) }
        app.$settings.dropFirst().sink { [weak self] value in
            MainActor.assumeIsolated { self?.settingsChanged(value) }
        }.store(in: &observers)
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification).sink { [weak self] _ in
            MainActor.assumeIsolated { self?.appWillResignActive() }
        }.store(in: &observers)
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification).sink { [weak self] _ in
            MainActor.assumeIsolated { self?.appDidBecomeActive() }
        }.store(in: &observers)
        load()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.tick)
                self?.onTick()
            }
        }
    }

    /// Saves the progress and stops the player and the torrent. The screen calls it when it goes away.
    func close() {
        guard !closed else { return }
        saveProgress()
        closed = true
        for task in [loadTask, tickTask, lookTask, nextTask] { task?.cancel() }
        pictureInPicture?.stopPictureInPicture()
        releasePlayer()
        stopTorrent()
        observers.removeAll()
        UIApplication.shared.isIdleTimerDisabled = false
        OrientationLock.unlock()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: Loading

    private func load() {
        loadTask?.cancel()
        error = nil
        buffering = true
        guard let app else { return }
        if let video {
            let saved = app.container.library.progress(video.videoId)
            let startAt = saved.map { $0.isFinished ? 0 : $0.position } ?? 0
            guard let torrent = video.torrent else {
                guard let url = URL(string: video.url) else { return badLink() }
                return open(url, headers: video.headers, startAt: startAt)
            }
            // The engine first gets the torrent information from peers, then serves the file on this device.
            torrentText = "Finding peers for the torrent"
            torrentHash = torrent.infoHash
            let folder = app.container.caches.appendingPathComponent("torrents")
            let upload = settings.torrentUpload ? 0 : TorrentEngine.defaultUploadLimit
            loadTask = Task { [weak self] in
                do {
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    try await TorrentEngine.shared.start(dataDir: folder, uploadLimit: upload)
                    let url = try await TorrentEngine.shared.play(infoHash: torrent.infoHash, fileIdx: torrent.fileIdx,
                                                                  trackers: torrent.trackers, name: torrent.name)
                    guard !Task.isCancelled else { return }
                    self?.open(url, headers: [:], startAt: startAt)
                } catch {
                    guard let self, !Task.isCancelled, !(error is CancellationError) else { return }
                    if !self.tryNext() { self.showError("This torrent does not start (\(error.localizedDescription)).") }
                }
            }
        } else if channels.indices.contains(channelIndex) {
            let channel = channels[channelIndex]
            guard let url = URL(string: channel.url) else { return badLink() }
            open(url, headers: channel.headers, startAt: 0)
        }
    }

    private func badLink() {
        if !tryNext() { showError(PlayerErrors.describe(.other(name: "bad link"))) }
    }

    /// Opens `url` in a new VLC player at `startAt` milliseconds.
    private func open(_ url: URL, headers: [String: String], startAt: Int) {
        guard !closed, let media = VLCMedia(url: url) else { return badLink() }
        current = (url, headers)
        resumeAt = startAt
        let buffer = PlayerBuffer.of(isTorrent: video?.torrent != nil)
        media.addOption(":network-caching=\(buffer.networkCachingMs)")
        // A dropped connection reconnects inside VLC before the player sees a fault.
        media.addOption(":http-reconnect")
        let request = VLCOptions.headers(headers)
        request.options.forEach(media.addOption)
        if let host = url.host {
            for cookie in request.cookies { _ = media.storeCookie(cookie, forHost: host, path: "/") }
        }
        if startAt > 0 { media.addOption(":start-time=\(Double(startAt) / 1000)") }
        if !settings.audioLanguage.isEmpty { media.addOption(":audio-language=\(settings.audioLanguage)") }
        // VLC chooses an embedded subtitle of the language. "none" stops a fall back to another language.
        media.addOption(settings.subtitlesOn ? ":sub-language=\(settings.subtitleLanguage.isEmpty ? "none" : settings.subtitleLanguage)" : ":sub-language=none")
        let player = makePlayer()
        player.media = media
        player.play()
    }

    private func makePlayer() -> VLCMediaPlayer {
        releasePlayer()
        generation += 1
        let number = generation
        log.clear()
        let player = VLCMediaPlayer(options: lookOptions)
        player.libraryInstance.loggers = [log]
        let bridge = PlayerEventBridge { [weak self] event in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.handle(event, from: number) }
            }
        }
        player.delegate = bridge
        player.drawable = surface
        surface.media.attach(player, live: isLive)
        self.player = player
        self.bridge = bridge
        playerReady = false
        playerEnded = false
        length = 0
        slaveTracks = [:]
        pendingSlaves = []
        applyFilter()
        applyAspect()
        return player
    }

    private func releasePlayer() {
        guard let player else { return }
        surface.media.attach(nil, live: isLive)
        // A new number, so that the events of this player, such as its stop, go nowhere.
        let number = generation
        generation += 1
        retired[number] = player
        player.stop()
        self.player = nil
        // A player that never says that it stopped goes after a few seconds.
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            self?.retired[number] = nil
        }
    }

    private func stopTorrent() {
        guard let hash = torrentHash else { return }
        torrentHash = nil
        Task.detached { await TorrentEngine.shared.stop(infoHash: hash) }
    }

    /// Opens the current link again at `at` milliseconds, in a new player.
    private func reopen(at: Int, paused: Bool = false) {
        guard let current else { return load() }
        pauseWhenReady = paused
        open(current.url, headers: current.headers, startAt: max(at, 0))
    }

    /// Plays another video in this player. The state of the old video goes away.
    func replace(_ next: VideoPlayback) {
        let oldHash = torrentHash
        torrentHash = nil
        loadTask?.cancel()
        nextTask?.cancel()
        releasePlayer()
        resetState()
        current = nil
        video = next
        labelUntil = Date().addingTimeInterval(Self.labelTime)
        prepareSubtitles()
        // The old torrent stops before the new one starts, because it can be the same torrent.
        loadTask = Task { [weak self] in
            if let oldHash { await TorrentEngine.shared.stop(infoHash: oldHash) }
            guard let self, !self.closed, !Task.isCancelled else { return }
            self.load()
        }
    }

    private func resetState() {
        everReady = false
        retries = 0
        faultAt = 0
        resumeAt = 0
        position = 0
        duration = 0
        error = nil
        torrentText = nil
        skips = []
        skipTimesAsked = false
        autoSkipped = []
        countdownEnds = nil
        countdownLeft = nil
        countdownCancelled = false
        preparedNext = nil
        preparing = false
        subtitleDelayMs = 0
        wantedSubtitle = nil
        wantedAudio = nil
        subtitleChoices = []
        audioChoices = []
        ambient = nil
        ambientShown = []
        buffering = true
        playing = false
    }

    private func prepareSubtitles() {
        let subtitles = video?.subtitles ?? []
        addonSubtitles = SubtitleLabels.labels(SubtitleLabels.arrange(subtitles, preferred: settings.subtitleLanguage))
    }

    // MARK: Events of VLC

    private func handle(_ event: PlayerEvent, from number: Int) {
        guard number == generation, !closed else {
            if case .state(let state) = event, state == .stopped { retired[number] = nil }
            return
        }
        switch event {
        case .state(let state): stateChanged(state)
        case .buffering(let progress): buffering = progress < 100 && player?.state != .paused
        case .time:
            updateTime()
            checkResume()
        case .length(let value):
            length = max(Int(value), 0)
            surface.media.update(length: Int64(length))
            updateTime()
            checkResume()
        case .trackAdded(let id, let isText):
            if isText, !pendingSlaves.isEmpty { slaveTracks[pendingSlaves.removeFirst()] = id }
            refreshTracks()
        case .tracksChanged: refreshTracks()
        case .snapshot: readSnapshot()
        }
    }

    private func stateChanged(_ state: VLCMediaPlayerState) {
        switch state {
        case .opening:
            buffering = true
        case .playing:
            playing = true
            checkReady()
        case .paused:
            playing = false
            buffering = false
        case .error, .stopped:
            playing = false
            // VLC stops a player after an error. The stop of the same player is not a second fault.
            guard !playerEnded else { break }
            playerEnded = true
            if state == .error {
                let lines = log.lines
                failed(FaultLog.fault(lines), reason: FaultLog.reason(lines))
            } else {
                ended()
            }
        default:
            break
        }
        UIApplication.shared.isIdleTimerDisabled = playing
        pictureInPicture?.invalidatePlaybackState()
        if !playing { showOverlay() }
    }

    private func updateTime() {
        guard let player, player.state != .stopped else { return }
        duration = max(length, Int(player.media?.length.intValue ?? 0))
        position = max(Int(player.time.intValue), 0)
        checkReady()
        positionChanged()
    }

    /// The first frame of a player, or the first sound of a stream with no picture.
    private func checkReady() {
        guard !playerReady, let player, player.state == .playing, let media = player.media else { return }
        let stats = media.statistics
        guard stats.displayedPictures > 0 || stats.playedAudioBuffers > 0 else { return }
        playerReady = true
        if !everReady {
            // A reconnect that is ready for a moment and fails at the same place is not a recovery.
            // The count of tries goes back to 0 only after good playback past the fault.
            retries = 0
            everReady = true
            if let video { app?.streamPlayed(video) }
        }
        error = nil
        buffering = false
        applyDelays()
        applyFilter()
        startTracks()
        updateVideoRect()
        if pauseWhenReady {
            pauseWhenReady = false
            player.pause()
        }
    }

    /// A saved position past the end of this source, less a margin, starts the video from the beginning.
    private func checkResume() {
        guard !everReady, resumeAt > 0, duration > 0, !Resume.fits(position: resumeAt, duration: duration) else { return }
        resumeAt = 0
        seek(to: 0)
    }

    private func ended() {
        guard video != nil else {
            // A live channel must not end.
            return failed(.network, reason: FaultLog.reason(log.lines))
        }
        if everReady && !PlayerErrors.endedEarly(position: position, duration: duration) {
            position = duration
            saveProgress()
            if settings.autoplayNext && !countdownCancelled {
                countdownEnds = nil
                countdownLeft = nil
                countdownCancelled = true
                changeEpisode(1)
            }
            return
        }
        // VLC stops a stream that drops in the middle, often with no error line.
        let lines = log.lines
        var fault = FaultLog.fault(lines)
        if case .other = fault { fault = .network }
        failed(fault, reason: FaultLog.reason(lines))
    }

    private func failed(_ fault: PlaybackFault, reason: String?) {
        if !everReady && tryNext() { return }
        if let video, everReady {
            faultAt = max(faultAt, position)
            switch PlayerErrors.midStream(fault, retries: retries, hasNextSource: !video.fallbacks.isEmpty) {
            case .reconnect:
                retries += 1
                show("Reconnecting")
                return reopen(at: position)
            case .skipAhead:
                retries += 1
                show("Skipping damaged data")
                return reopen(at: position + PlayerErrors.skipMs)
            case .nextSource:
                // The progress is saved first, so the next source starts at the same position.
                saveProgress()
                if tryNext(midStream: true) { return }
            case .stop:
                break
            }
        } else if video != nil, PlayerErrors.shouldRetry(fault, retries: retries) {
            retries += 1
            show("Reconnecting")
            return reopen(at: resumeAt)
        }
        let text = everReady ? PlayerErrors.describeMidStream(fault) : PlayerErrors.describe(fault)
        showError(text + (reason.map { " (\($0))" } ?? ""))
    }

    private func showError(_ text: String) {
        error = text
        buffering = false
        overlayVisible = true
    }

    /// Marks this stream as one that did not start, then plays the next best one. False when no stream is left.
    @discardableResult
    private func tryNext(midStream: Bool = false) -> Bool {
        guard let video, let app else { return false }
        app.streamFailed(video)
        guard let next = video.fallbacks.first else { return false }
        let following = VideoPlayback(meta: video.meta, videoId: video.videoId, label: video.label, episodes: video.episodes,
                                      listed: next, subtitles: video.subtitles, fallbacks: Array(video.fallbacks.dropFirst()))
        let name = following.sourceLabel ?? next.addon.name
        replace(following)
        show(midStream ? "That stream stopped. Going on with \(name)" : "That stream did not start. Trying \(name)")
        return true
    }

    // MARK: The clock of the screen

    private func onTick() {
        guard !closed else { return }
        ticks += 1
        tickCountdown()
        let now = Date()
        if ticks % 2 == 0 {
            updateTime()
            if retries > 0 && position > faultAt + PlayerErrors.recoveredMs { retries = 0 }
            if overlayVisible && playing && error == nil && now > overlayUntil { overlayVisible = false }
            if message != nil && now > messageUntil { message = nil }
            labelVisible = now < labelUntil || overlayVisible
            copyAmbient()
        }
        if ticks % 4 == 0, let hash = torrentHash {
            Task { [weak self] in
                guard let stats = await TorrentEngine.shared.stats(infoHash: hash), self?.torrentHash == hash else { return }
                self?.torrentText = TorrentMath.status(peers: stats.peers, downloadRate: stats.downloadRate,
                                                       fileDone: stats.fileDone, fileSize: stats.fileSize)
            }
        }
        if ticks % (Self.saveInterval * 4) == 0 && playing { saveProgress() }
    }

    private func tickCountdown() {
        guard let ends = countdownEnds else { return }
        let left = ends.timeIntervalSinceNow
        countdownLeft = max(Int(left.rounded(.up)), 0)
        guard left <= 0 else { return }
        countdownEnds = nil
        countdownLeft = nil
        countdownCancelled = true
        markWatched()
        changeEpisode(1)
    }

    /// Auto-skip, the "Next episode" countdown, and the search for the next episode follow the position.
    private func positionChanged() {
        guard let video, let app else { return }
        if duration > 0 && !skipTimesAsked {
            skipTimesAsked = true
            let id = video.videoId
            let known = duration
            Task { [weak self] in
                let found = await app.container.skipTimes.forVideo(id, durationMs: known)
                if self?.video?.videoId == id { self?.skips = found }
            }
        }
        if settings.autoSkipIntro, let range = Skip.autoSkip(skips, position: position, done: autoSkipped) {
            autoSkipped.insert(range.start)
            seek(to: range.end)
            show(range.kind.skippedMessage)
        }
        let start = Skip.countdownStart(skips, duration: duration)
        if hasNext && settings.autoplayNext && !countdownCancelled && countdownEnds == nil, let start, position >= start {
            countdownEnds = Date().addingTimeInterval(Self.countdownLength)
            countdownLeft = Int(Self.countdownLength)
        }
        // Going back before the start of the countdown stops it.
        if countdownEnds != nil, let start, position < start {
            countdownEnds = nil
            countdownLeft = nil
        }
        // About a minute before the countdown, find the next episode, so that it starts at once.
        if hasNext, video.addonUrl != nil, preparedNext == nil, !preparing,
           Skip.shouldPrepareNext(skips, duration: duration, position: position),
           let target = Episodes.neighbour(video.episodes, of: video.videoId, step: 1) {
            preparing = true
            Task { [weak self] in
                let found = await app.sameSourcePlayback(from: video, target: target, label: Episodes.label(target))
                guard let self, self.video?.videoId == video.videoId else { return }
                self.preparedNext = (target.id, found)
                self.preparing = false
            }
        }
    }

    // MARK: Actions

    /// Shows the controls, and a short message when `text` is not nil.
    func show(_ text: String? = nil) {
        showOverlay()
        if let text {
            message = text
            messageUntil = Date().addingTimeInterval(Self.messageTime)
        }
    }

    func showOverlay() {
        overlayVisible = true
        labelVisible = true
        overlayUntil = Date().addingTimeInterval(Self.overlayTime)
    }

    func toggleOverlay() {
        if overlayVisible && error == nil {
            overlayVisible = false
            labelVisible = Date() < labelUntil
        } else {
            showOverlay()
        }
    }

    func togglePlay() {
        guard let player else { return }
        if player.isPlaying { player.pause() } else { player.play() }
        showOverlay()
    }

    func seek(by delta: Int) {
        guard !isLive else { return }
        seek(to: max(position + delta, 0))
        showOverlay()
    }

    func seek(to ms: Int) {
        guard let player, player.isSeekable else { return }
        let target = duration > 0 ? min(ms, duration) : ms
        player.time = VLCTime(int: Int32(clamping: target))
        position = target
    }

    /// Goes to the end of the opening, ending, or recap. With no times, it jumps 85 seconds.
    func skip() {
        switch Skip.action(skips, position: position) {
        case .seekTo(let target, let kind):
            if kind == .ending { markWatched() }
            seek(to: target)
            show(kind.skippedMessage)
        case .jump(let by):
            seek(to: position + by)
            show(Skip.fallbackMessage)
        }
    }

    /// The text of the skip prompt while a part that the viewer can skip plays.
    var skipPrompt: String? { Skip.current(skips, position: position)?.kind.promptLabel }

    /// The text of the skip button of the controls: the part that it skips, or the jump.
    var skipButtonLabel: String {
        switch Skip.action(skips, position: position) {
        case .seekTo(_, let kind): kind.promptLabel
        case .jump(let by): "Skip \(by / 1000) s"
        }
    }

    func playNextNow() {
        guard countdownEnds != nil else { return }
        countdownEnds = Date()
        tickCountdown()
    }

    func cancelCountdown() {
        countdownEnds = nil
        countdownLeft = nil
        countdownCancelled = true
    }

    /// The next or the previous episode, or channel.
    func changeEpisode(_ step: Int) {
        guard let app else { return }
        guard let video else {
            guard !channels.isEmpty else { return }
            channelIndex = ((channelIndex + step) % channels.count + channels.count) % channels.count
            show()
            releasePlayer()
            resetState()
            current = nil
            return load()
        }
        guard let target = Episodes.neighbour(video.episodes, of: video.videoId, step: step) else {
            return show(step > 0 ? "This is the last episode" : "This is the first episode")
        }
        saveProgress()
        let label = Episodes.label(target)
        let list = Route.streams(VideoRequest(meta: video.meta, videoId: target.id, label: label, episodes: video.episodes))
        // The next episode was found before the end of this one, so it starts at once.
        if let ready = preparedNext, ready.id == target.id {
            if let next = ready.playback { replace(next) } else { app.closePlayer(opening: list) }
            return
        }
        show("Loading \(label)")
        guard video.addonUrl != nil else { return app.closePlayer(opening: list) }
        // The next episode plays from the same source, with no stop at the list of streams.
        nextTask?.cancel()
        nextTask = Task { [weak self] in
            let found = await app.sameSourcePlayback(from: video, target: target, label: label)
            guard let self, !Task.isCancelled, !self.closed, self.video?.videoId == video.videoId else { return }
            if let found { self.replace(found) } else { app.closePlayer(opening: list) }
        }
    }

    /// Closes the player and opens the list of streams of this video.
    func chooseSource() {
        saveProgress()
        guard let app else { return }
        if let video { app.chooseSource(for: video) } else { app.closePlayer() }
    }

    func saveProgress() {
        // A stream that never played has no position of the viewer. Its end must not mark the video as watched.
        guard !closed, let video, everReady, duration > 0, let app else { return }
        app.saveProgress(videoId: video.videoId, meta: video.meta, label: video.label, position: position, duration: duration)
    }

    private func markWatched() {
        guard let video else { return }
        app?.markWatched(video.videoId)
    }

    // MARK: Options

    func selectSubtitle(_ kind: TrackChoice.Kind) {
        wantedSubtitle = kind
        applySubtitle(kind)
    }

    private func applySubtitle(_ kind: TrackChoice.Kind) {
        guard let player else { return }
        switch kind {
        case .off:
            player.deselectAllTextTracks()
        case .track(let id):
            player.textTracks.first { $0.trackId == id }?.isSelectedExclusively = true
        case .addon(let link):
            if let id = slaveTracks[link], let track = player.textTracks.first(where: { $0.trackId == id }) {
                track.isSelectedExclusively = true
            } else if let url = URL(string: link) {
                pendingSlaves.append(link)
                _ = player.addPlaybackSlave(url, type: .subtitle, enforce: true)
            }
        }
        subtitleSelected = kind
    }

    func selectAudio(_ kind: TrackChoice.Kind) {
        wantedAudio = kind
        guard let player, case .track(let id) = kind else { return }
        player.audioTracks.first { $0.trackId == id }?.isSelectedExclusively = true
        audioSelected = kind
    }

    func shiftSubtitleDelay(_ direction: Int) {
        subtitleDelayMs = Timing.step(subtitleDelayMs, direction: direction, step: Timing.subtitleStep, limit: Timing.subtitleLimit)
        player?.currentVideoSubTitleDelay = subtitleDelayMs * 1000
    }

    func shiftAudioDelay(_ direction: Int) {
        let next = Timing.step(settings.audioDelayMs, direction: direction, step: Timing.audioStep, limit: Timing.audioLimit)
        app?.updateSettings { $0.audioDelayMs = next }
    }

    func updateSettings(_ change: (inout ViewerSettings) -> Void) {
        app?.updateSettings(change)
    }

    private func applyDelays() {
        player?.currentVideoSubTitleDelay = subtitleDelayMs * 1000
        player?.currentAudioPlaybackDelay = settings.audioDelayMs * 1000
    }

    /// The first tracks of a new player: the choice of the viewer, or else the settings.
    private func startTracks() {
        refreshTracks()
        if let wantedAudio { selectAudio(wantedAudio) }
        if let wantedSubtitle {
            applySubtitle(wantedSubtitle)
        } else if !settings.subtitlesOn {
            applySubtitle(.off)
        } else if player?.textTracks.contains(where: \.isSelected) != true {
            // No embedded track of the language: the first addon subtitle of the language plays.
            let wanted = SubtitleLabels.languageName(settings.subtitleLanguage)
            if let match = addonSubtitles.first(where: { SubtitleLabels.languageName($0.subtitle.lang).hasPrefix(wanted) }) {
                applySubtitle(.addon(match.subtitle.url))
            }
        }
        refreshTracks()
    }

    private func refreshTracks() {
        guard let player else { return }
        let slaves = Set(slaveTracks.values)
        let text = player.textTracks
        let embedded = text.filter { !slaves.contains($0.trackId) }
        subtitleChoices = [TrackChoice(kind: .off, label: "Off")]
            + zip(embedded, Self.labels(embedded)).map { TrackChoice(kind: .track($0.trackId), label: $1) }
            + addonSubtitles.map { TrackChoice(kind: .addon($0.subtitle.url), label: $0.label) }
        if let selected = text.first(where: \.isSelected) {
            subtitleSelected = slaveTracks.first { $0.value == selected.trackId }.map { .addon($0.key) } ?? .track(selected.trackId)
        } else if pendingSlaves.isEmpty {
            subtitleSelected = .off
        }
        let audio = player.audioTracks
        audioChoices = zip(audio, Self.labels(audio)).map { TrackChoice(kind: .track($0.trackId), label: $1) }
        audioSelected = audio.first(where: \.isSelected).map { .track($0.trackId) }
    }

    /// The language of each track, or its name, or its number. Two tracks of one language get a number.
    private static func labels(_ tracks: [VLCMediaPlayer.Track]) -> [String] {
        let names = tracks.enumerated().map { index, track in
            if let language = track.language, !language.isEmpty { return SubtitleLabels.languageName(language) }
            return track.trackName.isEmpty ? "Track \(index + 1)" : track.trackName
        }
        let totals = Dictionary(names.map { ($0, 1) }, uniquingKeysWith: +)
        var seen: [String: Int] = [:]
        return names.map { name in
            seen[name, default: 0] += 1
            return totals[name, default: 0] > 1 ? "\(name) \(seen[name, default: 1])" : name
        }
    }

    private func settingsChanged(_ value: ViewerSettings) {
        let old = settings
        settings = value
        if value.videoFilter != old.videoFilter { applyFilter() }
        if value.sideBars != old.sideBars { applyAspect() }
        if value.audioDelayMs != old.audioDelayMs { player?.currentAudioPlaybackDelay = value.audioDelayMs * 1000 }
        let look = VLCOptions.subtitles(value)
        guard look != lookOptions else { return }
        lookOptions = look
        lookTask?.cancel()
        lookTask = Task { [weak self] in
            try? await Task.sleep(for: Self.lookSettle)
            guard let self, !Task.isCancelled, !self.closed, self.current != nil else { return }
            // VLC reads the look of the text when the player starts, so the video starts again at the same place.
            self.reopen(at: self.position, paused: !self.playing)
        }
    }

    /// The colour part of the filter with the adjust filter of VLC. The tint is drawn over the video.
    private func applyFilter() {
        guard let player else { return }
        let filter = player.adjustFilter
        guard let adjust = VideoAdjust.of(settings.videoFilter) else {
            filter.isEnabled = false
            return
        }
        filter.contrast.value = NSNumber(value: adjust.contrast)
        filter.brightness.value = NSNumber(value: adjust.brightness)
        filter.saturation.value = NSNumber(value: adjust.saturation)
        filter.hue.value = NSNumber(value: adjust.hue)
        filter.gamma.value = NSNumber(value: adjust.gamma)
        filter.isEnabled = true
    }

    /// Stretch gives the picture the shape of the screen. The other choices keep the shape of the video.
    private func applyAspect() {
        guard let player else { return }
        if settings.sideBars == .stretch, viewSize.width > 0, viewSize.height > 0 {
            player.videoAspectRatio = "\(Int(viewSize.width.rounded())):\(Int(viewSize.height.rounded()))"
        } else {
            player.videoAspectRatio = nil
        }
        updateVideoRect()
    }

    private func layoutChanged(_ size: CGSize) {
        guard size != viewSize else { return }
        viewSize = size
        applyAspect()
    }

    // MARK: Ambient side bars

    /// The place of the picture in the view, so that the ambient fill covers only the bars.
    private func updateVideoRect() {
        guard let player, viewSize.width > 0, viewSize.height > 0 else { return }
        let size = player.videoSize
        guard size.width > 0, size.height > 0 else {
            ambientNeeded = false
            videoRect = nil
            return
        }
        var ratio: Float = 1
        if let track = player.videoTracks.first(where: \.isSelected)?.video,
           track.sourceAspectRatio > 0, track.sourceAspectRatioDenominator > 0 {
            ratio = Float(track.sourceAspectRatio) / Float(track.sourceAspectRatioDenominator)
        }
        ambientNeeded = settings.sideBars == .ambient
            && Ambient.needed(videoWidth: Int(size.width), videoHeight: Int(size.height), pixelRatio: ratio,
                              screenWidth: Int(viewSize.width), screenHeight: Int(viewSize.height))
        let shape = size.width * CGFloat(ratio) / size.height
        let width = min(viewSize.width, viewSize.height * shape)
        let height = width / shape
        videoRect = CGRect(x: (viewSize.width - width) / 2, y: (viewSize.height - height) / 2, width: width, height: height)
        if !ambientNeeded {
            ambient = nil
            ambientShown = []
        }
    }

    private var snapshotPath: String {
        (app?.container.caches ?? FileManager.default.temporaryDirectory).appendingPathComponent("ambient.png").path
    }

    /// A few times a second, VLC writes a tiny copy of the frame. A paused video needs one copy only.
    private func copyAmbient() {
        guard let player, playerReady else { return }
        if videoRect == nil { updateVideoRect() }
        guard ambientNeeded else { return }
        if player.isPlaying || !ambientCopied {
            player.saveVideoSnapshot(at: snapshotPath, withWidth: Int32(Ambient.width), andHeight: Int32(Ambient.height))
        }
        if player.isPlaying { ambientCopied = false }
    }

    private func readSnapshot() {
        guard ambientNeeded, let image = UIImage(contentsOfFile: snapshotPath)?.cgImage,
              let pixels = Self.pixels(image) else { return }
        ambientCopied = true
        let soft = Ambient.blur(pixels, width: Ambient.width, height: Ambient.height, radius: 2)
        // A new picture only for a clear change, such as a new scene.
        guard Ambient.change(soft, ambientShown) >= Ambient.minChange, let made = Self.image(soft) else { return }
        ambientShown = soft
        ambient = made
    }

    private static let pixelInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue

    /// The frame as ARGB numbers at the size of `Ambient`.
    private static func pixels(_ image: CGImage) -> [UInt32]? {
        var pixels = [UInt32](repeating: 0, count: Ambient.width * Ambient.height)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: Ambient.width, height: Ambient.height, bitsPerComponent: 8,
                                          bytesPerRow: Ambient.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: pixelInfo)
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: Ambient.width, height: Ambient.height))
            return true
        }
        return drawn ? pixels : nil
    }

    private static func image(_ pixels: [UInt32]) -> UIImage? {
        var copy = pixels
        return copy.withUnsafeMutableBytes { buffer in
            CGContext(data: buffer.baseAddress, width: Ambient.width, height: Ambient.height, bitsPerComponent: 8,
                      bytesPerRow: Ambient.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: pixelInfo)?
                .makeImage().map { UIImage(cgImage: $0) }
        }
    }

    // MARK: Picture in Picture

    private func pictureInPictureReady(_ controller: any VLCPictureInPictureWindowControlling) {
        pictureInPicture = controller
        pictureInPicturePossible = true
        controller.stateChangeEventHandler = { [weak self] started in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.pictureInPictureActive = started }
            }
        }
    }

    func togglePictureInPicture() {
        guard let pictureInPicture else { return }
        if pictureInPictureActive { pictureInPicture.stopPictureInPicture() } else { pictureInPicture.startPictureInPicture() }
    }

    /// The video goes on in a small window when the viewer leaves the app.
    private func appWillResignActive() {
        guard playing, !pictureInPictureActive else { return }
        pictureInPicture?.startPictureInPicture()
    }

    private func appDidBecomeActive() {
        if pictureInPictureActive { pictureInPicture?.stopPictureInPicture() }
    }
}
