import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shmooze/human.dart';
import 'package:shmooze/preview_page.dart';
import 'constants.dart';

class ShmoozeNamer extends StatefulWidget {
  final String name;
  final void Function(
      {String name,
      List<DocumentSnapshot> verses,
      String audioRecordingUrl,
      bool readyForDispatch,
      int startedRecording,
      String caption}) updateVariables;
  final bool readyForDispatch;
  final String audioRecordingUrl;
  final List<DocumentSnapshot> verses;
  final AudioPlayer audioPlayer;
  final String shmoozeId;
  final String caption;
  final int startedRecording;
  final Map<String, Map<String, String>> shmoozeSnapshot;

  ShmoozeNamer({
    @required this.audioPlayer,
    @required this.startedRecording,
    @required this.name,
    @required this.caption,
    @required this.audioRecordingUrl,
    @required this.readyForDispatch,
    @required this.updateVariables,
    @required this.verses,
    @required this.shmoozeId,
    @required this.shmoozeSnapshot,
  });

  @override
  _ShmoozeNamerState createState() => _ShmoozeNamerState();
}

class _ShmoozeNamerState extends State<ShmoozeNamer> {
  final FocusNode _focusNode = FocusNode();
  bool _readyForDispatch;
  bool _isTryingToLeavePage;
  List<DocumentSnapshot> _verses;
  final TextEditingController _textEditingController = TextEditingController();
  String _name;
  StreamSubscription<DocumentSnapshot> _inviteSubscription;
  int _startedRecording;
  String _audioRecordingUrl;
  OverlayEntry _overlayEntry;
  Timer _processingTimer;
  bool _isValid;
  bool _hasLeftPage;
  bool _hasTransferredUrl;

  void _navigateToPreviewPage() {
    dynamic playFrom =
        ((_verses[0].get('mouth')['opens']).toInt() - _startedRecording) -
            1000 ~/ 3;
    if (playFrom < 0) {
      playFrom = 0;
    }
    int playUntil =
        ((_verses[_verses.length - 1].get('mouth')['closes']).toInt() -
                _startedRecording) +
            1000 ~/ 3;
    final String audioRecordingUrl = _audioRecordingUrl;
    _hasLeftPage = true;
    Navigator.of(context)
        .push(CupertinoPageRoute(builder: (BuildContext context) {
      return PreviewPage(
        textScaleFactor: MediaQuery.of(context).textScaleFactor,
        deviceWidth: MediaQuery.of(context).size.width,
        receiverUid: widget.shmoozeSnapshot['receiver']['uid'],
        receiverDisplayName: widget.shmoozeSnapshot['receiver']['displayName'],
        receiverPhotoUrl: widget.shmoozeSnapshot['receiver']['photoUrl'],
        senderUid: Human.uid,
        playFrom: playFrom,
        playUntil: playUntil,
        startedRecording: _startedRecording,
        name: widget.caption,
        audioPlayer: widget.audioPlayer,
        verses: _verses,
        caption: _name,
        shmoozeId: widget.shmoozeId,
        audioRecordingUrl: audioRecordingUrl,
      );
    })).then((_) {
      _hasLeftPage = false;
      if (mounted) {
        if (!_audioRecordingUrl.endsWith('.m3u8') && !_hasTransferredUrl) {
          _hasTransferredUrl = true;
          widget.audioPlayer.setUrl(_audioRecordingUrl);
        }
      }
    });
  }

