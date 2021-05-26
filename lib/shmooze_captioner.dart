// import 'package:audioplayers/audioplayers.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
// import 'package:shmooze/shmooze_namer.dart';
//
// import 'constants.dart';
//
// class ShmoozeCaptioner extends StatefulWidget {
//   final List<DocumentSnapshot> verses;
//   final String audioRecordingUrl;
//   final bool readyForDispatch;
//   final String caption;
//   final String shmoozeId;
//   final String name;
//   final Map<String, Map<String, String>> shmoozeSnapshot;
//   final int startedRecording;
//   final void Function(
//       {String name,
//       List<DocumentSnapshot> verses,
//       String audioRecordingUrl,
//       bool readyForDispatch,
//       int startedRecording,
//       String caption}) updateVariables;
//
//   ShmoozeCaptioner({
//     @required this.updateVariables,
//     @required this.shmoozeSnapshot,
//     @required this.shmoozeId,
//     @required this.startedRecording,
//     @required this.name,
//     @required this.caption,
//     @required this.verses,
//     @required this.audioRecordingUrl,
//     @required this.readyForDispatch,
//   });
//
//   @override
//   _ShmoozeCaptionerState createState() => _ShmoozeCaptionerState();
// }
//
// class _ShmoozeCaptionerState extends State<ShmoozeCaptioner> {
//   final FocusNode _focusNode = FocusNode();
//   final TextEditingController _textEditingController = TextEditingController();
//   bool _isValid;
//   List<DocumentSnapshot> _verses;
//   bool _readyForDispatch;
//   String _caption;
//   String _name;
//   String _audioRecordingUrl;
//   int _startedRecording;
//   AudioPlayer _audioPlayer;
//
//   void _updateVariables(
//       {String name,
//       List<DocumentSnapshot> verses,
//       String audioRecordingUrl,
//       bool readyForDispatch,
//       int startedRecording,
//       String caption}) {
//     _name = name ?? _name;
//     _verses = verses ?? _verses;
//     _audioRecordingUrl = audioRecordingUrl ?? _audioRecordingUrl;
//     _readyForDispatch = readyForDispatch ?? _readyForDispatch;
//     _startedRecording = startedRecording ?? _startedRecording;
//     _caption = caption ?? _caption;
//     widget.updateVariables(
//         name: name,
//         verses: verses,
//         audioRecordingUrl: audioRecordingUrl,
//         readyForDispatch: readyForDispatch,
//         startedRecording: startedRecording,
//         caption: caption);
//   }
//
//   void _onNext() {
//     Navigator.of(context)
//         .push(CupertinoPageRoute(builder: (BuildContext context) {
//       return ShmoozeNamer(
//         shmoozeSnapshot: widget.shmoozeSnapshot,
//         shmoozeId: widget.shmoozeId,
//         audioPlayer: _audioPlayer,
//         updateVariables: _updateVariables,
//         startedRecording: _startedRecording,
//         name: _name,
//         caption: _caption,
//         audioRecordingUrl: _audioRecordingUrl,
//         readyForDispatch: _readyForDispatch,
//         verses: _verses,
//       );
//     }));
//   }
//
//   void _textListener() {
//     _updateVariables(caption: _textEditingController.text.trim());
//     if (_caption.length >= 12 && !_isValid) {
//       _isValid = true;
//       if (mounted) {
//         setState(() {});
//       }
//     }
//     if (_caption.length < 12 && _isValid) {
//       _isValid = false;
//       if (mounted) {
//         setState(() {});
//       }
//     }
//   }
//
//   @override
//   void initState() {
//     super.initState();
//     _audioPlayer = AudioPlayer(playerId: widget.shmoozeId)
//       ..setReleaseMode(ReleaseMode.LOOP).catchError((error) {
//         print(error);
//       });
//     ;
//     _audioRecordingUrl = widget.audioRecordingUrl;
//     _startedRecording = widget.startedRecording;
//     _name = widget.name;
//     _caption = widget.caption;
//     _readyForDispatch = widget.readyForDispatch;
//     _verses = widget.verses;
//     _textEditingController.text = widget.caption;
//     _isValid = _textEditingController.text.length >= 3;
//     _textEditingController.addListener(_textListener);
//   }
//
//   @override
//   void dispose() {
//     super.dispose();
//     _focusNode.dispose();
//     _audioPlayer?.dispose()?.catchError((error) {
//       print(error);
//     });
//     _textEditingController.dispose();
//   }
//
//   // void _showErrorMsg() {
//   //   showCupertinoDialog(
//   //       barrierDismissible: true,
//   //       context: context,
//   //       builder: (BuildContext context) {
//   //         return CupertinoAlertDialog(
//   //           content: Text(
//   //             'Description must have at least 12 characters.',
//   //             style: TextStyle(fontFamily: 'Roboto',
//   //               fontSize: 15.0 + 1 / 3,
//   //               color: CupertinoColors.black,
//   //             ),
//   //           ),
//   //           actions: [
//   //             TextButton(
//   //               child: Text(
//   //                 'Okay',
//   //                 style: TextStyle(fontFamily: 'Roboto',
//   //                   color: CupertinoColors.activeBlue,
//   //                   fontWeight: FontWeight.w500,
//   //                 ),
//   //               ),
//   //               onPressed: () {
//   //                 Navigator.of(context).pop();
//   //               },
//   //             )
//   //           ],
//   //         );
//   //       }).then((_) {
//   //     _focusNode.requestFocus();
//   //   }).catchError((error) {
//   //     print(error);
//   //   });
//   // }
//
//   Future<bool> _areYouSure() {
//     return showCupertinoDialog(
//         context: context,
//         barrierDismissible: true,
//         builder: (BuildContext context) {
//           return CupertinoAlertDialog(
//             content: Text('Are you sure you want to leave the flow?',
//                 style: TextStyle(
//                   fontFamily: 'Roboto',
//                   fontSize: 15.0 + 1 / 3,
//                   color: CupertinoColors.black,
//                 )),
//             actions: [
//               TextButton(
//                 child: Text(
//                   'No',
//                   style: TextStyle(
//                     fontFamily: 'Roboto',
//                     color: CupertinoColors.systemGrey,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//                 onPressed: () {
//                   Navigator.of(context).pop(false);
//                 },
//               ),
//               TextButton(
//                 child: Text(
//                   'Yes',
//                   style: TextStyle(
//                     fontFamily: 'Roboto',
//                     color: CupertinoColors.activeBlue,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//                 onPressed: () {
//                   Navigator.of(context).pop(true);
//                 },
//               ),
//             ],
//           );
//         });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return WillPopScope(
//       onWillPop: () async => (await _areYouSure() ?? false),
//       child: GestureDetector(
//         onTap: () {
//           _focusNode.unfocus();
//         },
//         child: Scaffold(
//           backgroundColor: CupertinoColors.white,
//           resizeToAvoidBottomInset: false,
//           appBar: AppBar(
//             automaticallyImplyLeading: false,
//             elevation: 0.0,
//             centerTitle: false,
//             backgroundColor: Colors.transparent,
//             title: IconButton(
//               icon: Icon(
//                 Icons.arrow_back_rounded,
//                 color: CupertinoColors.black,
//               ),
//               onPressed: () async => (await _areYouSure() ?? false)
//                   ? Navigator.of(context).pop()
//                   : null,
//             ),
//           ),
//           body: Padding(
//             padding: EdgeInsets.symmetric(
//                 horizontal: MediaQuery.of(context).size.width / 10),
//             child: Column(
//               children: [
//                 SizedBox(
//                     height: MediaQuery.of(context).size.height *
//                         0.025 *
//                         (1 + 1 / 3)),
//                 TextField(
//                   focusNode: _focusNode,
//                   autofocus: true,
//                   maxLines: null,
//                   cursorColor: CupertinoColors.activeBlue,
//                   textAlign: TextAlign.left,
//                   buildCounter: (BuildContext context,
//                           {int currentLength, int maxLength, bool isFocused}) =>
//                       null,
//                   maxLength: kShmoozeDescriptionMaxLength,
//                   style: TextStyle(
//                     fontFamily: 'Roboto',
//                     color: CupertinoColors.black,
//                     fontSize: 20.0,
//                     fontWeight: FontWeight.w400,
//                   ),
//                   textCapitalization: TextCapitalization.sentences,
//                   controller: _textEditingController,
//                   decoration: InputDecoration.collapsed(
//                     hintText: 'Describe the flow...',
//                     hintStyle: TextStyle(
//                         fontFamily: 'Roboto',
//                         color: CupertinoColors.systemGrey2,
//                         fontWeight: FontWeight.w400,
//                         fontSize: 20.0),
//                   ),
//                 ),
//                 SizedBox(
//                     height: MediaQuery.of(context).size.height *
//                         0.025 *
//                         (1 + 1 / 3)),
//                 Align(
//                   alignment: Alignment.centerRight,
//                   child: TextButton(
//                       onPressed: _onNext,
//                       // !_isValid ? null :
//                       child: Text(
//                         'Next',
//                         style: TextStyle(
//                           fontFamily: 'Roboto',
//                           color: CupertinoColors.activeBlue,
//                           fontWeight: FontWeight.w500,
//                           fontSize: 14.0,
//                         ),
//                       )),
//                 )
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
