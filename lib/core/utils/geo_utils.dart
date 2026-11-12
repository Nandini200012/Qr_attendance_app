import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class GeoUtils {
  const GeoUtils._();

  static bool isValidCoordinate(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) return false;
    if (!latitude.isFinite || !longitude.isFinite) return false;
    return latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  static double calculateDistanceMeters({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }

  static String formatCoordinates(double lat, double lng) {
    return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
  }

  static Uri buildGoogleMapsUri(double lat, double lng) {
    return Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}',
    );
  }

  static Future<bool> openOnMap(double lat, double lng) async {
    final uri = buildGoogleMapsUri(lat, lng);
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

