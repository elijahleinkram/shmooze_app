import 'dart:async';
import 'package:agora_rtc_engine/rtc_engine.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shmooze/recording_page.dart';
import 'package:shmooze/shmooze_namer.dart';
import 'package:shmooze/waiting_page.dart';
import 'package:wakelock/wakelock.dart';
import 'constants.dart';
import 'human.dart';

class PingPong extends StatefulWidget {
  final String photoUrl;
  final String senderUid;
  final String displayName;
  final String receiverUid;
  final String shmoozeId;
  final String inviteId;

  PingPong({
    @required this.photoUrl,
    @required this.shmoozeId,
    @required this.senderUid,
    @required this.displayName,
    @required this.receiverUid,
    @required this.inviteId,
  });

  @override
  _PingPongState createState() => _PingPongState();
}

class _PingPongState extends State<PingPong> {
  Timer _timer;
  bool _isConnected;
  StreamSubscription<DocumentSnapshot> _inviteSubscription;
  RtcEngine _engine;
  final int _extraMillis = (1000 ~/ 3) * 2;
  bool _hasFinished;
  String _caption;
  String _name;
  String _audioRecordingUrl;
  List<DocumentSnapshot> _verses;
  String _shmoozeId;
  bool _readyForDispatch;
  bool _hasBeenDestroyed;
  bool _hasInitializedEngine;
  String _inviteId;
  bool _isReceiver;
  bool _senderHasAbandonedTheShmooze;
  String _groupSid;
  String _groupResourceId;
  String _individualSid;
  String _individualResourceId;
  String _appId;
  Map<String, Map<String, String>> _shmoozeSnapshot;
  int _startedRecording;

  void _endShmoozeForSender() {
    if (_canGoThroughCheckpoint()) {
      if (_isConnected) {
        _endShmoozeEarly();
      } else {
        _retreat('${widget.displayName} is currently unavailable.');
      }
    }
  }

  void _startAudioRecording() async {
    FirebaseFunctions.instance.httpsCallable('startAudioRecording').call({
      'receiverUid': widget.receiverUid,
      'senderUid': widget.senderUid,
      'shmoozeId': _shmoozeId,
      'inviteId': _inviteId,
    }).then((HttpsCallableResult result) {
      if (result != null && result.data != null) {
        _individualSid = result.data[0];
        _individualResourceId = result.data[1];
        _groupSid = result.data[2];
        _groupResourceId = result.data[3];
        if (_hasFinished) {
          _stopAudioRecording();
        }
      }
    }).catchError((error) {
      print(error);
    });
  }

  Future<void> _getAgoraApi() async {
    try {
      final RemoteConfig remoteConfig = RemoteConfig.instance;
      await remoteConfig.fetchAndActivate().catchError((error) {
        print(error);
      });
      _appId = remoteConfig.getValue('appId').asString();
    } catch (e) {
      print(e);
    }
  }

  void _initEventHandlers() {
    if (_isSender) {
      _engine.setEventHandler(
          RtcEngineEventHandler(userOffline: (_, UserOfflineReason reason) {
        if (reason != UserOfflineReason.Quit) {
          return;
        }
        _endShmoozeForSender();
      }, tokenPrivilegeWillExpire: (_) {
        _endShmoozeForSender();
      }, joinChannelSuccess: (_, __, ___) async {
        _engine.enableAudio().catchError((error) {
          print(error);
        });
        _engine.setEnableSpeakerphone(true).catchError((error) {
          print(error);
        });
      }));
    } else {
      _engine.setEventHandler(
          RtcEngineEventHandler(userOffline: (_, UserOfflineReason reason) {
        if (reason != UserOfflineReason.Quit) {
          return;
        }
        if (_canGoThroughCheckpoint()) {
          if (_isConnected) {
            _retreat('The flow is over.');
          } else {
            _retreat('${widget.displayName} has left the flow.');
          }
        }
      }, joinChannelSuccess: (_, __, ___) {
        _engine.enableAudio().catchError((error) {
          print(error);
        });
        _engine.setEnableSpeakerphone(true).catchError((error) {
          print(error);
        });
      }));
    }
  }

