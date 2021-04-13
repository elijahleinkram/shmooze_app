import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shmooze/shmooze_namer.dart';
import 'dart:io';

class ShmoozeCaptioner extends StatefulWidget {
  final List<DocumentSnapshot> verses;
  final String audioRecordingUrl;
  final bool readyForDispatch;
  final String caption;
  final int startedRecording;
  final String inviteId;
  final List<int> senderSpeakingTimes;
  final File shmoozeFile;
  final List<int> receiverSpeakingTimes;
  final String senderUid;
  final void Function(String str) updateAudioRecordingUrl;
  final AudioPlayer audioPlayer;
  final void Function(List<DocumentSnapshot> verses) updateVerses;
  final void Function(bool readyForDispatch) updateDispatch;
  final void Function(String caption) updateCaption;
  final void Function(String caption) updateName;
  final String shmoozeId;
  final String name;

  ShmoozeCaptioner({
    @required this.audioPlayer,
    @required this.shmoozeId,
    @required this.updateName,
    @required this.name,
    @required this.updateCaption,
    @required this.caption,
    @required this.shmoozeFile,
    @required this.verses,
    @required this.updateDispatch,
    @required this.audioRecordingUrl,
    @required this.senderUid,
    @required this.readyForDispatch,
    @required this.startedRecording,
    @required this.receiverSpeakingTimes,
    @required this.senderSpeakingTimes,
    @required this.inviteId,
    @required this.updateAudioRecordingUrl,
    @required this.updateVerses,
  });

  @override
  _ShmoozeCaptionerState createState() => _ShmoozeCaptionerState();
}

class _ShmoozeCaptionerState extends State<ShmoozeCaptioner> {
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _textEditingController = TextEditingController();
  bool _isValid;
  String _audioRecordingUrl;
  List<DocumentSnapshot> _verses;
  bool _readyForDispatch;
  String _caption;

  String _name;

  void _updateVerses(List<DocumentSnapshot> verses) {
    _verses = verses;
    widget.updateVerses(verses);
  }

  void _updateDispatch(bool readyForDispatch) {
    _readyForDispatch = readyForDispatch;
    widget.updateDispatch(readyForDispatch);
  }

  void _updateAudioRecordingUrl(String audioRecordingUrl) {
    _audioRecordingUrl = audioRecordingUrl;
    widget.updateAudioRecordingUrl(audioRecordingUrl);
  }

  void _onNext() {
    Navigator.of(context)
        .push(CupertinoPageRoute(builder: (BuildContext context) {
      return ShmoozeNamer(
        name: _name,
        caption: _caption,
        updateName: (String name) {
          _name = name;
          widget.updateName(_name);
        },
        audioPlayer: widget.audioPlayer,
        audioRecordingUrl: _audioRecordingUrl,
        readyForDispatch: _readyForDispatch,
        receiverSpeakingTimes: widget.receiverSpeakingTimes,
        senderSpeakingTimes: widget.senderSpeakingTimes,
        shmoozeId: widget.shmoozeId,
        startedRecording: widget.startedRecording,
        updateAudioRecordingUrl: _updateAudioRecordingUrl,
        updateDispatch: _updateDispatch,
        updateVerses: _updateVerses,
        verses: _verses,
      );
    }));
  }

  void _textListener() {
    _caption = _textEditingController.text.trim();
    widget.updateCaption(_caption);
    if (_caption.length >= 3 && !_isValid) {
      _isValid = true;
      if (mounted) {
        setState(() {});
      }
    }
    if (_caption.length < 3 && _isValid) {
      _isValid = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _name = widget.name;
    _caption = widget.caption;
    _readyForDispatch = widget.readyForDispatch;
    _audioRecordingUrl = widget.audioRecordingUrl;
    _verses = widget.verses;
    _textEditingController.text = widget.caption.trim();
    _isValid = _textEditingController.text.trim().length >= 3;
    _textEditingController.addListener(_textListener);
  }

  @override
  void dispose() {
    super.dispose();
    _textEditingController.dispose();
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
              'Name must have at least three characters.',
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
          centerTitle: false,
          backgroundColor: Colors.transparent,
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
                  hintText: 'Name this shmooze...',
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
                          'Next',
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
