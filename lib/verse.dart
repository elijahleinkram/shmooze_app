import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Verse extends StatefulWidget {
  final dynamic displayName;
  final dynamic quote;
  final dynamic opensMouth;
  final dynamic photoUrl;
  final AudioPlayer audioPlayer;
  final dynamic startedRecording;

  Verse({
    @required this.startedRecording,
    @required this.photoUrl,
    @required this.displayName,
    @required this.quote,
    @required this.opensMouth,
    @required this.audioPlayer,
  });

  @override
  _VerseState createState() => _VerseState();
}

class _VerseState extends State<Verse> {
  String _time;

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

  @override
  void initState() {
    super.initState();
    _time = _getTime();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 21.0),
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
                      RichText(
                        text: TextSpan(
                          children: <TextSpan>[
                            TextSpan(
                                text: widget.displayName,
                                style: GoogleFonts.newsCycle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16.5,
                                    color: CupertinoColors.black)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  RichText(
                    text: TextSpan(
                      children: <TextSpan>[
                        TextSpan(
                            text: widget.quote,
                            style: GoogleFonts.newsCycle(
                                fontWeight: FontWeight.w400,
                                fontSize: 16.5 * (1 + 1 / 7.5),
                                color: CupertinoColors.black)),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: <TextSpan>[
                            TextSpan(
                                text: _time,
                                style: GoogleFonts.newsCycle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16.5 * 2 / 3,
                                    color: CupertinoColors.black)),
                          ],
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

