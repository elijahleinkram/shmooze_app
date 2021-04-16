import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'constants.dart';

class Verse extends StatefulWidget {
  final dynamic displayName;
  final dynamic quote;
  final bool isPlaying;
  final dynamic opensMouth;
  final int index;
  final int length;
  final dynamic photoUrl;
  final AudioPlayer audioPlayer;
  final ValueKey<dynamic> key;
  final Function(int index) updateLineNumber;
  final Function(double volume) changeVolumeTo;
  final bool isMuted;

  Verse({
    @required this.updateLineNumber,
    @required this.changeVolumeTo,
    @required this.isMuted,
    @required this.photoUrl,
    @required this.displayName,
    @required this.quote,
    @required this.isPlaying,
    @required this.opensMouth,
    @required this.audioPlayer,
    @required this.index,
    @required this.length,
    @required this.key,
  }) : super(key: key);

  @override
  _VerseState createState() => _VerseState();
}

class _VerseState extends State<Verse> {
  String _time;
  Widget _bottomWidget;

  String _getTime() {
    final DateTime dateTime =
        DateTime.fromMillisecondsSinceEpoch(widget.opensMouth);
    int hours = dateTime.hour;
    bool isPm = false;
    if (hours >= 12) {
      isPm = true;
    }
    hours = hours % 12;
    if (hours == 0) {
      hours = 12;
    }
    int minutes = dateTime.minute;
    return '$hours:${minutes < 10 ? '0$minutes' : minutes} ${isPm ? 'pm' : 'am'}';
  }

  Widget _faceWidget;

  Widget _trailingIcon() {
    if (widget.isPlaying) {
      if (widget.isMuted) {
        return Icon(
          Ionicons.ios_volume_mute,
          size: 17.5 * 0.75,
          color: CupertinoColors.activeBlue,
        );
      } else {
        return Icon(
          Ionicons.ios_volume_high,
          size: 17.5 * 0.75,
          color: CupertinoColors.activeBlue,
        );
      }
    }
    return Container();
  }

  @override
  void initState() {
    super.initState();
    _time = _getTime();
    final bool isAtTheEnd = widget.index == widget.length - 1;
    _faceWidget = widget.photoUrl == null
        ? Container()
        : CachedNetworkImage(
            imageUrl: widget.photoUrl,
            fit: BoxFit.cover,
          );
    _bottomWidget = isAtTheEnd
        ? SizedBox(
            height: 100 / 3,
          )
        : Container();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 100 / 3),
        Stack(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width / 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Material(
                        shape: CircleBorder(),
                        elevation: 1.5,
                        child: ClipOval(
                          child: Stack(
                            children: [
                              Container(
                                width: 100 / 4,
                                height: 100 / 4,
                                color: Color(kNorthStar).withOpacity(1 / 3),
                                child: Align(
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.person,
                                    color: CupertinoColors.systemGrey2,
                                    size: 20.0 * ((100 / 4) / 48),
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: _faceWidget,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 17.5 * 0.5),
                      Text(widget.displayName,
                          style: GoogleFonts.roboto(
                            fontSize: 17.5 * 3 / 4,
                            color: CupertinoColors.black,
                            fontWeight: FontWeight.w500,
                          )),
                    ],
                  ),
                  SizedBox(height: 17.5 * 0.5),
                  Text(
                    widget.quote,
                    textAlign: TextAlign.left,
                    style: GoogleFonts.newsCycle(
                      color: CupertinoColors.black,
                      fontSize: 17.5,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  SizedBox(height: 17.5 * 0.25),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        _time,
                        style: GoogleFonts.newsCycle(
                          fontSize: 17.5 * 2 / 3,
                          color: CupertinoColors.black,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      Stack(
                        children: [
                          Icon(Ionicons.ios_volume_high,
                              size: 17.5, color: Colors.transparent),
                          AnimatedSwitcher(
                            duration:
                                Duration(milliseconds: 1000 ~/ (10 * 2 / 3)),
                            child: _trailingIcon(),
                          )
                        ],
                      )
                    ],
                  )
                ],
              ),
            ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    if (!widget.isPlaying) {
                      widget.updateLineNumber(widget.index);
                    }
                    if (widget.isMuted) {
                      widget.changeVolumeTo(1.0);
                      widget.audioPlayer
                          .seek(Duration(milliseconds: (widget.opensMouth)));
                    } else {
                      if (widget.isPlaying) {
                        widget.changeVolumeTo(0.0);
                      } else {
                        widget.changeVolumeTo(1.0);
                        widget.audioPlayer
                            .seek(Duration(milliseconds: (widget.opensMouth)));
                      }
                    }
                  },
                ),
              ),
            )
          ],
        ),
        _bottomWidget,
      ],
    );
  }
}
