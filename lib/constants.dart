import 'package:fluttertoast/fluttertoast.dart';
import 'package:ntp/ntp.dart';

const int kSteamedMilk = 0xFFECE1D1;
const int kPureWhite = 0xFFeeede7;
const int kColorTrendInkWell = 0xFF242b38;
const int kLoyalBlue = 0xFF01455e;
const int kOrigamiWhite = 0xFFe5e2da;
const int kSkyPixel = 0xFF91CCEC;
const int kNorthStar = 0xFFcad0d2;
const int kVermilion = 0xFF7e191b;
const int kDefaultQuietColor = 0xFFF9F9F7;
const int kDefaultLoudColor = 0xFF53A4FD;
const int kDefaultActiveBlue = 0xFF007AFF;
final int kExpirationInMillis = 90000;
final int kTitleMaxLength = 32;
final int kDescriptionMaxLength = 128;
final int kNameMaxLength = 24;
enum Status {
  waiting,
  initializing,
  connected,
  unavailable,
  exits,
  cancelled,
  complete,
}

void showToastErrorMsg(String msg) {
  Fluttertoast.cancel().then((_) {
    Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
  }).catchError((error) {
    print(error);
  });
}

Future<int> getCurrentTime() async {
  final preMillis = DateTime.now().millisecondsSinceEpoch;
  final int currentMillis = (await NTP.now().catchError((error) {
            print(error);
          }) ??
          DateTime.now())
      .millisecondsSinceEpoch;
  final postMillis = DateTime.now().millisecondsSinceEpoch;
  return currentMillis - (postMillis - preMillis);
}
