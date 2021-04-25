import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:preload_page_view/preload_page_view.dart';
import 'package:shmooze/constants.dart';
import 'package:shmooze/fake_scripture.dart';
import 'package:shmooze/scripture.dart';
import 'main.dart';

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
  final dynamic _shmoozes = [];
  final dynamic _scripts = [];
  final List<AudioPlayer> _audioPlayers = [];
  bool _isLoadingShmooze;
  final List<ValueKey<dynamic>> _keys = [];
  bool _isRefreshing;
  int _pageLimit = 5;
  final Set<String> _hasPlayed = {};
  String _refreshToken;
  final PreloadPageController _pageController = PreloadPageController();
  bool _hasLeftStage;
  bool _hasLeftApp;

  void _listenToShmoozeCount() {
    final Stream<DocumentSnapshot> stream = FirebaseFirestore.instance
        .collection('metaData')
        .doc('shmoozes')
        .snapshots();
    _streamSubscription = stream.listen((event) {
      if (event != null && event.exists) {
        final int numberOfShmoozes = event.get('numberOfShmoozes');
        if (_numberOfShmoozes != numberOfShmoozes) {
          _numberOfShmoozes = numberOfShmoozes;
          if (mounted) {
            setState(() {});
          }
        }
      }
    });
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

  void _clearShmoozes() {
    _shmoozes.clear();
  }

  void _clearKeys() {
    _keys.clear();
  }

  void _clearScripts() {
    _scripts.clear();
  }

  void _clearAudioPlayers() {
    _disposeAudioPlayers();
    _hasPlayed.clear();
    _audioPlayers.clear();
  }

  void _clearData() {
    _clearShmoozes();
    _clearKeys();
    _clearScripts();
    _clearAudioPlayers();
  }

  Future<void> _getShmoozes(bool refreshMode) async {
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
    if (!refreshMode) {
      bool wasEmpty = isEmpty;
      if (_isRefreshing || _hasRefreshedPage(afterTime, wasEmpty)) {
        return;
      }
    } else {
      if (result != null && result.data != null) {
        if (result.data.first.first.isNotEmpty) {
          if (result.data.first.first['shmoozeId'] ==
              _shmoozes.first['shmoozeId']) {
            return;
          }
        }
      }
      _issueNewRefreshToken();
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
      _setupAudioPlayers(from, until);
      _cutKeys(from, until);
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _cutKeys(int from, int until) {
    for (int i = from; i < until; i++) {
      final dynamic shmooze = _shmoozes[i];
      final dynamic shmoozeId = shmooze['shmoozeId'];
      _keys.add(ValueKey(shmoozeId + ' ' + _refreshToken));
    }
  }

  int _itemCount() {
    final int remainder = _numberOfShmoozes - _shmoozes.length;
    int numberOfMorePages;
    if (remainder > _pageLimit) {
      numberOfMorePages = _pageLimit;
    } else {
      numberOfMorePages = remainder;
    }
    return _shmoozes.length + numberOfMorePages;
  }

  bool _hasPassedLastShmooze(int index) {
    return index >= _shmoozes.length;
  }

  bool _isCloseToTheEnd() {
    return _pageController.page >= _shmoozes.length - 5;
  }

  bool _noMoreShmoozes() {
    return _shmoozes.length >= _numberOfShmoozes;
  }

  int _currentPage;

  int _getCurrentPage() {
    if (!_pageController.hasClients) {
      return 0;
    }
    final double page = _pageController.page;
    if (page - page.toInt() >= 0.5) {
      return page.toInt() + 1;
    }
    return _pageController.page.toInt();
  }

  bool _pageHasChanged(int oldPage, int newPage) {
    return oldPage != newPage;
  }

  bool _canPlay() {
    return !_hasLeftStage && !_hasLeftApp;
  }

  void _playAudio(int index) {
    if (!_canPlay()) {
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
              position: Duration(
                milliseconds: playFrom,
              ))
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

  void _updateCurrentPage(int newPage) {
    _currentPage = newPage;
  }

  bool _shmoozeExists(int index) {
    return index < _shmoozes.length;
  }

  void _updatePlayer(int newPage) {
    final int exceptFor = newPage;
    _pauseAudio(exceptFor);
    final int index = newPage;
    if (_shmoozeExists(index)) {
      _playAudio(index);
    }
  }

  void _loadMoreShmoozes() async {
    if (_isLoadingShmooze || _noMoreShmoozes()) {
      return;
    }
    if (_isCloseToTheEnd()) {
      _isLoadingShmooze = true;
      await _getShmoozes(false);
      _isLoadingShmooze = false;
    }
  }

  bool _hasShmoozes() {
    return _shmoozes.isNotEmpty;
  }

  void _onPageSwipe() {
    if (_isRefreshing) {
      return;
    }
    final int oldPage = _currentPage;
    final int newPage = _getCurrentPage();
    if (_pageHasChanged(oldPage, newPage)) {
      _updateCurrentPage(newPage);
      if (_hasShmoozes()) {
        _updatePlayer(newPage);
        _loadMoreShmoozes();
      }
    }
  }

  void _setupAudioPlayers(int from, int until) {
    for (int i = from; i < until; i++) {
      final dynamic shmooze = _shmoozes[i];
      final dynamic playerId = shmooze['shmoozeId'] + ' ' + _refreshToken;
      final dynamic audioRecordingUrl = shmooze['audioRecordingUrl'];
      final AudioPlayer audioPlayer = AudioPlayer(playerId: playerId)
        ..setReleaseMode(ReleaseMode.LOOP).catchError((error) {
          print(error);
        });
      audioPlayer.setUrl(audioRecordingUrl).catchError((error) {
        print(error);
      });
      _audioPlayers.add(audioPlayer);
    }
  }

  void _toggleIsRefreshing() {
    _isRefreshing = !_isRefreshing;
  }

  void _disposeAudioPlayers() {
    for (int i = 0; i < _audioPlayers.length; i++) {
      final AudioPlayer audioPlayer = _audioPlayers[i];
      audioPlayer.dispose().catchError((error) {
        print(error);
      });
    }
  }

  Future<void> _getFirstBatchOfShmoozes() async {
    await _getShmoozes(false);
    if (_hasShmoozes()) {
      _playAudio(0);
    }
  }

  void _issueNewRefreshToken() {
    int refreshCount = int.parse(_refreshToken);
    _refreshToken = (refreshCount + 1).toString();
  }

  Future<void> _onRefresh() async {
    if (_isRefreshing) {
      return;
    }
    _toggleIsRefreshing();
    final String oldFirstShmooze = _shmoozes.first['shmoozeId'];
    await _getShmoozes(true);
    if (_hasShmoozes()) {
      final String newFirstShmooze = _shmoozes.first['shmoozeId'];
      if (oldFirstShmooze != newFirstShmooze) {
        _pageController.animateToPage(0,
            duration: Duration(milliseconds: 1000 ~/ 3),
            curve: Curves.fastOutSlowIn);
      }
    }
    _toggleIsRefreshing();
    _onPageSwipe();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      if (_hasLeftApp) {
        _hasLeftApp = false;
        if (_shmoozeExists(_currentPage)) {
          _playAudio(_currentPage);
        }
      }
    } else {
      if (!_hasLeftApp) {
        _hasLeftApp = true;
        _pauseAudio(-1);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _hasLeftApp = false;
    _hasLeftStage = false;
    _refreshToken = '0';
    WidgetsBinding.instance.addObserver(this);
    _currentPage = 0;
    _isRefreshing = false;
    _numberOfShmoozes = 5;
    _isLoadingShmooze = false;
    _listenToShmoozeCount();
    _pageController.addListener(_onPageSwipe);
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
      if (_shmoozeExists(_currentPage)) {
        _playAudio(_currentPage);
      }
    }
  }

  void didPushNext() {
    if (!_hasLeftStage) {
      _hasLeftStage = true;
      _pauseAudio(-1);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _streamSubscription?.cancel();
    _pageController.dispose();
    _disposeAudioPlayers();
  }

  @override
  Widget build(BuildContext context) {
    return PreloadPageView.builder(
      itemCount: _itemCount(),
      physics: BouncingScrollPhysics(),
      controller: _pageController,
      itemBuilder: (BuildContext context, int index) {
        if (_hasPassedLastShmooze(index)) {
          return FakeScripture();
        } else {
          final dynamic shmooze = _shmoozes[index];
          final dynamic name = shmooze['name'];
          final dynamic caption = shmooze['caption'];
          final dynamic startedRecording = shmooze['startedRecording'];
          final dynamic playFrom = shmooze['play']['from'];
          final dynamic playUntil = shmooze['play']['until'];
          final dynamic verses = _scripts[index];
          final AudioPlayer audioPlayer = _audioPlayers[index];
          final ValueKey<dynamic> key = _keys[index];
          return Scripture(
            personA: shmooze['personA'],
            personB: shmooze['personB'],
            shmoozeId: shmooze['shmoozeId'],
            startedRecording: startedRecording,
            playFrom: playFrom,
            playUntil: playUntil,
            getCurrentPage: _getCurrentPage,
            name: name,
            caption: caption,
            index: index,
            refreshToken: _refreshToken,
            onRefresh: _onRefresh,
            key: key,
            verses: verses,
            audioPlayer: audioPlayer,
            isPreview: false,
          );
        }
      },
    );
  }
}
