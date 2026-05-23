class GlobalApi {
  static const String baseUrl = 'https://api.alrehmaneyehospital.com/api';
  // Use 10.0.2.2 for Android Emulator to reach localhost on host machine
  static const String mobileBaseUrl = 'https://api.alrehmaneyehospital.com/api/mobile';
  // static const String mobileBaseUrl = 'http://10.0.2.2:3001/api/mobile';

  static String? getImageUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;

    // serverRoot is baseUrl without /api
    final serverRoot = baseUrl.replaceAll(RegExp(r'/api/?$'), '');

    String imagePath = path.trim();
    
    // Normalize: remove leading slash for consistency in logic
    if (imagePath.startsWith('/')) {
      imagePath = imagePath.substring(1);
    }

    // Ensure it starts with uploads/ if not already present
    if (!imagePath.startsWith('uploads/')) {
      imagePath = 'uploads/$imagePath';
    }

    // Result is serverRoot + / + imagePath
    return '$serverRoot/$imagePath';
  }
}