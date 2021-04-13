import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
    if (qs != null) {
      if (Human.uid == null) {
        Human.others = qs.docs;
        return;
      }
      Human.others = [];
      for (int i = 0; i < qs.docs.length; i++) {
        final DocumentSnapshot snapshot = qs.docs[i];
        if (snapshot.id != Human.uid) {
          Human.others.add(snapshot);
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
          horizontal: MediaQuery.of(context).size.width / 15),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300],
        highlightColor: Colors.grey[100],
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            ClipOval(
              child: Container(
                width: 36.0,
                height: 36.0,
                color: Colors.white,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
            ),
            ClipRect(
              child: Align(
                heightFactor: 0.5,
                child: Stack(
                  children: [
                    Text(
                      'Michael Finnegan',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.newsCycle(
                        color: CupertinoColors.black,
                        fontSize: 17.5,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    Positioned.fill(
                        child: Material(
                      color: Colors.white,
                    ))
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Future<bool> _areYouSure(DocumentSnapshot snapshot) {
    return showCupertinoDialog(
        barrierDismissible: true,
        context: context,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            content: Text(
                'Are you sure you want to shmooze with ${snapshot.get('displayName')}?',
                style: GoogleFonts.roboto(
                  fontSize: 14.0,
                  color: CupertinoColors.black,
                )),
            actions: [
              TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                  child: Text(
                    'No',
                    style: GoogleFonts.roboto(
                      color: CupertinoColors.systemGrey,
                      fontWeight: FontWeight.w400,
                    ),
                  )),
              TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                  child: Text(
                    'Yes',
                    style: GoogleFonts.roboto(
                      color: CupertinoColors.activeBlue,
                      fontWeight: FontWeight.w400,
                    ),
                  )),
            ],
          );
        });
  }

  String _getInviteId(String receiverUid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(receiverUid)
        .collection('invites')
        .doc()
        .id;
  }

  Future<bool> _canUseMic() async {
    final PermissionStatus status =
        await Permission.microphone.request().catchError((error) {
      print(error);
    });
    if (status == null || status.isPermanentlyDenied) {
      if (status.isPermanentlyDenied) {
        showToastErrorMsg(
            'Go to settings to give Shmooze access to your microphone.');
      }
      return false;
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
    return Material(
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
                    'Select a person to shmooze with',
                    style: GoogleFonts.roboto(
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
          body: ListView.separated(
              physics: BouncingScrollPhysics(),
              separatorBuilder: (BuildContext context, int index) {
                return SizedBox(height: 20.0);
              },
              itemCount: _getItemCount(),
              itemBuilder: (BuildContext context, int index) {
                if (_isLoading()) {
                  return Padding(
                      padding: EdgeInsets.only(
                        top: index == 0 ? 20.0 : 0.0,
                        bottom: index == _getItemCount() - 1 ? 20.0 : 0.0,
                      ),
                      child: _waitingWidget());
                }
                final DocumentSnapshot snapshot = Human.others[index];
                return Padding(
                  padding: EdgeInsets.only(
                    top: index == 0 ? 20.0 : 0.0,
                    bottom: index == _getItemCount() - 1 ? 20.0 : 0.0,
                    left: MediaQuery.of(context).size.width / 15,
                    right: MediaQuery.of(context).size.width / 15,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        if (await _areYouSure(snapshot) ?? false) {
                          if (await _canUseMic() ?? false) {
                            if (!mounted) {
                              return;
                            }
                            Navigator.of(context).pushReplacement(
                                CupertinoPageRoute(
                                    builder: (BuildContext context) {
                              return PingPong(
                                senderUid: Human.uid,
                                receiverUid: snapshot.id,
                                photoUrl: snapshot.get('photoUrl'),
                                displayName: snapshot.get('displayName'),
                                inviteId: _getInviteId(snapshot.id),
                              );
                            }));
                          }
                        }
                      },
                      child: Row(
                        children: [
                          Material(
                            elevation: 1.5,
                            shape: CircleBorder(),
                            child: ClipOval(
                              child: Stack(
                                children: [
                                  Material(
                                    color: Colors.white,
                                    child: Container(
                                      width: 36.0,
                                      height: 36.0,
                                      color:
                                          Color(kNorthStar).withOpacity(1 / 3),
                                      child: Icon(
                                        Icons.person,
                                        color: CupertinoColors.systemGrey2,
                                        size: 15.0,
                                      ),
                                    ),
                                  ),
                                  snapshot.get('photoUrl') == null
                                      ? Container()
                                      : Positioned.fill(
                                          child: CachedNetworkImage(
                                          imageUrl: snapshot.get('photoUrl'),
                                          fit: BoxFit.cover,
                                        )),
                                ],
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.0),
                          ),
                          Expanded(
                            child: Text(
                              snapshot.get('displayName'),
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.roboto(
                                color: CupertinoColors.black,
                                fontWeight: FontWeight.w400,
                                fontSize: 13 + 1 / 3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              })),
    );
  }
}
