import 'dart:async';
import 'dart:io';
import 'package:agora_rtc_engine/rtc_engine.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shmooze/recording_page.dart';
import 'package:shmooze/shmooze_captioner.dart';
import 'package:shmooze/waiting_page.dart';
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
  final int _extraMillis = 1000 ~/ 3;
  String _shmoozeFilePath;
  bool _hasFinished;
  bool _pauseScreen;
  String _caption;
  String _name;
  String _audioRecordingUrl;
  List<DocumentSnapshot> _verses;
  String _shmoozeId;
  final AudioPlayer _audioPlayer = AudioPlayer(playerId: 'shmooze_player')
    ..setReleaseMode(ReleaseMode.LOOP).catchError((error) {
      print(error);
    });
  bool _readyForDispatch;
  bool _hasBeenDestroyed;
  bool _showThatWeAreFinished;
  bool _hasInitializedEngine;
  String _inviteId;
  bool _isReceiver;
  bool _senderHasAbandonedTheShmooze;
  String _sid;
  String _resourceId;

  Future<String> _getTmpFile(String filename) async {
    Directory tempDir =
        await getApplicationDocumentsDirectory().catchError((error) {
      print(error);
    });
    if (tempDir == null) {
      return null;
    }
    String tempPath = tempDir.path;
    File tempFile = File('$tempPath/$filename');
    return tempFile.path;
  }

  void _updateCaption(String caption) {
    _caption = caption;
  }

  void _updateName(String name) {
    _name = name;
  }

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
        _sid = result.data[0];
        _resourceId = result.data[1];
        if (_hasFinished) {
          _stopAudioRecording();
        }
      }
    }).catchError((error) {
      print(error);
    });
  }

  void _initEventHandlers() {
    if (_isSender) {
      _engine.setEventHandler(RtcEngineEventHandler(userOffline: (_, __) {
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
        _shmoozeFilePath =
            await _getTmpFile('pod${await getCurrentTime()}.wav');
        if (_shmoozeFilePath == null) {
          if (_canGoThroughCheckpoint()) {
            _retreat('Something unexpected happened, please try again later.');
          }
        } else {
          _engine
              .startAudioRecording(_shmoozeFilePath,
                  AudioSampleRateType.Type48000, AudioRecordingQuality.High)
              .catchError((error) {
            print(error);
          });
        }
      }));
    } else {
      _engine.setEventHandler(RtcEngineEventHandler(userOffline: (_, __) {
        if (_canGoThroughCheckpoint()) {
          if (_isConnected) {
            _retreat('Shmooze has finished.');
          } else {
            _retreat('${widget.displayName} has cancelled the shmooze.');
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
    _hasInitializedEngine = true;
    _engine = await RtcEngine.createWithConfig(
        RtcEngineConfig('c63e3b70b6fb457f9be76b45b48dd779'));
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
            content: Text(
              caption,
              style: GoogleFonts.roboto(
                fontSize: 14.0,
                color: CupertinoColors.black,
              ),
            ),
            actions: [
              TextButton(
                child: Text(
                  'Okay',
                  style: GoogleFonts.roboto(
                    color: CupertinoColors.activeBlue,
                    fontWeight: FontWeight.w400,
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

  Future<bool> _letsProceed(String msg, List<String> actions) {
    return showCupertinoDialog(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            content: Text(
              msg,
              style: GoogleFonts.roboto(
                fontSize: 14.0,
                color: CupertinoColors.black,
              ),
            ),
            actions: actions
                .map(
                  (label) => TextButton(
                    child: Text(
                      label,
                      style: GoogleFonts.roboto(
                        color: label == 'No'
                            ? CupertinoColors.systemGrey
                            : CupertinoColors.activeBlue,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context)
                          .pop(actions.indexOf(label) == actions.length - 1);
                    },
                  ),
                )
                .toList(),
          );
        });
  }

  Future<bool> _areYouSure() {
    return showCupertinoDialog(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            content: Text(
              'Are you sure you want to leave the shmooze?',
              style: GoogleFonts.roboto(
                fontSize: 14.0,
                color: CupertinoColors.black,
              ),
            ),
            actions: [
              TextButton(
                child: Text(
                  'No',
                  style: GoogleFonts.roboto(
                    color: CupertinoColors.systemGrey,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
              ),
              TextButton(
                child: Text(
                  'Yes',
                  style: GoogleFonts.roboto(
                    color: CupertinoColors.activeBlue,
                    fontWeight: FontWeight.w400,
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
    if (await _letsProceed(
            'Are you ready to finish shmoozing with ${widget.displayName.split(' ')[0]}?',
            ['No', 'Yes']) ??
        false) {
      if (_canGoThroughCheckpoint()) {
        _finishShmooze();
        _uploadAudioRecordingUrl();

        _destroyEngineAndStream();
        _navigateToCaptioner();
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (!_showThatWeAreFinished) {
            _showThatWeAreFinished = true;
            if (mounted) {
              setState(() {});
            }
          }
        });
      }
    }
  }

  void _updateAudioRecordingUrl(String audioRecordingUrl) {
    _audioRecordingUrl = audioRecordingUrl;
  }

  void _updateVerses(List<DocumentSnapshot> verses) {
    _verses = verses;
  }

  void _updateDispatch(bool readyForDispatch) {
    _readyForDispatch = readyForDispatch;
  }

  void _uploadAudioRecordingUrl() {
    if (_shmoozeFilePath == null) {
      return;
    }
    final UploadTask uploadTask = FirebaseStorage.instance
        .ref('users/${Human.uid}/shmoozes/$_shmoozeId')
        .putFile(
            File(_shmoozeFilePath), SettableMetadata(contentType: 'audio/wav'));
    uploadTask.whenComplete(() async {
      try {
        final String audioRecordingUrl = await FirebaseStorage.instance
            .ref('users/${Human.uid}/shmoozes/$_shmoozeId')
            .getDownloadURL()
            .catchError((error) {
          print(error);
        });
        if (_audioRecordingUrl == null && audioRecordingUrl != null) {
          _updateAudioRecordingUrl(audioRecordingUrl);
          _audioPlayer.setUrl(audioRecordingUrl).catchError((error) {
            print(error);
          });
        }
      } catch (onError) {
        print(onError);
      }
    });
  }

  void _navigateToCaptioner() {
    Navigator.of(context)
        .push(CupertinoPageRoute(builder: (BuildContext context) {
      return ShmoozeCaptioner(
        shmoozeId: _shmoozeId,
        caption: _caption,
        name: _name,
        updateName: _updateName,
        updateCaption: _updateCaption,
        readyForDispatch: _readyForDispatch,
        updateDispatch: _updateDispatch,
        verses: _verses,
        audioPlayer: _audioPlayer,
        updateVerses: _updateVerses,
        audioRecordingUrl: _audioRecordingUrl,
        updateAudioRecordingUrl: _updateAudioRecordingUrl,
        senderUid: widget.senderUid,
        inviteId: _inviteId,
        shmoozeFile: File(_shmoozeFilePath),
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
      'sid': _sid,
      'resourceId': _resourceId,
      'receiverUid': widget.receiverUid,
      'senderUid': widget.senderUid,
      'inviteId': _inviteId,
      'shmoozeId': _shmoozeId,
    });
  }

  bool _shouldStopAudioRecording() {
    return _sid != null && _resourceId != null;
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
    if (!_pauseScreen) {
      _pauseScreen = true;
      setState(() {});
    }
  }

  void _endShmoozeEarly() {
    _finishShmooze();
    _uploadAudioRecordingUrl();
    _destroyEngineAndStream();

    _letsProceed('${widget.displayName} has left the shmooze.',
        ['End shmooze early']).then((_) {
      if (!mounted) {
        return;
      }
      _navigateToCaptioner();
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_showThatWeAreFinished) {
          _showThatWeAreFinished = true;
          if (mounted) {
            setState(() {});
          }
        }
      });
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
              _retreat('Shmooze has finished.');
            }
          } else {
            if (_isSender) {
              _retreat('${widget.displayName} is currently unavailable.');
            } else {
              _retreat('${widget.displayName} has cancelled the shmooze.');
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
    _timer?.cancel();
    _destroyEngineAndStream();
    _audioPlayer.dispose().catchError((error) {
      print(error);
    }).catchError((error) {
      print(error);
    });
  }

  void _onBack() async {
    if (_isConnected) {
      if (await _userWantsToLeave() == false) {
        return;
      }
      _finishShmooze();
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Future<bool> _userWantsToLeave() async {
    return await _areYouSure().catchError((error) {
          print(error);
        }) ??
        false;
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
    _senderHasAbandonedTheShmooze = false;
    _shmoozeId = widget.shmoozeId;
    _inviteId = widget.inviteId;
    _hasInitializedEngine = false;
    _showThatWeAreFinished = false;
    _hasBeenDestroyed = false;
    _caption = '';
    _name = '';
    _readyForDispatch = false;
    _hasFinished = false;
    _pauseScreen = false;
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (!_isConnected) {
          if (_isSender) {
            if (!_senderHasAbandonedTheShmooze) {
              _senderHasAbandonedTheShmooze = true;
              _finishShmooze();
              _onBack();
            }
          } else {
            _finishShmooze();
            _onBack();
          }
        }
        return false;
      },
      child: Material(
        color: Colors.white,
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: Colors.transparent,
          appBar: AppBar(
              backgroundColor: Colors.transparent,
              automaticallyImplyLeading: false,
              elevation: 0.0,
              title: AnimatedSwitcher(
                  duration: Duration(milliseconds: 400),
                  child: !_isConnected
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.arrow_back_rounded,
                                size: 20.0,
                              ),
                              color: CupertinoColors.black,
                              onPressed: _onBack,
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              _pauseScreen
                                  ? 'Shmooze has ended'
                                  : 'Shmoozing...',
                              style: GoogleFonts.roboto(
                                fontSize: 10 + 10 / 3,
                                fontWeight: FontWeight.w400,
                                color: CupertinoColors.black,
                              ),
                            )
                          ],
                        ))),
          body: Padding(
            padding: EdgeInsets.only(
                bottom: kToolbarHeight,
                left: MediaQuery.of(context).size.width / 15,
                right: MediaQuery.of(context).size.width / 15),
            child: AnimatedSwitcher(
                duration: Duration(milliseconds: 400),
                child: !_isConnected
                    ? WaitingPage(
                        receiverDisplayName: widget.displayName,
                        isSender: _isSender,
                      )
                    : Center(
                        child: RecordingPage(
                          pauseScreen: _pauseScreen,
                          navigateToCaptioner: _navigateToCaptioner,
                          isSender: _isSender,
                          showThatWeAreFinished: _showThatWeAreFinished,
                          onBack: _onBack,
                          wrapThisUp: _wrapThisUp,
                          displayName: widget.displayName,
                          photoUrl: widget.photoUrl,
                        ),
                      )),
          ),
        ),
      ),
    );
  }
}
