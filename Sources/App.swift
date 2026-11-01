import SwiftUI
import AVKit
import PhotosUI
import UniformTypeIdentifiers
import MobileVLCKit

let bg = Color(red: 0.051, green: 0.051, blue: 0.059)
let panel = Color(red: 0.09, green: 0.09, blue: 0.102)
let keyFill = Color(red: 0.133, green: 0.133, blue: 0.149)
let ink = Color(red: 0.957, green: 0.945, blue: 0.918)
let dim = Color(red: 0.553, green: 0.541, blue: 0.518)
let hairline = Color(red: 0.165, green: 0.165, blue: 0.18)
let accent = Color(red: 1.0, green: 0.353, blue: 0.122)

@main
struct ReelApp: App {
    init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
    }
    var body: some Scene {
        WindowGroup { RootView().preferredColorScheme(.dark) }
    }
}

func fmt(_ s: Double) -> String {
    let n = Int(max(0, s.isFinite ? s : 0))
    return String(format: "%d:%02d:%02d", n / 3600, n % 3600 / 60, n % 60)
}

func setOrientation(landscape: Bool) {
    guard let scene = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene }).first else { return }
    let mask: UIInterfaceOrientationMask = landscape ? .landscape : .portrait
    scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in }
}

// MARK: - Logo
struct Logo: View {
    var size: CGFloat
    var body: some View {
        let s = size / 100
        ZStack {
            accent
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 4 * s, style: .continuous)
                    .fill(bg)
                    .frame(width: 22 * s, height: 26 * s)
                    .position(x: (21 + 29 * CGFloat(i)) * s, y: 51 * s)
            }
            RoundedRectangle(cornerRadius: 1.5 * s)
                .fill(Color.white)
                .frame(width: 3 * s, height: 56 * s)
                .position(x: 50 * s, y: 50 * s)
            Path { p in
                p.move(to: CGPoint(x: 43 * s, y: 16 * s))
                p.addLine(to: CGPoint(x: 57 * s, y: 16 * s))
                p.addLine(to: CGPoint(x: 50 * s, y: 25 * s))
                p.closeSubpath()
            }.fill(Color.white)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
    }
}

// MARK: - Fotoğraflar'dan video alma
struct Movie: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { m in
            SentTransferredFile(m.url)
        } importing: { received in
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let dest = dir.appendingPathComponent(received.file.lastPathComponent)
            try FileManager.default.copyItem(at: received.file, to: dest)
            return Movie(url: dest)
        }
    }
}

