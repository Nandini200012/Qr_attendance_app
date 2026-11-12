import 'dart:async' as async_core;

import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart'
    as permission_handler;
import 'package:qr_attendance_app/core/constants/app_constants.dart';
import 'package:qr_attendance_app/core/errors/exceptions.dart';

class CapturedLocation extends Equatable {
  const CapturedLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.capturedAtUtc,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime capturedAtUtc;

  @override
  List<Object?> get props => [
        latitude,
        longitude,
        accuracyMeters,
        capturedAtUtc,
      ];
}

abstract class LocationService {
  Future<CapturedLocation> getCurrentLocation();
  Future<bool> openLocationSettings();
  Future<bool> openAppSettings();
}

class GeolocatorLocationService implements LocationService {
  @override
  Future<CapturedLocation> getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw const LocationException(
          'Location services are turned off. Please enable GPS to mark attendance.',
          errorType: LocationErrorType.servicesDisabled,
          isServiceDisabled: true,
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw const LocationException(
          'Location permission is required to verify your attendance coordinates.',
          errorType: LocationErrorType.permissionDenied,
        );
      }

      if (permission == LocationPermission.deniedForever) {
        throw const LocationException(
          'Location permission is permanently denied. Please enable it in app settings.',
          errorType: LocationErrorType.permissionDeniedForever,
          isPermissionDeniedForever: true,
        );
      }

      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: AppConstants.locationTimeout,
          ),
        );
      } on async_core.TimeoutException {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown == null) {
          throw const LocationException(
            'GPS signal timed out. Move near a window or retry.',
            errorType: LocationErrorType.timeout,
          );
        }
        position = lastKnown;
      }

      return CapturedLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        capturedAtUtc: DateTime.now().toUtc(),
      );
    } on LocationException {
      rethrow;
    } catch (_) {
      throw const LocationException(
        'Unable to read your current GPS coordinates. Please check location access and try again.',
        errorType: LocationErrorType.unavailable,
      );
    }
  }

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  @override
  Future<bool> openAppSettings() => permission_handler.openAppSettings();
}
