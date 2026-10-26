import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

enum BiometricKind { none, face, fingerprint, generic }

class BiometricCapability {
  const BiometricCapability(this.kind, this.label);
  static const unavailable = BiometricCapability(
    BiometricKind.none,
    'Biometrics',
  );
  final BiometricKind kind;
  final String label;
  bool get available => kind != BiometricKind.none;
}

// Android may report only strength, without identifying the sensor type.
BiometricCapability selectBiometricCapability(
  List<BiometricType> types,
  TargetPlatform platform,
) {
  if (types.contains(BiometricType.face)) {
    return BiometricCapability(
      BiometricKind.face,
      platform == TargetPlatform.iOS ? 'Face ID' : 'Face unlock',
    );
  }
  if (types.contains(BiometricType.fingerprint)) {
    return BiometricCapability(
      BiometricKind.fingerprint,
      platform == TargetPlatform.iOS ? 'Touch ID' : 'Fingerprint',
    );
  }
  if (types.isNotEmpty) {
    return const BiometricCapability(BiometricKind.generic, 'Biometrics');
  }
  return BiometricCapability.unavailable;
}

abstract interface class BiometricService {
  Future<BiometricCapability> capability();
  Future<bool> authenticate({required String reason});
  Future<void> cancel();
}

class DeviceBiometricService implements BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();
  @override
  Future<BiometricCapability> capability() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.iOS &&
            defaultTargetPlatform != TargetPlatform.android)) {
      return BiometricCapability.unavailable;
    }
    if (!await _auth.canCheckBiometrics) return BiometricCapability.unavailable;
    return selectBiometricCapability(
      await _auth.getAvailableBiometrics(),
      defaultTargetPlatform,
    );
  }

  @override
  Future<bool> authenticate({required String reason}) => _auth.authenticate(
    localizedReason: reason,
    biometricOnly: true,
    persistAcrossBackgrounding: false,
  );
  @override
  Future<void> cancel() async {
    await _auth.stopAuthentication();
  }
}
