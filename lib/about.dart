import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class About extends StatelessWidget {
  final String name;
  final String caption;

  About({@required this.name, @required this.caption});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width / 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 100 / 3),
          RichText(
            text: TextSpan(
              children: <TextSpan>[
                TextSpan(
                    text: this.name,
                    style: GoogleFonts.roboto(
                      fontWeight: FontWeight.bold,
                      fontSize: 17.5 * 0.9,
                      color: CupertinoColors.black,
                    )),
                TextSpan(
                    text: this.caption,
                    style: GoogleFonts.roboto(
                      fontSize: 17.5 * 0.9,
                      color: CupertinoColors.black,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
