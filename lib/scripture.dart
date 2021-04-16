import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shmooze/about.dart';
import 'package:shmooze/verse.dart';

class Scripture extends StatefulWidget {
  final dynamic audioRecordingUrl;
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
  final dynamic startedSpeaking;
  final dynamic finishedSpeaking;

  Scripture(
      {@required this.startedSpeaking,
      @required this.finishedSpeaking,
      @required this.getCurrentPage,
      @required this.audioRecordingUrl,
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
  int _lineNumber;
  StreamSubscription<Duration> _positionSubscription;
  StreamSubscription<AudioPlayerState> _playerStateSubscription;
  final List<ValueKey> _keys = [];
  bool _isRefreshing;
  Future<void> Function() _onRefresh;
  double _currentVolume;
  CupertinoSliverRefreshControl _cupertinoSliverRefreshControl;
  bool _isPlaying;
  OverlayEntry _overlayEntry;

  bool _isOnCurrentPage() {
    return widget.index == widget.getCurrentPage();
  }

  void _startStreams() {
    final Stream<AudioPlayerState> audioPlayerStream =
        widget.audioPlayer.onPlayerStateChanged;
    final Stream<Duration> positionStream =
        widget.audioPlayer.onAudioPositionChanged;
    audioPlayerStream.listen((AudioPlayerState state) {
      if (state == AudioPlayerState.PLAYING && !_isPlaying) {
        _isPlaying = true;
      }
      if ((state == AudioPlayerState.PAUSED) && _isPlaying) {
        _isPlaying = false;
        if (_isMuted() && !_isOnCurrentPage()) {
          _changeVolumeTo(1.0);
        }
      }
    });
    _positionSubscription = positionStream.listen((Duration duration) {
      if (duration.inMilliseconds < widget.verses[0]['mouth']['closes']) {
        _updateLineNumber(0);
      } else if (duration.inMilliseconds > widget.finishedSpeaking) {
        _updateLineNumber(0);
        widget.audioPlayer
            .seek(Duration(milliseconds: widget.startedSpeaking))
            .catchError((error) {
          print(error);
        });
      } else {
        for (int i = _lineNumber; i < widget.verses.length; i++) {
          final dynamic verse = widget.verses[i];
          final int closesMouth = (verse['mouth']['closes']);
          if (closesMouth > duration.inMilliseconds) {
            if (_lineNumber != i) {
              _lineNumber = i;
              if (mounted) {
                setState(() {});
              }
            }
            break;
          }
        }
      }
    });
  }

  void _cutKeys() {
    for (int i = 0; i < widget.verses.length; i++) {
      _keys.add(
          ValueKey(widget.verses[i]['verseId'] + ' ' + widget.refreshToken));
    }
  }

  void _toggleIsRefreshing() {
    _isRefreshing = !_isRefreshing;
    if (_isRefreshing) {
      this._overlayEntry = OverlayEntry(builder: (BuildContext context) {
        return Material(
          color: Colors.transparent,
        );
      });
      Overlay.of(context).insert(this._overlayEntry);
    } else {
      this._overlayEntry.remove();
      if (_currentVolume != 1.0) {
        _currentVolume = 1.0;
        widget.audioPlayer.setVolume(_currentVolume).catchError((error) {
          print(error);
        });
      }
      widget.audioPlayer
          .seek(Duration(milliseconds: widget.startedSpeaking))
          .catchError((error) {
        print(error);
      });
      if (_lineNumber != 0) {
        _lineNumber = 0;
      }
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _isPlaying = false;
    _currentVolume = 1.0;
    _isRefreshing = false;
    _lineNumber = 0;
    _startStreams();
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

  bool _isUpToHere(int index) {
    return _lineNumber == index;
  }

  void _updateLineNumber(int index) {
    if (_lineNumber == index) {
      return;
    }
    _lineNumber = index;
    if (mounted) {
      setState(() {});
    }
  }

  bool _updateCurrentVolume(double volume) {
    if (_currentVolume == volume) {
      return false;
    }
    _currentVolume = volume;
    return true;
  }

  bool _isMuted() {
    return _currentVolume == 0.0;
  }

  void _changeVolumeTo(double volume) {
    if (_updateCurrentVolume(volume)) {
      widget.audioPlayer.setVolume(volume);
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
    _playerStateSubscription?.cancel()?.catchError((error) {
      print(error);
    });
    _positionSubscription?.cancel()?.catchError((error) {
      print(error);
    });
    widget.audioPlayer.pause().catchError((error) {
      print(error);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return CustomScrollView(
      physics: BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        _cupertinoSliverRefreshControl,
        SliverList(
          delegate: SliverChildListDelegate([
            About(
              caption: widget.caption,
              name: widget.name,
            )
          ]),
        ),
        SliverList(
          delegate:
              SliverChildBuilderDelegate((BuildContext context, int index) {
            final dynamic verse = widget.verses[index];
            final dynamic quote = verse['quote'];
            final dynamic displayName = verse['displayName'];
            final dynamic photoUrl = verse['photoUrl'];
            final dynamic opensMouth = verse['mouth']['opens'];
            return Verse(
              changeVolumeTo: _changeVolumeTo,
              isMuted: _isMuted(),
              key: _keys[index],
              updateLineNumber: _updateLineNumber,
              index: index,
              photoUrl: photoUrl,
              audioPlayer: widget.audioPlayer,
              length: widget.verses.length,
              opensMouth: opensMouth,
              isPlaying: _isUpToHere(index),
              displayName: displayName,
              quote: quote,
            );
          }, childCount: widget.verses.length),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}
