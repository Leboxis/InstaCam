import SwiftUI
import Combine

struct CameraView: View {

    @StateObject private var camera = CameraController()
    @State private var mode: CaptureMode = .photo
    @State private var showSaved = false
    @State private var savedMessage = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            FilteredPreviewView(camera: camera)
                .ignoresSafeArea()

            VStack {
                topBar
                Spacer()
                FilterPickerView(selected: $camera.currentFilter)
                    .padding(.bottom, 8)
                controls
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)

            if let error = camera.errorMessage {
                errorBanner(error)
            }
        }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .overlay(alignment: .top) {
            if showSaved { savedToast }
        }
    }

    private var topBar: some View {
        HStack {
            Picker("Mode", selection: $mode) {
                Text("PHOTO").tag(CaptureMode.photo)
                Text("VIDEO").tag(CaptureMode.video)
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
        }
    }

    private var controls: some View {
        HStack {
            Button {
                // placeholder : acces galerie rapide
            } label: {
                Image(systemName: "photo.on.rectangle")
                    .font(.title2)
                    .foregroundStyle(.white)
            }

            Spacer()

            captureButton

            Spacer()

            Button {
                // placeholder : bascule camera avant
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 30)
    }

    private var captureButton: some View {
        Button {
            switch mode {
            case .photo:
                camera.capturePhoto()
            case .video:
                camera.toggleRecording()
            }
        } label: {
            ZStack {
                Circle()
                    .stroke(.white, lineWidth: 4)
                    .frame(width: 76, height: 76)
                if mode == .video && camera.isRecording {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.red)
                        .frame(width: 34, height: 34)
                } else {
                    Circle()
                        .fill(.white)
                        .frame(width: 62, height: 62)
                }
            }
        }
        .disabled(!camera.isReady)
        .onReceive(camera.$capturedImage.compactMap { $0 }) { image in
            PhotoSaver.savePhoto(image) { result in
                switch result {
                case .success:
                    savedMessage = "Photo enregistree"
                case .failure(let error):
                    savedMessage = error.localizedDescription
                }
                showSaved = true
            }
        }
        .onReceive(camera.$exportedVideoURL.compactMap { $0 }) { url in
            PhotoSaver.saveVideo(at: url) { result in
                switch result {
                case .success:
                    savedMessage = "Video enregistree"
                case .failure(let error):
                    savedMessage = error.localizedDescription
                }
                showSaved = true
            }
        }
    }

    private var savedToast: some View {
        Text(savedMessage)
            .font(.subheadline).bold()
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.top, 8)
            .task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                showSaved = false
            }
    }

    private func errorBanner(_ message: String) -> some View {
        VStack {
            Spacer()
            Text(message)
                .font(.footnote)
                .foregroundStyle(.white)
                .padding()
                .background(.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
                .padding()
        }
    }
}

#Preview {
    CameraView()
}
