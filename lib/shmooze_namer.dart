import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shmooze/constants.dart';
import 'package:shmooze/preview_page.dart';

class ShmoozeNamer extends StatefulWidget {
  final String name;
  final void Function(String name) updateName;
  final bool readyForDispatch;
  final int startedRecording;
  final List<int> senderSpeakingTimes;
  final List<int> receiverSpeakingTimes;
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
    @required this.receiverSpeakingTimes,
    @required this.updateAudioRecordingUrl,
    @required this.audioRecordingUrl,
    @required this.readyForDispatch,
    @required this.updateName,
    @required this.senderSpeakingTimes,
    @required this.startedRecording,
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
  bool _letsGo;
  String _audioRecordingUrl;
  List<DocumentSnapshot> _verses;
  dynamic _startedSpeaking;
  dynamic _finishedSpeaking;
  final TextEditingController _textEditingController = TextEditingController();
  String _name;
  bool _thereIsAnError;

  void _previewUnavailableMsg() {
    showCupertinoDialog(
        barrierDismissible: true,
        context: context,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            title: Text(
              'Preview unavailable',
              style: GoogleFonts.roboto(),
            ),
            content: Text(
              'We were unable to produce a transcript for this shmooze.',
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
        }).then((_) {
      if (_letsGo) {
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    }).catchError((error) {
      print(error);
    });
  }

  void _onNext() {
    if (_readyForDispatch) {
      if (_verses == null || _verses.isEmpty) {
        _previewUnavailableMsg();
      } else {
        _startedSpeaking =
            ((_verses[0].get('mouth')['opens'] * 1000).toInt()) - (1000 ~/ 3);
        if (_startedSpeaking < 0) {
          _startedSpeaking = 0;
        }
        _finishedSpeaking =
            (_verses[_verses.length - 1].get('mouth')['closes'] * 1000)
                    .toInt() +
                1000 ~/ 3;
        Navigator.of(context)
            .push(CupertinoPageRoute(builder: (BuildContext context) {
          return PreviewPage(
            finishedSpeaking: _finishedSpeaking,
            name: widget.caption.trim(),
            startedSpeaking: _startedSpeaking,
            startedRecording: widget.startedRecording,
            audioPlayer: widget.audioPlayer,
            verses: _verses,
            caption: _name.trim(),
            shmoozeId: widget.shmoozeId,
            audioRecordingUrl: _audioRecordingUrl,
          );
        }));
      }
    } else {
      if (_thereIsAnError) {
        showToastErrorMsg(
            'Something unexpected happened, please try again later.');
      } else {
        _letsGo = true;
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
          _letsGo = false;
        }).catchError((error) {
          print(error);
        });
      }
    }
  }

  void _showErrorMsg() {
    showCupertinoDialog(
        barrierDismissible: true,
        context: context,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            title: Text(
              'Too short',
              style: GoogleFonts.roboto(),
            ),
            content: Text(
              'Caption must have at least three characters.',
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
        }).then((_) {
      _focusNode.requestFocus();
    }).catchError((error) {
      print(error);
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
    });
    if (querySnapshot != null && querySnapshot.docs != null) {
      _verses = querySnapshot.docs;
      widget.updateVerses(_verses);
    }
  }

  // void _cleanShmoozeOfSin() {
  //   FirebaseFunctions.instance
  //       .httpsCallable('cleanShmoozeOfSin')
  //       .call({'shmoozeId': widget.shmoozeId}).catchError((error) {
  //     print(error);
  //   });
  // }

  void _setupStream() {
    final Stream<DocumentSnapshot> stream = FirebaseFirestore.instance
        .collection('shmoozes')
        .doc(widget.shmoozeId)
        .snapshots();
    _shmoozeSubscription = stream.listen((DocumentSnapshot snapshot) async {
      if (!snapshot.exists) {
        return;
      }
      _thereIsAnError = snapshot.get('thereIsAnError');
      if (_thereIsAnError) {
        if (_letsGo) {
          if (mounted) {
            Navigator.of(context).pop();
          }
          showToastErrorMsg(
              'Something unexpected happened, please try again later.');
        }
      } else if (snapshot.get('audioRecordingUrl') != null) {
        if (_audioRecordingUrl == null) {
          widget.updateAudioRecordingUrl(_audioRecordingUrl);
          _audioRecordingUrl = snapshot.get('audioRecordingUrl');
          widget.audioPlayer.setUrl(_audioRecordingUrl).catchError((error) {
            print(error);
          });
        }
        if (_verses == null) {
          await _getTranscript();
        }
        _readyForDispatch = true;
        widget.updateDispatch(true);
        if (_letsGo) {
          if (!mounted) {
            return;
          }
          if (_verses == null || _verses.isEmpty) {
            _previewUnavailableMsg();
          } else {
            _startedSpeaking =
                ((_verses[0].get('mouth')['opens'] * 1000).toInt()) - 250;
            if (_startedSpeaking < 0) {
              _startedSpeaking = 0;
            }
            _finishedSpeaking =
                (_verses[_verses.length - 1].get('mouth')['closes'] * 1000)
                        .toInt() +
                    250;
            Navigator.of(context).pushReplacement(
                CupertinoPageRoute(builder: (BuildContext context) {
              return PreviewPage(
                finishedSpeaking: _finishedSpeaking,
                name: widget.caption.trim(),
                startedRecording: widget.startedRecording,
                startedSpeaking: _startedSpeaking,
                audioPlayer: widget.audioPlayer,
                caption: _name.trim(),
                shmoozeId: widget.shmoozeId,
                audioRecordingUrl: _audioRecordingUrl,
                verses: _verses,
              );
            }));
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
    _textEditingController.text = widget.name.trim();
    _verses = widget.verses;
    _audioRecordingUrl = widget.audioRecordingUrl;
    _letsGo = false;
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
                    onTap: _showErrorMsg,
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


