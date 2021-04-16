import 'dart:async';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shmooze/constants.dart';
import 'package:shmooze/ping_pong.dart';
import 'human.dart';

class Incoming extends StatefulWidget {
  final String senderUid;
  final String senderPhotoUrl;
  final String senderDisplayName;
  final int expiresIn;
  final VoidCallback hideIncomingShmooze;
  final String inviteId;
  final String shmoozeId;

  Incoming({
    @required this.expiresIn,
    @required this.senderUid,
    @required this.senderPhotoUrl,
    @required this.senderDisplayName,
    @required this.hideIncomingShmooze,
    @required this.inviteId,
    @required this.shmoozeId,
  });

  @override
  _IncomingState createState() => _IncomingState();
}

class _IncomingState extends State<Incoming> {
  Timer _timer;

  void _updateInviteStatus(int status) {
    FirebaseFunctions.instance.httpsCallable('updateInviteStatus').call({
      'receiverUid': Human.uid,
      'senderUid': widget.senderUid,
      'status': status,
      'inviteId': widget.inviteId,
      'shmoozeId': widget.shmoozeId,
    }).catchError((error) {
      print(error);
    });
  }

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
          'Go to settings to give Shmooze access to your microphone.');
    }
    return status.isGranted;
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer(
        Duration(milliseconds: widget.expiresIn), widget.hideIncomingShmooze);
  }

  void _hideCancelUpdate(int statusUpdate) {
    _timer?.cancel();
    _updateInviteStatus(statusUpdate);
    widget.hideIncomingShmooze();
  }

  @override
  void dispose() {
    super.dispose();
    _timer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width / 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: Container(), flex: 2),
          Row(
            children: [
              Expanded(
                child: AutoSizeText(
                    'Do you want to shmooze with ${widget.senderDisplayName}?',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.roboto(
                      color: CupertinoColors.black,
                      fontWeight: FontWeight.w400,
                      fontSize: 15.0,
                    )),
              ),
            ],
          ),
          Expanded(child: Container(), flex: 1),
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width / 40),
            child: SizedBox(
              height: 100 / 3,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: Color(kNorthStar),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'No',
                        style: GoogleFonts.roboto(
                          color: CupertinoColors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 10 + 10 / 3,
                        ),
                      ),
                      onPressed: () {
                        _hideCancelUpdate(Status.finished.index);
                      },
                    ),
                  ),
                  SizedBox(width: MediaQuery.of(context).size.width / 15),
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: CupertinoColors.activeBlue,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Yes',
                        style: GoogleFonts.roboto(
                          color: CupertinoColors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 10 + 10 / 3,
                        ),
                      ),
                      onPressed: () async {
                        if (await _canUseMic() ?? false) {
                          _hideCancelUpdate(Status.initializing.index);
                          if (!mounted) {
                            return;
                          }
                          Navigator.of(context).push(CupertinoPageRoute(
                              builder: (BuildContext context) {
                            return PingPong(
                                shmoozeId: widget.shmoozeId,
                                photoUrl: widget.senderPhotoUrl,
                                senderUid: widget.senderUid,
                                displayName: widget.senderDisplayName,
                                inviteId: widget.inviteId,
                                receiverUid: Human.uid);
                          }));
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: Container(), flex: 2),
        ],
      ),
    );
  }
}
