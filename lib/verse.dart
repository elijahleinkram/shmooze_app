import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'dart:math' as math;

class Verse extends StatefulWidget {
  final dynamic displayName;
  final dynamic quote;
  final dynamic opensMouth;
  final dynamic photoUrl;
  final AudioPlayer audioPlayer;
  final dynamic startedRecording;
  final AutoScrollController autoScrollController;
  final int lineNumber;
  final List<double> offsets;
  final List<double> sizes;
  final Function(bool hasTapped,
      [int pageNumber, String refreshToken, int lineNumber]) seekVerse;

  Verse({
    @required this.startedRecording,
    @required this.lineNumber,
    @required this.offsets,
    @required this.sizes,
    @required this.photoUrl,
    @required this.autoScrollController,
    @required this.displayName,
    @required this.quote,
    @required this.opensMouth,
    @required this.seekVerse,
    @required this.audioPlayer,
  });

  @override
  _VerseState createState() => _VerseState();
}

class _VerseState extends State<Verse> {
  String _time;
  double _blurHeightFactor;

  bool _blurBottom;
  double _offset;

  String _getTime() {
    final DateTime dateTime =
        DateTime.fromMillisecondsSinceEpoch(widget.opensMouth);
    int hours = dateTime.hour;
    bool isPm = false;
    if (hours >= 12) {
      isPm = true;
    }
    hours = hours % 12;
    if (hours == 0) {
      hours = 12;
    }
    int minutes = dateTime.minute;
    return '$hours:${minutes < 10 ? '0$minutes' : minutes} ${isPm ? 'pm' : 'am'}';
  }

  void _scrollListener() {
    final double offset = math.max(widget.autoScrollController.offset, 0.0);
    if (_offset == offset) {
      return;
    }
    _offset = offset;
    final double currentOffset = widget.offsets[widget.lineNumber];
    final double currentSize = widget.sizes[widget.lineNumber];
    double previousOffset;
    double previousSize;
    if (widget.lineNumber == 0) {
      previousOffset = -1.0;
      previousSize = 0.0;
    } else {
      previousOffset = widget.offsets[widget.lineNumber - 1];
      previousSize = widget.sizes[widget.lineNumber - 1];
    }
    if (currentOffset == null ||
        currentSize == null ||
        previousOffset == null ||
        previousSize == null) {
      return;
    }
    double nextOffset = currentOffset + currentSize;
    double blurHeightFactor;
    bool blurBottom;
    if (offset > previousOffset && offset < nextOffset) {
      if (offset >= currentOffset) {
        final double distanceToCurrentOffset = offset - currentOffset;
        blurHeightFactor = (distanceToCurrentOffset / currentSize);
      } else {
        final double distanceToPreviousOffset = offset - previousOffset;
        blurHeightFactor = 1 - (distanceToPreviousOffset / previousSize);
      }
    } else {
      blurHeightFactor = 1.0;
    }
    blurBottom = currentOffset > offset;
    if (blurHeightFactor != _blurHeightFactor || blurBottom != _blurBottom) {
      _blurHeightFactor = blurHeightFactor;
      _blurBottom = blurBottom;
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _time = _getTime();
    _offset = 0.0;
    _blurBottom = widget.lineNumber == 0 ? false : true;
    _blurHeightFactor = widget.lineNumber == 0 ? 0.0 : 1.0;
    if (widget.autoScrollController.hasClients) {
      _scrollListener();
    }
    widget.autoScrollController.addListener(_scrollListener);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        children: [
          Column(
            children: [
              SizedBox(
                  height:
                      MediaQuery.of(context).size.width / (12.5 * (3 + 1 / 3))),
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.of(context).size.width / 12.5),
                child: RichText(
                  textScaleFactor: MediaQuery.of(context).textScaleFactor,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.start,
                  maxLines: null,
                  text: TextSpan(
                    children: <TextSpan>[
                      TextSpan(
                          text: widget.quote,
                          style: TextStyle(
                              fontFamily: 'NewsCycle',
                              fontWeight: FontWeight.w400,
                              fontSize: 16.5 * (1 + 1 / 7.5) * (1 + 1 / 3),
                              color: CupertinoColors.black)),
                      TextSpan(
                          text: '\n' + _time,
                          style: TextStyle(
                              fontFamily: 'NewsCycle',
                              fontWeight: FontWeight.w700,
                              fontSize: (16.5 * 2 / 3) * (1 + 1 / (10 * 2 / 3)),
                              color: CupertinoColors.black)),
                    ],
                  ),
                ),
              ),
              SizedBox(
                  height:
                      MediaQuery.of(context).size.width / (12.5 * (3 + 1 / 3))),
            ],
          ),
          Positioned.fill(
            child: Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment:
                  _blurBottom ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                SizedBox(
                  height: _blurHeightFactor *
                      (widget.sizes[widget.lineNumber] ?? 0.0),
                  width: double.infinity,
                  child: Material(
                    color: Colors.white.withOpacity(0.9),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

