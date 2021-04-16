import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WaitingPage extends StatelessWidget {
  final String receiverDisplayName;
  final bool isSender;

  WaitingPage({@required this.receiverDisplayName, @required this.isSender});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width / 15),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: AutoSizeText(
                  this.isSender
                      ? 'Waiting for ${this.receiverDisplayName} to join the shmooze...'
                      : 'Connecting to shmooze...',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.roboto(
                    color: CupertinoColors.black,
                    fontWeight: FontWeight.w400,
                    fontSize: 16.0,
                  )),
            )
          ],
        ),
      ),
    );
  }
}
