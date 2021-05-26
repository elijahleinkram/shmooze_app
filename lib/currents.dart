import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:preload_page_view/preload_page_view.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:shmooze/fake_speaking.dart';
import 'package:shmooze/speaking.dart';
import 'package:shmooze/stage_header.dart';
import 'dart:math' as math;
import 'constants.dart';

class Currents extends StatefulWidget {
  final List<AudioPlayer> audioPlayers;
  final List<List<double>> sizesOnPage;
  final VoidCallback navigateToHome;
  final List<List<double>> offsetsOnPage;
  final Function(bool hasTapped,
      [int pageNumber, String refreshToken, int lineNumber]) seekVerse;
  final List<bool> isAnimatingOnPage;
  final PreloadPageController pageController;
  final dynamic shmoozes;
  final List<AutoScrollController> autoScrollControllers;
  final dynamic scripts;
  final VoidCallback onPageSwipe;
  final int Function() getCurrentPage;
  final List<int> lineNumberOnPage;
  final VoidCallback togglePause;
  final bool Function() isPaused;
  final bool Function() isSliding;
  final VoidCallback toggleSliding;
  final int itemCount;
  final String refreshToken;
  final String Function() getRefreshToken;
  final List<bool> isScrollingOnPage;
  final bool Function() isRefreshing;
  final int Function(int pageNumber, [double newOffset]) getLineNumber;
  final String Function() getCurrentShmoozeId;
  final void Function(String) updateCurrentShmoozeId;
  final int Function() getOldPage;
  final void Function(int) updateOldPage;
  final int shmoozeCount;
  final bool isPreview;

  Currents({
    @required this.audioPlayers,
    @required this.shmoozeCount,
    @required this.isScrollingOnPage,
    @required this.seekVerse,
    @required this.isRefreshing,
    @required this.navigateToHome,
    @required this.getCurrentShmoozeId,
    @required this.updateOldPage,
    @required this.updateCurrentShmoozeId,
    @required this.getLineNumber,
    @required this.isAnimatingOnPage,
    @required this.getRefreshToken,
    @required this.refreshToken,
    @required this.offsetsOnPage,
    @required this.toggleSliding,
    @required this.itemCount,
    @required this.sizesOnPage,
    @required this.isSliding,
    @required this.isPaused,
    @required this.pageController,
    @required this.togglePause,
    @required this.lineNumberOnPage,
    @required this.onPageSwipe,
    @required this.isPreview,
    @required this.autoScrollControllers,
    @required this.getCurrentPage,
    @required this.getOldPage,
    @required this.shmoozes,
    @required this.scripts,
  });

  @override
  _CurrentsState createState() => _CurrentsState();
}

class _CurrentsState extends State<Currents> {
  bool _isSpeakingForTooLong(Duration duration, int pageNumber) {
    return duration.inMilliseconds >
        widget.shmoozes[pageNumber]['play']['until'];
  }

  bool _isPlaying;
  String _refreshToken;

  StreamSubscription<PlayerState> _playerStateSubscription;

  double _sliderDuration;
  int _sliderAnimationMillis;
  bool _sliderAnimationEnabled;
  String _speakingUid;
  bool _hostIsTalking;
  List<ValueKey<String>> _speakerKeys = [null, null];

  void _updateLineNumber(int lineNumber, bool isFlying, int pageNumber) {
    final int oldLineNumber = widget.lineNumberOnPage[pageNumber];
    if (oldLineNumber == lineNumber) {
      return;
    }
    widget.lineNumberOnPage[pageNumber] = lineNumber;
    if (widget.isSliding() ||
        widget.isScrollingOnPage[pageNumber] ||
        widget.isRefreshing()) {
      return;
    }
    _scrollToLineNumber(pageNumber, lineNumber, isFlying);
  }

  StreamSubscription<Duration> _positionSubscription;

