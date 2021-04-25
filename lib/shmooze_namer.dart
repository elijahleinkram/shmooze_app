import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shmooze/preview_page.dart';

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
    Navigator.of(context)
        .push(CupertinoPageRoute(builder: (BuildContext context) {
      return PreviewPage(
        receiverUid: widget.shmoozeSnapshot['receiver']['uid'],
        receiverDisplayName: widget.shmoozeSnapshot['receiver']['displayName'],
        receiverPhotoUrl: widget.shmoozeSnapshot['receiver']['photoUrl'],
        senderUid: widget.shmoozeSnapshot['sender']['uid'],
        senderDisplayName: widget.shmoozeSnapshot['sender']['displayName'],
        senderPhotoUrl: widget.shmoozeSnapshot['sender']['photoUrl'],
        playFrom: playFrom,
        playUntil: playUntil,
        startedRecording: _startedRecording,
        name: widget.caption,
        audioPlayer: widget.audioPlayer,
        verses: _verses,
        caption: _name,
        shmoozeId: widget.shmoozeId,
        audioRecordingUrl: _audioRecordingUrl,
      );
    }));
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

      _processingTimer = Timer(
          Duration(
            milliseconds: 18000,
          ), () {
        if (_isTryingToLeavePage) {
          _isTryingToLeavePage = false;
          this._overlayEntry.remove();
          _showErrorMsg(
              'Something unexpected happened, please try again later.');
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
            content: Text(
              caption,
              style: GoogleFonts.roboto(
                fontSize: 15.0,
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
        });
  }

  bool _shouldGetReady() {
    return _hasVerses() && _hasAudioRecording();
  }

  void _initDispatch() {
    _readyForDispatch = true;
    _inviteSubscription.cancel().catchError((error) {
      print(error);
    });
    widget.updateVariables(readyForDispatch: _readyForDispatch);
    if (_isTryingToLeavePage) {
      _isTryingToLeavePage = false;
      this._overlayEntry.remove();
      if (!mounted) {
        return;
      }
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
        if (!_hasAudioRecording() &&
            snapshot.get('audioRecordingUrl') != null &&
            snapshot.get('startedRecording') != null) {
          _audioRecordingUrl = snapshot.get('audioRecordingUrl');
          _startedRecording = snapshot.get('startedRecording');
          widget.audioPlayer.setUrl(_audioRecordingUrl).catchError((error) {
            print(error);
          });
          widget.updateVariables(
              audioRecordingUrl: _audioRecordingUrl,
              startedRecording: _startedRecording);
          if (_shouldGetReady()) {
            _initDispatch();
          }
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
      },
    );
  }

  void _textListener(String txt) {
    _name = txt.trim();
    widget.updateVariables(name: _name);
  }

  bool _hasVerses() {
    return _verses != null;
  }

  @override
  void initState() {
    super.initState();
    _audioRecordingUrl = widget.audioRecordingUrl;
    _startedRecording = widget.startedRecording;
    _name = widget.name;
    _textEditingController.text = _name;
    _verses = widget.verses;
    _isTryingToLeavePage = false;
    _readyForDispatch = widget.readyForDispatch;
    if (!_readyForDispatch) {
      _setupStream();
    }
  }

  bool _hasAudioRecording() {
    return _audioRecordingUrl != null && _startedRecording != null;
  }

  @override
  void dispose() {
    super.dispose();
    if (!_readyForDispatch) {
      _inviteSubscription.cancel().catchError((error) {
        print(error);
      });
    }
    _textEditingController.dispose();
    _processingTimer?.cancel();
    _focusNode.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !_isTryingToLeavePage,
      child: GestureDetector(
          onTap: () {
            _focusNode.unfocus();
          },
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
                ),
                onPressed:
                    !_isTryingToLeavePage ? Navigator.of(context).pop : null,
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
                    autofocus: !_isTryingToLeavePage ? true : false,
                    maxLines: null,
                    onChanged: _textListener,
                    cursorColor: CupertinoColors.activeBlue,
                    textAlign: TextAlign.left,
                    style: GoogleFonts.roboto(
                      color: CupertinoColors.black,
                      fontSize: 20.0,
                      fontWeight: FontWeight.w400,
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    controller: _textEditingController,
                    decoration: InputDecoration.collapsed(
                      hintText: 'Caption this shmooze...',
                      hintStyle: GoogleFonts.roboto(
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
                          style: GoogleFonts.roboto(
                            color: CupertinoColors.activeBlue,
                            fontWeight: FontWeight.w500,
                            fontSize: 14.0,
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
