import SwiftUI

struct GalleryView: View {

    @StateObject private var library = MediaLibrary()

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 2)]

    var body: some View {
        NavigationStack {
            Group {
                if !library.authorized && library.items.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.largeTitle)
                        Text("Acces a la phototheque requis")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(library.items) { item in
                                ZStack(alignment: .bottomTrailing) {
                                    Image(uiImage: item.thumbnail)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 100)
                                        .clipped()
                                    if item.isVideo {
                                        Image(systemName: "video.fill")
                                            .font(.caption)
                                            .foregroundStyle(.white)
                                            .padding(4)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Galerie")
            .onAppear { library.load() }
        }
    }
}

#Preview {
    GalleryView()
}
