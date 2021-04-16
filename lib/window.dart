import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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

  bool _isShowingNotification([String inviteId]) {
    return _containerMaxHeight == _containerHeight &&
        _incomingShmooze.isNotEmpty &&
        (inviteId ?? _incomingShmooze['inviteId']) ==
            _incomingShmooze['inviteId'];
  }

  void _showIncomingShmooze(
    String inviteId,
    String senderUid,
    String senderPhotoUrl,
    String senderDisplayName,
    int expiresIn,
    String shmoozeId,
  ) {
    _incomingShmooze['inviteId'] = inviteId;
    _incomingShmooze['senderUid'] = senderUid;
    _incomingShmooze['senderPhotoUrl'] = senderPhotoUrl;
    _incomingShmooze['senderDisplayName'] = senderDisplayName;
    _incomingShmooze['expiresIn'] = expiresIn;
    _incomingShmooze['shmoozeId'] = shmoozeId;
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
        .collection('mailRoom')
        .where('receiver.uid', isEqualTo: Human.uid)
        .orderBy('expiresIn', descending: true)
        .where('expiresIn', isGreaterThan: (await getCurrentTime()))
        .limit(1)
        .snapshots();
    _inviteSubscription = stream.listen((QuerySnapshot qs) async {
      if (qs != null && qs.docs.isNotEmpty) {
        final DocumentSnapshot snapshot = qs.docs.first;
        final int status = snapshot.get('status');
        if (!_isValid(status)) {
          if (_isShowingNotification(snapshot.id)) {
            _hideIncomingShmooze();
          }
        } else {
          final int expiresIn =
              snapshot.get('expiresIn') - (await getCurrentTime());
          if (expiresIn >= 10000 ~/ 3) {
            if (!_isShowingNotification(snapshot.id)) {
              _showIncomingShmooze(
                  snapshot.id,
                  snapshot.get('sender.uid'),
                  snapshot.get('sender.photoUrl'),
                  snapshot.get('sender.displayName'),
                  expiresIn,
                  snapshot.get('shmoozeId'));
            }
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
                    shmoozeId: _incomingShmooze['shmoozeId'],
                    inviteId: _incomingShmooze['inviteId'],
                    expiresIn: _incomingShmooze['expiresIn'],
                    senderDisplayName: _incomingShmooze['senderDisplayName'],
                    senderPhotoUrl: _incomingShmooze['senderPhotoUrl'],
                    hideIncomingShmooze: _hideIncomingShmooze,
                    senderUid: _incomingShmooze['senderUid']),
              ));
  }
}
