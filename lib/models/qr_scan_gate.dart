import 'demo_qr.dart';
import 'recipient.dart';

// Claims one detection at a time so repeated camera frames cannot open
// several transfer screens. Invalid codes require an explicit retry.
class QrScanGate {
  bool _claimed = false;
  bool get claimed => _claimed;
  Recipient? accept(String raw) {
    if (_claimed) return null;
    _claimed = true;
    return DemoQr.decode(raw);
  }

  void pause() => _claimed = true;
  void reset() => _claimed = false;
}
