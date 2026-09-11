import SwiftUI
import MapKit
import PhotosUI
import AVFoundation

@main struct GunmaJourneyApp: App {
    @StateObject private var store = JourneyStore()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store).tint(.teal)
                .alert("お知らせ", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
                    Button("閉じる", role: .cancel) { store.errorMessage = nil }
                } message: { Text(store.errorMessage ?? "") }
        }
    }
}
let gunmaRegion = MKCoordinateRegion(center: .init(latitude: 36.55, longitude: 139.10), span: .init(latitudeDelta: 1.0, longitudeDelta: 1.35))
struct RootView: View {
    @State private var selectedTab = 0
    var body: some View {
        TabView(selection: $selectedTab) {
            CollectionView().tabItem { Label("44の訪問先", systemImage: "square.grid.3x3") }.tag(0)
            JourneyMap().tabItem { Label("地図", systemImage: "map") }.tag(1)
            PhotoGallery().tabItem { Label("写真", systemImage: "photo.on.rectangle") }.tag(2)
            AboutView().tabItem { Label("使い方", systemImage: "info.circle") }.tag(3)
        }.preferredColorScheme(selectedTab == 0 || selectedTab == 2 ? .dark : nil)
    }
}
let stampColor = Color(red: 0.86, green: 0.25, blue: 0.14)
let readableGray = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.72, alpha: 1) : UIColor(white: 0.38, alpha: 1) })
func statusColor(_ status: VisitStatus) -> Color { status == .visited ? stampColor : status == .photo ? .indigo : readableGray }
func statusTitle(_ status: VisitStatus) -> String { status == .visited ? "訪問済み" : status == .photo ? "写真記録" : "未訪問" }
struct CollectionView: View {
    @EnvironmentObject var store: JourneyStore
    @State private var selected: Place?
    @State private var showingShare = false
    private let columns = 6
    private let rows = 8
    private let gap: CGFloat = 5
    private var collectionTitle: String {
        return "訪問 \(store.visitedCount) / 44"
    }
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let width = max(1, (geometry.size.width - 20 - gap * CGFloat(columns - 1)) / CGFloat(columns))
                let height = max(1, (geometry.size.height - 80 - gap * CGFloat(rows - 1)) / CGFloat(rows))
                VStack(spacing: 8) {
                    HStack {
                        Text(collectionTitle).font(.subheadline.bold()).foregroundStyle(.primary)
                        Spacer()
                    }.dynamicTypeSize(...DynamicTypeSize.large).frame(height: 24)
                    VStack(spacing: gap) {
                        ForEach(0..<rows, id: \.self) { row in
                            HStack(spacing: gap) {
                                ForEach(0..<columns, id: \.self) { column in
                                    let index = row * columns + column
                                    if index < store.places.count {
                                        let place = store.places[index]
                                        Button { selected = place } label: {
                                            VisitCard(place: place, width: width, height: height)
                                        }.buttonStyle(.plain)
                                            .accessibilityLabel("\(place.kana)、\(place.destination)、\(statusTitle(store.visit(place).status))")
                                    } else { Color.clear.frame(width: width, height: height).accessibilityHidden(true) }
                                }
                            }
                        }
                    }
                    Color.clear.frame(height: 24).accessibilityHidden(true)
                }.padding(.horizontal, 10).padding(.vertical, 8)
            }.background(Color.black)
                .navigationTitle("群馬をめぐる").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showingShare = true } label: { Image(systemName: "square.and.arrow.up") }
                            .accessibilityLabel("進捗を画像で共有")
                    }
                }
                .sheet(isPresented: $showingShare) { ProgressShareView() }
                .sheet(item: $selected) { DetailView(place: $0) }
        }
    }
}
struct VisitCard: View {
    let place: Place
    let width: CGFloat
    let height: CGFloat
    @EnvironmentObject var store: JourneyStore
    var exportImage: UIImage? = nil
    var loadsThumbnail = true
    var showsName = true
    @State private var loadedThumbnail: UIImage?
    private var thumbnail: UIImage? { loadsThumbnail ? loadedThumbnail : exportImage }
    private var cardName: String {
        switch place.id {
        case "g06": return "高崎市役所"
        case "g18": return "群馬県庁"
        case "g27": return "白衣大観音"
        case "g37": return "貫前神社"
        default: return place.destination
        }
    }
    private var cardLines: [String] {
        if place.id == "g34" { return ["いせさき", "明治館"] }
        let font = UIFont.systemFont(ofSize: height < 45 ? 8 : 9, weight: .medium)
        let available = max(1, width - 8)
        if height < 45 || (cardName as NSString).size(withAttributes: [.font: font]).width <= available { return [cardName] }
        let preferred: [String: Int] = ["g04": 3, "g07": 2, "g10": 2, "g11": 4, "g17": 4, "g19": 4, "g23": 5, "g24": 3, "g26": 3, "g29": 3, "g30": 4, "g34": 4, "g43": 2]
        let chars = Array(cardName)
        let split = min(preferred[place.id] ?? chars.count / 2, chars.count / 2)
        return [String(chars.prefix(split)), String(chars.dropFirst(split)).trimmingCharacters(in: CharacterSet(charactersIn: "・"))]
    }
    var body: some View {
        let state = store.visit(place).status
        ZStack {
            if let thumbnail {
                Image(uiImage: thumbnail).resizable().scaledToFill().frame(width: width, height: height).clipped()
                LinearGradient(colors: [.black.opacity(0.28), .clear, .black.opacity(showsName ? 0.75 : 0)], startPoint: .top, endPoint: .bottom)
            } else {
                Rectangle().fill(state == .unvisited ? Color(.secondarySystemGroupedBackground) : statusColor(state).opacity(0.12))
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .top, spacing: 0) {
                    Text(place.kana).font(.custom("HiraMinProN-W6", fixedSize: min(23, height * 0.32)))
                        .offset(y: -min(23, height * 0.32) * 0.09)
                    Spacer(minLength: 0)
                    if let date = store.visit(place).capturedDateLabel {
                        let parts = date.split(separator: ".")
                        if parts.count >= 2 {
                            Text("\(parts[0])\n\(parts[1])")
                                .font(.custom("HiraMinProN-W6", fixedSize: 8))
                                .multilineTextAlignment(.trailing).fixedSize()
                                .shadow(color: .black.opacity(thumbnail == nil ? 0 : 0.35), radius: 0.7, x: 0, y: 0.3)
                                .accessibilityLabel("撮影年月 \(parts[0])年\(parts[1])月")
                        }
                    }
                }
                Spacer(minLength: 0)
                if showsName {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(cardLines.enumerated()), id: \.offset) { _, line in
                        Text(line).font(.custom("HiraMinProN-W6", fixedSize: height < 45 ? 8 : 9)).lineLimit(1).minimumScaleFactor(0.8)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .ignore).accessibilityLabel(cardName)
                }
            }.padding(4).foregroundStyle(thumbnail == nil ? Color.primary : .white)
                .shadow(color: .black.opacity(thumbnail == nil ? 0 : 0.55), radius: 1, x: 0, y: 0.5)
        }.frame(width: width, height: height).clipped()
            .overlay(Rectangle().strokeBorder(state == .unvisited ? Color.secondary.opacity(0.25) : statusColor(state), lineWidth: state == .unvisited ? 0.5 : 2))
            .task(id: store.visit(place).photoFilename) { if loadsThumbnail { loadedThumbnail = store.thumbnail(for: place) } }
    }
}
// The export uses a fixed canvas and synchronous thumbnails so every card is
// present in ImageRenderer; it never captures navigation or tab controls.
struct ProgressPoster: View {
    @EnvironmentObject var store: JourneyStore
    let photos: [String: UIImage]
    let showsNames: Bool
    let irohaOrder: Bool
    private var orderedPlaces: [Place] {
        guard irohaOrder else { return store.places }
        let kanaOrder = Array("いろはにほへとちりぬるをわかよたれそつねならむうゐのおくやまけふこえてあさきゆめみしゑひもせす")
        return store.places.sorted {
            (kanaOrder.firstIndex(of: $0.kana.first ?? " ") ?? 99) <
            (kanaOrder.firstIndex(of: $1.kana.first ?? " ") ?? 99)
        }
    }
    private let gap: CGFloat = 5
    private let cardWidth: CGFloat = 60.5
    private let cardHeight: CGFloat = 82
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(progressTitle).font(.custom("HiraMinProN-W6", fixedSize: 18))
                Spacer()
            }.padding(.vertical, 8)
            VStack(spacing: gap) {
                ForEach(0..<8, id: \.self) { row in
                    HStack(spacing: gap) {
                        ForEach(0..<6, id: \.self) { column in
                            let index = row * 6 + column
                            if index < orderedPlaces.count {
                                let place = orderedPlaces[index]
                                VisitCard(place: place, width: cardWidth, height: cardHeight,
                                          exportImage: photos[place.id], loadsThumbnail: false, showsName: showsNames)
                            } else {
                                Color.clear.frame(width: cardWidth, height: cardHeight)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 420)
        .background(Color.black)
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        .environment(\.dynamicTypeSize, .large)
    }
    private var progressTitle: String {
        return "訪問 \(store.visitedCount) / 44"
    }
}

struct ProgressShareView: View {
    @EnvironmentObject var store: JourneyStore
    @Environment(\.dismiss) private var dismiss
    @State private var includesPhotos = true
    @State private var includesNames = true
    @State private var irohaOrder = false
    @State private var preview: UIImage?
    @State private var showingActivity = false
    @State private var failed = false
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("並び順", selection: $irohaOrder) {
                    Text("五十音順").tag(false)
                    Text("いろは順").tag(true)
                }.pickerStyle(.segmented).padding(.horizontal)
                Toggle("写真を含める", isOn: $includesPhotos)
                    .padding(.horizontal)
                Toggle("場所名を表示", isOn: $includesNames)
                    .padding(.horizontal)
                if let preview {
                    ScrollView {
                        Image(uiImage: preview).resizable().scaledToFit()
                            .accessibilityLabel("44の訪問先の共有画像")
                            .padding(.horizontal)
                    }
                    Button { showingActivity = true } label: {
                        Label("画像を共有・保存", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }.buttonStyle(.borderedProminent).padding(.horizontal)
                } else if failed {
                    ContentUnavailableView("画像を作成できませんでした", systemImage: "photo")
                    Button("もう一度試す") { render() }
                } else { Spacer(); ProgressView("画像を作成中…"); Spacer() }
            }
            .padding(.vertical)
            .navigationTitle("進捗を共有").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } } }
            .task { render() }
            .onChange(of: includesPhotos) { _, _ in render() }
            .onChange(of: includesNames) { _, _ in render() }
            .onChange(of: irohaOrder) { _, _ in render() }
            .sheet(isPresented: $showingActivity) {
                if let preview { ProgressActivityView(image: preview) }
            }
        }
    }
    @MainActor private func render() {
        var photos: [String: UIImage] = [:]
        if includesPhotos {
            for place in store.places {
                if let image = store.thumbnail(for: place) { photos[place.id] = image }
            }
        }
        let renderer = ImageRenderer(content: ProgressPoster(photos: photos, showsNames: includesNames, irohaOrder: irohaOrder).environmentObject(store))
        renderer.scale = 3
        renderer.isOpaque = true
        preview = renderer.uiImage
        failed = preview == nil
    }
}