// MARK: - Ana ekran
struct RootView: View {
    @State private var url: URL?
    @State private var item: PhotosPickerItem?
    @State private var importing = false
    @State private var loading = false

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            if let url {
                PlayerScreen(url: url) { self.url = nil }.id(url)
            } else {
                home
            }
        }
        .fileImporter(isPresented: $importing,
                      allowedContentTypes: [.movie, .video, .audiovisualContent, .data]) { r in
            if case .success(let u) = r {
                _ = u.startAccessingSecurityScopedResource()
                url = u
            }
        }
        .onChange(of: item) { newItem in
            guard let newItem else { return }
            loading = true
            Task {
                if let m = try? await newItem.loadTransferable(type: Movie.self) { url = m.url }
                loading = false
                item = nil
            }
        }
    }

    var home: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                Logo(size: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reel").font(.system(size: 22, weight: .bold))
                    Text("VİDEO OYNATICI").font(.system(size: 11, weight: .semibold))
                        .tracking(1.6).foregroundColor(dim)
                }
            }
            Spacer()
            Text("Her kareyi").font(.system(size: 44, weight: .bold)).tracking(-1.6)
            Text("yakala.").font(.system(size: 44, weight: .bold)).tracking(-1.6)
                .foregroundColor(accent)
            Text("Saatlik videolarda saniyesine kadar sar. Her formatı aç. Hiçbir şey internete yüklenmez.")
                .font(.system(size: 15)).foregroundColor(dim)
                .padding(.top, 12).padding(.bottom, 24)
            if loading {
                ProgressView().frame(maxWidth: .infinity).frame(height: 54)
            } else {
                HStack(spacing: 10) {
                    PhotosPicker(selection: $item, matching: .videos) {
                        Text("Fotoğraflar").font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity).frame(height: 54)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(accent))
                    }
                    Button { importing = true } label: {
                        Text("Dosyalar").font(.system(size: 17, weight: .bold))
                            .foregroundColor(ink)
                            .frame(maxWidth: .infinity).frame(height: 54)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(panel))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(hairline, lineWidth: 1))
                    }
                }
            }
        }
        .padding(.horizontal, 22).padding(.top, 28).padding(.bottom, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Motorlar
protocol Engine: AnyObject {
    var onTime: ((Double) -> Void)? { get set }
    var onDuration: ((Double) -> Void)? { get set }
    var onPlaying: ((Bool) -> Void)? { get set }
    var onFailed: (() -> Void)? { get set }
    var onSize: ((CGSize) -> Void)? { get set }
    func attach(_ host: UIView)
    func play(rate: Float)
    func pause()
    func setRate(_ r: Float)
    func seek(_ t: Double, exact: Bool)
    func shutdown()
}

final class PlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

struct SeekRequest { var t: Double; var exact: Bool }

// iPhone'un donanım motoru
final class AVEngine: NSObject, Engine {
    var onTime: ((Double) -> Void)?
    var onDuration: ((Double) -> Void)?
    var onPlaying: ((Bool) -> Void)?
    var onFailed: (() -> Void)?
    var onSize: ((CGSize) -> Void)?

    private let player: AVPlayer
    private let item: AVPlayerItem
    private var layerView: PlayerUIView?
    private var timeObs: Any?
    private var statusObs: NSKeyValueObservation?
    private var endObs: NSObjectProtocol?
    private var seeking = false
    private var pending: SeekRequest?
    private var checked = false

    init(asset: AVAsset) {
        item = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: item)
        player.automaticallyWaitsToMinimizeStalling = false
        super.init()
        timeObs = player.addPeriodicTimeObserver(
            forInterval: CMTime(value: 1, timescale: 30), queue: .main
        ) { [weak self] t in self?.onTime?(t.seconds) }
        statusObs = item.observe(\.status, options: [.new]) { [weak self] it, _ in
            DispatchQueue.main.async {
                if it.status == .failed { self?.onFailed?() }
            }
        }
        endObs = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in self?.onPlaying?(false) }
        Task { [weak self] in
            if let d = try? await asset.load(.duration) {
                await MainActor.run { self?.onDuration?(d.seconds) }
            }
        }
    }

    deinit { shutdown() }

    func attach(_ host: UIView) {
        let v = PlayerUIView(frame: host.bounds)
        v.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        v.backgroundColor = .black
        v.playerLayer.player = player
        v.playerLayer.videoGravity = .resizeAspect
        host.addSubview(v)
        layerView = v
    }

    func play(rate: Float) {
        player.defaultRate = rate
        player.play()
        player.rate = rate
        onPlaying?(true)
        if !checked {
            checked = true
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                await MainActor.run {
                    guard let self else { return }
                    if self.item.presentationSize == .zero && self.item.status != .failed {
                        self.onFailed?()
                    }
                }
            }
        }
    }

    func pause() { player.pause(); onPlaying?(false) }

    func setRate(_ r: Float) {
        player.defaultRate = r
        if player.rate != 0 { player.rate = r }
    }

    func seek(_ t: Double, exact: Bool) {
        pending = SeekRequest(t: t, exact: exact)
        if !seeking { runSeek() }
    }

    private func runSeek() {
        guard let p = pending else { return }
        pending = nil
        seeking = true
        let tol: CMTime = p.exact ? .zero : .positiveInfinity
        player.seek(to: CMTime(seconds: p.t, preferredTimescale: 600),
                    toleranceBefore: tol, toleranceAfter: tol) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.seeking = false
                if self.pending != nil { self.runSeek() }
            }
        }
    }

    func shutdown() {
        if let o = timeObs { player.removeTimeObserver(o); timeObs = nil }
        statusObs?.invalidate(); statusObs = nil
        if let e = endObs { NotificationCenter.default.removeObserver(e); endObs = nil }
        player.pause()
        layerView?.playerLayer.player = nil
        layerView?.removeFromSuperview()
        layerView = nil
    }
}

