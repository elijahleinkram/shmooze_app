import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shmooze/constants.dart';
import 'package:shmooze/human.dart';
import 'package:shmooze/ping_pong.dart';

class Shmoozers extends StatefulWidget {
  final IconData backButtonIcon;

  Shmoozers({@required this.backButtonIcon});

  @override
  _ShmoozersState createState() => _ShmoozersState();
}

class _ShmoozersState extends State<Shmoozers> {
  final int _fakeItemLength = 100;

  void _getOthers() async {
    final QuerySnapshot qs = await FirebaseFirestore.instance
        .collection('users')
        .orderBy('displayName', descending: false)
        .get()
        .catchError((error) {
      print(error);
    });
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
      if (mounted) {
        setState(() {});
      }
    }
  }

  int _getItemCount() {
    final int length = Human.others.length;
    if (length == 0) {
      return _fakeItemLength;
    }
    return length;
  }

  bool _isLoading() {
    return Human.others.isEmpty;
  }

  Widget _waitingWidget() {
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width / 12.5),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300],
        highlightColor: Colors.grey[100],
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            ClipOval(
              child: Container(
                width: 45.0,
                height: 45.0,
                color: Colors.white,
              ),
            ),
            SizedBox(width: MediaQuery.of(context).size.width / 12.5 / 2),
            Stack(
              children: [
                Text(
                  'Michael Hollywood',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: CupertinoColors.black,
                    fontWeight: FontWeight.w400,
                    fontSize: 15.0,
                  ),
                ),
                Positioned.fill(
                    child: Material(
                  color: Colors.white,
                ))
              ],
            )
          ],
        ),
      ),
    );
  }

  // Future<bool> _areYouSure(DocumentSnapshot snapshot) {
  //   return showCupertinoDialog(
  //       barrierDismissible: true,
  //       context: context,
  //       builder: (BuildContext context) {
  //         return CupertinoAlertDialog(
  //           content: Text(
  //               'Are you sure you want to start the flow with ${snapshot.get('displayName')}?',
  //               style: TextStyle(
  //                   fontSize: 15.0 + 1 / 3,
  //                   color: CupertinoColors.black,
  //                   fontFamily: 'Roboto')),
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

  @override
  void initState() {
    super.initState();
    if (Human.others.isEmpty) {
      _getOthers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener(
      onNotification: (OverscrollIndicatorNotification overscroll) {
        overscroll.disallowGlow();
        return;
      },
      child: Material(
        color: Colors.white,
        child: Scaffold(
            backgroundColor: Colors.transparent,
            resizeToAvoidBottomInset: false,
            appBar: AppBar(
                automaticallyImplyLeading: false,
                backgroundColor: Colors.transparent,
                elevation: 0.0,
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(widget.backButtonIcon, size: 20.0),
                      color: CupertinoColors.black,
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    Text(
                      'Select a person to start the flow',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        color: CupertinoColors.black,
                        fontSize: 15.0,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    IconButton(
                      onPressed: null,
                      icon: Icon(
                        widget.backButtonIcon,
                        color: Colors.transparent,
                        size: 20.0,
                      ),
                    ),
                  ],
                )),
            body: CustomScrollView(
              slivers: [
                SliverList(
                    delegate:
                        SliverChildListDelegate([SizedBox(height: 10.0)])),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int index) {
                      if (_isLoading()) {
                        return Padding(
                            padding: EdgeInsets.only(
                              top: 10.0,
                              bottom: 10.0,
                            ),
                            child: _waitingWidget());
                      }
                      final DocumentSnapshot snapshot = Human.others[index];
                      return Stack(
                        children: [
                          Padding(
                            padding: EdgeInsets.only(
                              top: 10.0,
                              bottom: 10.0,
                              left: MediaQuery.of(context).size.width / 12.5,
                              right: MediaQuery.of(context).size.width / 12.5,
                            ),
                            child: Row(
                              children: [
                                ClipOval(
                                  child: Stack(
                                    children: [
                                      Material(
                                        color: Colors.white,
                                        child: Container(
                                          width: 45.0,
                                          height: 45.0,
                                          color: Color(kNorthStar)
                                              .withOpacity(1 / 3),
                                          child: Align(
                                            alignment: Alignment.center,
                                            child: Icon(
                                              Icons.person,
                                              color:
                                                  CupertinoColors.systemGrey2,
                                              size: 45.0 * 0.375,
                                            ),
                                          ),
                                        ),
                                      ),
                                      snapshot.get('photoUrl') == null
                                          ? Positioned.fill(child: Container())
                                          : Positioned.fill(
                                              child: CachedNetworkImage(
                                              imageUrl:
                                                  snapshot.get('photoUrl'),
                                              fit: BoxFit.cover,
                                            )),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                    width: MediaQuery.of(context).size.width /
                                        12.5 /
                                        2),
                                Expanded(
                                  child: Text(
                                    snapshot.get('displayName'),
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      color: CupertinoColors.black,
                                      fontWeight: FontWeight.w400,
                                      fontSize: 15.0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned.fill(
                              child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () async {
                                // if (await _areYouSure(snapshot) ?? false) {
                                if (await _canUseMic() ?? false) {
                                  if (!mounted) {
                                    return;
                                  }
                                  final String receiverUid = snapshot.id;
                                  final String photoUrl =
                                      snapshot.get('photoUrl');
                                  final String displayName =
                                      snapshot.get('displayName');
                                  Navigator.of(context).pushReplacement(
                                      CupertinoPageRoute(
                                          builder: (BuildContext context) {
                                    return PingPong(
                                      shmoozeId: null,
                                      inviteId: null,
                                      senderUid: Human.uid,
                                      receiverUid: receiverUid,
                                      photoUrl: photoUrl,
                                      displayName: displayName,
                                    );
                                  }));
                                }
                                // }
                              },
                            ),
                          ))
                        ],
                      );
                    },
                    childCount: _getItemCount(),
                  ),
                ),
                SliverList(
                    delegate:
                        SliverChildListDelegate([SizedBox(height: 10.0)])),
              ],
            )),
      ),
    );
  }
}
