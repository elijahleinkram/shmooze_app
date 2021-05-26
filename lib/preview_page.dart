import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:shmooze/scripture.dart';
import 'currents.dart';
import 'home.dart';
import 'package:flutter/rendering.dart' as rendering;
import 'human.dart';
import 'dart:math' as math;

class PreviewPage extends StatefulWidget {
  final String caption;
  final String name;
  final String shmoozeId;
  final String audioRecordingUrl;
  final List<DocumentSnapshot> verses;
  final AudioPlayer audioPlayer;
  final dynamic playFrom;
  final dynamic playUntil;
  final dynamic startedRecording;
  final String senderUid;
  final String receiverUid;
  final String receiverDisplayName;
  final String receiverPhotoUrl;
  final double deviceWidth;
  final double textScaleFactor;

  PreviewPage(
      {@required this.caption,
      @required this.deviceWidth,
      @required this.startedRecording,
      @required this.receiverDisplayName,
      @required this.textScaleFactor,
      @required this.receiverPhotoUrl,
      @required this.shmoozeId,
      @required this.senderUid,
      @required this.receiverUid,
      @required this.playFrom,
      @required this.name,
      @required this.audioPlayer,
      @required this.playUntil,
      @required this.verses,
      @required this.audioRecordingUrl});

  @override
  _PreviewPageState createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage> with WidgetsBindingObserver {
  final dynamic _verses = [];
  final List<dynamic> _scripts = [];
  final List<List<double>> _sizesOnPage = [[]];
  final List<List<double>> _offsetsOnPage = [[]];
  bool _isPaused;
  final List<int> _lineNumberOnPage = [0];
  final List<AutoScrollController> _autoScrollControllers = [
    AutoScrollController()
  ];
  final List<bool> _isScrollingOnPage = [false];
  final List<bool> _isAnimatingOnPage = [false];
  final List<AudioPlayer> _audioPlayers = [];
  dynamic _shmooze;
  final List<dynamic> _shmoozes = [];
  final String _refreshToken = '0';
  double _scrollOffset;

  bool _hasTapped;
  bool _isSliding;
  Offset _pointerPosition;

  Future<void> _uploadShmooze() async {
    await FirebaseFunctions.instance.httpsCallable('uploadShmooze').call({
      'shmoozeId': widget.shmoozeId,
      'caption': widget.caption,
      'name': widget.name,
      'senderUid': widget.senderUid,
      'receiverUid': widget.receiverUid,
    }).catchError((error) {
      print(error);
    });
  }

  void _navigateToHome() {
    Navigator.of(context).pushAndRemoveUntil(
        CupertinoPageRoute(builder: (BuildContext context) {
      return Home(
        uploadShmooze: _uploadShmooze,
      );
    }), (route) => false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      if (!_isPaused) {
        widget.audioPlayer.resume().catchError((error) {
          print(error);
        });
      }
    } else {
      widget.audioPlayer.pause().catchError((error) {
        print(error);
      });
    }
  }

  void _playAudio() {
    widget.audioPlayer
        .play(widget.audioRecordingUrl,
            stayAwake: true,
            volume: 1.0,
            position: Duration(
              milliseconds: widget.playFrom,
            ))
        .catchError((error) {
      print('there was an error');
      widget.audioPlayer.resume().catchError((error) {
        print(error);
      });
    });
  }

  void _convertVersesToDynamic() {
    for (int i = 0; i < widget.verses.length; i++) {
      final DocumentSnapshot verse = widget.verses[i];
      final bool isSender = verse.get('authorUid') == widget.senderUid;
      String displayName;
      String photoUrl;
      if (isSender) {
        displayName = Human.displayName;
        photoUrl = Human.photoUrl;
      } else {
        displayName = widget.receiverDisplayName;
        photoUrl = widget.receiverPhotoUrl;
      }
      _verses.add({
        'mouth': {
          'opens': (verse.get('mouth.opens')).toInt(),
          'closes': (verse.get('mouth.closes')).toInt(),
        },
        'displayName': displayName,
        'photoUrl': photoUrl,
        'quote': verse.get('quote'),
        'verseId': verse.id,
      });
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
    final double horizontalPaddingSum = (widget.deviceWidth / 12.5) * 2;
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
      textScaleFactor: widget.textScaleFactor,
      textDirection: rendering.TextDirection.ltr,
      textAlign: TextAlign.start,
    )..layout(minWidth: 0, maxWidth: widget.deviceWidth - horizontalPaddingSum);
    return textPainter.size.height +
        ((widget.deviceWidth / (12.5 * (3 + 1 / 3))) * 2);
  }

  void _togglePause() {
    _isPaused = !_isPaused;
  }

  void _getDimensions() {
    double offset = 0.0;
    for (int i = 0; i < _verses.length; i++) {
      final dynamic verse = _verses[i];
      final String time = _getTime(verse['mouth']['opens']);
      final String quote = verse['quote'];
      final double height = _getHeight(quote, time);
      _sizesOnPage[0].add(height);
      _offsetsOnPage[0].add(offset);
      offset += height;
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

  int _getCurrentPage() => 0;

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
    if (_refreshToken != rToken || !mounted) {
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
    if (_refreshToken != rToken || !mounted) {
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

  void _createShmooze() {
    _shmooze = {
      'personA': {
        'displayName': Human.displayName,
        'photoUrl': Human.photoUrl,
        'uid': Human.uid
      },
      'personB': {
        'displayName': widget.receiverDisplayName,
        'photoUrl': widget.receiverPhotoUrl,
        'uid': widget.receiverUid
      },
      'play': {'from': widget.playFrom, 'until': widget.playUntil},
      'shmoozeId': widget.shmoozeId,
      'startedRecording': widget.startedRecording,
      'audioRecordingUrl': widget.audioRecordingUrl,
      'timeCreated': DateTime.now().millisecondsSinceEpoch,
      'name': widget.name,
      'caption': widget.caption,
    };
  }

  void _onPointerDown(PointerDownEvent p) {
    final int currentPage = _getCurrentPage();
    if (currentPage >= _shmoozes.length) {
      return;
    }
    _hasTapped = true;
    _isScrollingOnPage[currentPage] = true;
    _pointerPosition = p.position;
    _scrollOffset = _autoScrollControllers[currentPage].offset;
  }

  void _onPointerMove(PointerMoveEvent p) {
    final int currentPage = _getCurrentPage();
    if (currentPage >= _shmoozes.length) {
      return;
    }
    if (_autoScrollControllers[currentPage].offset != _scrollOffset) {
      _hasTapped = false;
    }
  }

  void _onPointerUp(PointerUpEvent p) {
    final int currentPage = _getCurrentPage();
    if (currentPage >= _shmoozes.length) {
      return;
    }
    _isScrollingOnPage[currentPage] = false;
    final bool hasMovedSideways =
        ((p.position.dx - _pointerPosition.dx).abs() >= (10 * 2 / 3));
    final bool hasTapped = _hasTapped && !hasMovedSideways;
    if (hasTapped) {
      if (_autoScrollControllers[currentPage].offset <= 0.0) {
        _seekVerse(hasTapped, currentPage, _refreshToken, 0);
      } else {
        _seekVerse(hasTapped, currentPage, _refreshToken);
      }
    }
  }

  void _onPointerCancel(_) {
    final int currentPage = _getCurrentPage();
    if (currentPage >= _shmoozes.length || !_isScrollingOnPage[currentPage]) {
      return;
    }
    _isScrollingOnPage[currentPage] = false;
  }

  @override
  void initState() {
    super.initState();
    _createShmooze();
    _shmoozes.add(_shmooze);
    _audioPlayers.add(widget.audioPlayer);
    _isSliding = _isPaused = false;
    WidgetsBinding.instance.addObserver(this);
    _convertVersesToDynamic();
    _getDimensions();
    _createShmooze();
    _scripts.add(_verses);
    _playAudio();
  }

  @override
  void dispose() {
    super.dispose();
    widget.audioPlayer.pause().catchError((error) {
      print(error);
    });
    widget.audioPlayer
        .seek(Duration(milliseconds: widget.playFrom))
        .catchError((error) {
      print(error);
    });
    _autoScrollControllers.first.dispose();
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener(
      onNotification: (OverscrollIndicatorNotification overScroll) {
        overScroll.disallowGlow();
        return false;
      },
      child: Material(
        color: Colors.white,
        child: SafeArea(
          child: Scaffold(
              backgroundColor: Colors.transparent,
              resizeToAvoidBottomInset: false,
              body: Stack(
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
                          onPointerDown: _onPointerDown,
                          onPointerMove: _onPointerMove,
                          onPointerUp: _onPointerUp,
                          onPointerCancel: _onPointerCancel,
                          child: Scripture(
                            seekVerse: null,
                            isScrollingOnPage: _isScrollingOnPage,
                            isAnimatingOnPage: _isAnimatingOnPage,
                            offsets: _offsetsOnPage[0],
                            sizes: _sizesOnPage[0],
                            autoScrollController: _autoScrollControllers[0],
                            shmoozeId: widget.shmoozeId,
                            playFrom: widget.playFrom,
                            playUntil: widget.playUntil,
                            startedRecording: widget.startedRecording,
                            caption: null,
                            name: null,
                            getCurrentPage: () {
                              return 0;
                            },
                            pageNumber: 0,
                            onRefresh: null,
                            refreshToken: '-1',
                            isPreview: true,
                            verses: _verses,
                            audioPlayer: widget.audioPlayer,
                          ),
                        ),
                      )
                    ],
                  ),
                  Positioned.fill(
                      child: Currents(
                    navigateToHome: _navigateToHome,
                    shmoozeCount: 1,
                    seekVerse: _seekVerse,
                    getOldPage: () => 0,
                    updateOldPage: (_) => null,
                    getCurrentShmoozeId: () => widget.shmoozeId,
                    updateCurrentShmoozeId: (_) => null,
                    getLineNumber: _getLineNumber,
                    isRefreshing: () => false,
                    refreshToken: _refreshToken,
                    getRefreshToken: () => _refreshToken,
                    isScrollingOnPage: _isScrollingOnPage,
                    isAnimatingOnPage: _isAnimatingOnPage,
                    offsetsOnPage: _offsetsOnPage,
                    pageController: null,
                    itemCount: 1,
                    isPreview: true,
                    sizesOnPage: _sizesOnPage,
                    toggleSliding: _toggleSliding,
                    isSliding: () => _isSliding,
                    isPaused: () => _isPaused,
                    togglePause: _togglePause,
                    lineNumberOnPage: _lineNumberOnPage,
                    onPageSwipe: () => null,
                    scripts: _scripts,
                    autoScrollControllers: _autoScrollControllers,
                    audioPlayers: _audioPlayers,
                    shmoozes: _shmoozes,
                    getCurrentPage: () => 0,
                  )),
                ],
              )),
        ),
      ),
    );
  }
}