// Her formatı açan yedek motor
final class VLCEngine: NSObject, Engine, VLCMediaPlayerDelegate {
    var onTime: ((Double) -> Void)?
    var onDuration: ((Double) -> Void)?
    var onPlaying: ((Bool) -> Void)?
    var onFailed: (() -> Void)?
    var onSize: ((CGSize) -> Void)?

    private let player = VLCMediaPlayer()
    private var lastSeek = Date.distantPast
    private var lastLen = 0.0
    private var sized = false

    init(url: URL) {
        super.init()
        player.media = VLCMedia(url: url)
        player.delegate = self
    }

    deinit { shutdown() }

    func attach(_ host: UIView) { player.drawable = host }

    func play(rate: Float) {
        player.play()
        player.rate = rate
        onPlaying?(true)
    }

    func pause() { player.pause(); onPlaying?(false) }
    func setRate(_ r: Float) { player.rate = r }

    func seek(_ t: Double, exact: Bool) {
        if !exact && Date().timeIntervalSince(lastSeek) < 0.08 { return }
        lastSeek = Date()
        player.time = VLCTime(int: Int32(max(0, t) * 1000))
    }

    func shutdown() {
        player.delegate = nil
        player.stop()
        player.drawable = nil
    }

    func mediaPlayerTimeChanged(_ aNotification: Notification!) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let len = Double(self.player.media?.length.intValue ?? 0) / 1000
            if len > 0 && len != self.lastLen { self.lastLen = len; self.onDuration?(len) }
            if !self.sized {
                let s = self.player.videoSize
                if s.width > 0 && s.height > 0 { self.sized = true; self.onSize?(s) }
            }
            self.onTime?(Double(self.player.time.intValue) / 1000)
        }
    }

    func mediaPlayerStateChanged(_ aNotification: Notification!) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch self.player.state {
            case .playing: self.onPlaying?(true)
            case .paused, .stopped, .ended, .error: self.onPlaying?(false)
            default: break
            }
        }
    }
}

// MARK: - Küçük resimler (arka planda, sadece görünen kısım)
final class ThumbStore: ObservableObject {
    @Published var version = 0
    private(set) var images: [Int: CGImage] = [:]
    private let gen: AVAssetImageGenerator
    private var queue: [Int] = []
    private var failed = Set<Int>()
    private var running = false

    init(asset: AVAsset) {
        gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 200, height: 112)
        gen.requestedTimeToleranceBefore = .positiveInfinity
        gen.requestedTimeToleranceAfter = .positiveInfinity
    }

    // ids: en uzak önce, en yakın en sonda
    func want(_ ids: [Int]) {
        queue = ids.filter { images[$0] == nil && !failed.contains($0) }
        pump()
    }

    private func pump() {
        guard !running, let i = queue.popLast() else { return }
        running = true
        Task {
            let t = CMTime(seconds: Double(i) * 10, preferredTimescale: 600)
            let r = try? await gen.image(at: t)
            await MainActor.run {
                if let r { self.images[i] = r.image; self.version += 1 }
                else { self.failed.insert(i) }
                self.running = false
                self.pump()
            }
        }
    }
}

// MARK: - Model
final class Clock: ObservableObject { @Published var time = 0.0 }

final class PlayerModel: ObservableObject {
    let url: URL
    let name: String
    let clock = Clock()
    let host = UIView()
    let thumbs: ThumbStore
    @Published var duration = 0.0
    @Published var isPlaying = false
    @Published var fast = false
    @Published var baseRate: Float = 1
    @Published var scrubbing = false
    @Published var engineName = ""
    @Published var portraitVideo = false
    @Published var fps = 30.0
    private var engine: Engine?
    private var wasPlaying = false
    private var ignoreUntil = Date.distantPast
    private var fellBack = false
    private var key: String { "pos." + name }
    private var rate: Float { fast ? 2 : baseRate }

