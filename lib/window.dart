import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shmooze/ping_pong.dart';

import 'constants.dart';
import 'human.dart';

class Window extends StatefulWidget {
  @override
  _WindowState createState() => _WindowState();
}

class _WindowState extends State<Window> {
  StreamSubscription<QuerySnapshot> _inviteSubscription;
  final Map<String, dynamic> _invitation = {};
  Timer _timer;
  final List<ValueKey> _keys = [ValueKey('open'), ValueKey('closed')];

  void _hideInvitation() {
    _invitation.clear();
    if (mounted) {
      setState(() {});
    }
  }

  bool _isValid(int status) {
    return Status.waiting.index == status;
  }

  bool _isShowingInvitation(String invitationId) {
    return _invitation['inviteId'] != null &&
        _invitation['inviteId'] == invitationId;
  }

  void _showInvitation(String inviteId, String senderUid, String senderPhotoUrl,
      String senderDisplayName, int expiresIn, String shmoozeId) async {
    if (_timer != null && _timer.isActive) {
      _timer.cancel();
    }
    _timer = Timer(Duration(milliseconds: expiresIn), () {
      // _updateInviteStatus(
      //     Status.finished.index, senderUid, inviteId, shmoozeId);
      _hideInvitation();
    });
    _invitation['inviteId'] = inviteId;
    _invitation['senderUid'] = senderUid;
    _invitation['senderPhotoUrl'] = senderPhotoUrl;
    _invitation['senderDisplayName'] = senderDisplayName;
    _invitation['expiresIn'] = expiresIn;
    _invitation['shmoozeId'] = shmoozeId;
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    super.dispose();
    _inviteSubscription?.cancel()?.catchError((error) => print(error));
  }

  void _startWaitingForInvitations() async {
    final Stream<QuerySnapshot> stream = FirebaseFirestore.instance
        .collection('mailRoom')
        .where('receiver.uid', isEqualTo: Human.uid)
        .orderBy('expiresIn', descending: true)
        .where('expiresIn', isGreaterThan: (await getCurrentTime()))
        .limit(1)
        .snapshots();
    _inviteSubscription = stream.listen((QuerySnapshot qs) async {
      if (qs != null && qs.docs != null && qs.docs.isNotEmpty) {
        final DocumentSnapshot snapshot = qs.docs.first;
        final int status = snapshot.get('status');
        if (!_isValid(status)) {
          if (_isShowingInvitation(snapshot.id)) {
            _hideInvitation();
          }
        } else {
          final int expiresIn =
              snapshot.get('expiresIn') - (await getCurrentTime());
          if (expiresIn >= 0) {
            if (!_isShowingInvitation(snapshot.id)) {
              _showInvitation(
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

  // Future<bool> _areYouSure(String displayName) {
  //   return showCupertinoDialog(
  //       barrierDismissible: true,
  //       context: context,
  //       builder: (BuildContext context) {
  //         return CupertinoAlertDialog(
  //           content: Text(
  //               'Are you sure you want to start flowing with $displayName?',
  //               style: TextStyle(
  //                 fontFamily: 'Roboto',
  //                 fontSize: 15.0 + 1 / 3,
  //                 color: CupertinoColors.black,
  //               )),
  //           actions: [
  //             TextButton(
  //                 onPressed: () {
  //                   Navigator.of(context).pop(false);
  //                 },
  //                 child: Text(
  //                   'No',
  //                   style: TextStyle(
  //                     fontFamily: 'Roboto',
  //                     color: CupertinoColors.systemGrey,
  //                     fontWeight: FontWeight.w500,
  //                   ),
  //                 )),
  //             TextButton(
  //                 onPressed: () {
  //                   Navigator.of(context).pop(true);
  //                 },
  //                 child: Text(
  //                   'Yes',
  //                   style: TextStyle(
  //                     fontFamily: 'Roboto',
  //                     color: CupertinoColors.activeBlue,
  //                     fontWeight: FontWeight.w500,
  //                   ),
  //                 )),
  //           ],
  //         );
  //       });
  // }

  Future<bool> _canUseMic() async {
    final PermissionStatus status =
        await Permission.microphone.request().catchError((error) {
      print(error);
    });
    if (status == null) {
      return false;
    }
    if (status.isPermanentlyDenied) {
      showToastErrorMsg(
          'Go to settings to give The Flow access to your microphone.');
    }
    return status.isGranted;
  }

  void _updateInviteStatus(
      int status, String senderUid, String inviteId, String shmoozeId) {
    FirebaseFunctions.instance.httpsCallable('updateInviteStatus').call({
      'receiverUid': Human.uid,
      'senderUid': senderUid,
      'status': status,
      'inviteId': inviteId,
      'shmoozeId': shmoozeId,
    }).catchError((error) {
      print(error);
    });
  }

  void _onTap() async {
    if (await _canUseMic() ?? false) {
      final String inviteId = _invitation['inviteId'];
      final String senderPhotoUrl = _invitation['senderPhotoUrl'];
      final String senderUid = _invitation['senderUid'];
      final String senderDisplayName = _invitation['senderDisplayName'];
      final String shmoozeId = _invitation['shmoozeId'];
      _updateInviteStatus(
          Status.initializing.index, senderUid, inviteId, shmoozeId);
      _timer.cancel();
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (_invitation['inviteId'] != null &&
            _invitation['inviteId'] == inviteId) {
          _hideInvitation();
        }
      });
      if (!mounted) {
        return;
      }
      Navigator.of(context)
          .push(CupertinoPageRoute(builder: (BuildContext context) {
        return PingPong(
            shmoozeId: shmoozeId,
            photoUrl: senderPhotoUrl,
            senderUid: senderUid,
            displayName: senderDisplayName,
            inviteId: inviteId,
            receiverUid: Human.uid);
      }));
    }
  }

  @override
  void initState() {
    super.initState();
    _startWaitingForInvitations();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Duration(milliseconds: 1000 ~/ 3),
      reverseDuration: Duration(milliseconds: 1000 ~/ 3),
      child: _invitation.isEmpty
          ? SizedBox.shrink(
              key: _keys.first,
            )
          : SizedBox(
              key: _keys.last,
              height: 100.0 * 0.5,
              width: double.infinity,
              child: Material(
                color: CupertinoColors.activeGreen,
                child: InkWell(
                  onTap: _onTap,
                  child: Center(
                      child: AutoSizeText(
                    'Tap here to enter the flow with ${_invitation['senderDisplayName']}',
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 14.0,
                    ),
                  )),
                ),
              ),
            ),
    );
  }
}