struct ProgressActivityView: UIViewControllerRepresentable {
    let image: UIImage
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

struct PhotoGallery: View {
    @EnvironmentObject var store: JourneyStore
    @State private var selectedID: String = ""
    var photographed: [Place] { store.places.filter { store.visit($0).photoFilename != nil } }
    var body: some View {
        NavigationStack {
            Group {
                if photographed.isEmpty {
                    ContentUnavailableView("写真はまだありません", systemImage: "photo", description: Text("訪問先で撮影するか、写真を選ぶとここに表示されます。"))
                } else {
                    VStack(spacing: 0) {
                        TabView(selection: $selectedID) {
                            ForEach(photographed) { place in
                                GalleryPage(place: place).tag(place.id)
                            }
                        }.tabViewStyle(.page(indexDisplayMode: .never))
                        HStack {
                            Button { step(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.disabled(index == 0).accessibilityLabel("前の写真")
                            Spacer()
                            Text("\(index + 1) / \(photographed.count)").monospacedDigit().foregroundStyle(readableGray)
                            Spacer()
                            Button { step(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }.disabled(index >= photographed.count - 1).accessibilityLabel("次の写真")
                        }.padding(.horizontal)
                    }
                }
            }.background(Color.black).navigationTitle("写真").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        if let place = photographed.first(where: { $0.id == selectedID }) {
                            DeletePhotoButton(place: place)
                        }
                    }
                }
                .onAppear { reconcileSelection() }
                .onChange(of: photographed.map(\.id)) { _, _ in reconcileSelection() }
        }
    }
    private var index: Int { photographed.firstIndex { $0.id == selectedID } ?? 0 }
    private func reconcileSelection() {
        if !photographed.contains(where: { $0.id == selectedID }) { selectedID = photographed.first?.id ?? "" }
    }
    private func step(_ delta: Int) {
        let next = index + delta
        guard photographed.indices.contains(next) else { return }
        withAnimation { selectedID = photographed[next].id }
    }
}
struct GalleryPage: View {
    let place: Place
    @EnvironmentObject var store: JourneyStore
    @State private var photo: UIImage?
    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { geometry in
                if let photo {
                    Image(uiImage: photo).resizable().scaledToFit()
                        .overlay(alignment: .bottom) { PhotoCaption(visit: store.visit(place), place: place) }
                        .overlay(Rectangle().strokeBorder(statusColor(store.visit(place).status), lineWidth: 3))
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .accessibilityLabel(place.destination + "の写真")
                } else {
                    Text("写真を読み込めませんでした").foregroundStyle(readableGray).frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
            Text(place.kana + " · " + place.destination).font(.headline).multilineTextAlignment(.center)
        }.padding()
            .task(id: store.visit(place).photoFilename) { photo = store.image(for: place) }
    }
}
struct JourneyMap: View {
    @EnvironmentObject var store: JourneyStore
    @AppStorage("mapBackground") private var background = "apple"
    @State private var reset = 0
    @State private var detail: Place?
    var body: some View {
        NavigationStack {
            NativeJourneyMap(places: store.places, visits: store.visits, background: background, initialRegion: gunmaRegion, reset: reset) { detail = $0 }
                .safeAreaInset(edge: .bottom, spacing: 0) { if background == "gsi" { GSICredit() } }
                .navigationTitle("44地点の地図").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { Button("全体") { reset += 1 } }
                    ToolbarItem(placement: .topBarTrailing) { MapBackgroundMenu(selection: $background) }
                }
                .sheet(item: $detail) { DetailView(place: $0) }
        }
    }
}
struct PlaceStoryView: View {
    let copy: PlaceCopy
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                if let heading = copy.heading, !heading.isEmpty {
                    Text(heading)
                        .font(.custom("HiraMinProN-W6", size: 18, relativeTo: .headline))
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 12)
                        .overlay(alignment: .leading) {
                            Rectangle().fill(.secondary.opacity(0.5)).frame(width: 2)
                                .accessibilityHidden(true)
                        }
                }
            }
            VStack(alignment: .leading, spacing: 16) {
                Text(indented(copy.place))
                if !copy.theme.isEmpty { Text(indented(copy.theme)) }
            }
            .font(.custom("HiraMinProN-W3", size: 17, relativeTo: .body))
            .lineSpacing(7)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
            if let sources = copy.sources, !sources.isEmpty {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(sources.indices, id: \.self) { index in
                            if let url = URL(string: sources[index].url) {
                                Link(sources[index].title, destination: url)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }.padding(.top, 10)
                } label: {
                    Text("出典・関連情報").foregroundStyle(.secondary)
                }
                .font(.footnote)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 20)
    }
    private func indented(_ text: String) -> String {
        text.components(separatedBy: "\n").map { paragraph in
            paragraph.isEmpty ? "" : "　" + paragraph.trimmingCharacters(in: .whitespaces)
        }.joined(separator: "\n")
    }

}

