import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'home.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();
FirebaseAnalytics analytics = FirebaseAnalytics();

void main() {
  LicenseRegistry.addLicense(() async* {
    final license =
        await rootBundle.loadString('google_fonts/OFL.txt').catchError((error) {
      print(error);
    });
    if (license != null) {
      yield LicenseEntryWithLineBreaks(['google_fonts'], license);
    }
  });
  WidgetsFlutterBinding.ensureInitialized();
  Firebase.initializeApp().then((value) => runApp(MaterialApp(
        navigatorObservers: [
          routeObserver,
          FirebaseAnalyticsObserver(analytics: analytics),
        ],
        title: 'The Flow',
        home: NotificationListener(
          onNotification: (OverscrollIndicatorNotification overScroll) {
            overScroll.disallowGlow();
            return false;
          },
          child: Home(
            uploadShmooze: null,
          ),
        ),
        debugShowCheckedModeBanner: false,
      )));
}