    init(url: URL) {
        self.url = url
        name = url.lastPathComponent
        thumbs = ThumbStore(asset: AVURLAsset(url: url))
        host.backgroundColor = .black
        UIApplication.shared.isIdleTimerDisabled = true
        choose()
    }

    deinit { engine?.shutdown() }

    private func choose() {
        let asset = AVURLAsset(url: url)
        Task {
            var ok = false
            var portrait = false
            var f = 30.0
            if let p = try? await asset.load(.isPlayable), p,
               let tracks = try? await asset.loadTracks(withMediaType: .video),
               let tr = tracks.first {
                ok = true
                if let size = try? await tr.load(.naturalSize),
                   let tf = try? await tr.load(.preferredTransform) {
                    let r = size.applying(tf)
                    portrait = abs(r.height) > abs(r.width)
                }
                if let nf = try? await tr.load(.nominalFrameRate), nf > 1 { f = Double(nf) }
            }
            let okF = ok, portraitF = portrait, fpsF = f
            await MainActor.run {
                self.portraitVideo = portraitF
                self.fps = fpsF
                if okF { self.startAV(asset) } else { self.startVLC() }
            }
        }
    }

    private func startAV(_ asset: AVAsset) {
        let e = AVEngine(asset: asset)
        e.onFailed = { [weak self] in self?.fallbackToVLC() }
        install(e, label: "AVPlayer")
    }

    private func startVLC() { install(VLCEngine(url: url), label: "VLC") }

    private func wire(_ e: Engine) {
        e.onTime = { [weak self] t in
            guard let self, !self.scrubbing, Date() > self.ignoreUntil else { return }
            if abs(t - self.clock.time) > 0.02 { self.clock.time = t }
        }
        e.onDuration = { [weak self] d in if d > 0 { self?.duration = d } }
        e.onPlaying = { [weak self] p in self?.isPlaying = p }
        e.onSize = { [weak self] s in self?.portraitVideo = s.height > s.width }
    }

    private func install(_ e: Engine, label: String) {
        wire(e)
        engine = e
        engineName = label
        e.attach(host)
        e.play(rate: baseRate)
        isPlaying = true
        let saved = UserDefaults.standard.double(forKey: key)
        if saved > 5 {
            clock.time = saved
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { e.seek(saved, exact: true) }
        }
    }

    private func fallbackToVLC() {
        guard !fellBack else { return }
        fellBack = true
        let t = clock.time
        engine?.shutdown()
        host.subviews.forEach { $0.removeFromSuperview() }
        let e = VLCEngine(url: url)
        wire(e)
        engine = e
        engineName = "VLC"
        e.attach(host)
        e.play(rate: rate)
        isPlaying = true
        if t > 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { e.seek(t, exact: true) }
        }
    }

    func play() {
        if duration > 0 && clock.time >= duration - 0.3 {
            clock.time = 0
            engine?.seek(0, exact: true)
        }
        engine?.play(rate: rate)
        isPlaying = true
    }

    func toggle() {
        if isPlaying { engine?.pause(); isPlaying = false } else { play() }
    }

    func setFast(_ on: Bool) {
        guard on != fast else { return }
        fast = on
        engine?.setRate(rate)
        if on && !isPlaying { play() }
    }

    func cycleSpeed() {
        let steps: [Float] = [0.5, 1, 1.5, 2]
        let i = steps.firstIndex(of: baseRate) ?? 1
        baseRate = steps[(i + 1) % steps.count]
        engine?.setRate(rate)
    }

    private func clamp(_ v: Double) -> Double {
        let top = duration > 0 ? duration : Double.greatestFiniteMagnitude
        return Swift.min(Swift.max(0, v), top)
    }

    func jump(_ s: Double) {
        clock.time = clamp(clock.time + s)
        ignoreUntil = Date().addingTimeInterval(0.5)
        engine?.seek(clock.time, exact: true)
    }

    func beginScrub() {
        wasPlaying = isPlaying
        if isPlaying { engine?.pause(); isPlaying = false }
        scrubbing = true
    }

    func scrub(_ d: Double, fine: Bool) {
        clock.time = clamp(clock.time + d)
        engine?.seek(clock.time, exact: fine)
    }

    func endScrub() {
        engine?.seek(clock.time, exact: true)
        ignoreUntil = Date().addingTimeInterval(0.5)
        scrubbing = false
        if wasPlaying { play() }
        save()
    }

    func save() {
        let v = (duration > 0 && clock.time > duration - 5) ? 0 : clock.time
        UserDefaults.standard.set(v, forKey: key)
    }

    func close() {
        save()
        engine?.shutdown()
        engine = nil
        UIApplication.shared.isIdleTimerDisabled = false
    }
}

