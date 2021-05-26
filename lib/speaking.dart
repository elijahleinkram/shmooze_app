import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'constants.dart';

class Speaking extends StatefulWidget {
  final bool hostIsTalking;
  final List<ValueKey> speakerKeys;
  final dynamic shmoozes;
  final int Function() getOldPage;

  const Speaking({
    @required this.hostIsTalking,
    @required this.speakerKeys,
    @required this.shmoozes,
    @required this.getOldPage,
  });

  @override
  _SpeakingState createState() => _SpeakingState();
}

class _SpeakingState extends State<Speaking> {
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AnimatedSwitcher(
            duration: Duration(milliseconds: 1000 ~/ 3),
            reverseDuration: Duration(milliseconds: 1000 ~/ 3),
            child: widget.hostIsTalking
                ? Material(
                    key: widget.speakerKeys.first,
                    shape: CircleBorder(),
                    elevation: 10 / 3,
                    child: ClipOval(
                      child: Stack(
                        children: [
                          Material(
                            color: Color(kNorthStar).withOpacity(1 / 3),
                            child: Container(
                              width: 45.0,
                              height: 45.0,
                              color: Color(kNorthStar).withOpacity(1 / 3),
                              child: Align(
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.person,
                                  color: CupertinoColors.systemGrey2,
                                  size: 45.0 * 0.375,
                                ),
                              ),
                            ),
                          ),
                          widget.shmoozes[widget.getOldPage()]['personA']
                                      ['photoUrl'] ==
                                  null
                              ? Positioned.fill(child: Container())
                              : Positioned.fill(
                                  child: CachedNetworkImage(
                                    imageUrl:
                                        widget.shmoozes[widget.getOldPage()]
                                            ['personA']['photoUrl'],
                                    fit: BoxFit.cover,
                                  ),
                                ),
                        ],
                      ),
                    ),
                  )
                : Material(
                    key: widget.speakerKeys.last,
                    shape: CircleBorder(),
                    elevation: 10 / 3,
                    child: ClipOval(
                      child: Stack(
                        children: [
                          Material(
                            color: Color(kNorthStar).withOpacity(1 / 3),
                            child: Container(
                              width: 45.0,
                              height: 45.0,
                              color: Color(kNorthStar).withOpacity(1 / 3),
                              child: Align(
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.person,
                                  color: CupertinoColors.systemGrey2,
                                  size: 45.0 * 0.375,
                                ),
                              ),
                            ),
                          ),
                          widget.shmoozes[widget.getOldPage()]['personB']
                                      ['photoUrl'] ==
                                  null
                              ? Positioned.fill(child: Container())
                              : Positioned.fill(
                                  child: CachedNetworkImage(
                                    imageUrl:
                                        widget.shmoozes[widget.getOldPage()]
                                            ['personB']['photoUrl'],
                                    fit: BoxFit.cover,
                                  ),
                                ),
                        ],
                      ),
                    ),
                  )),
        SizedBox(width: MediaQuery.of(context).size.width / 12.5 / 2),
        Text(
          widget.hostIsTalking
              ? widget.shmoozes[widget.getOldPage()]['personA']['displayName']
              : widget.shmoozes[widget.getOldPage()]['personB']['displayName'],
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'NewsCycle',
            fontWeight: FontWeight.w700,
            color: CupertinoColors.black,
            fontSize: 16.5,
          ),
        )
      ],
    );
  }
}