  void _setupStreams() {
    final int pageNumber = widget.getOldPage();
    final String refreshToken = _refreshToken;
    final Stream<Duration> positionStream =
        widget.audioPlayers[pageNumber].onAudioPositionChanged;
    _positionSubscription = positionStream.listen((Duration duration) async {
      if (refreshToken != widget.getRefreshToken() ||
          pageNumber != widget.getOldPage() ||
          !mounted) {
        return;
      }
      if (duration.inMilliseconds <
          widget.shmoozes[pageNumber]['play']['from']) {
        _updateLineNumber(0, true, pageNumber);
      } else if (_isSpeakingForTooLong(duration, pageNumber)) {
        await widget.audioPlayers[pageNumber]
            .seek(Duration(
                milliseconds: widget.shmoozes[pageNumber]['play']['from']))
            .catchError((error) {
          print(error);
        });
        if (refreshToken != widget.getRefreshToken() ||
            pageNumber != widget.getOldPage() ||
            !mounted) {
          return;
        }
        _updateLineNumber(0, true, pageNumber);
      } else {
        for (int i = widget.lineNumberOnPage[pageNumber];
            i < widget.scripts[pageNumber].length;
            i++) {
          final dynamic verse = widget.scripts[pageNumber][i];
          final int closesMouth = (verse['mouth']['closes']);
          if (closesMouth >
              widget.shmoozes[pageNumber]['startedRecording'] +
                  duration.inMilliseconds) {
            _updateLineNumber(i, false, pageNumber);
            break;
          }
        }
      }
    });
    final Stream<PlayerState> playerStateStream =
        widget.audioPlayers[pageNumber].onPlayerStateChanged;
    _playerStateSubscription =
        playerStateStream.listen((PlayerState playerState) {
      if (pageNumber != widget.getOldPage() ||
          refreshToken != widget.getRefreshToken() ||
          !mounted) {
        return;
      }
      if (playerState == PlayerState.PAUSED) {
        if (_isPlaying) {
          _isPlaying = false;
          if (mounted) {
            setState(() {});
          }
        }
      }
      if (playerState == PlayerState.PLAYING) {
        if (!_isPlaying) {
          _isPlaying = true;
          if (mounted) {
            setState(() {});
          }
        }
      }
    });
  }

  void _updateSlidingButton(bool isSliding) {
    if (widget.isSliding() != isSliding) {
      widget.toggleSliding();
    }
  }

  void _updatePauseButton(bool isPaused) {
    if (widget.isPaused() != isPaused) {
      widget.togglePause();
    }
  }

  Future<void> _scrollToLineNumber(
      int pageNumber, int newLineNumber, bool isFlying) async {
    if (!widget.autoScrollControllers[pageNumber].hasClients) {
      return;
    }
    if (widget.isAnimatingOnPage[pageNumber]) {
      return;
    }
    final double destination = widget.offsetsOnPage[pageNumber][newLineNumber];
    if (isFlying) {
      if (destination != null) {
        widget.autoScrollControllers[pageNumber].jumpTo(destination);
      }
      return;
    }
    widget.isAnimatingOnPage[pageNumber] = true;
    final String refreshToken = _refreshToken;
    if (destination != null) {
      final int milliseconds =
          ((widget.autoScrollControllers[pageNumber].offset - destination)
                  .abs()) ~/
              10;
      await widget.autoScrollControllers[pageNumber]
          .animateTo(destination,
              duration:
                  Duration(milliseconds: math.max(milliseconds, 1000 ~/ 3)),
              curve: Curves.linear)
          .catchError((error) {
        print(error);
      });
    } else {
      await widget.autoScrollControllers[pageNumber]
          .scrollToIndex(
        newLineNumber,
        duration: Duration(milliseconds: 1000 ~/ 3),
        preferPosition: AutoScrollPosition.begin,
      )
          .catchError((error) {
        print(error);
      });
    }
    if (refreshToken != widget.getRefreshToken() || !mounted) {
      return;
    }
    widget.isAnimatingOnPage[pageNumber] = false;
  }

  void _playOrPause() {
    if (_isPlaying) {
      _updatePauseButton(true);
      widget.audioPlayers[widget.getOldPage()].pause();
    } else {
      _updatePauseButton(false);
      widget.audioPlayers[widget.getOldPage()].resume();
    }
    _isPlaying = !_isPlaying;
    setState(() {});
  }

  void _cancelSubscriptions() {
    _positionSubscription?.cancel()?.catchError((error) => print(error));
    _playerStateSubscription?.cancel()?.catchError((error) => print(error));
  }

  @override
  void dispose() {
    super.dispose();
    _cancelSubscriptions();
  }

  double _getWidthFactor(int pageNumber) {
    return (_sliderDuration - _minValue(pageNumber)) / _maxValue(pageNumber);
  }

  double _getSliderDuration(double sliderDuration, int pageNumber) {
    if (sliderDuration < _minValue(pageNumber)) {
      return _minValue(pageNumber);
    }
    if (sliderDuration > _maxValue(pageNumber)) {
      return _maxValue(pageNumber);
    }
    return sliderDuration;
  }

  void _initPage(int pageNumber) {
    widget.updateCurrentShmoozeId(widget.shmoozes[pageNumber]['shmoozeId']);
    _refreshToken = widget.getRefreshToken();
    final bool hasClients = widget.autoScrollControllers[pageNumber].hasClients;
    _sliderDuration = _getSliderDuration(
        !hasClients ? 0.0 : widget.autoScrollControllers[pageNumber].offset,
        pageNumber);
    final int lineNumber = !hasClients ? 0 : widget.getLineNumber(pageNumber);
    if (lineNumber < 0) {
      return;
    }
    _speakingUid = widget.scripts[pageNumber][lineNumber]['authorUid'];
    _hostIsTalking =
        _speakingUid == widget.shmoozes[pageNumber]['personA']['uid'];
    _speakerKeys.first =
        ValueKey('speaking' + widget.shmoozes[pageNumber]['personA']['uid']);
    _speakerKeys.last =
        ValueKey('speaking' + widget.shmoozes[pageNumber]['personB']['uid']);
    widget.autoScrollControllers[pageNumber].addListener(_scrollListener);
    _setupStreams();
  }

