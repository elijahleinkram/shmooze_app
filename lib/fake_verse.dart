import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class FakeVerse extends StatelessWidget {
  const FakeVerse();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300],
      highlightColor: Colors.grey[100],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.width / (12.5 * (3 + 1 / 3)),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width / 12.5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 10 * 2 / 3),
                Stack(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: RichText(
                        textScaleFactor: MediaQuery.of(context).textScaleFactor,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.start,
                        maxLines: 1,
                        text: TextSpan(
                          children: <TextSpan>[
                            TextSpan(
                                text: 'a',
                                style: TextStyle(
                                    fontFamily: 'NewsCycle',
                                    fontWeight: FontWeight.w400,
                                    fontSize: 16.5 *
                                        (1 + 1 / 7.5) *
                                        (1 + 1 / 3) *
                                        0.5,
                                    color: Colors.transparent)),
                          ],
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Material(color: Colors.white),
                    )
                  ],
                ),
                SizedBox(height: 10 * 2 / 3),
                Stack(
                  children: [
                    Align(
                      widthFactor: ((2 / 3) + (1 / 2)) / 2,
                      child: SizedBox(
                        width: double.infinity,
                        child: RichText(
                          textScaleFactor:
                              MediaQuery.of(context).textScaleFactor,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.start,
                          maxLines: 1,
                          text: TextSpan(
                            children: <TextSpan>[
                              TextSpan(
                                  text: 'a',
                                  style: TextStyle(
                                      fontFamily: 'NewsCycle',
                                      fontWeight: FontWeight.w400,
                                      fontSize: 16.5 *
                                          (1 + 1 / 7.5) *
                                          (1 + 1 / 3) *
                                          0.5,
                                      color: Colors.transparent)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Material(color: Colors.white),
                    )
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            height: MediaQuery.of(context).size.width / (12.5 * (3 + 1 / 3)),
          ),
        ],
      ),
    );
  }
}