struct DetailView: View {
    let place: Place
    @EnvironmentObject var store: JourneyStore
    @Environment(\.dismiss) var dismiss
    @StateObject private var location = LocationService()
    @State private var photo: PhotosPickerItem?
    @State private var importing = false
    @State private var showCamera = false
    @State private var message: String?
    @AppStorage("mapBackground") private var background = "apple"
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(place.kana)
                            .font(.custom("HiraMinProN-W6", size: 34, relativeTo: .largeTitle))
                            .foregroundStyle(.teal)
                        Text(place.destination)
                            .font(.custom("HiraMinProN-W6", size: 22, relativeTo: .title3))
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        Spacer(minLength: 0)
                    }
                    if let copy = store.descriptions[place.id] {
                        PlaceStoryView(copy: copy)
                    } else if let url = place.contextSourceUrl.flatMap(URL.init(string:)) {
                        Link("詳しい情報", destination: url)
                    }
                    VStack(spacing: 0) {
                        HStack { Spacer(); MapBackgroundMenu(selection: $background) }.padding(.bottom, 6)
                        NativeJourneyMap(places: [place], visits: store.visits, background: background,
                            initialRegion: .init(center: place.coordinate, latitudinalMeters: max(350, place.radiusM * 3.5), longitudinalMeters: max(350, place.radiusM * 3.5)), fix: location.fix)
                            .frame(height: 240).clipShape(RoundedRectangle(cornerRadius: 16))
                        if background == "gsi" { GSICredit() }
                    }
                    Button { openDirections() } label: {
                        Label("Appleマップで経路を表示", systemImage: "arrow.triangle.turn.up.right.diamond.fill").frame(maxWidth: .infinity)
                    }.buttonStyle(.borderedProminent)
                    Button { openGoogleDirections() } label: {
                        Label("Googleマップで経路を表示", systemImage: "arrow.triangle.turn.up.right.diamond.fill").frame(maxWidth: .infinity)
                    }.buttonStyle(.bordered)
                    Text("案内先：" + navigationDestination).font(.footnote).foregroundStyle(readableGray)
                    Text("案内先はおおよその位置です。出発前に、目的地や入口の位置をご自身でご確認ください。").font(.footnote).foregroundStyle(readableGray)
                    Divider()
                    if let date = store.visit(place).liveDate {
                        Text("訪問日：\(date.formatted(date: .abbreviated, time: .shortened))").foregroundStyle(stampColor)
                        Button { Task { await openCamera() } } label: { Label("写真を撮って残す", systemImage: "camera").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent)
                    } else {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            let fix = location.fix
                            let canStamp = fix.map { VisitRule.canStamp(place, fix: $0, now: context.date) } ?? false
                            VStack(alignment: .leading, spacing: 8) {
                                Button {
                                    if canStamp, let fix {
                                        do { try store.stamp(place, fix: fix); location.stop(); UINotificationFeedbackGenerator().notificationOccurred(.success) }
                                        catch { message = error.localizedDescription }
                                    } else { location.refresh() }
                                } label: {
                                    HStack {
                                        if location.busy && !canStamp { ProgressView() }
                                        Text(canStamp ? "スタンプを押す" : location.busy ? "現在地を確認中…" : "現在地を確認する")
                                    }.frame(maxWidth: .infinity)
                                }.buttonStyle(.borderedProminent).disabled(location.busy && !canStamp)
                                if !canStamp, let fix, VisitRule.validFix(fix, now: context.date) {
                                    Text("訪問範囲まであと約\(Int(max(0, place.distance(from: fix) - place.radiusM)))m").font(.footnote).foregroundStyle(readableGray)
                                }
                                if !canStamp, let note = location.message { Text(note).font(.footnote).foregroundStyle(readableGray) }
                            }
                        }
                        if location.denied { Button("位置情報の設定を開く") { UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!) } }
                    }
                    let photoButtonTitle = importing ? "写真を確認中…" : (store.visit(place).liveDate != nil ? "写真を選んで残す" : "位置情報付き写真で記録")
                    PhotosPicker(selection: $photo, matching: .images, preferredItemEncoding: .current) {
                        Label(photoButtonTitle, systemImage: "photo.badge.plus").frame(maxWidth: .infinity)
                    }.buttonStyle(.bordered).disabled(importing)
                    if let image = store.image(for: place) { Image(uiImage: image).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 12)).accessibilityLabel("この地点に保存した写真") }
                    if store.visit(place).photoFilename != nil { DeletePhotoButton(place: place) }
                }.padding()
            }.navigationTitle("訪問先").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("閉じる") { dismiss() } } }
                .onDisappear { location.stop() }
                .onChange(of: photo) { _, item in
                    guard let item else { return }; importing = true
                    Task {
                        defer { importing = false; photo = nil }
                        do {
                            guard let data = try await item.loadTransferable(type: Data.self) else { throw StoreError.message("写真を読み込めませんでした。") }
                            try store.addImportedPhoto(data, to: place)
                        } catch { message = error.localizedDescription }
                    }
                }
                .fullScreenCover(isPresented: $showCamera) { CameraView { image in
                    if let image { do { try store.addCameraPhoto(image, to: place) } catch { message = error.localizedDescription } }
                }.ignoresSafeArea() }
                .alert("お知らせ", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("閉じる", role: .cancel) { message = nil } } message: { Text(message ?? "") }
        }
    }
    private var navigationDestination: String {
        switch place.id {
        case "g01": return "鬼押出し園"
        case "g02": return "伊香保温泉 石段街"
        case "g06": return "高崎市役所"
        case "g08": return "草津温泉 湯畑"
        case "g11": return "桜山公園"
        case "g13": return "赤城神社"
        case "g15": return "桐生駅"
        case "g18": return "群馬県庁"
        case "g35": return "妙義神社"
        case "g25": return "榛名公園ビジターセンター"
        case "g32": return "谷川岳ヨッホ（土合口駅）"
        default: return place.destination
        }
    }
    private func openGoogleDirections() {
        var components = URLComponents(string: "https://www.google.com/maps/dir/")!
        let destination = place.id == "g32" ? "36.8364836,138.961864" : place.id == "g44" ? "36.244635437566075,139.07870512881433" : "群馬県 " + navigationDestination
        components.queryItems = [URLQueryItem(name: "api", value: "1"), URLQueryItem(name: "destination", value: destination)]
        guard let url = components.url else { return }
        UIApplication.shared.open(url, options: [:]) { success in
            if !success { message = "Googleマップを開けませんでした。" }
        }
    }
    private func openDirections() {
        if place.id == "g32" || place.id == "g44" {
            let coordinate = place.id == "g44" ? CLLocationCoordinate2D(latitude: 36.244635437566075, longitude: 139.07870512881433) : CLLocationCoordinate2D(latitude: 36.8364836, longitude: 138.961864)
            let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
            item.name = navigationDestination
            if !item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDefault]) {
                message = "Appleマップを開けませんでした。"
            }
            return
        }
        var components = URLComponents(string: "https://maps.apple.com/")!
        components.queryItems = [URLQueryItem(name: "daddr", value: "群馬県 " + navigationDestination)]
        guard let url = components.url else { return }
        UIApplication.shared.open(url, options: [:]) { success in
            if !success { message = "Appleマップを開けませんでした。" }
        }
    }
    private func openCamera() async {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { message = "この端末ではカメラを利用できません。"; return }
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        if granted { showCamera = true } else { message = "設定でカメラの利用を許可すると撮影できます。" }
    }
}
struct CameraView: UIViewControllerRepresentable {
    let complete: (UIImage?) -> Void
    @Environment(\.dismiss) var dismiss
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIImagePickerController { let p = UIImagePickerController(); p.sourceType = .camera; p.delegate = context.coordinator; return p }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let owner: CameraView
        init(_ owner: CameraView) { self.owner = owner }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { owner.dismiss() }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) { owner.complete(info[.originalImage] as? UIImage); owner.dismiss() }
    }
}
struct AboutView: View {
    @EnvironmentObject var store: JourneyStore
    var body: some View {
        NavigationStack {
            List {
                Section("群馬をめぐる") { Text("44の訪問先をめぐり、自然・歴史・文化との出会いを記録するアプリです。") }
                Section("スタンプを集める") {
                    Label("訪問先を選び、行き先を確認する", systemImage: "1.circle")
                    Label("到着したら「現在地を確認する」", systemImage: "2.circle")
                    Label("範囲内で「スタンプを押す」", systemImage: "3.circle")
                    Text("写真撮影は任意です。過去の位置情報付き写真からも、紫色の写真記録を残せます。後日訪問すると朱色の現地スタンプになります。訪問済みの場所には、位置情報のない写真も追加できます。")
                }
                Section("記録とプライバシー") {
                    Text("スタンプと選んだ写真は、このiPhoneのアプリ内に保存します。位置情報は現在地の確認中に利用し、常時追跡はしません。アプリを削除すると記録も削除されます。")
                    Text("地図の表示や外部リンクには通信が必要です。共有画像は、選んだ共有先へ渡されます。")
                    NavigationLink("プライバシーポリシー") { PrivacyPolicyView() }
                    Link("お問い合わせ", destination: URL(string: "https://github.com/early277/GunmaJourney/blob/main/SUPPORT.md")!)
                }
                Section("訪問するとき") {
                    Text("判定円は立ち入り可能な範囲を示すものではありません。公開されている道や施設から、現地の営業時間・通行案内に従って訪問してください。記録操作は安全に立ち止まれる場所で行ってください。")
                }
                Section("地図・座標の出典") {
                    Link("地理院タイル（標準地図）の出典", destination: URL(string: "https://maps.gsi.go.jp/development/ichiran.html")!)
                    Text("地理院タイルに、本アプリが訪問先のピン・判定円を重ねています。")
                    Link("国土地理院コンテンツ利用規約", destination: URL(string: "https://www.gsi.go.jp/kikakuchousei/kikakuchousei40182.html")!)
                    Text("地図：Apple Maps / MapKit・地理院タイル\n座標資料：国土地理院、OpenStreetMap、各施設・観光案内等")
                    Text("写真の略図：国土交通省「国土数値情報（行政区域データ）」2025年・群馬県を加工して作成")
                    Link("市町村境界データの出典", destination: URL(string: "https://nlftp.mlit.go.jp/ksj/gml/datalist/KsjTmplt-N03-2025.html")!)
                    Link("市町村境界のライセンス：CC BY 4.0", destination: URL(string: "https://creativecommons.org/licenses/by/4.0/")!)
                    Link("© OpenStreetMap contributors", destination: URL(string: "https://www.openstreetmap.org/copyright")!)
                    NavigationLink("各地点の座標資料") { List(store.places) { p in
                        if let url = URL(string: p.coordinateSourceUrl) { Link(p.kana + " · " + p.destination, destination: url) }
                    }.navigationTitle("座標資料") }
                }
                Section { Text("バージョン " + (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")).font(.footnote).foregroundStyle(readableGray) }
            }.navigationTitle("使い方")
        }
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        List {
            Section("端末内の記録") {
                Text("訪問日時、選んだ写真、写真の撮影日を、このアプリの保存領域に記録します。写真の位置情報は追加時の訪問範囲の判定にだけ使い、保存しません。写真画面の略図は訪問先の位置を示します。開発者のサーバーへの送信、広告配信、行動分析、追跡は行いません。")
            }
            Section("位置情報と写真") {
                Text("現在地は、利用者が現在地確認を選んだときに取得します。背景での継続追跡は行いません。写真の選択にはiOSの写真選択画面を使い、利用者が選んだ写真のみを読み込みます。元の写真は変更しません。")
                Text("取り込んだ写真は縮小したコピーをアプリ内に保存します。撮影日は記録データに保存しますが、コピー画像には元写真のEXIF情報を引き継ぎません。旧バージョンで保存した写真の座標は、更新後の起動時にアプリ内の記録から取り除きます。")
            }
            Section("地図・外部サービス") {
                Text("Appleマップや地理院タイルを表示するとき、表示地域やIPアドレスなど通信に必要な情報が提供元へ送られます。経路案内や関連情報のリンクを開くと、目的地等が選択したサービスへ渡されます。移動先では各提供元のプライバシーポリシーが適用されます。")
                Link("Appleのプライバシーポリシー", destination: URL(string: "https://www.apple.com/legal/privacy/jp/")!)
                Link("Googleのプライバシーポリシー", destination: URL(string: "https://policies.google.com/privacy?hl=ja")!)
                Link("国土地理院の個人情報保護", destination: URL(string: "https://www.gsi.go.jp/GSI/puraibasi-porisi.htm")!)
            }
            Section("共有と保存") {
                Text("共有を選ぶと、プレビューに表示された画像を、利用者が指定したアプリや保存先に渡します。写真・場所名の表示は共有前に選べます。ひらがな、訪問状況、撮影年月は画像に含まれます。共有画像にGPSのEXIF情報は付けません。")
            }
            Section("保存期間と削除") {
                Text("記録はアプリを削除するまで端末内に残ります。写真を削除した場合や置き換えた場合、対象のアプリ内コピーは削除します。iPhoneの設定により、記録が端末バックアップに含まれることがあります。バックアップや共有先・写真ライブラリに保存したコピーは、それぞれのサービスで管理・削除してください。")
                Text("位置情報・カメラ・写真への追加の許可は、iPhoneの設定から変更できます。アカウント登録はありません。")
            }
            Section("公開ページ・お問い合わせ") {
                Link("プライバシーポリシーの公開ページ", destination: URL(string: "https://github.com/early277/GunmaJourney/blob/main/PRIVACY.md")!)
                Link("お問い合わせ", destination: URL(string: "https://github.com/early277/GunmaJourney/blob/main/SUPPORT.md")!)
                Text("GitHubの投稿は公開されます。個人情報や位置情報付き写真は投稿しないでください。")
            }
        }.navigationTitle("プライバシーポリシー").navigationBarTitleDisplayMode(.inline)
    }
}

struct PhotoCaption: View {
    let visit: Visit
    let place: Place
    var body: some View {
        HStack(alignment: .bottom) {
            GunmaPhotoOutline(latitude: place.latitude, longitude: place.longitude)
                .frame(width: 76, height: 72)
                .accessibilityLabel("群馬県の輪郭と訪問先の位置")
            Spacer(minLength: 8)
            if let date = visit.capturedDateLabel {
                Text(date).font(.system(size: 15, weight: .medium, design: .monospaced)).foregroundStyle(.white)
                    .accessibilityLabel("撮影日 " + date)
            }
        }.shadow(color: .black.opacity(0.55), radius: 1, x: 0, y: 0.5).padding(12)
            .allowsHitTesting(false)
    }
}
struct GunmaPhotoOutline: View {
    let latitude: Double?
    let longitude: Double?
    private struct Boundaries: Decodable { let outer: [[[Double]]]; let inner: [[[Double]]] }
    private static let boundaries: Boundaries = {
        guard let url = Bundle.main.url(forResource: "municipalities", withExtension: "json"),
              let data = try? Data(contentsOf: url), let value = try? JSONDecoder().decode(Boundaries.self, from: data) else {
            return Boundaries(outer: [], inner: [])
        }
        return value
    }()
    var body: some View {
        Canvas { context, size in
            let ratio = cos(36.5 * .pi / 180)
            let outer = Self.boundaries.outer.map { $0.map { CGPoint(x: $0[0] * ratio, y: -$0[1]) } }
            let inner = Self.boundaries.inner.map { $0.map { CGPoint(x: $0[0] * ratio, y: -$0[1]) } }
            let points = outer.flatMap { $0 }
            guard !points.isEmpty else { return }
            let marker: CGPoint? = {
                guard let lat = latitude, let lon = longitude, lat.isFinite, lon.isFinite else { return nil }
                return CGPoint(x: lon * ratio, y: -lat)
            }()
            // Include an out-of-prefecture photograph honestly, without snapping its point to Gunma.
            let extent = points + (marker.map { [$0] } ?? [])
            let minX = extent.map(\.x).min()!, maxX = extent.map(\.x).max()!
            let minY = extent.map(\.y).min()!, maxY = extent.map(\.y).max()!
            let scale = min((size.width - 8) / (maxX - minX), (size.height - 8) / (maxY - minY))
            func project(_ p: CGPoint) -> CGPoint {
                CGPoint(x: (p.x - (minX + maxX) / 2) * scale + size.width / 2,
                        y: (p.y - (minY + maxY) / 2) * scale + size.height / 2)
            }
            var subdivisions = Path()
            for line in inner { subdivisions.addLines(line.map(project)) }
            context.stroke(subdivisions, with: .color(.white.opacity(0.8)), lineWidth: 0.4)
            var path = Path()
            for line in outer { path.addLines(line.map(project)) }
            context.stroke(path, with: .color(.white), lineWidth: 1.3)
            if let marker {
                let p = project(marker)
                context.fill(Path(ellipseIn: CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6)), with: .color(.white))
            }
        }
    }
}

struct MapBackgroundMenu: View {
    @Binding var selection: String
    var body: some View {
        Menu {
            Picker("地図の種類", selection: $selection) {
                Text("Appleマップ").tag("apple")
                Text("航空写真").tag("satellite")
                Text("地理院地図").tag("gsi")
            }
        } label: { Label(selection == "gsi" ? "地理院地図" : selection == "satellite" ? "航空写真" : "Appleマップ", systemImage: "map") }
    }
}
struct GSICredit: View {
    var body: some View {
        Link("出典：地理院タイル", destination: URL(string: "https://maps.gsi.go.jp/development/ichiran.html")!)
            .font(.caption).padding(6).frame(maxWidth: .infinity).background(.regularMaterial)
    }
}
struct NativeJourneyMap: UIViewRepresentable {
    let places: [Place]
    let visits: [String: Visit]
    let background: String
    let initialRegion: MKCoordinateRegion
    var reset: Int = 0
    var fix: CLLocation? = nil
    var onSelect: ((Place) -> Void)? = nil
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(); map.delegate = context.coordinator
        map.showsCompass = true; map.showsScale = true; map.isPitchEnabled = false
        map.setRegion(initialRegion, animated: false)
        for p in places {
            let pin = PlacePin(p); map.addAnnotation(pin)
            map.addOverlay(MKCircle(center: p.coordinate, radius: p.radiusM), level: .aboveLabels)
        }
        return map
    }
    func updateUIView(_ map: MKMapView, context: Context) {
        let c = context.coordinator; c.parent = self
        if c.background != background {
            if let tile = c.tile { map.removeOverlay(tile); c.tile = nil }
            map.mapType = background == "satellite" ? .hybrid : .standard
            if background == "gsi" {
                let tile = MKTileOverlay(urlTemplate: "https://cyberjapandata.gsi.go.jp/xyz/std/{z}/{x}/{y}.png")
                tile.minimumZ = 2; tile.maximumZ = 18; tile.canReplaceMapContent = true
                map.insertOverlay(tile, at: 0, level: .aboveLabels); c.tile = tile
            }
            c.background = background
        }
        if c.reset != reset { c.reset = reset; map.setRegion(initialRegion, animated: true) }
        for case let pin as PlacePin in map.annotations {
            (map.view(for: pin) as? MKMarkerAnnotationView)?.markerTintColor = c.color(pin.place)
        }
        if let fix {
            if let pin = c.fixPin { pin.coordinate = fix.coordinate }
            else { let pin = MKPointAnnotation(); pin.title = "現在地"; pin.coordinate = fix.coordinate; c.fixPin = pin; map.addAnnotation(pin) }
        } else if let pin = c.fixPin { map.removeAnnotation(pin); c.fixPin = nil }
    }
    static func dismantleUIView(_ map: MKMapView, coordinator: Coordinator) { map.delegate = nil }
    final class PlacePin: NSObject, MKAnnotation {
        let place: Place
        var coordinate: CLLocationCoordinate2D { place.coordinate }
        var title: String? { place.kana + " · " + place.destination }
        init(_ place: Place) { self.place = place }
    }
    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: NativeJourneyMap
        var background = ""
        var reset = 0
        var tile: MKTileOverlay?
        var fixPin: MKPointAnnotation?
        init(_ parent: NativeJourneyMap) { self.parent = parent }
        func color(_ place: Place) -> UIColor {
            switch parent.visits[place.id]?.status ?? .unvisited {
            case .unvisited: return .systemTeal
            case .visited: return UIColor(red: 0.86, green: 0.25, blue: 0.14, alpha: 1)
            case .photo: return .systemIndigo
            }
        }
        func mapView(_ map: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tile = overlay as? MKTileOverlay { return MKTileOverlayRenderer(tileOverlay: tile) }
            if let circle = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circle)
                renderer.fillColor = UIColor.systemTeal.withAlphaComponent(0.16)
                renderer.strokeColor = .systemTeal; renderer.lineWidth = 1.5; return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        func mapView(_ map: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let pin = annotation as? PlacePin {
                let view = MKMarkerAnnotationView(annotation: pin, reuseIdentifier: nil)
                view.markerTintColor = color(pin.place); view.glyphText = pin.place.kana
                view.canShowCallout = parent.onSelect == nil; return view
            }
            let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: nil)
            view.markerTintColor = .systemBlue; view.glyphImage = UIImage(systemName: "location.fill"); return view
        }
        func mapView(_ map: MKMapView, didSelect view: MKAnnotationView) {
            guard let pin = view.annotation as? PlacePin, let select = parent.onSelect else { return }
            map.deselectAnnotation(pin, animated: false)
            DispatchQueue.main.async { select(pin.place) }
        }
    }
}

struct DeletePhotoButton: View {
    let place: Place
    @EnvironmentObject var store: JourneyStore
    @State private var confirming = false
    @State private var failure: String?
    var body: some View {
        Button(role: .destructive) { confirming = true } label: {
            Label("写真を削除", systemImage: "trash")
        }
        .confirmationDialog("この写真を削除しますか？", isPresented: $confirming, titleVisibility: .visible) {
            Button("写真を削除", role: .destructive) {
                do { try store.removePhoto(from: place) }
                catch { failure = error.localizedDescription }
            }
            Button("キャンセル", role: .cancel) { }
        } message: {
            Text("アプリ内の写真だけを削除します。スタンプと訪問記録、写真ライブラリの元の写真は残ります。")
        }
        .alert("写真を削除できませんでした", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("閉じる", role: .cancel) { failure = nil }
        } message: { Text(failure ?? "") }
    }
}
