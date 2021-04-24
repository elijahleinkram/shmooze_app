import 'dart:async';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shmooze/constants.dart';

class RecordingPage extends StatefulWidget {
  final String displayName;
  final bool isSender;
  final String photoUrl;
  final VoidCallback wrapThisUp;
  final VoidCallback onBack;
  final bool showThatWeAreFinished;
  final bool pauseScreen;
  final VoidCallback navigateToCaptioner;

  RecordingPage({
    @required this.pauseScreen,
    @required this.displayName,
    @required this.isSender,
    @required this.navigateToCaptioner,
    @required this.photoUrl,
    @required this.wrapThisUp,
    @required this.showThatWeAreFinished,
    @required this.onBack,
  });

  @override
  _RecordingPageState createState() => _RecordingPageState();
}

class _RecordingPageState extends State<RecordingPage> {
  Timer _timer;

  String _getCountdown() {
    final int minutes = _timer.tick ~/ 60;
    final int seconds = _timer.tick - (minutes * 60);
    String minStr;
    String secStr;
    if (minutes < 10) {
      minStr = '0$minutes';
    } else {
      minStr = '$minutes';
    }
    if (seconds < 10) {
      secStr = '0$seconds';
    } else {
      secStr = '$seconds';
    }
    return minStr + ':' + secStr;
  }

  Future<bool> _areYouSure() {
    return showCupertinoDialog(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            title: Text('Discard shmooze?'),
            content: Text(
              'Shmooze will never be able to be recovered.',
              style: GoogleFonts.roboto(),
            ),
            actions: [
              TextButton(
                child: Text(
                  'No',
                  style: GoogleFonts.roboto(
                    color: CupertinoColors.systemGrey,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
              ),
              TextButton(
                child: Text(
                  'Yes',
                  style: GoogleFonts.roboto(
                    color: CupertinoColors.activeBlue,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
              ),
            ],
          );
        });
  }

  void _discardShmooze() async {
    if (await _areYouSure() ?? false) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(covariant RecordingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pauseScreen != widget.pauseScreen && widget.pauseScreen) {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    super.dispose();
    _timer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          children: [
            Text(
              widget.displayName + ' ',
              style: GoogleFonts.roboto(
                fontSize: 25.0,
                fontWeight: FontWeight.w400,
                color: CupertinoColors.black,
              ),
            ),
            SizedBox(height: MediaQuery.of(context).size.height / 40),
            Text(
              _getCountdown(),
              style: GoogleFonts.roboto(
                fontSize: 15.0,
                fontWeight: FontWeight.w400,
                color: CupertinoColors.black,
              ),
            ),
          ],
        ),
        Material(
            shape: CircleBorder(),
            elevation: 10 / 3 / 2,
            child: Stack(
              children: [
                Center(
                  child: CircleAvatar(
                    radius: MediaQuery.of(context).size.width / 5,
                    backgroundColor: Color(kNorthStar).withOpacity(1 / 3),
                    child: Icon(
                      Icons.person,
                      color: CupertinoColors.systemGrey2,
                      size:
                          ((MediaQuery.of(context).size.width / 5) / 48) * 20.0,
                    ),
                  ),
                ),
                widget.photoUrl == null
                    ? Container()
                    : Center(
                        child: CircleAvatar(
                          radius: MediaQuery.of(context).size.width / 5,
                          backgroundImage:
                              CachedNetworkImageProvider(widget.photoUrl),
                        ),
                      ),
              ],
            )),
        widget.isSender
            ? widget.showThatWeAreFinished
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          FloatingActionButton(
                            heroTag: 'left',
                            onPressed: _discardShmooze,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            backgroundColor:
                                Color(kNorthStar).withOpacity(1 / (10 / 3)),
                            highlightElevation: 0.0,
                            focusElevation: 0.0,
                            hoverElevation: 0.0,
                            elevation: 0.0,
                            child: Center(
                              child: Icon(
                                MaterialCommunityIcons.delete,
                                color: CupertinoColors.black,
                                size: 20,
                              ),
                            ),
                          ),
                          SizedBox(height: 18.0),
                          Text(
                            'Discard',
                            style: GoogleFonts.roboto(
                              fontSize: 14.0,
                              fontWeight: FontWeight.w400,
                              color: CupertinoColors.black,
                            ),
                          )
                        ],
                      ),
                      Column(
                        children: [
                          FloatingActionButton(
                            heroTag: 'right',
                            onPressed: widget.navigateToCaptioner,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            backgroundColor:
                                Color(kNorthStar).withOpacity(1 / (10 / 3)),
                            elevation: 0.0,
                            highlightElevation: 0.0,
                            focusElevation: 0.0,
                            hoverElevation: 0.0,
                            child: Center(
                              child: Icon(
                                MaterialCommunityIcons.share,
                                color: CupertinoColors.black,
                                size: 20,
                              ),
                            ),
                          ),
                          SizedBox(height: 18.0),
                          Text(
                            'Share',
                            style: GoogleFonts.roboto(
                              fontSize: 14.0,
                              fontWeight: FontWeight.w400,
                              color: CupertinoColors.black,
                            ),
                          )
                        ],
                      )
                    ],
                  )
                : Column(
                    children: [
                      FloatingActionButton(
                        heroTag: 'up',
                        onPressed: widget.wrapThisUp,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor:
                            Color(kNorthStar).withOpacity(1 / (10 / 3)),
                        elevation: 0.0,
                        highlightElevation: 0.0,
                        focusElevation: 0.0,
                        hoverElevation: 0.0,
                        child: Center(
                          child: Icon(
                            MaterialCommunityIcons.page_next_outline,
                            color: CupertinoColors.black,
                            size: 20,
                          ),
                        ),
                      ),
                      SizedBox(height: 18.0),
                      Text(
                        'Finish talking and preview the shmooze',
                        style: GoogleFonts.roboto(
                          fontSize: 14.0,
                          fontWeight: FontWeight.w400,
                          color: CupertinoColors.black,
                        ),
                      )
                    ],
                  )
            : Column(
                children: [
                  FloatingActionButton(
                    heroTag: 'down',
                    onPressed: widget.onBack,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor:
                        Color(kNorthStar).withOpacity(1 / (10 / 3)),
                    elevation: 0.0,
                    highlightElevation: 0.0,
                    focusElevation: 0.0,
                    hoverElevation: 0.0,
                    child: Center(
                      child: Transform.rotate(
                        angle: pi,
                        child: Icon(
                          MaterialCommunityIcons.exit_to_app,
                          color: CupertinoColors.black,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 18.0),
                  Text(
                    'Leave shmooze',
                    style: GoogleFonts.roboto(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w400,
                      color: CupertinoColors.black,
                    ),
                  )
                ],
              )
      ],
    );
  }
}