// MARK: - Yardımcı görünümler
struct VideoLayer: UIViewRepresentable {
    let host: UIView
    func makeUIView(context: Context) -> UIView { host }
    func updateUIView(_ uiView: UIView, context: Context) {}
}

struct Press: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct TimeCode: View {
    @ObservedObject var clock: Clock
    var fps: Double
    var body: some View {
        let t = max(0, clock.time)
        let r = fps > 1 ? fps : 30
        let f = min(Int((t - floor(t)) * r), Int(r) - 1)
        (Text(fmt(t)).foregroundColor(ink)
         + Text(String(format: ":%02d", max(0, f))).foregroundColor(accent))
            .font(.system(size: 24, weight: .semibold, design: .monospaced))
    }
}

// MARK: - Film şeridi
struct Filmstrip: View {
    @ObservedObject var m: PlayerModel
    @ObservedObject var clock: Clock
    @ObservedObject var store: ThumbStore
    var onEnd: () -> Void
    @State private var lastX: CGFloat = 0
    @State private var hint = ""
    let pps = 9.95
    let sec = 10.0
    let th: CGFloat = 38
    let rh: CGFloat = 8

    var fade: LinearGradient {
        LinearGradient(stops: [
            .init(color: .clear, location: 0),
            .init(color: .black, location: 0.1),
            .init(color: .black, location: 0.9),
            .init(color: .clear, location: 1)
        ], startPoint: .leading, endPoint: .trailing)
    }

    func lastIndex() -> Int { max(0, Int((max(m.duration, 0.1) - 0.05) / sec)) }

