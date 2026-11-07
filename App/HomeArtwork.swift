import SwiftUI

struct HomeEdition: Decodable {
    struct Slide: Decodable {
        let title, kicker, description, image, alt: String
        let primary, secondary: [String]
        var asset: String { URL(fileURLWithPath: image).deletingPathExtension().lastPathComponent }
        var id: String { image }
    }
    struct Saying: Decodable { let text, url, label: String }
    let slides: [Slide]
    let wisdom: [Saying]
    static let shared: HomeEdition = {
        guard let url = Bundle.main.url(forResource: "HomeEdition", withExtension: "json"),
              let data = try? Data(contentsOf: url), let edition = try? JSONDecoder().decode(HomeEdition.self, from: data), !edition.slides.isEmpty, !edition.wisdom.isEmpty
        else { preconditionFailure("The app bundle is missing its home edition.") }
        return edition
    }()
    static var day: Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        let start = cal.date(from: DateComponents(year: 1970, month: 1, day: 1))!
        return cal.dateComponents([.day], from: start, to: cal.startOfDay(for: .now)).day ?? 0
    }
    var weekly: [Slide] {
        // The Center's rotation starts on Monday, October 5, 2026.
        let dayZero = 20731
        let offset = Int(floor(Double(Self.day-dayZero)/7.0))*5
        return (0..<min(5, slides.count)).map { slides[(($0+offset)%slides.count+slides.count)%slides.count] }
    }
    var saying: Saying { wisdom[(Self.day % wisdom.count + wisdom.count) % wisdom.count] }
}

struct CoverStory: View {
    @State private var index = 0
    @State private var viewingPhoto = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let open: (URL) -> Void

    var body: some View {
        let slides = HomeEdition.shared.weekly
        let slide = slides[index]
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.aspectRatio(1.9, contentMode: .fit)
                .overlay {
                    TabView(selection: $index) {
                        ForEach(slides.indices, id: \.self) { position in
                            photo(slides[position], position: position, count: slides.count)
                                .tag(position)
                        }
                    }.tabViewStyle(.page(indexDisplayMode: .never))
                }
                .clipped()

            VStack(alignment: .leading, spacing: 9) {
                let parts = slide.title.components(separatedBy: "\n")
                (Text(parts[0] + " ").font(.custom("Georgia", size: 35, relativeTo: .largeTitle))
                 + Text(parts.dropFirst().joined(separator: " ")).font(.custom("Georgia-Italic", size: 35, relativeTo: .largeTitle)).foregroundColor(CenterInk.gold))
                    .tracking(-0.6).accessibilityAddTraits(.isHeader)
                Text(slide.description).font(.body).lineSpacing(2)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        primary(slide)
                        Spacer(minLength: 0)
                        pageButtons(count: slides.count)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        primary(slide)
                        pageButtons(count: slides.count)
                    }
                }
                .padding(.top, 5)
            }
            .foregroundStyle(CenterInk.paper)
            .fixedSize(horizontal: false, vertical: true)
            .padding(18)
        }
        .background(CenterInk.pine)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .fullScreenCover(isPresented: $viewingPhoto) {
            CommunityPhotoViewer(slides: slides, index: $index)
        }
    }

    private func photo(_ slide: HomeEdition.Slide, position: Int, count: Int) -> some View {
        Button { viewingPhoto = true } label: {
            Rectangle().fill(.clear)
                .overlay { Image(slide.asset).resizable().scaledToFill() }
                .clipped()
                .overlay(alignment: .topLeading) {
                    Text("\(position + 1) of \(count)")
                        .font(.subheadline.weight(.semibold)).monospacedDigit()
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(.black.opacity(0.75), in: Capsule())
                        .padding(12).accessibilityHidden(true)
                }
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44).background(.black.opacity(0.75), in: Circle())
                        .padding(10).accessibilityHidden(true)
                }
                .foregroundStyle(.white).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("View full photo")
        .accessibilityValue(slide.alt)
        .accessibilityHint("Opens a photo you can zoom in on.")
        .accessibilityIdentifier(position == index ? "feature-photo" : "feature-photo-\(position)")
        .accessibilityHidden(position != index)
    }

    private func primary(_ slide: HomeEdition.Slide) -> some View {
        Button { open(centerURL(slide.primary[1])) } label: {
            let label = slide.primary[0] == "See the weekly schedule" ? "Weekly schedule" : slide.primary[0]
            Label(label, systemImage: "arrow.right")
                .labelStyle(TrailingActionIcon())
                .font(.body.weight(.semibold))
                .padding(.horizontal, 15).padding(.vertical, 8)
                .frame(minHeight: 50)
                .background(CenterInk.gold, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(CenterInk.pine)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("feature-action")
    }

    private func advance(_ step: Int, count: Int) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
            index = (index + step + count) % count
        }
    }

    private func pageButtons(count: Int) -> some View {
        HStack(spacing: 6) {
            ForEach([-1, 1], id: \.self) { step in
                Button {
                    advance(step, count: count)
                } label: {
                    Image(systemName: step == 1 ? "chevron.right" : "chevron.left")
                        .font(.body.weight(.semibold))
                        .frame(minWidth: 46, minHeight: 48)
                        .background(.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(step == 1 ? "Next feature" : "Previous feature")
                .accessibilityValue("Feature \(index + 1) of \(count)")
            }
        }
    }
}

private struct TrailingActionIcon: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) { configuration.title; configuration.icon }
    }
}

