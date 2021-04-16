import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shmooze/preview_page.dart';

class ShmoozeNamer extends StatefulWidget {
  final String name;
  final void Function(String name) updateName;
  final bool readyForDispatch;
  final void Function(String str) updateAudioRecordingUrl;
  final String audioRecordingUrl;
  final List<DocumentSnapshot> verses;
  final void Function(List<DocumentSnapshot> verses) updateVerses;
  final AudioPlayer audioPlayer;
  final void Function(bool readyForDispatch) updateDispatch;
  final String shmoozeId;
  final String caption;

  ShmoozeNamer({
    @required this.audioPlayer,
    @required this.name,
    @required this.caption,
    @required this.updateAudioRecordingUrl,
    @required this.audioRecordingUrl,
    @required this.readyForDispatch,
    @required this.updateName,
    @required this.verses,
    @required this.shmoozeId,
    @required this.updateDispatch,
    @required this.updateVerses,
  });

  @override
  _ShmoozeNamerState createState() => _ShmoozeNamerState();
}

class _ShmoozeNamerState extends State<ShmoozeNamer> {
  final FocusNode _focusNode = FocusNode();
  StreamSubscription<DocumentSnapshot> _shmoozeSubscription;
  bool _readyForDispatch;
  bool _isTryingToLeavePage;
  String _audioRecordingUrl;
  List<DocumentSnapshot> _verses;
  int _startedSpeaking;
  int _finishedSpeaking;
  final TextEditingController _textEditingController = TextEditingController();
  String _name;
  bool _thereIsAnError;
  DocumentSnapshot _shmoozeSnapshot;

  void _navigateToPreviewPage() {
    _startedSpeaking = (_verses[0].get('mouth')['opens']).toInt() - (1000 ~/ 3);
    if (_startedSpeaking < 0) {
      _startedSpeaking = 0;
    }
    _finishedSpeaking =
        (_verses[_verses.length - 1].get('mouth')['closes']).toInt() +
            1000 ~/ 3;
    Navigator.of(context)
        .push(CupertinoPageRoute(builder: (BuildContext context) {
      return PreviewPage(
        receiverUid: _shmoozeSnapshot.get('receiver.uid'),
        receiverDisplayName: _shmoozeSnapshot.get('receiver.displayName'),
        receiverPhotoUrl: _shmoozeSnapshot.get('receiver.photoUrl'),
        senderUid: _shmoozeSnapshot.get('sender.uid'),
        senderDisplayName: _shmoozeSnapshot.get('sender.displayName'),
        senderPhotoUrl: _shmoozeSnapshot.get('sender.photoUrl'),
        finishedSpeaking: _finishedSpeaking,
        name: widget.caption,
        startedSpeaking: _startedSpeaking,
        audioPlayer: widget.audioPlayer,
        verses: _verses,
        caption: _name,
        shmoozeId: widget.shmoozeId,
        audioRecordingUrl: _audioRecordingUrl,
      );
    }));
  }

