import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

class FakeVerse extends StatefulWidget {
  final int index;
  final int length;

  FakeVerse({@required this.index, @required this.length});

  @override
  _FakeVerseState createState() => _FakeVerseState();
}

class _FakeVerseState extends State<FakeVerse> {
  Widget _bottomWidget;

  @override
  void initState() {
    super.initState();
    final bool isAtTheEnd = widget.index == widget.length - 1;
    _bottomWidget = isAtTheEnd
        ? SizedBox(
            height: 100 / 3,
          )
        : Container();
  }

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300],
      highlightColor: Colors.grey[100],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 100 / 3),
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
                    ClipOval(
                      child: Container(
                        width: 40.0,
                        height: 40.0,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 17.5 * 0.5),
                    ClipRect(
                      child: Align(
                        heightFactor: 0.5,
                        child: Stack(
                          children: [
                            Text(
                              '770 Eastern Parkway',
                              style: GoogleFonts.newsCycle(
                                color: CupertinoColors.black,
                                fontSize: 17.5,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                            Positioned.fill(
                                child: Material(color: Colors.white))
                          ],
                        ),
                      ),
                    )
                  ],
                ),
                SizedBox(height: 17.5 * 0.5),
                ClipRect(
                  child: Align(
                    heightFactor: 0.5,
                    child: Stack(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: Text(
                            'There once was a man named michael finnegan',
                            textAlign: TextAlign.left,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: GoogleFonts.newsCycle(
                              color: CupertinoColors.black,
                              fontSize: 20.0,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                        Positioned.fill(child: Material(color: Colors.white))
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 17.5 * 0.5),
                ClipRect(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    heightFactor: 0.5,
                    child: Stack(
                      children: [
                        Text(
                          'Who had some...',
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.left,
                          maxLines: 1,
                          style: GoogleFonts.newsCycle(
                            color: CupertinoColors.black,
                            fontSize: 20.0,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        Positioned.fill(child: Material(color: Colors.white))
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _bottomWidget,
        ],
      ),
    );
  }
}
