import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class About extends StatefulWidget {
  final String name;
  final String caption;
  final double horizontalPadding;

  About(
      {@required this.name,
      @required this.caption,
      @required this.horizontalPadding});

  @override
  _AboutState createState() => _AboutState();
}

class _AboutState extends State<About> {
  Widget child;

  @override
  void initState() {
    super.initState();
    if (widget.caption.isEmpty) {
      child = Container();
    } else {
      child = Padding(
        padding: EdgeInsets.symmetric(horizontal: widget.horizontalPadding),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(height: 100 / 3),
          Text(widget.caption,
              style: GoogleFonts.roboto(
                fontWeight: FontWeight.w500,
                fontSize: 15.0,
                color: CupertinoColors.black,
              )),
        ]),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
