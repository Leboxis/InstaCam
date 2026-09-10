# InstaCam

App iOS (SwiftUI + AVFoundation) qui reproduit le pipeline camera d'Instagram :
capture photo/video, apercu filtre en temps reel via Metal/Core Image, galerie locale.

## Stack

- **AVFoundation** : `AVCaptureSession`, `AVCapturePhotoOutput`, `AVCaptureMovieFileOutput`, `AVCaptureVideoDataOutput`
- **Metal + Core Image** : apercu en temps reel, filtres type Instagram
- **SwiftUI** : interface (camera + galerie)
- **PhotoKit** : sauvegarde automatique dans la phototheque

## Structure

```
InstaCam/
  App/          InstaCamApp, ContentView
  Camera/       CameraController, FilteredPreviewView, PhotoCaptureProcessor
  Filters/      FilterType, FilterEngine
  Library/      MediaLibrary, PhotoSaver
  Views/        CameraView, GalleryView, FilterPickerView, CameraPreview
  Utils/        UIImage+Orientation
  Info.plist
InstaCamTests/  FilterEngineTests
project.yml     config XcodeGen
```

## Build local

```bash
brew install xcodegen
xcodegen generate
open InstaCam.xcodeproj
```

Puis lancer depuis Xcode sur un **appareil reel** pour la camera (le simulateur iOS
peut afficher une mire de test mais ne fournit pas de vraie capture).

## CI (GitHub Actions)

Le workflow `.github/workflows/ios.yml` genere le projet avec XcodeGen puis
build + teste sur simulateur a chaque push/PR sur `main`.

## Notes qualite

Instagram ne beneficie d'aucun acces privilegie au capteur. La difference vient
du post-traitement (filtres, colorimetrie, contraste, nettetee) et de la
compression. Ce projet applique exactement ce principe : flux AVFoundation brut
puis rendu GPU (Core Image / LUT) avant sauvegarde.