  Future<void> _initAgoraEngine() async {
    if (_hasInitializedEngine) {
      return;
    }
    if (_appId == null) {
      await _getAgoraApi();
    }
    if (_appId == null) {
      return;
    }
    _hasInitializedEngine = true;
    _engine = await RtcEngine.createWithConfig(RtcEngineConfig(_appId));
    if (_hasInitializedEngine == false) {
      _engine?.destroy()?.catchError((error) {
        print(error);
      });
      return;
    }
    final List<Future<dynamic>> promises = [];
    promises.add(_engine.enableInEarMonitoring(false).catchError((error) {
      print(error);
    }));
    promises.add(_engine.enableDeepLearningDenoise(true).catchError((error) {
      print(error);
    }));
    promises.add(_engine
        .setChannelProfile(ChannelProfile.LiveBroadcasting)
        .catchError((error) {
      print(error);
    }));
    promises
        .add(_engine.setClientRole(ClientRole.Broadcaster).catchError((error) {
      print(error);
    }));
    promises.add(_engine
        .setAudioProfile(AudioProfile.Default, AudioScenario.MEETING)
        .catchError((error) {
      print(error);
    }));
    await Future.wait(promises).catchError((error) {
      print(error);
    });
    _engine
        .joinChannel(_token, _shmoozeId, null, _isSender ? 177 : 178)
        .catchError((error) {
      print(error);
    });
    _initEventHandlers();
  }

  String _token;
  bool _isSender;
  DocumentSnapshot _latestSnapshot;
  final int _maxNumberOfTries = 3;

  void _updateInviteStatus(int status) {
    FirebaseFunctions.instance.httpsCallable('updateInviteStatus').call({
      'senderUid': widget.senderUid,
      'receiverUid': widget.receiverUid,
      'status': status,
      'inviteId': _inviteId,
      'shmoozeId': _shmoozeId,
    });
  }

  void _getToken(int numberOfTries) async {
    if (!_canGoThroughCheckpoint()) {
      return;
    }
    if (numberOfTries == 3) {
      _retreat('Something unexpected happened, please try again later.');
      return;
    }
    final HttpsCallableResult result =
        await FirebaseFunctions.instance.httpsCallable('getToken').call({
      'shmoozeId': _shmoozeId,
      'inviteId': _inviteId,
      'receiverUid': widget.receiverUid,
      'senderUid': widget.senderUid,
    }).catchError((error) {
      print(error);
    });
    if (result != null && result.data != null) {
      _token = result.data;
      return;
    } else {
      _getToken(numberOfTries + 1);
    }
  }

  void _inviteUserForShmooze() {
    FirebaseFunctions.instance.httpsCallable('inviteUserForShmooze').call({
      'senderUid': widget.senderUid,
      'receiverUid': widget.receiverUid,
    }).then((HttpsCallableResult result) {
      if (result != null && result.data != null) {
        if (result.data is bool) {
          bool greatSuccess = result.data;
          if (_canGoThroughCheckpoint()) {
            if (!greatSuccess) {
              _retreat('${widget.displayName} is currently unavailable.');
            }
          }
        } else {
          _inviteId = result.data[0];
          _shmoozeId = result.data[1];
          if (_canGoThroughCheckpoint()) {
            _startAudioRecording();
            _getToken(0);
            _listenToInviteStatus();
          }
          if (_senderHasAbandonedTheShmooze) {
            _updateInviteStatus(Status.finished.index);
          }
        }
      } else {
        if (_canGoThroughCheckpoint()) {
          _retreat('${widget.displayName} is currently unavailable.');
        }
      }
    }).catchError((error) {
      print(error);
    });
  }

