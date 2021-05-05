import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'home.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();
FirebaseAnalytics analytics = FirebaseAnalytics();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Firebase.initializeApp().then((value) => runApp(MaterialApp(
        navigatorObservers: [
          routeObserver,
          FirebaseAnalyticsObserver(analytics: analytics),
        ],
        title: 'Shmooze',
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
