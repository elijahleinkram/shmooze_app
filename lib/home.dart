import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
      if (qs != null && qs.docs != null) {
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
          child: MainStage(
            uploadShmooze: widget.uploadShmooze,
          ),
        ),
      ),
    );
  }
}