  void _scrollListener() {
    final int pageNumber = widget.getOldPage();
    double sliderDuration = widget.autoScrollControllers[pageNumber].offset;
    bool hasChanged = sliderDuration != _sliderDuration;
    _sliderDuration = _getSliderDuration(sliderDuration, pageNumber);
    int lineNumber = -1;
    for (int i = 0; i < widget.offsetsOnPage[pageNumber].length; i++) {
      if (widget.autoScrollControllers[pageNumber].offset ==
          widget.offsetsOnPage[pageNumber][i]) {
        lineNumber = i;
        break;
      }
    }
    if (lineNumber >= 0) {
      final String speakingUid =
          widget.scripts[pageNumber][lineNumber]['authorUid'];
      hasChanged = hasChanged || (speakingUid != _speakingUid);
      _speakingUid = speakingUid;
      _hostIsTalking =
          widget.shmoozes[pageNumber]['personA']['uid'] == _speakingUid;
    }
    if (hasChanged) {
      if (mounted) {
        setState(() {});
      }
    }
  }

  int _getSliderAnimationMillis(double oldWidth, double newWidth) {
    return ((newWidth - oldWidth) * 1000).toInt().abs();
  }

  void _onPageSwipe(int oldPage, int newPage) async {
    double oldWidth;
    if (oldPage < widget.shmoozes.length &&
        _refreshToken != null &&
        _refreshToken == widget.getRefreshToken() &&
        widget.getCurrentShmoozeId() == widget.shmoozes[oldPage]['shmoozeId']) {
      widget.isScrollingOnPage[oldPage] = false;
      widget.updateCurrentShmoozeId(null);
      _updateSlidingButton(false);
      final bool hasClients = widget.autoScrollControllers[oldPage].hasClients;
      widget.autoScrollControllers[oldPage].removeListener(_scrollListener);
      widget.lineNumberOnPage[oldPage] =
          !hasClients ? 0 : widget.getLineNumber(oldPage);
      _scrollToLineNumber(oldPage, widget.lineNumberOnPage[oldPage], true);
      _cancelSubscriptions();
      oldWidth = _getWidthFactor(oldPage);
    } else {
      oldWidth = 0.0;
    }
    _updateSlidingButton(false);
    if (newPage < widget.shmoozes.length) {
      _initPage(newPage);
      final double newWidth = _getWidthFactor(newPage);
      _sliderAnimationMillis = _getSliderAnimationMillis(oldWidth, newWidth);
      _sliderAnimationEnabled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _sliderAnimationEnabled = false;
      });
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _onChangeEnd(double duration) async {
    if (!widget.autoScrollControllers[widget.getOldPage()].hasClients) {
      return;
    }
    final double sliderDuration = duration;
    if (sliderDuration != _sliderDuration) {
      _sliderDuration = sliderDuration;
    }
    final double offset = _sliderDuration;
    int newLineNumber = widget.getLineNumber(widget.getOldPage(), offset);
    if (newLineNumber < 0) {
      return;
    }
    final int pageNumber = widget.getOldPage();
    final String refreshToken = _refreshToken;
    int milliseconds = widget.scripts[pageNumber][newLineNumber]['mouth']
            ['opens'] -
        widget.shmoozes[pageNumber]['startedRecording'];
    await widget.audioPlayers[pageNumber]
        .seek(Duration(milliseconds: milliseconds))
        .catchError((error) {
      print(error);
    });
    if (refreshToken != widget.getRefreshToken() ||
        widget.getOldPage() != pageNumber ||
        !mounted) {
      return;
    }
    _scrollToLineNumber(pageNumber, newLineNumber, true);
    _updateLineNumber(newLineNumber, false, pageNumber);
    _updateSlidingButton(false);
  }

  void _onChange(double duration) {
    if (!widget.autoScrollControllers[widget.getOldPage()].hasClients) {
      return;
    }
    _updateSlidingButton(true);
    final double currentDuration = duration;
    if (_sliderDuration != currentDuration) {
      _sliderDuration = currentDuration;
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant Currents oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken ||
        oldWidget.shmoozeCount != widget.shmoozeCount) {
      final int pageNumber = widget.getCurrentPage();
      if (pageNumber < widget.shmoozes.length) {
        final String shmoozeId = widget.shmoozes[pageNumber]['shmoozeId'];
        if (widget.getCurrentShmoozeId() != shmoozeId) {
          _initPage(pageNumber);
        }
      }
    }
  }

