import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class About extends StatefulWidget {
  final String name;
  final String caption;
  final double horizontalPadding;
  final dynamic playUntil;
  final AudioPlayer audioPlayer;
  final dynamic playFrom;
  final dynamic startedRecording;
  final List<dynamic> verses;

  About({
    @required this.name,
    @required this.caption,
    @required this.horizontalPadding,
    @required this.playUntil,
    @required this.audioPlayer,
    @required this.playFrom,
    @required this.verses,
    @required this.startedRecording,
  });

  @override
  _AboutState createState() => _AboutState();
}

class _AboutState extends State<About> {
  bool _isSpeakingForTooLong(Duration duration) {
    return duration.inMilliseconds > widget.playUntil;
  }

  bool _isPlaying;
  int _currentDuration;

  int _lineNumber;

  void _updateCurrentDuration(int currentDuration) {
    if (_currentDuration == currentDuration) {
      return;
    }
    _currentDuration = currentDuration;
    if (mounted) {
      setState(() {});
    }
  }

  void _updateLineNumber(int lineNumber) {
    _lineNumber = lineNumber;
  }

  StreamSubscription<Duration> _positionSubscription;

  void _startStream() {
    widget.audioPlayer.onPlayerStateChanged
        .listen((AudioPlayerState audioPlayerState) {
      print('the state is');
      print(audioPlayerState);
      if (audioPlayerState == AudioPlayerState.PLAYING) {
        if (!_isPlaying) {
          _isPlaying = true;
          if (mounted) {
            setState(() {});
          }
        }
      }
      if (audioPlayerState == AudioPlayerState.PAUSED) {
        if (_isPlaying) {
          _isPlaying = false;
          if (mounted) {
            setState(() {});
          }
        }
      }
    });
    final Stream<Duration> positionStream =
        widget.audioPlayer.onAudioPositionChanged;
    _positionSubscription = positionStream.listen((Duration duration) {
      if (duration.inMilliseconds < widget.playFrom) {
        _updateCurrentDuration(widget.playFrom);
        _updateLineNumber(0);
      } else if (_isSpeakingForTooLong(duration)) {
        _updateLineNumber(0);
        _updateCurrentDuration(widget.playFrom);
        widget.audioPlayer
            .seek(Duration(milliseconds: widget.playFrom))
            .catchError((error) {
          print(error);
        });
      } else {
        _updateCurrentDuration(duration.inMilliseconds);
        for (int i = _lineNumber; i < widget.verses.length; i++) {
          final dynamic verse = widget.verses[i];
          final int closesMouth = (verse['mouth']['closes']);
          if (closesMouth > widget.startedRecording + duration.inMilliseconds) {
            _updateLineNumber(i);
            break;
          }
        }
      }
    });
  }

  void _pauseOrPlay() {
    if (_isPlaying) {
      widget.audioPlayer.pause();
    } else {
      widget.audioPlayer.resume();
    }
    _isPlaying = !_isPlaying;
    setState(() {});
  }

  @override
  void dispose() {
    super.dispose();
    _positionSubscription?.cancel()?.catchError((error) => print(error));
  }

  @override
  void initState() {
    super.initState();
    _currentDuration = 0;
    _isPlaying = false;
    _lineNumber = 0;
    _startStream();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: MediaQuery.of(context).size.width / 15.0),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(height: 21.0 * 1 / 3),
            RichText(
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                children: <TextSpan>[
                  TextSpan(
                      text: widget.name,
                      style: GoogleFonts.newsCycle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16.5,
                          color: CupertinoColors.black)),
                  TextSpan(
                      text: widget.caption,
                      style: GoogleFonts.newsCycle(
                          fontWeight: FontWeight.w400,
                          fontSize: 16.5,
                          color: CupertinoColors.black)),
                ],
              ),
            ),
            SizedBox(height: 21.0 * 1 / 3),
          ]),
        ),
        IconButton(
          icon: Icon(
            _isPlaying ? Icons.pause : Icons.play_arrow_rounded,
            size: 20.0,
          ),
          onPressed: _pauseOrPlay,
        ),
        SizedBox(width: MediaQuery.of(context).size.width / 15.0 / 1.5),
      ],
    );
  }
}
