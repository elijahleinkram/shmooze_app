import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shmooze/scripture.dart';
import 'home.dart';

class PreviewPage extends StatefulWidget {
  final String caption;
  final String name;
  final String shmoozeId;
  final String audioRecordingUrl;
  final List<DocumentSnapshot> verses;
  final AudioPlayer audioPlayer;
  final dynamic startedSpeaking;
  final dynamic finishedSpeaking;
  final String senderUid;
  final String receiverUid;
  final String senderDisplayName;
  final String senderPhotoUrl;
  final String receiverDisplayName;
  final String receiverPhotoUrl;

  PreviewPage(
      {@required this.caption,
      @required this.senderDisplayName,
      @required this.senderPhotoUrl,
      @required this.receiverDisplayName,
      @required this.receiverPhotoUrl,
      @required this.shmoozeId,
      @required this.senderUid,
      @required this.receiverUid,
      @required this.finishedSpeaking,
      @required this.name,
      @required this.audioPlayer,
      @required this.startedSpeaking,
      @required this.verses,
      @required this.audioRecordingUrl});

  @override
  _PreviewPageState createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage> with WidgetsBindingObserver {
  final dynamic _verses = [];

  Future<void> _uploadShmooze() async {
    await FirebaseFunctions.instance.httpsCallable('uploadShmooze').call({
      'shmoozeId': widget.shmoozeId,
      'caption': widget.caption,
      'name': widget.name,
    }).catchError((error) {
      print(error);
    });
  }

  void _navigateToHome() {
    Navigator.of(context).pushAndRemoveUntil(
        CupertinoPageRoute(builder: (BuildContext context) {
      return Home(
        uploadShmooze: _uploadShmooze,
      );
    }), (route) => false);
  }

  ValueKey<dynamic> _key;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      widget.audioPlayer.resume().catchError((error) {
        print(error);
      });
    } else {
      widget.audioPlayer.pause().catchError((error) {
        print(error);
      });
    }
  }

  void _playAudio() {
    widget.audioPlayer
        .play(widget.audioRecordingUrl,
            stayAwake: true,
            volume: 1.0,
            position: Duration(
              milliseconds: widget.startedSpeaking,
            ))
        .catchError((error) {
      widget.audioPlayer.resume().catchError((error) {
        print(error);
      });
    });
  }

  void _convertVersesToDynamic() {
    for (int i = 0; i < widget.verses.length; i++) {
      final DocumentSnapshot verse = widget.verses[i];
      final bool isSender = verse.get('authorUid') == widget.senderUid;
      String displayName;
      String photoUrl;
      if (isSender) {
        displayName = widget.senderDisplayName;
        photoUrl = widget.senderPhotoUrl;
      } else {
        displayName = widget.receiverDisplayName;
        photoUrl = widget.receiverPhotoUrl;
      }
      _verses.add({
        'mouth': {
          'opens': (verse.get('mouth.opens')).toInt(),
          'closes': (verse.get('mouth.closes')).toInt(),
        },
        'displayName': displayName,
        'photoUrl': photoUrl,
        'quote': verse.get('quote'),
        'verseId': verse.id,
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _convertVersesToDynamic();
    _key = ValueKey(widget.shmoozeId);
    _playAudio();
  }

  @override
  void dispose() {
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
    widget.audioPlayer.pause().catchError((error) {
      print(error);
    });
    widget.audioPlayer
        .seek(Duration(milliseconds: widget.startedSpeaking))
        .catchError((error) {
      print(error);
    });
    widget.audioPlayer.setVolume(1.0).catchError((error) {
      print(error);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: SafeArea(
        child: ElevatedButton(
          style: TextButton.styleFrom(
            backgroundColor: CupertinoColors.activeBlue,
            padding: EdgeInsets.symmetric(horizontal: 18.0, vertical: 11.0),
            shape: StadiumBorder(),
          ),
          onPressed: _navigateToHome,
          child: Text(
            'Share with audience',
            style: GoogleFonts.roboto(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
      appBar: AppBar(
          automaticallyImplyLeading: false,
          elevation: 0.0,
          backgroundColor: Colors.transparent,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: CupertinoColors.black,
                  size: 20.0,
                ),
                onPressed: Navigator.of(context).pop,
              ),
              Text(
                'Preview shmooze',
                style: GoogleFonts.roboto(
                  color: CupertinoColors.black,
                  fontSize: 17.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.transparent,
                  size: 20.0,
                ),
                onPressed: null,
              ),
            ],
          )),
      body: Scripture(
        startedSpeaking: widget.startedSpeaking,
        finishedSpeaking: widget.finishedSpeaking,
        caption: widget.caption.endsWith('.') ||
                widget.caption.endsWith('?') ||
                widget.caption.endsWith('!')
            ? ' ' + widget.caption
            : ' ' + widget.caption + '.',
        name: widget.name.endsWith('.') ||
                widget.name.endsWith('?') ||
                widget.name.endsWith('!')
            ? widget.name
            : widget.name + ',',
        getCurrentPage: () {
          return 0;
        },
        index: 0,
        onRefresh: null,
        refreshToken: '-1',
        isPreview: true,
        key: _key,
        verses: _verses,
        audioPlayer: widget.audioPlayer,
        audioRecordingUrl: widget.audioRecordingUrl,
      ),
    );
  }
}
