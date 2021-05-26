import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class WaitingPage extends StatelessWidget {
  final String receiverDisplayName;
  final bool isSender;

  WaitingPage({@required this.receiverDisplayName, @required this.isSender});

  @override
  Widget build(BuildContext context) {
    return AutoSizeText(
        this.isSender
            ? 'Waiting for ${this.receiverDisplayName} to enter the flow...'
            : 'Please wait while we get the flow ready...',
        textAlign: TextAlign.center,
        maxLines: 1,
        style: TextStyle(
          fontFamily: 'Roboto',
          color: CupertinoColors.black,
          fontWeight: FontWeight.w400,
          fontSize: 10.0 + 10 * 2 / 3,
        ));
  }
}
