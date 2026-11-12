import 'package:equatable/equatable.dart';

enum FailedAttemptReason {
  expired('expired', 'Expired QR'),
  duplicate('duplicate', 'Duplicate Attempt'),
  invalidSignature('invalid_signature', 'Invalid Signature'),
  outOfRange('out_of_range', 'Out of Range'),
  unauthorized('unauthorized', 'Unauthorized'),
  networkError('network_error', 'Network Error');

  const FailedAttemptReason(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static FailedAttemptReason fromWireValue(String? raw) {
    for (final reason in FailedAttemptReason.values) {
      if (reason.wireValue == raw) return reason;
    }
    return FailedAttemptReason.invalidSignature;
  }
}

class FailedAttemptEntity extends Equatable {
  const FailedAttemptEntity({
    required this.id,
    required this.employeeId,
    this.employeeName,
    required this.timestamp,
    required this.reason,
    this.sessionId,
    this.lat,
    this.lng,
    this.message,
  });

  final String id;
  final int employeeId;
  final String? employeeName;
  final DateTime timestamp;
  final FailedAttemptReason reason;
  final String? sessionId;
  final double? lat;
  final double? lng;
  final String? message;

  String get displayEmployeeName {
    final trimmed = employeeName?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    if (employeeId > 0) {
      return 'EMP-${employeeId.toString().padLeft(3, '0')}';
    }
    return 'Unknown Employee';
  }

  FailedAttemptEntity copyWith({String? employeeName}) {
    return FailedAttemptEntity(
      id: id,
      employeeId: employeeId,
      employeeName: employeeName ?? this.employeeName,
      timestamp: timestamp,
      reason: reason,
      sessionId: sessionId,
      lat: lat,
      lng: lng,
      message: message,
    );
  }

  @override
  List<Object?> get props => [
        id,
        employeeId,
        employeeName,
        timestamp,
        reason,
        sessionId,
        lat,
        lng,
        message,
      ];
}

