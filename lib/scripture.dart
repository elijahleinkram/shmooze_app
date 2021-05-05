import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:shmooze/about.dart';
import 'package:shmooze/verse.dart';
import 'constants.dart';

class Scripture extends StatefulWidget {
  final dynamic verses;
  final AudioPlayer audioPlayer;
  final ValueKey<dynamic> key;
  final Future<void> Function() onRefresh;
  final bool isPreview;
  final String refreshToken;
  final int index;
  final String name;
  final String caption;
  final int Function() getCurrentPage;
  final dynamic startedRecording;
  final dynamic playFrom;
  final dynamic playUntil;
  final String shmoozeId;
  final dynamic personA;
  final dynamic personB;

  Scripture(
      {@required this.startedRecording,
      @required this.playFrom,
      @required this.personA,
      @required this.personB,
      @required this.shmoozeId,
      @required this.playUntil,
      @required this.getCurrentPage,
      @required this.verses,
      @required this.audioPlayer,
      @required this.onRefresh,
      @required this.isPreview,
      @required this.refreshToken,
      @required this.index,
      @required this.caption,
      @required this.name,
      @required this.key})
      : super(key: key);

  @override
  _ScriptureState createState() => _ScriptureState();
}

class _ScriptureState extends State<Scripture>
    with AutomaticKeepAliveClientMixin {
  final List<ValueKey> _keys = [];
  bool _isRefreshing;
  Future<void> Function() _onRefresh;
  CupertinoSliverRefreshControl _cupertinoSliverRefreshControl;
  final AutoScrollController _autoScrollController = AutoScrollController();

  void _cutKeys() {
    for (int i = 0; i < widget.verses.length; i++) {
      _keys.add(
          ValueKey(widget.verses[i]['verseId'] + ' ' + widget.refreshToken));
    }
  }

  void _toggleIsRefreshing() async {
    _isRefreshing = !_isRefreshing;
    if (_isRefreshing) {
      return;
    }
    await widget.audioPlayer
        .seek(Duration(milliseconds: widget.playFrom))
        .catchError((error) {
      print(error);
    });
    widget.audioPlayer.resume().catchError((error) {
      print(error);
    });
  }

  @override
  void initState() {
    super.initState();
    _isRefreshing = false;
    _cutKeys();
    if (widget.onRefresh != null) {
      _onRefresh = () async {
        if (_isRefreshing) {
          return;
        }
        _toggleIsRefreshing();
        await widget.onRefresh();
        _toggleIsRefreshing();
      };
    }
    if (widget.isPreview) {
      _cupertinoSliverRefreshControl = CupertinoSliverRefreshControl(
        refreshTriggerPullDistance: 100.0,
        refreshIndicatorExtent: 60.0,
        onRefresh: null,
        builder: null,
      );
    } else {
      _cupertinoSliverRefreshControl = CupertinoSliverRefreshControl(
        refreshTriggerPullDistance: 100.0,
        refreshIndicatorExtent: 60.0,
        onRefresh: _onRefresh,
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
    widget.audioPlayer.pause().catchError((error) {
      print(error);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            controller: _autoScrollController,
            physics:
                BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              _cupertinoSliverRefreshControl,
              SliverList(
                delegate: SliverChildListDelegate([
                  SizedBox(
                    height: 21.0 * 1 / 3,
                  )
                ]),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int index) {
                  final dynamic verse = widget.verses[index];
                  final dynamic quote = verse['quote'];
                  final dynamic displayName = verse['displayName'];
                  final dynamic photoUrl = verse['photoUrl'];
                  final dynamic opensMouth = verse['mouth']['opens'];
                  return AutoScrollTag(
                    index: index,
                    key: _keys[index],
                    controller: _autoScrollController,
                    child: Verse(
                      startedRecording: widget.startedRecording,
                      photoUrl: photoUrl,
                      audioPlayer: widget.audioPlayer,
                      opensMouth: opensMouth,
                      displayName: displayName,
                      quote: quote,
                    ),
                  );
                }, childCount: widget.verses.length),
              ),
              SliverList(
                delegate: SliverChildListDelegate([
                  SizedBox(
                    height: 21.0,
                  )
                  // Promote(
                  //   personA: widget.personA,
                  //   personB: widget.personB,
                  //   heroTag: 'share ' + widget.key.value,
                  //   shmoozeId: widget.shmoozeId,
                  //   isPreview: widget.isPreview,
                  // )
                ]),
              ),
            ],
          ),
        ),
        Material(
          color: Colors.white,
          elevation: 10.0,
          child: Material(
            color: Color(kNorthStar).withOpacity(1 / (10 * 2 / 3)),
            child: About(
              playFrom: widget.playFrom,
              startedRecording: widget.startedRecording,
              verses: widget.verses,
              audioPlayer: widget.audioPlayer,
              playUntil: widget.playUntil,
              name: 'The dangling conversation, ' + widget.caption,
              caption:
                  'this is where we talk about random things like love...' +
                      widget.name,
              horizontalPadding: MediaQuery.of(context).size.width / 15.0,
            ),
          ),
        )
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}




