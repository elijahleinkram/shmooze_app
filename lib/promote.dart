import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:share/share.dart';
import 'constants.dart';

class Promote extends StatefulWidget {
  final String heroTag;
  final String shmoozeId;
  final dynamic personA;
  final dynamic personB;
  final bool isPreview;

  Promote({
    @required this.heroTag,
    @required this.shmoozeId,
    @required this.personA,
    @required this.personB,
    @required this.isPreview,
  });

  @override
  _PromoteState createState() => _PromoteState();
}

class _PromoteState extends State<Promote> {
  void _promoteShmooze() {
    Share.share(
        'You might want to listen to this...\n${this.widget.personA} shmoozes with ${this.widget.personB}...\nhttps://getshmoozing.com/${this.widget.shmoozeId}');
  }

  Widget _child;

  @override
  void initState() {
    super.initState();
    if (widget.isPreview) {
      _child = SizedBox(height: 100 / 3);
    } else {
      _child = Column(
        children: [
          SizedBox(
            height: 100 / 3,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FloatingActionButton.extended(
                heroTag: widget.heroTag,
                onPressed: _promoteShmooze,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: Color(kNorthStar).withOpacity(1 / (10 / 3)),
                elevation: 0.0,
                highlightElevation: 0.0,
                focusElevation: 0.0,
                hoverElevation: 0.0,
                icon: Icon(
                  MaterialCommunityIcons.share,
                  color: CupertinoColors.black,
                  size: 20,
                ),
                label: Text(
                  'Share',
                  style: TextStyle(fontFamily: 'Roboto',
                    fontSize: 14.0,
                    fontWeight: FontWeight.w400,
                    color: CupertinoColors.black,
                  ),
                ),
              )
            ],
          ),
          SizedBox(
            height: 100 / 3,
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _child;
  }
}