  void _onNext() {
    if (_readyForDispatch) {
      _navigateToPreviewPage();
    } else {
      if (_thereIsAnError) {
        _showErrorMsg('Preview unavailable',
            'We were unable to produce a transcript for this shmooze.');
      } else {
        if (_isTryingToLeavePage) {
          return;
        }
        _isTryingToLeavePage = true;
        showCupertinoDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return WillPopScope(
                onWillPop: () async {
                  return false;
                },
                child: Center(
                  child: CupertinoActivityIndicator(
                    radius: 24.0,
                  ),
                ),
              );
            }).then((_) {
          _isTryingToLeavePage = false;
        }).catchError((error) {
          print(error);
        });
      }
    }
  }

  Future<void> _showErrorMsg(String titleMsg, String contentMsg) {
    return showCupertinoDialog(
        barrierDismissible: true,
        context: context,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            title: Text(
              titleMsg,
              style: GoogleFonts.roboto(),
            ),
            content: Text(
              contentMsg,
              style: GoogleFonts.roboto(),
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

  bool _isValid;

  Future<void> _getTranscript() async {
    final QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('shmoozes')
        .doc(widget.shmoozeId)
        .collection('transcript')
        .orderBy('mouth.opens', descending: false)
        .get()
        .catchError((error) {
      print(error);
    }).catchError((error) {
      print(error);
    });
    if (querySnapshot != null && querySnapshot.docs != null) {
      _verses = querySnapshot.docs;
      widget.updateVerses(_verses);
    }
  }

  void _registerError() {
    if (_isTryingToLeavePage) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      _showErrorMsg('Preview unavailable',
          'We were unable to produce a transcript for this shmooze.');
    }
  }

  void _setupStream() {
    final Stream<DocumentSnapshot> stream = FirebaseFirestore.instance
        .collection('shmoozes')
        .doc(widget.shmoozeId)
        .snapshots();
    _shmoozeSubscription = stream.listen((DocumentSnapshot snapshot) async {
      if (snapshot == null || !snapshot.exists || _thereIsAnError) {
        return;
      }
      _shmoozeSnapshot = snapshot;
      _thereIsAnError = _shmoozeSnapshot.get('thereIsAnError');
      if (_thereIsAnError) {
        _registerError();
      } else if (_shmoozeSnapshot.get('readyForDispatch')) {
        if (_audioRecordingUrl == null) {
          _audioRecordingUrl = _shmoozeSnapshot.get('audioRecordingUrl');
          widget.updateAudioRecordingUrl(_audioRecordingUrl);
          widget.audioPlayer.setUrl(_audioRecordingUrl).catchError((error) {
            print(error);
          });
        }
        if (_verses == null) {
          await _getTranscript();
        }
        _thereIsAnError = _verses == null || _verses.isEmpty;
        if (_thereIsAnError) {
          _registerError();
        } else {
          _readyForDispatch = true;
          widget.updateDispatch(_readyForDispatch);
          if (_isTryingToLeavePage) {
            if (!mounted) {
              return;
            }
            _navigateToPreviewPage();
          }
        }
      }
    });
  }

  void _textListener() {
    _name = _textEditingController.text.trim();
    widget.updateName(_name);
    if (_name.length >= 3 && !_isValid) {
      _isValid = true;
      if (mounted) {
        setState(() {});
      }
    }
    if (_name.length < 3 && _isValid) {
      _isValid = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _thereIsAnError = false;
    _name = widget.name;
    _textEditingController.text = _name;
    _verses = widget.verses;
    _audioRecordingUrl = widget.audioRecordingUrl;
    _isTryingToLeavePage = false;
    _readyForDispatch = widget.readyForDispatch;
    if (!_readyForDispatch) {
      _setupStream();
    }
    _isValid = _textEditingController.text.trim().length >= 3;
    _textEditingController.addListener(_textListener);
  }

  @override
  void dispose() {
    super.dispose();
    _shmoozeSubscription?.cancel()?.catchError((error) {
      print(error);
    });
    _textEditingController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
            onPressed: Navigator.of(context).pop,
          ),
        ),
        body: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width / 10),
          child: Column(
            children: [
              SizedBox(
                  height:
                      MediaQuery.of(context).size.height * 0.025 * (1 + 1 / 3)),
              TextField(
                focusNode: _focusNode,
                autofocus: true,
                maxLines: null,
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
                  height:
                      MediaQuery.of(context).size.height * 0.025 * (1 + 1 / 3)),
              Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () {
                      _showErrorMsg('Too short',
                              'Caption must have at least three characters.')
                          .then((_) {
                        _focusNode.requestFocus();
                      }).catchError((error) {
                        print(error);
                      });
                    },
                    child: TextButton(
                        onPressed: !_isValid ? null : _onNext,
                        child: Text(
                          'Preview',
                          style: GoogleFonts.roboto(
                            color: CupertinoColors.activeBlue,
                            fontWeight: FontWeight.w500,
                            fontSize: 14.0,
                          ),
                        )),
                  ))
            ],
          ),
        ),
      ),
    );
  }
}
