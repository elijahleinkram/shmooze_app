import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:preload_page_view/preload_page_view.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:shmooze/constants.dart';
import 'package:shmooze/currents.dart';
import 'package:shmooze/scripture.dart';
import 'package:shmooze/window.dart';
import 'fake_scripture.dart';
import 'human.dart';
import 'main.dart';
import 'dart:math' as math;
import 'package:flutter/rendering.dart' as rendering;

class MainStage extends StatefulWidget {
  final Future<void> Function() uploadShmooze;

  MainStage({
    @required this.uploadShmooze,
  });

  @override
  _MainStageState createState() => _MainStageState();
}

class _MainStageState extends State<MainStage>
    with WidgetsBindingObserver, RouteAware {
  StreamSubscription<DocumentSnapshot> _streamSubscription;
  int _numberOfShmoozes;
  OverlayEntry _overlayEntry;
  final dynamic _shmoozes = [];
  final dynamic _scripts = [];
  bool _isLoadingShmooze;
  final List<ValueKey<String>> _keys = [];
  bool _isRefreshing;
  int kShmoozeLimit = 3;
  final Set<String> _hasPlayed = {};
  String _refreshToken;
  final PreloadPageController _pageController = PreloadPageController();
  bool _hasLeftStage;
  bool _hasLeftApp;
  final List<AutoScrollController> _autoScrollControllers = [];
  final List<int> _lineNumberOnPage = [];
  final List<List<double>> _sizesOnPage = [];
  final List<List<double>> _offsetsOnPage = [];
  final List<bool> _isAnimatingOnPage = [];
  final List<bool> _isScrollingOnPage = [];
  final List<AudioPlayer> _audioPlayers = [];
  bool _isPaused;
  bool _isSliding;
  Offset _pointerPosition;
  double _scrollOffset;
  String _currentShmoozeId;
  int _oldPage;
  bool _hasTapped;
  int _shmoozeCount;

  // void _listenToShmoozeCount() {
  //   final Stream<DocumentSnapshot> stream = FirebaseFirestore.instance
  //       .collection('metaData')
  //       .doc('shmoozes')
  //       .snapshots();
  //   _streamSubscription = stream.listen((event) {
  //     if (event != null && event.exists) {
  //       final int numberOfShmoozes = event.get('numberOfShmoozes');
  //       if (_numberOfShmoozes != numberOfShmoozes) {
  //         final int oldRemainder = _numberOfShmoozes - _shmoozes.length;
  //         _numberOfShmoozes = numberOfShmoozes;
  //         final int newRemainder = _numberOfShmoozes - _shmoozes.length;
  //         if (oldRemainder < kShmoozeLimit && newRemainder > oldRemainder) {
  //           if (mounted) {
  //             setState(() {});
  //           }
  //         }
  //       }
  //     }
  //   });
  // }
  void _getShmoozeCount(int numberOfTries) async {
    if (numberOfTries == 3) {
      return;
    }
    final metaSnapshot = await FirebaseFirestore.instance
        .collection('metaData')
        .doc('shmoozes')
        .get()
        .catchError((error) {
      print(error);
    });
    if (metaSnapshot == null || !metaSnapshot.exists) {
      _getShmoozeCount(numberOfTries + 1);
    } else {
      _numberOfShmoozes = metaSnapshot.get('numberOfShmoozes');
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context));
  }

  bool _hasRefreshedPage(int oldTime, bool wasEmpty) {
    final bool isEmpty = _shmoozes.isEmpty;
    if (isEmpty != wasEmpty) {
      return true;
    }
    if (isEmpty) {
      return false;
    }
    final newTime = _shmoozes.last['timeCreated'];
    return newTime != oldTime;
  }

  void _clearData() {
    _scripts.clear();
    _keys.clear();
    _shmoozes.clear();
    _hasPlayed.clear();
    _autoScrollControllers.clear();
    _sizesOnPage.clear();
    _offsetsOnPage.clear();
    _isAnimatingOnPage.clear();
    _lineNumberOnPage.clear();
    _audioPlayers.clear();
    _isScrollingOnPage.clear();
    _isSliding = false;
    _isPaused = false;
    _currentShmoozeId = null;
    _oldPage = 0;
  }

  Future<bool> _getShmoozes(bool refreshMode) async {
    int afterTime;
    bool isEmpty = _shmoozes.isEmpty;
    if (isEmpty || refreshMode) {
      afterTime = await getCurrentTime();
    } else {
      afterTime = _shmoozes.last['timeCreated'];
    }
    final HttpsCallableResult result = await FirebaseFunctions.instance
        .httpsCallable('getShmoozes')
        .call({'afterTime': afterTime}).catchError((error) {
      print(error);
    });
    String refreshToken = _refreshToken;
    if (!refreshMode) {
      bool wasEmpty = isEmpty;
      if (_hasRefreshedPage(afterTime, wasEmpty)) {
        return false;
      }
    } else {
      if (result != null && result.data != null) {
        if (_shmoozes.isNotEmpty && result.data.first.first.isNotEmpty) {
          if (result.data.first.first['shmoozeId'] ==
              _shmoozes.first['shmoozeId']) {
            return false;
          }
        }
        if (_shmoozes.isEmpty && result.data.first.first.isEmpty) {
          return false;
        }
      } else {
        return false;
      }
      refreshToken = _issueNewRefreshToken(refreshToken);
    }
    if (result != null && result.data != null) {
      List<dynamic> resultData = result.data;
      int from;
      if (refreshMode) {
        from = 0;
      } else {
        from = _shmoozes.length;
      }
      if (refreshMode) {
        _disposeControllers();
        _clearData();
      }
      for (int i = 0; i < resultData.first.length; i++) {
        final dynamic shmooze = resultData.first[i];
        shmooze['play']['from'] = shmooze['play']['from'].toInt();
        shmooze['play']['until'] = shmooze['play']['until'].toInt();
        shmooze['startedRecording'] = shmooze['startedRecording'].toInt();
        _shmoozes.add(shmooze);
      }
      for (int i = 0; i < resultData.last.length; i++) {
        final dynamic verses = [];
        for (int j = 0; j < resultData.last[i].length; j++) {
          final dynamic verse = resultData.last[i][j];
          verse['mouth']['opens'] = verse['mouth']['opens'].toInt();
          verse['mouth']['closes'] = verse['mouth']['closes'].toInt();
          verses.add(verse);
        }
        _scripts.add(verses);
      }
      int until = _shmoozes.length;
      _setupShmoozes(from, until, refreshToken);
    } else {
      return false;
    }
    _refreshToken = refreshToken;
    _shmoozeCount = _shmoozes.length;
    if (mounted) {
      setState(() {});
    }
    return true;
  }

  int _itemCount() {
    final int remainder = math.max(0, _numberOfShmoozes - _shmoozes.length);
    int numberOfMorePages;
    if (remainder > kShmoozeLimit) {
      numberOfMorePages = kShmoozeLimit;
    } else {
      numberOfMorePages = remainder;
    }
    return _shmoozes.length + numberOfMorePages;
  }

  bool _isCloseToTheEnd() {
    return _pageController.page >= _shmoozes.length - 3;
  }

  bool _noMoreShmoozes() {
    return _shmoozes.length >= _numberOfShmoozes;
  }

  int _getCurrentPage() {
    if (!_pageController.hasClients) {
      return 0;
    }
    final double page = _pageController.page ?? 0.0;
    if (page - page.toInt() >= 0.5) {
      return math.max(0, page.toInt() + 1);
    }
    return math.max(0, page.toInt());
  }

  bool _canPlay() {
    return !_hasLeftStage && !_hasLeftApp && !_isPaused;
  }

  void _playAudio(int index) {
    if (!_shmoozeExists(index) || !_canPlay()) {
      return;
    }
    final AudioPlayer audioPlayer = _audioPlayers[index];
    final dynamic shmooze = _shmoozes[index];
    final dynamic playFrom = shmooze['play']['from'];
    final dynamic audioRecordingUrl = shmooze['audioRecordingUrl'];
    if (_hasPlayed.contains(audioPlayer.playerId)) {
      audioPlayer.resume().catchError((error) {
        print(error);
      });
    } else {
      _hasPlayed.add(audioPlayer.playerId);
      audioPlayer
          .play(audioRecordingUrl,
              stayAwake: true,
              volume: 1.0,
              position: Duration(milliseconds: playFrom))
          .catchError((error) {
        print(error);
      });
    }
  }

  void _pauseAudio(int exceptFor) {
    for (int i = 0; i < _audioPlayers.length; i++) {
      if (i == exceptFor) {
        continue;
      }
      final AudioPlayer audioPlayer = _audioPlayers[i];
      audioPlayer.pause().catchError((error) {
        print(error);
      });
    }
  }

  bool _shmoozeExists(int index) {
    return index < _shmoozes.length;
  }

  void _updatePlayer(int newPage) {
    final int exceptFor = newPage;
    _pauseAudio(exceptFor);
    final int index = newPage;
    _playAudio(index);
  }

  void _loadMoreShmoozes() async {
    if (_isLoadingShmooze || _noMoreShmoozes()) {
      return;
    }
    _isLoadingShmooze = true;
    await _getShmoozes(false);
    final int currentPage = _getCurrentPage();
    if (currentPage < _shmoozes.length) {
      _playAudio(currentPage);
    }
    _isLoadingShmooze = false;
  }

  void _onPageSwipe() {
    final int newPage = _getCurrentPage();
    _updatePlayer(newPage);
    if (_isCloseToTheEnd()) {
      _loadMoreShmoozes();
    }
  }

  void _getDimensionsOnPage(int pageNumber) {
    final List<dynamic> verses = _scripts[pageNumber];
    final List<double> sizesOnPage = [];
    final List<double> offsetsOnPage = [];
    double offset = 0.0;
    for (int i = 0; i < verses.length; i++) {
      final dynamic verse = verses[i];
      final String time = _getTime(verse['mouth']['opens']);
      final String quote = verse['quote'];
      final double height = _getHeight(quote, time);
      sizesOnPage.add(height);
      offsetsOnPage.add(offset);
      offset += height;
    }
    _sizesOnPage.add(sizesOnPage);
    _offsetsOnPage.add(offsetsOnPage);
  }

  void _setupShmoozes(int from, int until, String refreshToken) {
    for (int i = from; i < until; i++) {
      final dynamic shmooze = _shmoozes[i];
      final dynamic playerId = shmooze['shmoozeId'] + ' ' + refreshToken;
      _keys.add(ValueKey(playerId));
      final dynamic audioRecordingUrl = shmooze['audioRecordingUrl'];
      final AudioPlayer audioPlayer = AudioPlayer(playerId: playerId)
        ..setReleaseMode(ReleaseMode.LOOP).catchError((error) {
          print(error);
        });
      audioPlayer.setUrl(audioRecordingUrl).catchError((error) {
        print(error);
      });
      _audioPlayers.add(audioPlayer);
      _getDimensionsOnPage(i);
      // _sizesOnPage.add(List.filled(_scripts[i].length, null));
      // _offsetsOnPage.add(List.filled(_scripts[i].length, null));
      _isScrollingOnPage.add(false);
      _lineNumberOnPage.add(0);
      _autoScrollControllers.add(AutoScrollController());
      _isAnimatingOnPage.add(false);
    }
  }

  String _getTime(int opensMouth) {
    final DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(opensMouth);
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

  double _getHeight(String quote, time) {
    final double horizontalPaddingSum =
        (MediaQuery.of(context).size.width / 12.5) * 2;
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        children: <TextSpan>[
          TextSpan(
              text: quote,
              style: TextStyle(
                  fontFamily: 'NewsCycle',
                  fontWeight: FontWeight.w400,
                  fontSize: 16.5 * (1 + 1 / 7.5) * (1 + 1 / 3),
                  color: CupertinoColors.black)),
          TextSpan(
              text: '\n' + time,
              style: TextStyle(
                  fontFamily: 'NewsCycle',
                  fontWeight: FontWeight.w700,
                  fontSize: (16.5 * 2 / 3) * (1 + 1 / (10 * 2 / 3)),
                  color: CupertinoColors.black)),
        ],
      ),
      maxLines: null,
      textScaleFactor: MediaQuery.of(context).textScaleFactor,
      textDirection: rendering.TextDirection.ltr,
      textAlign: TextAlign.start,
    )..layout(
        minWidth: 0,
        maxWidth: MediaQuery.of(context).size.width - horizontalPaddingSum);
    return textPainter.size.height +
        ((MediaQuery.of(context).size.width / (12.5 * (3 + 1 / 3))) * 2);
  }

  void _toggleIsRefreshing() {
    _isRefreshing = !_isRefreshing;
  }

  void _disposeControllers() {
    for (int i = 0; i < _audioPlayers.length; i++) {
      final AudioPlayer audioPlayer = _audioPlayers[i];
      AutoScrollController autoScrollController = _autoScrollControllers[i];
      audioPlayer.dispose().catchError((error) {
        print(error);
      });
      autoScrollController.dispose();
    }
  }

  void _getFirstBatchOfShmoozes() async {
    await _getShmoozes(false);
    _playAudio(_getCurrentPage());
  }

  String _issueNewRefreshToken(String refreshToken) {
    int refreshCount = int.parse(refreshToken);
    return (refreshCount + 1).toString();
  }

  Future<void> _onRefresh() async {
    if (_isRefreshing) {
      return;
    }
    _toggleIsRefreshing();
    _overlayEntry = OverlayEntry(builder: (BuildContext context) {
      return Material(
        color: Colors.transparent,
      );
    });
    Overlay.of(context).insert(_overlayEntry);
    final int currentPage = _getCurrentPage();
    if (currentPage < _shmoozes.length) {
      _audioPlayers[currentPage].pause().catchError((error) {
        print(error);
      });
    }
    final bool greatSuccess = await _getShmoozes(true);
    if (greatSuccess) {
      await _pageController
          .animateToPage(0,
              duration: Duration(milliseconds: 1000 ~/ 3),
              curve: Curves.fastOutSlowIn)
          .catchError((error) {
        print(error);
      });
    } else {
      for (int i = 0; i < _audioPlayers.length; i++) {
        _lineNumberOnPage[i] = 0;
        _isScrollingOnPage[i] = false;
        _audioPlayers[i]
            .seek(Duration(milliseconds: _shmoozes[i]['play']['from']));
        if (_autoScrollControllers[i].hasClients) {
          _autoScrollControllers[i].jumpTo(0.0);
        }
      }
      _isSliding = false;
      _isPaused = false;
    }
    final int pageNumber = _getCurrentPage();
    _playAudio(pageNumber);
    _overlayEntry.remove();
    _toggleIsRefreshing();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      if (_hasLeftApp) {
        _hasLeftApp = false;
        if (!_isPaused) {
          _playAudio(_getCurrentPage());
        }
      }
    } else {
      if (!_hasLeftApp) {
        _hasLeftApp = true;
        _pauseAudio(-1);
      }
    }
  }

  void _togglePause() {
    _isPaused = !_isPaused;
  }

  // @override
  // void didUpdateWidget(covariant MainStage oldWidget) {
  //   super.didUpdateWidget(oldWidget);
  //   if (Human.uid != null && !_isWaitingForInvitations()) {
  //     _startWaitingForInvitations();
  //   }
  // }

  @override
  void initState() {
    super.initState();
    // if (Human.uid != null) {
    //   _startWaitingForInvitations();
    // }
    _shmoozeCount = 0;
    _oldPage = 0;
    _isSliding = false;
    _isPaused = false;
    _hasLeftApp = false;
    _hasLeftStage = false;
    _refreshToken = '0';
    _keys.addAll({
      ValueKey('0'),
      ValueKey('1'),
      ValueKey('2'),
    });
    WidgetsBinding.instance.addObserver(this);
    _isRefreshing = false;
    _numberOfShmoozes = 3;
    _isLoadingShmooze = false;
    _getShmoozeCount(0);
    // _listenToShmoozeCount();
    if (widget.uploadShmooze != null) {
      widget.uploadShmooze().then((_) async {
        _getFirstBatchOfShmoozes();
      }).catchError((error) {
        print(error);
      });
    } else {
      _getFirstBatchOfShmoozes();
    }
  }

  @override
  void didPopNext() {
    if (_hasLeftStage) {
      _hasLeftStage = false;
      if (!_isPaused) {
        _playAudio(_getCurrentPage());
      }
    }
  }

  void didPushNext() {
    if (!_hasLeftStage) {
      _hasLeftStage = true;
      _pauseAudio(-1);
    }
  }

  void _toggleSliding() {
    _isSliding = !_isSliding;
  }

  int _getLineNumber(int pageNumber, [double newOffset]) {
    final List<double> offsets = _offsetsOnPage[pageNumber];
    final List<double> sizes = _sizesOnPage[pageNumber];
    final double offset =
        newOffset ?? _autoScrollControllers[pageNumber].offset;
    for (int lineNumber = 0; lineNumber < offsets.length; lineNumber++) {
      final double currentOffset = offsets[lineNumber];
      final double currentSize = sizes[lineNumber];
      final double nextOffset = currentOffset + currentSize;
      if (offset >= currentOffset && offset < nextOffset) {
        if ((offset - currentOffset <= nextOffset - offset) ||
            (lineNumber == offsets.length - 1)) {
          return lineNumber;
        }
        return lineNumber + 1;
      }
    }
    return -1;
  }

  void _seekVerse(bool hasTapped,
      [int pageNumber, String refreshToken, int lineNumber]) async {
    final int pNumber = pageNumber ?? _getCurrentPage();
    final String rToken = refreshToken ?? _refreshToken;
    int lNumber = lineNumber ?? _getLineNumber(pNumber);
    if (hasTapped) {
      if (lNumber != _scripts[pageNumber].length - 1) {
        lNumber = lNumber + 1;
      }
    }
    if (lNumber < 0) {
      return;
    }
    if (_isAnimatingOnPage[pNumber]) {
      return;
    }
    _isAnimatingOnPage[pNumber] = true;
    if (!hasTapped) {
      if (lNumber == 0) {
        await _audioPlayers[pNumber]
            .seek(Duration(milliseconds: _shmoozes[pNumber]['play']['from']))
            .catchError((error) {
          print(error);
        });
      } else {
        await _audioPlayers[pNumber]
            .seek(Duration(
                milliseconds: _scripts[pNumber][lNumber]['mouth']['opens'] -
                    _shmoozes[pNumber]['startedRecording']))
            .catchError((error) {
          print(error);
        });
      }
    }
    if (_refreshToken != rToken) {
      return;
    }
    _lineNumberOnPage[pNumber] = lNumber;
    await _autoScrollControllers[pNumber]
        .animateTo(_offsetsOnPage[pNumber][lNumber],
            duration: Duration(
                milliseconds: math
                    .max(
                        ((_autoScrollControllers[pNumber].offset -
                                    _offsetsOnPage[pNumber][lNumber])
                                .abs()) /
                            10 *
                            (hasTapped ? 1 : 1 / 2).toInt(),
                        1000 ~/ 3)
                    .toInt()),
            curve: Curves.linear)
        .catchError((error) {
      print(error);
    });
    if (_refreshToken != rToken) {
      return;
    }
    if (hasTapped) {
      for (int i = 0; i < _offsetsOnPage[pageNumber].length; i++) {
        if (_offsetsOnPage[pageNumber][i] ==
            _autoScrollControllers[pageNumber].offset) {
          if (i != lineNumber) {
            final int currentPosition =
                await _audioPlayers[pNumber].getCurrentPosition();
            if (!mounted || _refreshToken != rToken) {
              return;
            }
            if (currentPosition <
                    _scripts[pNumber][i]['mouth']['opens'] -
                        _shmoozes[pNumber]['startedRecording'] ||
                currentPosition >
                    _scripts[pNumber][i]['mouth']['closes'] -
                        _shmoozes[pNumber]['startedRecording']) {
              await _audioPlayers[pNumber]
                  .seek(Duration(
                      milliseconds: _scripts[pNumber][i]['mouth']['opens'] -
                          _shmoozes[pNumber]['startedRecording']))
                  .catchError((error) {
                print(error);
              });
            }
            break;
          }
        }
      }
    }
    _isAnimatingOnPage[pNumber] = false;
  }

  void _onTapDown(PointerDownEvent p) {
    final int currentPage = _getCurrentPage();
    _pointerPosition = p.position;
    _hasTapped = true;
    if (currentPage >= _shmoozes.length ||
        !(_autoScrollControllers[currentPage].hasClients)) {
      return;
    }
    _isScrollingOnPage[currentPage] = true;
    _scrollOffset = _autoScrollControllers[currentPage].offset;
  }

  void _onTapMove(PointerMoveEvent p) {
    final int currentPage = _getCurrentPage();
    if (currentPage >= _shmoozes.length ||
        !(_autoScrollControllers[currentPage].hasClients)) {
      return;
    }
    if (_autoScrollControllers[currentPage].offset != _scrollOffset) {
      _hasTapped = false;
    }
  }

  void _onTapUp(PointerUpEvent p) {
    final int currentPage = _getCurrentPage();
    if (currentPage >= _shmoozes.length ||
        !(_autoScrollControllers[currentPage].hasClients)) {
      return;
    }
    _isScrollingOnPage[currentPage] = false;
    final bool hasMovedSideways =
        ((p.position.dx - _pointerPosition.dx).abs() >= (10 * 2 / 3));
    final bool hasTapped = _hasTapped && !hasMovedSideways;
    if (_autoScrollControllers[currentPage].offset <= 0.0) {
      _seekVerse(hasTapped, currentPage, _refreshToken, 0);
    } else {
      _seekVerse(hasTapped, currentPage, _refreshToken);
    }
  }

  void _onTapCancel(_) {
    final int currentPage = _getCurrentPage();
    if (currentPage >= _shmoozes.length ||
        !(_autoScrollControllers[currentPage].hasClients) ||
        !_isScrollingOnPage[currentPage]) {
      return;
    }
    _isScrollingOnPage[currentPage] = false;
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _streamSubscription?.cancel()?.catchError((error) {
      print(error);
    });
    _pageController.dispose();
    _disposeControllers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            Human.uid == null ? Container() : Window(),
            Expanded(
              child: Stack(
                children: [
                  Column(
                    children: [
                      SizedBox(
                          height: ((MediaQuery.of(context).size.width /
                                      (12.5 * (3 + 1 / 3)) *
                                      2 *
                                      2 *
                                      (1 + 1 / 3)) +
                                  (45.0 + (40.0 + (10 / 3)))) -
                              (MediaQuery.of(context).size.width /
                                  (12.5 * (3 + 1 / 3)))),
                      Expanded(
                        child: Listener(
                          behavior: HitTestBehavior.deferToChild,
                          onPointerDown: _onTapDown,
                          onPointerMove: _onTapMove,
                          onPointerUp: _onTapUp,
                          onPointerCancel: _onTapCancel,
                          child: PreloadPageView.builder(
                            itemCount: _itemCount(),
                            physics: BouncingScrollPhysics(
                                parent: AlwaysScrollableScrollPhysics()),
                            controller: _pageController,
                            itemBuilder:
                                (BuildContext context, int pageNumber) {
                              return pageNumber >= _shmoozes.length
                                  ? FakeScripture()
                                  : Scripture(
                                      seekVerse: _seekVerse,
                                      isAnimatingOnPage: _isAnimatingOnPage,
                                      isScrollingOnPage: _isScrollingOnPage,
                                      offsets: _offsetsOnPage[pageNumber],
                                      sizes: _sizesOnPage[pageNumber],
                                      autoScrollController:
                                          _autoScrollControllers[pageNumber],
                                      shmoozeId: _shmoozes[pageNumber]
                                          ['shmoozeId'],
                                      startedRecording: _shmoozes[pageNumber]
                                          ['startedRecording'],
                                      playFrom: _shmoozes[pageNumber]['play']
                                          ['from'],
                                      playUntil: _shmoozes[pageNumber]['play']
                                          ['until'],
                                      getCurrentPage: _getCurrentPage,
                                      name: _shmoozes[pageNumber]['name'],
                                      caption: _shmoozes[pageNumber]['caption'],
                                      pageNumber: pageNumber,
                                      refreshToken: _refreshToken,
                                      onRefresh: _onRefresh,
                                      verses: _scripts[pageNumber],
                                      audioPlayer: _audioPlayers[pageNumber],
                                      isPreview: false,
                                    );
                            },
                          ),
                        ),
                      )
                    ],
                  ),
                  Positioned.fill(
                      child: Currents(
                    navigateToHome: null,
                    shmoozeCount: _shmoozeCount,
                    isPreview: false,
                    seekVerse: _seekVerse,
                    getOldPage: () => _oldPage,
                    updateOldPage: (int oldPage) => _oldPage = oldPage,
                    getCurrentShmoozeId: () => _currentShmoozeId,
                    updateCurrentShmoozeId: (String currentShmoozeId) =>
                        _currentShmoozeId = currentShmoozeId,
                    getLineNumber: _getLineNumber,
                    isRefreshing: () => _isRefreshing,
                    refreshToken: _refreshToken,
                    getRefreshToken: () => _refreshToken,
                    isScrollingOnPage: _isScrollingOnPage,
                    isAnimatingOnPage: _isAnimatingOnPage,
                    offsetsOnPage: _offsetsOnPage,
                    pageController: _pageController,
                    itemCount: _itemCount(),
                    sizesOnPage: _sizesOnPage,
                    toggleSliding: _toggleSliding,
                    isSliding: () => _isSliding,
                    isPaused: () => _isPaused,
                    togglePause: _togglePause,
                    lineNumberOnPage: _lineNumberOnPage,
                    onPageSwipe: _onPageSwipe,
                    scripts: _scripts,
                    autoScrollControllers: _autoScrollControllers,
                    audioPlayers: _audioPlayers,
                    shmoozes: _shmoozes,
                    getCurrentPage: _getCurrentPage,
                  )),
                ],
              ),
            )
          ],
        ));
  }
}
