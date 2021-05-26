import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class FakeSpeaking extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300],
      highlightColor: Colors.grey[100],
      child: Row(
        children: [
          ClipOval(
            child: SizedBox(
              height: 45.0,
              width: 45.0,
              child: Material(
                color: Colors.white,
                shape: CircleBorder(),
                elevation: 10 / 3,
              ),
            ),
          ),
          SizedBox(width: MediaQuery.of(context).size.width / 12.5 / 2),
          Stack(
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width / (10 / 3),
                child: Text(
                  'a',
                  style: TextStyle(
                    fontFamily: 'NewsCycle' ,
                    fontWeight: FontWeight.w700,
                    color: Colors.transparent,
                    fontSize: 16.5,
                  ),
                ),
              ),
              Positioned.fill(
                  child: Padding(
                padding: EdgeInsets.symmetric(vertical: 5.75),
                child: Material(
                  color: Colors.white,
                ),
              ))
            ],
          )
        ],
      ),
    );
  }
}
