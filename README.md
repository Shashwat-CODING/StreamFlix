# 🎬 StreamFlix

A modern, cross-platform streaming application built with Flutter that provides access to movies and TV shows with a beautiful, Netflix-inspired interface.

## ✨ Features

- **🎥 Movie & TV Show Streaming**: Watch your favorite content with high-quality video playback
- **🔍 Advanced Search**: Search through extensive movie and TV show databases
- **📱 Cross-Platform**: Works on Android, iOS, Web, Windows, macOS, and Linux
- **🌙 Dark/Light Theme**: Automatic theme switching with system preference support
- **🎮 Video Player**: Custom video player with full-screen support and playback controls
- **📚 Popular Content**: Discover trending movies and TV shows
- **🌍 Multi-language Support**: Content available in multiple languages
- **📱 Responsive Design**: Optimized for both mobile and desktop experiences

## 🖼️ Screenshots

### Mobile Interface
![Mobile Screenshot 1](screenshots/mob1.jpeg)
![Mobile Screenshot 2](screenshots/mob2.jpeg)
![Mobile Screenshot 3](screenshots/mob3.jpeg)

## 🚀 Getting Started

### Prerequisites

- [Flutter](https://flutter.dev/) (version 3.8.1 or higher)
- [Dart](https://dart.dev/) SDK
- Android Studio / VS Code with Flutter extensions
- Git

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/streamflix.git
   cd streamflix
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

### Building for Production

- **Android APK**: `flutter build apk --release`
- **iOS**: `flutter build ios --release`
- **Web**: `flutter build web --release`
- **Desktop**: `flutter build windows/macos/linux --release`

## 🏗️ Architecture

The app follows a clean architecture pattern with the following structure:

```
lib/
├── main.dart              # Main application entry point
├── services/
│   ├── tmdb_service.dart  # TMDB API integration
│   └── media_service.dart # Media streaming service
└── widgets/               # Reusable UI components
```

### Key Components

- **StreamFlixApp**: Main application widget with theme configuration
- **HomePage**: Landing page with search and popular content
- **DetailsPage**: Movie/TV show details and playback options
- **PlaybackPage**: Video player with custom controls

## 🔧 Dependencies

- **Flutter**: UI framework
- **http**: HTTP client for API requests
- **chewie**: Video player with custom controls
- **video_player**: Core video playback functionality
- **html**: HTML parsing utilities

## 🌐 API Integration

- **TMDB API**: Movie and TV show metadata
- **Media Service**: Stream resolution and playback

## 🎨 UI/UX Features

- **Material Design 3**: Modern, intuitive interface
- **Responsive Layout**: Adapts to different screen sizes
- **Smooth Animations**: Fluid transitions and interactions
- **Accessibility**: Screen reader support and keyboard navigation

## 📱 Platform Support

- ✅ Android (API 21+)
- ✅ iOS (12.0+)
- ✅ Web (Chrome, Firefox, Safari, Edge)
- ✅ Windows (10+)
- ✅ macOS (10.14+)
- ✅ Linux (Ubuntu 18.04+)

## 🚧 Development

### Code Style

The project follows Flutter's official style guide and uses `flutter_lints` for code quality.

### Testing

```bash
# Run unit tests
flutter test

# Run integration tests
flutter test integration_test/
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📞 Support

If you encounter any issues or have questions:

- Create an issue on GitHub
- Check the [Flutter documentation](https://docs.flutter.dev/)
- Review the [Dart documentation](https://dart.dev/guides)

## 🙏 Acknowledgments

- [Flutter Team](https://flutter.dev/) for the amazing framework
- [TMDB](https://www.themoviedb.org/) for movie and TV show data
- [Chewie](https://pub.dev/packages/chewie) for the video player
- [Video Player](https://pub.dev/packages/video_player) for core video functionality

---

**Made with ❤️ by Shashwat**
