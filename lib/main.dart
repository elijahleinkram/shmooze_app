import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'home.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Firebase.initializeApp().then((value) => runApp(MaterialApp(
        navigatorObservers: [routeObserver],
        title: 'Shmooze',
        home: Home(
          prepareForDispatch: null,
        ),
        debugShowCheckedModeBanner: false,
      )));
}