  void _retreat(String caption) {
    _finishShmooze();
    showCupertinoDialog(
        barrierDismissible: true,
        context: context,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            content: Text(caption,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 15.0 + 1 / 3,
                  color: CupertinoColors.black,
                )),
            actions: [
              TextButton(
                child: Text(
                  'Okay',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: CupertinoColors.activeBlue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              )
            ],
          );
        }).then((_) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }

  Future<bool> _letsProceed(String msg, String action) {
    return showCupertinoDialog(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            content: Text(msg,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 15.0 + 1 / 3,
                  color: CupertinoColors.black,
                )),
            actions: [
              TextButton(
                child: Text(
                  action,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: CupertinoColors.activeBlue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              )
            ],
          );
        });
  }

  Future<bool> _areYouSure(String txt) {
    return showCupertinoDialog(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            content: Text(txt,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 15.0 + 1 / 3,
                  color: CupertinoColors.black,
                )),
            actions: [
              TextButton(
                child: Text(
                  'No',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: CupertinoColors.systemGrey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
              ),
              TextButton(
                child: Text(
                  'Yes',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: CupertinoColors.activeBlue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
              ),
            ],
          );
        });
  }

  void _connectShmoozers() {
    _isConnected = true;
    setState(() {});
    if (_isSender) {
      if (_timer?.isActive ?? false) {
        _timer?.cancel();
      }
    }
  }

  void _startTimer() {
    _timer = Timer(Duration(milliseconds: kExpirationInMillis), () {
      _retreat('${widget.displayName} is currently unavailable.');
    });
  }

  void _receiverBecomesAware() {
    FirebaseFunctions.instance.httpsCallable('receiverBecomesAware').call({
      'senderUid': widget.senderUid,
      'inviteId': _inviteId,
      'receiverUid': widget.receiverUid,
      'shmoozeId': _shmoozeId,
    }).catchError((error) {
      print(error);
    });
  }

  void _wrapThisUp() async {
    if (((await _areYouSure('Are you sure you want to stop the flow?')) ??
            false) &&
        _canGoThroughCheckpoint()) {
      _finishShmooze();
      _destroyEngineAndStream();
      _navigateToCaptioner();
    }
  }

  void _updateVariables(
      {String name,
      List<DocumentSnapshot> verses,
      String audioRecordingUrl,
      bool readyForDispatch,
      int startedRecording,
      String caption}) {
    _name = name ?? _name;
    _verses = verses ?? _verses;
    _audioRecordingUrl = audioRecordingUrl ?? _audioRecordingUrl;
    _readyForDispatch = readyForDispatch ?? _readyForDispatch;
    _startedRecording = startedRecording ?? _startedRecording;
    _caption = caption ?? _caption;
  }

  void _navigateToCaptioner() {
    Navigator.of(context)
        .pushReplacement(CupertinoPageRoute(builder: (BuildContext context) {
      return ShmoozeNamer(
        audioPlayer: AudioPlayer(playerId: _shmoozeId)
          ..setReleaseMode(ReleaseMode.LOOP),
        updateVariables: _updateVariables,
        startedRecording: _startedRecording,
        shmoozeSnapshot: _shmoozeSnapshot,
        shmoozeId: _shmoozeId,
        caption: _caption,
        name: _name,
        readyForDispatch: _readyForDispatch,
        verses: _verses,
        audioRecordingUrl: _audioRecordingUrl,
      );
    }));
  }

  bool _canGoThroughCheckpoint() {
    return !_hasFinished && mounted;
  }

  bool _hasShmoozeAndInvite() {
    return _shmoozeId != null && _inviteId != null;
  }

  bool _shouldUpdateStatus() {
    return _hasShmoozeAndInvite() &&
        (_latestSnapshot == null ||
            (_latestSnapshot.get('status') != Status.finished.index));
  }

  void _stopAudioRecording() {
    FirebaseFunctions.instance.httpsCallable('stopAudioRecording').call({
      'individualSid': _individualSid,
      'individualResourceId': _individualResourceId,
      'groupSid': _groupSid,
      'groupResourceId': _groupResourceId,
      'receiverUid': widget.receiverUid,
      'senderUid': widget.senderUid,
      'inviteId': _inviteId,
      'shmoozeId': _shmoozeId,
    });
  }

  bool _shouldStopAudioRecording() {
    return _individualSid != null &&
        _individualResourceId != null &&
        _groupSid != null &&
        _groupResourceId != null;
  }

  void _finishShmooze() {
    if (_hasFinished) {
      return;
    }
    _hasFinished = true;
    if (_shouldStopAudioRecording()) {
      _stopAudioRecording();
    }
    if (_shouldUpdateStatus()) {
      _updateInviteStatus(Status.finished.index);
    }
  }

  void _endShmoozeEarly() {
    _finishShmooze();
    _destroyEngineAndStream();
    _letsProceed('${widget.displayName} has left the flow.', 'Okay').then((_) {
      if (!mounted) {
        return;
      }
      _navigateToCaptioner();
    }).catchError((error) {
      print(error);
    });
  }

  void _listenToInviteStatus() {
    final Stream<DocumentSnapshot> stream = FirebaseFirestore.instance
        .collection('mailRoom')
        .doc(_inviteId)
        .snapshots();
    _inviteSubscription = stream.listen((DocumentSnapshot ds) async {
      if (!_canGoThroughCheckpoint()) {
        return;
      }
      if (ds != null && ds.exists) {
        _latestSnapshot = ds;
        final int status = ds.get('status');
        if (status == Status.finished.index) {
          if (_isConnected) {
            if (_isSender) {
              _endShmoozeEarly();
            } else {
              _retreat('The flow is over.');
            }
          } else {
            if (_isSender) {
              _retreat('${widget.displayName} is currently unavailable.');
            } else {
              _retreat('${widget.displayName} has left the flow.');
            }
          }
        }
        final dynamic senderIsReadyToShmoozeIn =
            ds.get('sender.readyToShmoozeIn');
        final dynamic receiverIsReadyToShmoozeIn =
            ds.get('receiver.readyToShmoozeIn');
        if (_isReceiver) {
          if (senderIsReadyToShmoozeIn != null &&
              receiverIsReadyToShmoozeIn != null) {
            if ((await getCurrentTime()) < senderIsReadyToShmoozeIn &&
                _hasToken()) {
              if (_canGoThroughCheckpoint()) {
                _receiverBecomesAware();
              }
            }
          }
        }
        if (_isSender) {
          if (receiverIsReadyToShmoozeIn != null &&
              senderIsReadyToShmoozeIn == null) {
            if ((await getCurrentTime()) < receiverIsReadyToShmoozeIn &&
                _hasToken()) {
              if (_canGoThroughCheckpoint()) {
                _senderConnectsToReceiver();
              }
            }
          }
          if (status != Status.waiting.index && (_timer?.isActive ?? false)) {
            _timer?.cancel();
          }
        }
      }
    });
  }

  bool _hasToken() {
    return _token != null;
  }

  void _destroyStream() {
    _inviteSubscription?.cancel()?.catchError((error) {
      print(error);
    });
  }

  void _destroyEngineAndStream() {
    if (_hasBeenDestroyed) {
      return;
    }
    _hasBeenDestroyed = true;
    _destroyStream();
    _destroyEngine();
  }

  @override
  void dispose() {
    super.dispose();
    Wakelock.disable().catchError((error) {
      print(error);
    });
    _timer?.cancel();
    _destroyEngineAndStream();
  }

  bool _canConnect(int letsConnectIn) {
    if (!_canGoThroughCheckpoint()) {
      return false;
    }
    return _latestSnapshot != null &&
        _latestSnapshot.get('sender.isAware') &&
        _latestSnapshot.get('receiver.isAware') &&
        (_latestSnapshot.get('sender.readyToShmoozeIn') ?? -1) ==
            letsConnectIn &&
        (_latestSnapshot.get('receiver.readyToShmoozeIn') ?? -1) ==
            letsConnectIn;
  }

  void _destroyEngine() {
    if (_hasInitializedEngine) {
      _hasInitializedEngine = false;
      _engine?.destroy()?.catchError((error) {
        print(error);
      });
    }
  }

  Future<bool> _initConnection(int letsConnectIn) async {
    final int inMillis =
        (letsConnectIn - (await getCurrentTime())) - _extraMillis;
    if (inMillis >= 0) {
      await Future.delayed(Duration(milliseconds: inMillis));
      if (_canConnect(letsConnectIn)) {
        _initAgoraEngine();
        await Future.delayed(Duration(milliseconds: _extraMillis));
        if (_canConnect(letsConnectIn)) {
          _connectShmoozers();
          return true;
        } else {
          _destroyEngine();
        }
      }
    }
    return false;
  }

  void _senderConnectsToReceiver() async {
    final HttpsCallableResult<dynamic> result =
        await FirebaseFunctions.instance.httpsCallable('letsShmoozeIn').call({
      'senderUid': widget.senderUid,
      'receiverUid': widget.receiverUid,
      'inviteId': _inviteId,
      'shmoozeId': _shmoozeId,
    }).catchError((error) {
      print(error);
    });
    if (result != null && result.data != null) {
      _initConnection(result.data);
    }
  }

  void _receiverConnectsToSender(int numberOfTries) async {
    if (!_canGoThroughCheckpoint()) {
      return;
    }
    if (numberOfTries == _maxNumberOfTries) {
      _retreat('Something unexpected happened, please try again later.');
      return;
    }
    final HttpsCallableResult<dynamic> result =
        await FirebaseFunctions.instance.httpsCallable('letsShmoozeIn').call({
      'senderUid': widget.senderUid,
      'receiverUid': widget.receiverUid,
      'inviteId': _inviteId,
      'shmoozeId': _shmoozeId,
    }).catchError((error) {
      print(error);
    });
    if (result != null && result.data != null) {
      final bool hasConnected = await _initConnection(result.data);
      if (hasConnected) {
        return;
      }
    }
    _receiverConnectsToSender(numberOfTries + 1);
  }

  @override
  void initState() {
    super.initState();
    _getAgoraApi();
    Wakelock.enable().catchError((error) {
      print(error);
    });
    _shmoozeSnapshot = {
      'receiver': {
        'uid': widget.receiverUid,
        'photoUrl': widget.photoUrl,
        'displayName': widget.displayName,
      }
    };
    _senderHasAbandonedTheShmooze = false;
    _shmoozeId = widget.shmoozeId;
    _inviteId = widget.inviteId;
    _hasInitializedEngine = false;
    _hasBeenDestroyed = false;
    _name = _caption = '';
    _readyForDispatch = false;
    _hasFinished = false;
    _isSender = widget.senderUid == Human.uid;
    _isReceiver = !_isSender;
    _isConnected = false;
    if (_isSender) {
      _startTimer();
      _inviteUserForShmooze();
    } else {
      _getToken(0);
      _receiverConnectsToSender(0);
      _listenToInviteStatus();
    }
  }

  Future<bool> _onBack() async {
    if (_hasFinished) {
      return false;
    }
    bool shouldPop = true;
    if (!_isConnected) {
      if (_isSender) {
        if (!_senderHasAbandonedTheShmooze) {
          _senderHasAbandonedTheShmooze = true;
          _finishShmooze();
        }
      } else {
        _finishShmooze();
      }
    } else {
      if (await _areYouSure('Are you sure you want to leave the flow?') ??
          false) {
        _finishShmooze();
      } else {
        shouldPop = false;
      }
    }
    return shouldPop;
  }

  final List<ValueKey<String>> _keys = [
    ValueKey('sender'),
    ValueKey('receiver')
  ];

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onBack,
      child: Material(
        color: Colors.white,
        child: Scaffold(
            resizeToAvoidBottomInset: false,
            backgroundColor: Colors.transparent,
            floatingActionButtonLocation:
                FloatingActionButtonLocation.centerFloat,
            floatingActionButton: !_isConnected
                ? null
                : Padding(
                    padding: EdgeInsets.only(
                      bottom: 100 / 3 / 1.5 / 3,
                    ),
                    child: SizedBox(
                      height: 40.0 + 10 / 3,
                      child: !_isSender
                          ? TextButton(
                              key: _keys.first,
                              style: TextButton.styleFrom(
                                shape: StadiumBorder(),
                                padding: EdgeInsets.symmetric(horizontal: 20.0),
                                backgroundColor: CupertinoColors.activeBlue,
                              ),
                              child: Icon(
                                Icons.mic,
                                size: 24.0,
                                color: CupertinoColors.white,
                              ),
                              onPressed: null,
                            )
                          : TextButton(
                              key: _keys.last,
                              style: TextButton.styleFrom(
                                shape: StadiumBorder(),
                                padding: EdgeInsets.symmetric(horizontal: 20.0),
                                backgroundColor: CupertinoColors.destructiveRed,
                              ),
                              child: Icon(
                                Icons.stop_rounded,
                                size: 24.0,
                                color: CupertinoColors.white,
                              ),
                              onPressed: _wrapThisUp,
                              // label: Text(
                              //   '',
                              //   style: TextStyle(
                              //     fontFamily: 'Roboto',
                              //     fontSize: 15.0,
                              //     fontWeight: FontWeight.w500,
                              //     color: CupertinoColors.white,
                              //   ),
                              // )
                            ),
                    ),
                  ),
            appBar: AppBar(
                backgroundColor: Colors.transparent,
                automaticallyImplyLeading: false,
                elevation: 0.0,
                title: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_rounded, size: 20.0),
                      color: CupertinoColors.black,
                      onPressed: () async {
                        if ((await _onBack()) && mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  ],
                )),
            body: Padding(
              padding: EdgeInsets.only(
                  bottom: kToolbarHeight,
                  left: MediaQuery.of(context).size.width / 12.5 * (1 + 1 / 3),
                  right:
                      MediaQuery.of(context).size.width / 12.5 * (1 + 1 / 3)),
              child: Center(
                child: AnimatedSwitcher(
                  duration: Duration(milliseconds: 400),
                  child: !_isConnected
                      ? WaitingPage(
                          receiverDisplayName: widget.displayName,
                          isSender: _isSender,
                        )
                      : RecordingPage(
                          isSender: _isSender,
                          displayName: widget.displayName,
                          photoUrl: widget.photoUrl,
                        ),
                ),
              ),
            )),
      ),
    );
  }
}
