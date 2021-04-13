import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ntp/ntp.dart';
import 'package:shmooze/constants.dart';
import 'package:shmooze/human.dart';
import 'incoming.dart';

class Window extends StatefulWidget {
  @override
  _WindowState createState() => _WindowState();
}

class _WindowState extends State<Window> {
  StreamSubscription<QuerySnapshot> _inviteSubscription;
  final double _containerMinHeight = 0.0;
  final double _containerMaxHeight = 200.0;
  double _containerHeight;
  final Map<String, dynamic> _incomingShmooze = {};

  bool _isShowingNotification() {
    return _containerMaxHeight == _containerHeight &&
        _incomingShmooze.isNotEmpty;
  }

  void _showIncomingShmooze(String inviteId, String senderUid, String photoUrl,
      String displayName, int expiresIn) {
    _incomingShmooze['inviteId'] = inviteId;
    _incomingShmooze['senderUid'] = senderUid;
    _incomingShmooze['photoUrl'] = photoUrl;
    _incomingShmooze['displayName'] = displayName;
    _incomingShmooze['expiresIn'] = expiresIn;
    _containerHeight = _containerMaxHeight;
    if (mounted) {
      setState(() {});
    }
  }

  bool _isValid(int status) {
    return Status.waiting.index == status;
  }

  void _startListeningForNotifications() async {
    final Stream<QuerySnapshot> stream = FirebaseFirestore.instance
        .collection('users')
        .doc(Human.uid)
        .collection('invites')
        .orderBy('timestamp', descending: true)
        .where('timestamp',
            isGreaterThan: (await getCurrentTime()) - kExpirationInMillis)
        .limit(1)
        .snapshots();
    _inviteSubscription = stream.listen((QuerySnapshot qs) async {
      if (qs != null && qs.docs.isNotEmpty) {
        final DocumentSnapshot snapshot = qs.docs.first;
        final int status = snapshot.get('status');
        if (!_isValid(status)) {
          if (_isShowingNotification()) {
            _hideIncomingShmooze();
          }
        } else {
          final int expiresIn = kExpirationInMillis -
              ((await NTP.now()).millisecondsSinceEpoch -
                  snapshot.get('timestamp'));
          if (expiresIn >= 10000 / 3) {
            if (_isShowingNotification()) {
              return;
            }
            _showIncomingShmooze(
                snapshot.id,
                snapshot.get('senderUid'),
                snapshot.get('photoUrl'),
                snapshot.get('displayName'),
                expiresIn);
          }
        }
      }
    });
  }

  void _hideIncomingShmooze() {
    _incomingShmooze.clear();
    _containerHeight = 0.0;
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _containerHeight = _containerMinHeight;
    _startListeningForNotifications();
  }

  @override
  void dispose() {
    super.dispose();
    _inviteSubscription?.cancel()?.catchError((error) {
      print(error);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
        height: _containerHeight,
        width: double.infinity,
        color: Color(kNorthStar).withOpacity(1 / (10 * 2 / 3)),
        clipBehavior: Clip.none,
        curve: Curves.fastOutSlowIn,
        duration: Duration(milliseconds: 1000 ~/ 3),
        child: !_isShowingNotification()
            ? Container()
            : OverflowBox(
                maxHeight: _containerMaxHeight,
                child: Incoming(
                    inviteId: _incomingShmooze['inviteId'],
                    expiresIn: _incomingShmooze['expiresIn'],
                    displayName: _incomingShmooze['displayName'],
                    photoUrl: _incomingShmooze['photoUrl'],
                    hideIncomingShmooze: _hideIncomingShmooze,
                    senderUid: _incomingShmooze['senderUid']),
              ));
  }
}
