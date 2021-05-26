import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class RecordingPage extends StatefulWidget {
  final String displayName;
  final bool isSender;
  final String photoUrl;

  RecordingPage({
    @required this.displayName,
    @required this.isSender,
    @required this.photoUrl,
  });

  @override
  _RecordingPageState createState() => _RecordingPageState();
}

class _RecordingPageState extends State<RecordingPage> {
  @override
  Widget build(BuildContext context) {
    return AutoSizeText(
      'Flowing with ' + widget.displayName + '...',
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      maxLines: 1,
      style: TextStyle(
        fontFamily: 'Roboto',
        color: CupertinoColors.black,
        fontWeight: FontWeight.w400,
        fontSize: 10.0 + 10 * 2 / 3,
      ),
    );
  }
}