    func request() {
        let c = Int(clock.time / sec)
        let lo = max(0, c - 8), hi = min(lastIndex(), c + 8)
        guard lo <= hi else { return }
        let ids = Array(lo...hi).sorted { abs($0 - c) > abs($1 - c) }
        store.want(ids)
    }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                Canvas { ctx, size in
                    _ = store.version
                    let t = clock.time
                    let half = size.width / 2 / pps
                    let last = lastIndex()
                    let a = min(last, max(0, Int(floor((t - half) / sec))))
                    let b = min(last, max(a, Int(floor((t + half) / sec))))
                    for i in a...b {
                        let x = size.width / 2 + (Double(i) * sec - t) * pps
                        let rect = CGRect(x: x, y: 0, width: sec * pps, height: size.height)
                        ctx.fill(Path(rect), with: .color(Color(white: 0.12)))
                        if let cg = store.images[i] {
                            ctx.drawLayer { l in
                                l.clip(to: Path(rect))
                                let ih = rect.width * CGFloat(cg.height) / CGFloat(cg.width)
                                let r = CGRect(x: rect.minX, y: rect.midY - ih / 2,
                                               width: rect.width, height: ih)
                                l.draw(Image(decorative: cg, scale: 1), in: r)
                            }
                        }
                        ctx.fill(Path(CGRect(x: rect.maxX - 1, y: 0, width: 1, height: size.height)),
                                 with: .color(.black))
                    }
                }
                .frame(height: th)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                Canvas { ctx, size in
                    let t = clock.time
                    let half = size.width / 2 / pps
                    let first = Int(floor((t - half) / 5))
                    let lastK = Int(ceil((t + half) / 5))
                    guard first <= lastK else { return }
                    for k in first...lastK where k >= 0 {
                        let x = size.width / 2 + (Double(k) * 5 - t) * pps
                        let h: CGFloat = k % 2 == 0 ? 7 : 4
                        ctx.fill(Path(CGRect(x: x, y: 1, width: 1, height: h)),
                                 with: .color(dim.opacity(0.8)))
                    }
                }
                .frame(height: rh)
            }
            .mask(fade)
            ZStack(alignment: .top) {
                Rectangle().fill(accent).frame(width: 2, height: th + rh)
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 9)).foregroundColor(accent).offset(y: -6)
            }
            .frame(height: th + rh)
            .allowsHitTesting(false)
            if !hint.isEmpty {
                Text(hint).font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white).shadow(color: .black, radius: 3)
                    .padding(.top, 4).allowsHitTesting(false)
            }
        }
        .frame(height: th + rh)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { v in
                    if !m.scrubbing { m.beginScrub(); lastX = 0 }
                    let up = max(0, -v.translation.height)
                    let f = up > 110 ? 0.1 : (up > 40 ? 0.35 : 1.0)
                    hint = f == 1 ? "" : (f == 0.35 ? "HASSAS · ⅓ HIZ" : "ÇOK HASSAS · 1/10 HIZ")
                    let dx = v.translation.width - lastX
                    lastX = v.translation.width
                    m.scrub(-Double(dx) * f / pps, fine: f < 1)
                }
                .onEnded { _ in hint = ""; m.endScrub(); onEnd() }
        )
        .onAppear { request() }
        .onChange(of: Int(clock.time / sec)) { _ in request() }
        .onChange(of: m.duration) { _ in request() }
    }
}

// MARK: - Oynatıcı ekranı
struct PlayerScreen: View {
    @StateObject private var m: PlayerModel
    let onClose: () -> Void
    @State private var showUI = true
    @State private var fs = false
    @State private var flash: String?
    @State private var flashID = 0
    @State private var hideID = 0

    init(url: URL, onClose: @escaping () -> Void) {
        _m = StateObject(wrappedValue: PlayerModel(url: url))
        self.onClose = onClose
    }

