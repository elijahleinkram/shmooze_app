import 'package:fluttertoast/fluttertoast.dart';
import 'package:ntp/ntp.dart';

const int kNorthStar = 0xFFcad0d2;
final int kExpirationInMillis = (60 * 3) * 1000;
final int kNameMaxLength = 24;

enum Status {
  waiting,
  initializing,
  connected,
  finished,
}

void showToastErrorMsg(String msg) {
  Fluttertoast.cancel().then((_) {
    Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    ).catchError((error) {
      print(error);
    });
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