  void _onNext() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.unfocus();
      }
    });
    if (_readyForDispatch) {
      _navigateToPreviewPage();
    } else {
      if (_isTryingToLeavePage) {
        return;
      }
      _isTryingToLeavePage = true;
      if (mounted) {
        setState(() {});
      }
      _processingTimer = Timer(
          Duration(
            milliseconds: 18000,
          ), () {
        if (_isTryingToLeavePage) {
          _isTryingToLeavePage = false;
          this._overlayEntry.remove();
          if (!mounted) {
            return;
          }
          _showErrorMsg(
              'Something unexpected happened, please try again later.');
          setState(() {});
        }
      });
      this._overlayEntry = OverlayEntry(builder: (BuildContext context) {
        return Material(
          color: Colors.transparent,
          child: Center(
            child: CupertinoActivityIndicator(
              radius: 24.0,
            ),
          ),
        );
      });
      Overlay.of(context).insert(this._overlayEntry);
    }
  }

  Future<void> _showErrorMsg(String caption) {
    return showCupertinoDialog(
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
        });
  }

  bool _shouldGetReady() {
    return _hasVerses() && _hasAudioRecording();
  }

  void _initDispatch() {
    _readyForDispatch = true;
    if (!_audioRecordingUrl.endsWith('.m3u8')) {
      _inviteSubscription.cancel().catchError((error) {
        print(error);
      });
    }
    widget.updateVariables(readyForDispatch: _readyForDispatch);
    if (_isTryingToLeavePage) {
      _isTryingToLeavePage = false;
      this._overlayEntry.remove();
      if (!mounted) {
        return;
      }
      setState(() {});
      _navigateToPreviewPage();
    }
  }

  void _setupStream() {
    final Stream<DocumentSnapshot> inviteStream = FirebaseFirestore.instance
        .collection('mailRoom')
        .doc(widget.shmoozeId)
        .snapshots();
    _inviteSubscription = inviteStream.listen(
      (DocumentSnapshot snapshot) async {
        if (snapshot == null || !snapshot.exists) {
          return;
        }
        if (!_hasVerses() && snapshot.get('hasTranscript')) {
          final QuerySnapshot transcriptQuery = await FirebaseFirestore.instance
              .collection('shmoozes')
              .doc(widget.shmoozeId)
              .collection('transcript')
              .orderBy('mouth.opens', descending: false)
              .get()
              .catchError((error) {
            print(error);
          });
          if (transcriptQuery != null && transcriptQuery.docs != null) {
            _verses = transcriptQuery.docs;
            widget.updateVariables(verses: _verses);
            if (_shouldGetReady()) {
              _initDispatch();
            }
          }
        }
        final bool hasAudioRecording = _hasAudioRecording();
        if ((!hasAudioRecording || _audioRecordingUrl.endsWith('.m3u8')) &&
            snapshot.get('audioRecordingUrl') != null &&
            snapshot.get('startedRecording') != null) {
          _audioRecordingUrl = snapshot.get('audioRecordingUrl');
          _startedRecording = snapshot.get('startedRecording');
          if (hasAudioRecording) {
            if (_audioRecordingUrl.endsWith('.m3u8')) {
              return;
            }
          }
          if (!_hasLeftPage) {
            if (!_audioRecordingUrl.endsWith('.m3u8')) {
              _hasTransferredUrl = true;
            }
            widget.audioPlayer.setUrl(_audioRecordingUrl).catchError((error) {
              print(error);
            });
          }
          widget.updateVariables(
              audioRecordingUrl: _audioRecordingUrl,
              startedRecording: _startedRecording);
          if (_shouldGetReady()) {
            _initDispatch();
          }
        }
      },
    );
  }

  void _textListener() {
    final String name = _textEditingController.text.trim();
    widget.updateVariables(name: name);
    if (name.isNotEmpty && !_isValid) {
      _isValid = true;
      if (mounted) {
        setState(() {});
      }
    }
    if (name.isEmpty && _isValid) {
      _isValid = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  bool _hasVerses() {
    return _verses != null;
  }

  @override
  void initState() {
    super.initState();
    _hasLeftPage = false;
    _hasTransferredUrl = false;
    _isValid = _textEditingController.text.isNotEmpty;
    _audioRecordingUrl = widget.audioRecordingUrl;
    _startedRecording = widget.startedRecording;
    _name = widget.name;
    _textEditingController.text = _name;
    _verses = widget.verses;
    _isTryingToLeavePage = false;
    _readyForDispatch = widget.readyForDispatch;
    if (!_readyForDispatch || _audioRecordingUrl.endsWith('.m3u8')) {
      _setupStream();
    }
    _textEditingController.addListener(_textListener);
  }

  bool _hasAudioRecording() {
    return _audioRecordingUrl != null && _startedRecording != null;
  }

  @override
  void dispose() {
    super.dispose();
    if (!_readyForDispatch || _audioRecordingUrl.endsWith('.m3u8')) {
      _inviteSubscription.cancel().catchError((error) {
        print(error);
      });
    }
    widget.audioPlayer.dispose().catchError((error) {
      print(error);
    });
    _textEditingController.dispose();
    _processingTimer?.cancel();
    _focusNode.dispose();
  }

  Future<bool> _areYouSure() {
    return showCupertinoDialog(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            content: Text('Are you sure you want to leave the flow?',
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

  Future<bool> _onBack() async {
    return !_isTryingToLeavePage && (await _areYouSure() ?? false);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onBack,
      child: GestureDetector(
          onTap: _focusNode.unfocus,
          child: Scaffold(
            backgroundColor: CupertinoColors.white,
            resizeToAvoidBottomInset: false,
            appBar: AppBar(
              automaticallyImplyLeading: false,
              elevation: 0.0,
              backgroundColor: Colors.transparent,
              centerTitle: false,
              title: IconButton(
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: CupertinoColors.black,
                  size: 20.0,
                ),
                onPressed: _isTryingToLeavePage
                    ? null
                    : () async {
                        if (await _areYouSure() ?? false) {
                          Navigator.of(context).pop();
                        }
                      },
              ),
            ),
            body: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width / 10),
              child: Column(
                children: [
                  SizedBox(
                      height: MediaQuery.of(context).size.height *
                          0.025 *
                          (1 + 1 / 3)),
                  TextField(
                    focusNode: _focusNode,
                    autofocus: true,
                    maxLines: null,
                    cursorColor: CupertinoColors.activeBlue,
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      color: CupertinoColors.black,
                      fontSize: 20.0,
                      fontWeight: FontWeight.w400,
                    ),
                    buildCounter: (BuildContext context,
                            {int currentLength,
                            int maxLength,
                            bool isFocused}) =>
                        null,
                    maxLength: kShmoozeNameMaxLength,
                    textCapitalization: TextCapitalization.sentences,
                    controller: _textEditingController,
                    decoration: InputDecoration.collapsed(
                      hintText: 'Describe the flow...',
                      hintStyle: TextStyle(
                          fontFamily: 'Roboto',
                          color: CupertinoColors.systemGrey2,
                          fontWeight: FontWeight.w400,
                          fontSize: 20.0),
                    ),
                  ),
                  SizedBox(
                      height: MediaQuery.of(context).size.height *
                          0.025 *
                          (1 + 1 / 3)),
                  Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _onNext,
                        child: Text(
                          'Preview',
                          style: TextStyle(
                            color: CupertinoColors.activeBlue,
                            fontWeight: FontWeight.w500,
                            fontSize: 15.0,
                          ),
                        ),
                      ))
                ],
              ),
            ),
          )),
    );
  }
}
