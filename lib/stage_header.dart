import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shmooze/constants.dart';
import 'package:shmooze/human.dart';
import 'package:shmooze/personify.dart';
import 'package:shmooze/shmoozers.dart';

class StageHeader extends StatefulWidget {
  final bool isPreview;
  final VoidCallback navigateToHome;

  StageHeader({@required this.isPreview, @required this.navigateToHome});

  @override
  _StageHeaderState createState() => _StageHeaderState();
}

class _StageHeaderState extends State<StageHeader> {
  final List<ValueKey<String>> _keys = [
    ValueKey('join'),
    ValueKey('start'),
    ValueKey('upload')
  ];

  void _navigateToShmoozes() {
    Navigator.of(context).push(CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (BuildContext context) {
          return Shmoozers(backButtonIcon: Icons.clear);
        }));
  }

  void _navigateToPersonify() {
    Navigator.of(context)
        .push(CupertinoPageRoute(builder: (BuildContext context) {
      return Personify(refreshStageHeader: _refreshStageHeader);
    }));
  }

  void _refreshStageHeader() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedSwitcher(
          duration: Duration(milliseconds: 1000 ~/ 3),
          reverseDuration: Duration(milliseconds: 1000 ~/ 3),
          child: !widget.isPreview
              ? !Human.accountExists
                  ? SizedBox(
                      key: _keys[0],
                      height: 40.0 + 10 / 3,
                      child: TextButton(
                          style: TextButton.styleFrom(
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: StadiumBorder(),
                              primary: CupertinoColors.systemGreen,
                              padding: EdgeInsets.symmetric(horizontal: 20.0),
                              backgroundColor:
                                  Color(kNorthStar).withOpacity(1 / 3)),
                          onPressed: _navigateToPersonify,
                          child: Text(
                            'Tap here to join the flow',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 15.0,
                              fontWeight: FontWeight.w500,
                              color: CupertinoColors.systemGrey,
                            ),
                          )),
                    )
                  : SizedBox(
                      key: _keys[1],
                      height: 40.0 + 10 / 3,
                      child: TextButton.icon(
                          style: TextButton.styleFrom(
                              primary: CupertinoColors.systemGreen,
                              shape: StadiumBorder(),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 15.0 + 1 / 3),
                              backgroundColor:
                                  Color(kNorthStar).withOpacity(1 / 3)),
                          onPressed: _navigateToShmoozes,
                          icon: Icon(
                            Icons.add,
                            size: 18.0,
                            color: CupertinoColors.systemGrey,
                          ),
                          label: Text(
                            'Start a new flow',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 15.0 + 1 / 3,
                              fontWeight: FontWeight.w500,
                              color: CupertinoColors.systemGrey,
                            ),
                          )),
                    )
              : SizedBox(
                  key: _keys[2],
                  height: 40.0 + 10 / 3,
                  child: TextButton(
                      style: TextButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: StadiumBorder(),
                        padding: EdgeInsets.symmetric(horizontal: 20.0),
                        backgroundColor: CupertinoColors.systemGreen,
                      ),
                      onPressed: widget.navigateToHome,
                      child: Text(
                        'Upload this flow',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 15.0,
                          fontWeight: FontWeight.w500,
                          color: CupertinoColors.white,
                        ),
                      )),
                )),
    );
  }
}
