import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            CameraView()
                .tabItem { Label("Camera", systemImage: "camera.fill") }

            GalleryView()
                .tabItem { Label("Galerie", systemImage: "photo.on.rectangle") }
        }
    }
}

#Preview {
    ContentView()
}