private struct CommunityPhotoViewer: View {
    let slides: [HomeEdition.Slide]
    @Binding var index: Int
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Photo \(index + 1) of \(slides.count)").font(.headline)
                Spacer()
                Button { dismiss() } label: {
                    Text("Done").font(.body.weight(.semibold)).padding(.horizontal, 14)
                        .frame(minHeight: 48).background(.white.opacity(0.16), in: Capsule())
                }
            }.padding(.horizontal, 16).padding(.vertical, 6)
            ZoomablePhoto(name: slides[index].asset, description: slides[index].alt)
                .id(slides[index].asset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Text(slides[index].alt)
                .font(.body).fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20).padding(.vertical, 10)
            HStack {
                Button { index = (index - 1 + slides.count) % slides.count } label: {
                    Image(systemName: "arrow.left").frame(minWidth: 52, minHeight: 48)
                        .background(.white.opacity(0.16), in: Capsule())
                }.accessibilityLabel("Previous photo")
                Spacer()
                Button { index = (index + 1) % slides.count } label: {
                    Image(systemName: "arrow.right").frame(minWidth: 52, minHeight: 48)
                        .background(.white.opacity(0.16), in: Capsule())
                }.accessibilityLabel("Next photo")
            }.font(.title3.weight(.semibold)).padding(.horizontal, 18).padding(.bottom, 5)
        }
        .buttonStyle(.plain).foregroundStyle(.white)
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}

private struct ZoomablePhoto: UIViewRepresentable {
    let name: String
    let description: String

    func makeUIView(context: Context) -> PhotoScrollView {
        let scroll = PhotoScrollView()
        scroll.photo.image = UIImage(named: name)
        scroll.photo.accessibilityLabel = description
        return scroll
    }

    func updateUIView(_ uiView: PhotoScrollView, context: Context) {}
}

private final class PhotoScrollView: UIScrollView, UIScrollViewDelegate {
    let photo = UIImageView()
    private var lastSize = CGSize.zero

    init() {
        super.init(frame: .zero)
        delegate = self
        maximumZoomScale = 4
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        photo.contentMode = .scaleAspectFit
        photo.isAccessibilityElement = true
        photo.accessibilityTraits = .image
        addSubview(photo)
        let tap = UITapGestureRecognizer(target: self, action: #selector(toggleZoom(_:)))
        tap.numberOfTapsRequired = 2
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) { fatalError("Use init()") }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let original = photo.image?.size, bounds.width > 0, bounds.height > 0 else { return }
        if bounds.size != lastSize {
            lastSize = bounds.size
            setZoomScale(1, animated: false)
            let scale = min(bounds.width / original.width, bounds.height / original.height)
            photo.frame = CGRect(origin: .zero, size: CGSize(width: original.width * scale, height: original.height * scale))
            contentSize = photo.frame.size
        }
        centerPhoto()
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { photo }
    func scrollViewDidZoom(_ scrollView: UIScrollView) { centerPhoto() }

    private func centerPhoto() {
        let x = max(0, (bounds.width - contentSize.width) / 2)
        let y = max(0, (bounds.height - contentSize.height) / 2)
        let inset = UIEdgeInsets(top: y, left: x, bottom: y, right: x)
        if contentInset != inset { contentInset = inset }
    }

    @objc private func toggleZoom(_ tap: UITapGestureRecognizer) {
        if zoomScale > 1.01 {
            setZoomScale(1, animated: true)
        } else {
            let point = tap.location(in: photo)
            let size = CGSize(width: bounds.width / 2.5, height: bounds.height / 2.5)
            zoom(to: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2,
                            width: size.width, height: size.height), animated: true)
        }
    }
}
