import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shmooze/personify.dart';
import 'package:shmooze/shmoozers.dart';
import 'window.dart';
import 'human.dart';
import 'main_stage.dart';

class Home extends StatefulWidget {
  final Future<void> Function() uploadShmooze;

  Home({@required this.uploadShmooze});

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  StreamSubscription<QuerySnapshot> _userSubscription;

  void _startListeningForUsers() {
    final Stream<QuerySnapshot> stream = FirebaseFirestore.instance
        .collection('users')
        .orderBy('displayName', descending: false)
        .snapshots();
    _userSubscription = stream.listen((QuerySnapshot qs) {
      if (qs != null && qs.docs.isNotEmpty) {
        if (Human.uid == null) {
          Human.others = qs.docs;
        } else {
          Human.others = [];
          for (int i = 0; i < qs.docs.length; i++) {
            final DocumentSnapshot snapshot = qs.docs[i];
            if (snapshot.id != Human.uid) {
              Human.others.add(snapshot);
            }
          }
        }
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    _userSubscription.cancel().catchError((error) {
      print(error);
    });
  }

  bool _hasSignedIn() {
    return Human.uid != null;
  }

  FloatingActionButtonLocation _getFloatingActionButtonLocation() {
    if (Human.accountExists) {
      return FloatingActionButtonLocation.endFloat;
    } else {
      return FloatingActionButtonLocation.centerFloat;
    }
  }

  Widget _getFloatingActionButton() {
    if (Human.accountExists) {
      return FloatingActionButton(
        heroTag: 'make',
        child: Icon(Icons.add, color: Colors.white),
        backgroundColor: CupertinoColors.activeBlue,
        onPressed: () {
          Navigator.of(context)
              .push(CupertinoPageRoute(
                  fullscreenDialog: true,
                  builder: (BuildContext context) {
                    return Shmoozers(
                      backButtonIcon: Icons.clear,
                    );
                  }))
              .catchError((error) {
            print(error);
          });
        },
      );
    } else {
      return ElevatedButton(
        style: TextButton.styleFrom(
            shape: StadiumBorder(),
            backgroundColor: CupertinoColors.activeBlue,
            padding: EdgeInsets.symmetric(horizontal: 18.0, vertical: 11.0)),
        onPressed: () {
          Navigator.of(context)
              .push(CupertinoPageRoute(builder: (BuildContext context) {
            return Personify(
              updateMainStage: () {
                if (mounted) {
                  setState(() {});
                }
              },
            );
          }));
        },
        child: Text(
          'Create account to start shmoozing',
          style: GoogleFonts.roboto(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    Human.accountExists = false;
    Human.others = [];
    final User user = FirebaseAuth.instance.currentUser;
    Human.currentUser = user;
    if (user == null) {
      FirebaseAuth.instance.signInAnonymously().then((UserCredential uc) {
        Human.uid = uc.user.uid;
        Human.currentUser = uc.user;
        if (mounted) {
          setState(() {});
        }
      });
    } else {
      Human.uid = user.uid;
      Human.accountExists =
          user.displayName != null && user.displayName.isNotEmpty;
      if (Human.accountExists) {
        Human.displayName = user.displayName;
        Human.photoUrl = user.photoURL;
      }
    }
    _startListeningForUsers();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return false;
      },
      child: Material(
        color: Colors.white,
        child: SafeArea(
          child: Column(
            children: [
              !_hasSignedIn() ? Container() : Window(),
              Expanded(
                  child: Scaffold(
                resizeToAvoidBottomInset: false,
                floatingActionButtonLocation:
                    _getFloatingActionButtonLocation(),
                floatingActionButton: _getFloatingActionButton(),
                backgroundColor: Colors.transparent,
                body: MainStage(
                  uploadShmooze: widget.uploadShmooze,
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }
}