  double _maxValue(int pageNumber) {
    return (widget.offsetsOnPage[pageNumber].last) +
        (widget.sizesOnPage[pageNumber].last);
  }

  double _minValue(int pageNumber) {
    return 0.0;
  }

  @override
  void initState() {
    super.initState();
    _isPlaying = true;
    _sliderAnimationEnabled = false;
    _sliderAnimationMillis = 0;
    _refreshToken = widget.getRefreshToken();
    if (widget.isPreview) {
      _initPage(widget.getCurrentPage());
    } else {
      widget.pageController.addListener(() {
        final int oldPage = widget.getOldPage();
        final int newPage = widget.getCurrentPage();
        if (newPage != oldPage) {
          widget.updateOldPage(newPage);
          widget.onPageSwipe();
          _onPageSwipe(oldPage, newPage);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.getOldPage() >= widget.shmoozes.length
            ? Container()
            : Stack(
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          AnimatedContainer(
                            curve: Curves.linear,
                            duration: Duration(
                                milliseconds: _sliderAnimationEnabled
                                    ? _sliderAnimationMillis
                                    : 0),
                            color: Color(kNorthStar),
                            width: _getWidthFactor(widget.getOldPage()) *
                                (MediaQuery.of(context).size.width),
                            height: 5,
                          ),
                          Expanded(
                              child: SizedBox(
                            height: 5,
                            child: Material(
                              color: Colors.white,
                              child: Material(
                                color: Color(kNorthStar).withOpacity(1 / 3),
                              ),
                            ),
                          ))
                        ],
                      )
                    ],
                  ),
                  Column(
                    children: [
                      Expanded(child: Container()),
                      Opacity(
                        opacity: 0.0,
                        child: SliderTheme(
                          data: SliderThemeData(
                            trackShape: CustomTrackShape(),
                            thumbShape: RoundSliderThumbShape(
                                enabledThumbRadius: 100 / 3),
                          ),
                          child: Slider(
                            min: _minValue(widget.getOldPage()),
                            max: _maxValue(widget.getOldPage()),
                            onChanged: _onChange,
                            onChangeEnd: _onChangeEnd,
                            value: _sliderDuration,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
        Align(
            alignment: Alignment.topCenter,
            child: Material(
              color: Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                      height: (MediaQuery.of(context).size.width /
                          (12.5 * (3 + 1 / 3)) *
                          2 *
                          (1 + 1 / 3))),
                  StageHeader(
                    isPreview: widget.isPreview,
                    navigateToHome: widget.navigateToHome,
                  ),
                  SizedBox(
                      height: (MediaQuery.of(context).size.width /
                          (12.5 * (3 + 1 / 3)) *
                          2 *
                          (1 + 1 / 3))),
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: MediaQuery.of(context).size.width / 12.5),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        widget.getOldPage() >= widget.shmoozes.length
                            ? FakeSpeaking()
                            : Speaking(
                                hostIsTalking: _hostIsTalking,
                                speakerKeys: _speakerKeys,
                                shmoozes: widget.shmoozes,
                                getOldPage: widget.getOldPage),
                        Container(),
                      ],
                    ),
                  ),
                  SizedBox(
                      height: MediaQuery.of(context).size.width /
                          (12.5 * (3 + 1 / 3)) *
                          (1 + 1 / 3)),
                ],
              ),
            )),
        Align(
          alignment: Alignment.bottomRight,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FloatingActionButton(
                    elevation: 0.0,
                    highlightElevation: 0.0,
                    hoverElevation: 0.0,
                    focusElevation: 0.0,
                    heroTag: 'play or pause',
                    disabledElevation: 0.0,
                    onPressed: widget.getOldPage() >= widget.shmoozes.length
                        ? null
                        : _playOrPause,
                    backgroundColor: CupertinoColors.activeBlue,
                    child: Icon(
                      (_isPlaying &&
                              (widget.getOldPage() < widget.shmoozes.length))
                          ? Icons.pause
                          : Icons.play_arrow_rounded,
                      color: CupertinoColors.white,
                    ),
                  ),
                  SizedBox(width: 100 / (10 / 3) * 0.875),
                ],
              ),
              SizedBox(height: 100 / (10 / 3)),
            ],
          ),
        )
      ],
    );
  }
}

class CustomTrackShape extends RoundedRectSliderTrackShape {
  Rect getPreferredRect({
    @required RenderBox parentBox,
    Offset offset = Offset.zero,
    @required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight;
    final double trackLeft = offset.dx;
    final double trackTop =
        offset.dy + (parentBox.size.height - trackHeight) / 2;
    final double trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}
