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
  final Future<void> Function() prepareForDispatch;

  MainStage({
    @required this.prepareForDispatch,
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
  final int _firstPage = 0;
  bool _isRefreshing;
  int _pageLimit = 5;
  final Set<String> _hasPlayed = {};
  int _refreshCount;
  final PreloadPageController _pageController = PreloadPageController();
  bool _hasLeftTheStage;

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
    final newTime = _shmoozes.last['timestamp'];
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

  Future<void> _getShmoozes(bool resetAndGet) async {
    int beforeTime;
    bool isEmpty = _shmoozes.isEmpty;
    if (isEmpty || resetAndGet) {
      beforeTime = await getCurrentTime();
    } else {
      beforeTime = _shmoozes.last['timestamp'];
    }
    final HttpsCallableResult result =
        await FirebaseFunctions.instance.httpsCallable('getShmoozes').call({
      'beforeTime': beforeTime,
    }).catchError((error) {
      print(error);
    });
    if (!resetAndGet) {
      if (_isRefreshing || _hasRefreshedPage(beforeTime, isEmpty)) {
        return;
      }
    } else {
      if (result != null && result.data != null) {
        if (result.data.first.first.isNotEmpty) {
          if (result.data.first.first['id'] == _shmoozes.first['id']) {
            return;
          }
        }
      }
    }
    if (result != null && result.data != null) {
      List<dynamic> resultData = result.data;
      int from;
      if (resetAndGet) {
        from = 0;
      } else {
        from = _shmoozes.length;
      }
      if (resetAndGet) {
        _clearData();
      }
      for (int i = 0; i < resultData.first.length; i++) {
        final dynamic shmooze = resultData.first[i];
        shmooze['startedSpeaking'] = shmooze['startedSpeaking'].toInt();
        shmooze['finishedSpeaking'] = shmooze['finishedSpeaking'].toInt();
        _shmoozes.add(shmooze);
      }
      for (int i = 0; i < resultData.last.length; i++) {
        _scripts.add(resultData.last[i]);
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
      final dynamic id = shmooze['id'];
      _keys.add(ValueKey(id + ' ' + _refreshCount.toString()));
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
    return _pageController.page >= _shmoozes.length - 4;
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

  void _playAudio(int index) {
    final AudioPlayer audioPlayer = _audioPlayers[index];
    final dynamic shmooze = _shmoozes[index];
    final dynamic startedSpeaking = shmooze['startedSpeaking'];
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
                milliseconds: startedSpeaking,
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

  void _updatePlayer(int newPage) {
    final int exceptFor = newPage;
    _pauseAudio(exceptFor);
    final int index = newPage;
    if (index < _shmoozes.length) {
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

  void _pageListener() {
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
      final dynamic playerId = shmooze['id'] + ' ' + _refreshCount.toString();
      final dynamic audioRecordingUrl = shmooze['audioRecordingUrl'];
      final AudioPlayer audioPlayer = AudioPlayer(playerId: playerId)
        ..setReleaseMode(ReleaseMode.LOOP).catchError((error) {
          print(error);
        });
      audioPlayer.setUrl(audioRecordingUrl);
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
      _playAudio(_firstPage);
    }
  }

  Future<void> _onRefresh() async {
    if (_isRefreshing) {
      return;
    }
    _refreshCount++;
    _toggleIsRefreshing();
    final String oldFirstShmooze = _shmoozes.first['id'];
    await _getShmoozes(true);
    if (_hasShmoozes()) {
      final String newFirstShmooze = _shmoozes.first['id'];
      if (oldFirstShmooze != newFirstShmooze) {
        _pageController.animateToPage(0,
            duration: Duration(milliseconds: 1000 ~/ 3),
            curve: Curves.fastOutSlowIn);
      }
    }
    _toggleIsRefreshing();
    _pageListener();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_hasShmoozes()) {
      if (state == AppLifecycleState.resumed) {
        if (_currentPage < _shmoozes.length) {
          _playAudio(_currentPage);
        }
      } else {
        _pauseAudio(-1);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _hasLeftTheStage = false;
    _refreshCount = 0;
    WidgetsBinding.instance.addObserver(this);
    _currentPage = _firstPage;
    _isRefreshing = false;
    _numberOfShmoozes = 5;
    _isLoadingShmooze = false;
    _listenToShmoozeCount();
    _pageController.addListener(_pageListener);
    if (widget.prepareForDispatch != null) {
      widget.prepareForDispatch().then((_) async {
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
    if (_hasLeftTheStage) {
      _hasLeftTheStage = false;
      if (_hasShmoozes()) {
        if (_currentPage < _shmoozes.length) {
          _playAudio(_currentPage);
        }
      }
    }
  }

  void didPushNext() {
    if (!_hasLeftTheStage) {
      _hasLeftTheStage = true;
      if (_hasShmoozes()) {
        _pauseAudio(-1);
      }
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
          final dynamic startedSpeaking = shmooze['startedSpeaking'];
          final dynamic finishedSpeaking = shmooze['finishedSpeaking'];
          final dynamic audioRecordingUrl = shmooze['audioRecordingUrl'];
          final dynamic verses = _scripts[index];
          final AudioPlayer audioPlayer = _audioPlayers[index];
          final ValueKey<dynamic> key = _keys[index];
          return Scripture(
            startedSpeaking: startedSpeaking,
            finishedSpeaking: finishedSpeaking,
            getCurrentPage: _getCurrentPage,
            name: name,
            caption: caption,
            index: index,
            refreshCount: _refreshCount,
            onRefresh: _onRefresh,
            key: key,
            startedRecording: startedRecording,
            audioRecordingUrl: audioRecordingUrl,
            verses: verses,
            audioPlayer: audioPlayer,
            isPreview: false,
          );
        }
      },
    );
  }
}