    var body: some View {
        GeometryReader { geo in
            let land = geo.size.width > geo.size.height
            let full = fs || land
            let ins = geo.safeAreaInsets
            VStack(spacing: 0) {
                if !full && showUI { topBar(full: false).padding(.horizontal, 6) }
                video
                    .overlay(alignment: .topLeading) { badge.padding(10).padding(.top, full ? ins.top : 0) }
                    .overlay(alignment: .top) {
                        if full && showUI {
                            topBar(full: true)
                                .padding(.horizontal, 8)
                                .padding(.leading, ins.leading).padding(.trailing, ins.trailing)
                                .padding(.top, ins.top + 4).padding(.bottom, 24)
                                .background(LinearGradient(colors: [.black.opacity(0.7), .clear],
                                                           startPoint: .top, endPoint: .bottom))
                        }
                    }
                    .overlay(alignment: .bottom) {
                        if full && showUI {
                            controls(solid: false)
                                .frame(maxWidth: 620)
                                .padding(.bottom, max(ins.bottom, 6) + 4)
                                .padding(.top, 28)
                                .frame(maxWidth: .infinity)
                                .background(LinearGradient(colors: [.clear, .black.opacity(0.88)],
                                                           startPoint: .top, endPoint: .bottom))
                        }
                    }
                if !full && showUI { controls(solid: true) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .ignoresSafeArea(edges: full ? .all : [])
        }
        .background(Color.black.ignoresSafeArea())
        .statusBarHidden(fs)
        .persistentSystemOverlays(fs ? .hidden : .automatic)
        .animation(.easeOut(duration: 0.22), value: showUI)
        .onDisappear { m.close() }
    }

    var video: some View {
        VideoLayer(host: m.host)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { m.jump(5); say("+5 sn") }
            .onTapGesture { showUI.toggle(); poke() }
            .onLongPressGesture(minimumDuration: 0.35, maximumDistance: 60, perform: {
                m.setFast(true)
            }, onPressingChanged: { pressing in
                if !pressing { m.setFast(false) }
            })
    }

    @ViewBuilder
    var badge: some View {
        if let f = flash {
            chip(f)
        } else if m.fast {
            chip("2×")
        }
    }

    func chip(_ t: String) -> some View {
        Text(t).font(.system(size: 12, weight: .bold)).foregroundColor(.white)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(accent))
            .allowsHitTesting(false)
    }

    func topBar(full: Bool) -> some View {
        ZStack {
            VStack(spacing: 1) {
                Text(m.name).font(.system(size: 13, weight: .semibold))
                    .foregroundColor(full ? ink : dim).lineLimit(1)
                Text(m.engineName).font(.system(size: 9)).foregroundColor(dim.opacity(0.7))
            }
            .padding(.horizontal, 60)
            HStack {
                Button { m.close(); onClose() } label: {
                    Image(systemName: "chevron.left").font(.system(size: 17, weight: .semibold))
                        .foregroundColor(ink).frame(width: 40, height: 40)
                }
                Spacer()
                Button { toggleFS() } label: {
                    Image(systemName: fs
                          ? "arrow.down.right.and.arrow.up.left"
                          : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ink).frame(width: 40, height: 40)
                }
            }
        }
        .frame(height: 40)
    }

    func controls(solid: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                TimeCode(clock: m.clock, fps: m.fps)
                Spacer()
                Text(fmt(m.duration))
                    .font(.system(size: 13, design: .monospaced)).foregroundColor(dim)
                Button { m.cycleSpeed(); poke() } label: {
                    Text(String(format: "%g×", Double(m.baseRate)))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(ink))
                }
                .padding(.leading, 8)
            }
            .padding(.horizontal, 14).padding(.bottom, 6)
            Filmstrip(m: m, clock: m.clock, store: m.thumbs, onEnd: { poke() })
                .padding(.horizontal, 12)
            HStack(spacing: 4) {
                ForEach([-60, -30, -5], id: \.self) { skip($0) }
                Button { m.toggle(); poke() } label: {
                    Image(systemName: m.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 19)).foregroundColor(.white)
                        .frame(width: 46, height: 46)
                        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(accent))
                }
                .buttonStyle(Press()).padding(.horizontal, 4)
                ForEach([5, 30, 60], id: \.self) { skip($0) }
            }
            .padding(.top, 6)
        }
        .padding(.vertical, 8)
        .background(solid ? panel : Color.clear)
    }

    func skip(_ s: Int) -> some View {
        Button {
            m.jump(Double(s))
            say(s > 0 ? "+\(s) sn" : "−\(-s) sn")
            poke()
        } label: {
            Text(s > 0 ? "+\(s)" : "−\(-s)")
                .font(.system(size: 13, weight: .semibold)).foregroundColor(ink)
                .frame(width: 40, height: 36)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(keyFill))
        }
        .buttonStyle(Press())
    }

    func toggleFS() {
        fs.toggle()
        if !m.portraitVideo { setOrientation(landscape: fs) }
        showUI = true
        poke()
    }

    // Tam ekranda kontroller 3,5 sn sonra kendiliğinden gizlenir
    func poke() {
        hideID += 1
        let id = hideID
        guard fs, showUI else { return }
        Task {
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            await MainActor.run {
                if id == hideID && fs && m.isPlaying && !m.scrubbing { showUI = false }
            }
        }
    }

    func say(_ s: String) {
        flash = s
        flashID += 1
        let id = flashID
        Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            await MainActor.run { if id == flashID { flash = nil } }
        }
    }
}
