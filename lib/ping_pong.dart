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
  final String inviteId;

  PingPong({
    @required this.photoUrl,
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
  final List<int> _senderSpeakingTimes = [];
  final List<int> _receiverSpeakingTimes = [];
  String _caption;
  String _name;
  int _startedRecording;
  String _audioRecordingUrl;
  List<DocumentSnapshot> _verses;
  String _shmoozeId;
  final AudioPlayer _audioPlayer = AudioPlayer(playerId: 'shmooze_poster')
    ..setReleaseMode(ReleaseMode.LOOP).catchError((error) {
      print(error);
    });
  bool _readyForDispatch;
  bool _isLeaving;
  bool _hasBeenDestroyed;
  bool _showThatWeAreFinished;
  bool _hasInitializedEngine;

  void _updateCaption(String caption) {
    _caption = caption;
  }

  void _updateName(String name) {
    _name = name;
  }

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
    // promises.add(
    //     _engine.enableAudioVolumeIndication(50, 3, true).catchError((error) {
    //   print(error);
    // }));
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
    await _engine
        .joinChannel(_token, _shmoozeId, null, _isSender ? 177 : 178)
        .catchError((error) {
      print(error);
    });
    if (_isSender) {
      _engine.setEventHandler(RtcEngineEventHandler(userOffline: (_, __) {
        if (!_isLeaving && mounted && !_hasFinished) {
          if (_isConnected) {
            _updateInviteStatus(Status.complete.index);
            _destroyEnginesAndStreams();
            if (!_pauseScreen) {
              _pauseScreen = true;
              setState(() {});
            }
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
          } else {
            _updateInviteStatus(Status.cancelled.index);
            _retreat('${widget.displayName} is currently unavailable.');
          }
        }
      }, tokenPrivilegeWillExpire: (_) {
        if (!mounted || _isLeaving || _hasFinished) {
          return;
        }
        if (_isConnected) {
          _updateInviteStatus(Status.complete.index);
          _destroyEnginesAndStreams();
          if (!_pauseScreen) {
            _pauseScreen = true;
            setState(() {});
          }
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
        } else {
          _updateInviteStatus(Status.cancelled.index);
          _retreat('${widget.displayName} is currently unavailable.');
        }
      },
          //     audioVolumeIndication:
          //     (List<AudioVolumeInfo> speakers, int totalVolume) async {
          //   int senderVolume = 0;
          //   int receiverVolume = 0;
          //   for (int i = 0; i < speakers.length; i++) {
          //     int volume = speakers[i].volume;
          //     if (speakers[i].vad == 1) {
          //       senderVolume = volume;
          //     } else {
          //       receiverVolume = volume;
          //     }
          //   }
          //   if (senderVolume >= 50 || receiverVolume >= 50) {
          //     if (senderVolume >= receiverVolume) {
          //       _senderSpeakingTimes.add(await getCurrentTime());
          //     } else {
          //       _receiverSpeakingTimes.add((await getCurrentTime()));
          //     }
          //   }
          // },
          joinChannelSuccess: (_, __, ___) async {
        _engine.enableAudio().catchError((error) {
          print(error);
        });
        _engine.setEnableSpeakerphone(true).catchError((error) {
          print(error);
        });
        // _shmoozeFilePath =
        //     await _getTmpFile('pod${await getCurrentTime()}.wav');
        // if (_shmoozeFilePath == null) {
        //   if (!_isLeaving && !_hasFinished) {
        //     _updateInviteStatus(Status.cancelled.index);
        //     _retreat('Something unexpected happened, please try again later.');
        //   }
        // } else {
        //   await _engine
        //       .startAudioRecording(_shmoozeFilePath,
        //           AudioSampleRateType.Type48000, AudioRecordingQuality.High)
        //       .catchError((error) {
        //     print(error);
        //   });
        //   _startedRecording = await getCurrentTime();
        // }
      }));
    } else {
      _engine.setEventHandler(RtcEngineEventHandler(userOffline: (_, __) {
        if (_isLeaving || !mounted) {
          return;
        }
        if (_isConnected) {
          _updateInviteStatus(Status.exits.index);
          _retreat('Shmooze has finished.');
        } else {
          _updateInviteStatus(Status.unavailable.index);
          _retreat('${widget.displayName} has cancelled the shmooze.');
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

  String _token;
  bool _isSender;
  DocumentSnapshot _latestSnapshot;
  final int _maxNumberOfTries = 3;

  void _updateInviteStatus(int status) {
    FirebaseFunctions.instance.httpsCallable('updateInviteStatus').call({
      'senderUid': widget.senderUid,
      'receiverUid': widget.receiverUid,
      'status': status,
      'inviteId': widget.inviteId,
    });
  }

  void _getToken(int numberOfTries) async {
    if (_isLeaving || _hasFinished || !mounted) {
      return;
    }
    if (numberOfTries == 3) {
      final int status =
          _isSender ? Status.cancelled.index : Status.exits.index;
      _updateInviteStatus(status);
      _retreat('Something unexpected happened, please try again later.');
      return;
    }
    final HttpsCallableResult result = await FirebaseFunctions.instance
        .httpsCallable('getToken')
        .call()
        .catchError((error) {
      print(error);
    });
    if (result != null && result.data != null) {
      _token = result.data;
      return;
    } else {
      _getToken(numberOfTries + 1);
    }
  }

  void _inviteUser() {
    FirebaseFunctions.instance.httpsCallable('inviteUserForShmooze').call({
      'senderUid': widget.senderUid,
      'receiverUid': widget.receiverUid,
      'inviteId': widget.inviteId,
    }).then((HttpsCallableResult result) {
      if (result != null && result.data != null) {
        bool greatSuccess = result.data;
        if (!greatSuccess) {
          _retreat('${widget.displayName} is currently unavailable.');
        }
      } else {
        _retreat('${widget.displayName} is currently unavailable.');
      }
    }).catchError((error) {
      print(error);
    });
  }

  void _retreat(String caption) {
    _isLeaving = true;
    if (!mounted || _hasFinished) {
      return;
    }
    if (!_pauseScreen) {
      _pauseScreen = true;
      setState(() {});
    }
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
    if (actions.length == 1) {
      _makeAndUpload();
      _hasFinished = true;
    }
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

  void _toggleConnection() {
    _isConnected = true;
    if (mounted) {
      setState(() {});
    }
    if (_isSender) {
      if (_timer?.isActive ?? false) {
        _timer?.cancel();
      }
      _updateInviteStatus(Status.connected.index);
    }
  }

  void _startTimer() {
    _timer = Timer(Duration(milliseconds: kExpirationInMillis), () {
      _retreat('${widget.displayName} is currently unavailable.');
    });
  }

  void _receiverLearnsAboutOther() {
    FirebaseFunctions.instance.httpsCallable('receiverLearnsAboutOther').call({
      'senderUid': widget.senderUid,
      'inviteId': widget.inviteId,
      'receiverUid': widget.receiverUid,
    }).catchError((error) {
      print(error);
    });
  }

  void _wrapThisUp() async {
    if (await _letsProceed(
            'Are you ready to finish shmoozing with ${widget.displayName.split(' ')[0]}?',
            ['No', 'Yes']) ??
        false) {
      _updateInviteStatus(Status.complete.index);
      if (!mounted || _hasFinished) {
        return;
      }
      _makeAndUpload();
      _hasFinished = true;
      if (!_pauseScreen) {
        _pauseScreen = true;
        setState(() {});
      }
      _destroyEnginesAndStreams();
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
        .ref('users/${widget.senderUid}/shmoozes/$_shmoozeId')
        .putFile(
            File(_shmoozeFilePath), SettableMetadata(contentType: 'audio/wav'));
    uploadTask.whenComplete(() async {
      try {
        if (_audioRecordingUrl != null) {
          return;
        }
        final String audioRecordingUrl = await FirebaseStorage.instance
            .ref('users/${widget.senderUid}/shmoozes/$_shmoozeId')
            .getDownloadURL()
            .catchError((error) {
          print(error);
        });
        if (_audioRecordingUrl == null && audioRecordingUrl != null) {
          _updateAudioRecordingUrl(audioRecordingUrl);
          _audioPlayer.setUrl(_audioRecordingUrl).catchError((error) {
            print(error);
          });
        }
      } catch (onError) {
        print(onError);
      }
    });
  }

  String _getShmoozeId() {
    return FirebaseFirestore.instance.collection('shmoozes').doc().id;
  }

  void _makeAndUpload() {
    FirebaseFunctions.instance.httpsCallable('makeShmooze').call({
      'startedRecording': _startedRecording,
      'senderSpeakingTimes': _senderSpeakingTimes,
      'receiverSpeakingTimes': _receiverSpeakingTimes,
      'inviteId': widget.inviteId,
      'shmoozeId': _shmoozeId,
    }).then((_) {
      _uploadAudioRecordingUrl();
    }).catchError((error) {
      print(error);
    });
  }

  void _navigateToCaptioner() {
    if (_shmoozeFilePath == null) {
      showToastErrorMsg(
          'Something unexpected happened, please try again later.');
    } else {
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
          startedRecording: _startedRecording,
          senderSpeakingTimes: _senderSpeakingTimes,
          receiverSpeakingTimes: _receiverSpeakingTimes,
          senderUid: widget.senderUid,
          inviteId: widget.inviteId,
          shmoozeFile: File(_shmoozeFilePath),
        );
      }));
    }
  }

  void _listenToInviteStatus() {
    final Stream<DocumentSnapshot> stream = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.receiverUid)
        .collection('invites')
        .doc(widget.inviteId)
        .snapshots();
    _inviteSubscription = stream.listen((DocumentSnapshot ds) async {
      if (_isLeaving || _hasFinished) {
        return;
      }
      if (ds != null && ds.exists) {
        _shmoozeId = _shmoozeId ?? ds.get('shmoozeId');
        final int status = ds.get('status');
        if (!_isSender) {
          if (status == Status.complete.index ||
              status == Status.cancelled.index) {
            if (_isConnected) {
              _retreat('Shmooze has finished.');
            } else {
              _retreat('${widget.displayName} has cancelled the shmooze.');
            }
          }
          final int letsConnectIn = ds.get('readyToShmoozeIn.sender');
          if (letsConnectIn != null &&
              ds.get('readyToShmoozeIn.receiver') != null) {
            if ((await getCurrentTime()) < letsConnectIn && _hasToken()) {
              if (_isLeaving) {
                return;
              }
              _receiverLearnsAboutOther();
            }
          }
        }
        if (_isSender) {
          final int letsConnectIn = ds.get('readyToShmoozeIn.receiver');
          if (letsConnectIn != null &&
              ds.get('readyToShmoozeIn.sender') == null) {
            if ((await getCurrentTime()) < letsConnectIn && _hasToken()) {
              if (_isLeaving || _hasFinished) {
                return;
              }
              _letsConnectToReceiver();
            }
          }
          if (status == Status.unavailable.index) {
            _retreat('${widget.displayName} is currently unavailable.');
          }
          if (status == Status.exits.index) {
            if (_isConnected) {
              _destroyEnginesAndStreams();
              if (!_pauseScreen) {
                _pauseScreen = true;
                setState(() {});
              }
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
            } else {
              _retreat('${widget.displayName} is currently unavailable.');
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

  void _destroyEnginesAndStreams() {
    if (_hasBeenDestroyed) {
      return;
    }
    _hasBeenDestroyed = true;
    _inviteSubscription?.cancel()?.catchError((error) {
      print(error);
    });
    if (_hasInitializedEngine) {
      _hasInitializedEngine = false;
      _engine?.destroy()?.catchError((error) {
        print(error);
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
    _timer?.cancel();
    if (!_hasBeenDestroyed) {
      _destroyEnginesAndStreams();
    }
    _audioPlayer.dispose().catchError((error) {
      print(error);
    }).catchError((error) {
      print(error);
    });
  }

  void _onBack() async {
    if (_isConnected && !(await _userWantsToLeave())) {
      return;
    }
    final int status = _isSender ? Status.cancelled.index : Status.exits.index;
    _updateInviteStatus(status);
    if (!mounted) {
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<bool> _userWantsToLeave() async {
    return await _areYouSure().catchError((error) {
          print(error);
        }) ??
        false;
  }

  bool _canConnect(int letsConnectIn) {
    if (_latestSnapshot == null || _isLeaving || _hasFinished || !mounted) {
      return false;
    }
    return _latestSnapshot.get('knowsAboutOther.sender') &&
        _latestSnapshot.get('knowsAboutOther.receiver') &&
        (_latestSnapshot.get('readyToShmoozeIn.sender') ?? -1) ==
            letsConnectIn &&
        (_latestSnapshot.get('readyToShmoozeIn.receiver') ?? -1) ==
            letsConnectIn;
  }

  void _letsConnectToReceiver() async {
    final HttpsCallableResult<dynamic> result =
        await FirebaseFunctions.instance.httpsCallable('letsShmoozeIn').call({
      'senderUid': widget.senderUid,
      'receiverUid': widget.receiverUid,
      'inviteId': widget.inviteId,
    }).catchError((error) {
      print(error);
    });
    if (result != null && result.data != null) {
      final int letsConnectIn = result.data;
      final int inMillis =
          (letsConnectIn - (await getCurrentTime())) - _extraMillis;
      if (inMillis >= 0) {
        await Future.delayed(Duration(milliseconds: inMillis));
        if (_canConnect(letsConnectIn)) {
          _initAgoraEngine();
          await Future.delayed(Duration(milliseconds: _extraMillis));
          if (_canConnect(letsConnectIn)) {
            _toggleConnection();
          } else {
            if (_hasInitializedEngine) {
              _hasInitializedEngine = false;
              _engine?.destroy()?.catchError((error) {
                print(error);
              });
            }
            _clearSpeakingTimes();
          }
        }
      }
    }
  }

  void _letsConnectToSender(int numberOfTries) async {
    if (_isLeaving || !mounted) {
      return;
    }
    if (numberOfTries == _maxNumberOfTries) {
      _updateInviteStatus(Status.unavailable.index);
      _retreat('Something unexpected happened, please try again later.');
      return;
    }
    final HttpsCallableResult<dynamic> result =
        await FirebaseFunctions.instance.httpsCallable('letsShmoozeIn').call({
      'senderUid': widget.senderUid,
      'receiverUid': widget.receiverUid,
      'inviteId': widget.inviteId,
    }).catchError((error) {
      print(error);
    });
    if (result != null && result.data != null) {
      final int letsConnectIn = result.data;
      int inMillis = (letsConnectIn - (await getCurrentTime())) - _extraMillis;
      if (inMillis >= 0) {
        await Future.delayed(Duration(milliseconds: inMillis));
        if (_canConnect(letsConnectIn)) {
          _initAgoraEngine();
          await Future.delayed(Duration(milliseconds: _extraMillis));
          if (_canConnect(letsConnectIn)) {
            _toggleConnection();
            return;
          } else {
            if (_hasInitializedEngine) {
              _hasInitializedEngine = false;
              _engine?.destroy()?.catchError((error) {
                print(error);
              });
            }
            _clearSpeakingTimes();
          }
        }
      }
    }
    _letsConnectToSender(numberOfTries + 1);
  }

  void _clearSpeakingTimes() {
    _senderSpeakingTimes.clear();
    _receiverSpeakingTimes.clear();
  }

  @override
  void initState() {
    super.initState();
    _hasInitializedEngine = false;
    _showThatWeAreFinished = false;
    _hasBeenDestroyed = false;
    _caption = '';
    _name = '';
    _isLeaving = false;
    _readyForDispatch = false;
    _hasFinished = false;
    _pauseScreen = false;
    _getToken(0);
    _isSender = widget.senderUid == Human.uid;
    _isConnected = false;
    if (_isSender) {
      _startTimer();
      _inviteUser();
    } else {
      _letsConnectToSender(0);
    }
    _listenToInviteStatus();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (!_isConnected) {
          _onBack();
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
                            // _pauseScreen
                            //     ? Row(
                            //         children: [
                            //           // _pauseScreen
                            //           //     ?
                            //           Icon(
                            //             MaterialCommunityIcons.phone_hangup,
                            //             size: 14.0,
                            //             color: CupertinoColors.black,
                            //           ),
                            //           SizedBox(width: 10.0),
                            //           // : Material(
                            //           //     shape: CircleBorder(),
                            //           //     elevation: 2 / 3,
                            //           //     shadowColor: Color(kNorthStar),
                            //           //     child: CircleAvatar(
                            //           //       backgroundColor:
                            //           //           CupertinoColors.systemRed,
                            //           //       radius: 2.5,
                            //           //     ),
                            //           //   ),
                            //         ],
                            //       )
                            //     : Container(),
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
                        displayName: widget.displayName,
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
