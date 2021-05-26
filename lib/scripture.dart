import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:shmooze/verse.dart';
import 'constants.dart';

class Scripture extends StatefulWidget {
  final dynamic verses;
  final AudioPlayer audioPlayer;
  final Future<void> Function() onRefresh;
  final bool isPreview;
  final String refreshToken;
  final int pageNumber;
  final String name;
  final String caption;
  final int Function() getCurrentPage;
  final dynamic startedRecording;
  final dynamic playFrom;
  final dynamic playUntil;
  final String shmoozeId;
  final AutoScrollController autoScrollController;
  final List<double> sizes;
  final List<double> offsets;
  final List<bool> isScrollingOnPage;
  final List<bool> isAnimatingOnPage;
  final Function(bool hasTapped,
      [int pageNumber, String refreshToken, int lineNumber]) seekVerse;

  Scripture({
    @required this.startedRecording,
    @required this.isAnimatingOnPage,
    @required this.isScrollingOnPage,
    @required this.autoScrollController,
    @required this.seekVerse,
    @required this.playFrom,
    @required this.sizes,
    @required this.offsets,
    @required this.shmoozeId,
    @required this.playUntil,
    @required this.getCurrentPage,
    @required this.verses,
    @required this.audioPlayer,
    @required this.onRefresh,
    @required this.isPreview,
    @required this.refreshToken,
    @required this.pageNumber,
    @required this.caption,
    @required this.name,
  });

  @override
  _ScriptureState createState() => _ScriptureState();
}

class _ScriptureState extends State<Scripture>
    with AutomaticKeepAliveClientMixin {
  final List<ValueKey> _keys = [];

  // bool _isRefreshing;

  // Future<void> Function() _onRefresh;
  // CupertinoSliverRefreshControl _cupertinoSliverRefreshControl;

  void _cutKeys() {
    for (int i = 0; i < widget.verses.length; i++) {
      _keys.add(
          ValueKey(widget.verses[i]['verseId'] + ' ' + widget.refreshToken));
    }
  }

  // void _toggleIsRefreshing() async {
  //   _isRefreshing = !_isRefreshing;
  // }

  @override
  void initState() {
    super.initState();
    // _isRefreshing = false;
    _cutKeys();
    // if (widget.onRefresh != null) {
    //   _onRefresh = () async {
    //     if (_isRefreshing) {
    //       return;
    //     }
    //     _toggleIsRefreshing();
    //     await widget.onRefresh();
    //     _toggleIsRefreshing();
    //   };
    // }
    // if (widget.isPreview) {
    //   _cupertinoSliverRefreshControl = CupertinoSliverRefreshControl(
    //     refreshTriggerPullDistance: 200.0,
    //     refreshIndicatorExtent: 120.0,
    //     onRefresh: null,
    //     builder: null,
    //   );
    // } else {
    //   _cupertinoSliverRefreshControl = CupertinoSliverRefreshControl(
    //     refreshTriggerPullDistance: 200.0,
    //     refreshIndicatorExtent: 120.0,
    //     onRefresh: _onRefresh,
    //   );
    // }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return CustomScrollView(
      controller: widget.autoScrollController,
      physics: BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        // _cupertinoSliverRefreshControl,
        SliverList(
          delegate: SliverChildListDelegate([
            SizedBox(
                height:
                    MediaQuery.of(context).size.width / (12.5 * (3 + 1 / 3))),
          ]),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
              (BuildContext context, int lineNumber) {
            final dynamic verse = widget.verses[lineNumber];
            final dynamic quote = verse['quote'];
            final dynamic displayName = verse['displayName'];
            final dynamic photoUrl = verse['photoUrl'];
            final dynamic opensMouth = verse['mouth']['opens'];
            return AutoScrollTag(
              index: lineNumber,
              key: _keys[lineNumber],
              highlightColor: Color(kNorthStar).withOpacity(1 / (10 * 2 / 3)),
              controller: widget.autoScrollController,
              child: Verse(
                offsets: widget.offsets,
                seekVerse: widget.seekVerse,
                sizes: widget.sizes,
                lineNumber: lineNumber,
                autoScrollController: widget.autoScrollController,
                startedRecording: widget.startedRecording,
                photoUrl: photoUrl,
                audioPlayer: widget.audioPlayer,
                opensMouth: opensMouth,
                displayName: displayName,
                quote: quote,
              ),
              // ),
            );
          }, childCount: widget.verses.length),
        ),
        SliverList(
          delegate: SliverChildListDelegate([
            SizedBox(
              height: MediaQuery.of(context).size.height -
                  (widget.sizes.isEmpty ? 0.0 : widget.sizes.last ?? 0.0) -
                  (((MediaQuery.of(context).size.width /
                              (12.5 * (3 + 1 / 3)) *
                              2 *
                              2 *
                              (1 + 1 / 3)) +
                          (45.0 + (40.0 + (10 / 3)))) -
                      (MediaQuery.of(context).size.width /
                          (12.5 * (3 + 1 / 3)))) -
                  100 / 3,
            )
          ]),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}

// SliverList(
//   delegate: SliverChildListDelegate([
//     SizedBox(
//       height: 21.0 / 2,
//     )
//   ]),
// ),
// SliverList(
//   delegate: SliverChildListDelegate([
//     Padding(
//       padding: EdgeInsets.symmetric(
//           horizontal: MediaQuery.of(context).size.width / 15,
//           vertical: 21.0 / 2),
//       child: RichText(
//         text: TextSpan(
//           children: <TextSpan>[
//             TextSpan(
//                 text: 'The dangling conversation, ',
//                 style: GoogleFonts.newsCycle(
//                     fontWeight: FontWeight.bold,
//                     fontSize: 16.5 * (1 + 1 / 7.5),
//                     color: CupertinoColors.black)),
//             TextSpan(
//                 text:
//                     'some poeple just want it all, but I don\'t want anything at all, if it ain\'t you baby...',
//                 style: GoogleFonts.newsCycle(
//                     fontWeight: FontWeight.w400,
//                     fontSize: 16.5 * (1 + 1 / 7.5),
//                     color: CupertinoColors.black)),
//           ],
//         ),
//       ),
//     ),
//   ]),
// ),
