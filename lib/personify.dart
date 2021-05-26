import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shmooze/constants.dart';
import 'package:shmooze/human.dart';
import 'package:shmooze/shmoozers.dart';

class Personify extends StatefulWidget {
  final VoidCallback refreshStageHeader;

  const Personify({
    @required this.refreshStageHeader,
  });

  @override
  _PersonifyState createState() => _PersonifyState();
}

class _PersonifyState extends State<Personify> {
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _textEditingController = TextEditingController();
  File _imageFile;
  bool _usernameIsValid;

  void _showErrorMsg() {
    showCupertinoDialog(
        barrierDismissible: true,
        context: context,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            content: Text(
              'Name must have at least three characters.',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 15.0 + 1 / 3,
                color: CupertinoColors.black,
              ),
            ),
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
      _focusNode.requestFocus();
    }).catchError((error) {
      print(error);
    });
  }

  Future<File> _getImage() async {
    final ImagePicker imagePicker = ImagePicker();
    final PickedFile pickedFile = await imagePicker
        .getImage(source: ImageSource.gallery)
        .catchError((error) {
      print(error);
    });
    if (pickedFile != null) {
      return File(pickedFile.path);
    }
    return null;
  }

  Future<String> _getPhotoUrl() async {
    final UploadTask _uploadTask = FirebaseStorage.instance
        .ref('users/${Human.uid}/photoUrl')
        .putFile(_imageFile, SettableMetadata(contentType: 'image/png'));
    await Future.value(_uploadTask).catchError((error) {
      print(error);
    });
    final String photoUrl =
        await _uploadTask.snapshot.ref.getDownloadURL().catchError((error) {
      print(error);
    });
    return photoUrl;
  }

  bool _hasImage() {
    return _imageFile != null;
  }

  void _createProfile(String displayName) async {
    Human.accountExists = true;
    Human.displayName = displayName;
    Human.currentUser
        .updateProfile(displayName: displayName)
        .then((_) => Human.currentUser.reload().catchError((error) {
              print(error);
            }))
        .catchError((error) {
      print(error);
    });
    String photoUrl;
    if (_imageFile != null) {
      photoUrl = await _getPhotoUrl();
    }
    Human.photoUrl = photoUrl;
    Human.currentUser
        .updateProfile(photoURL: photoUrl)
        .then((_) => Human.currentUser.reload().catchError((error) {
              print(error);
            }))
        .catchError((error) {
      print(error);
    });
    FirebaseFunctions.instance.httpsCallable('createProfile').call({
      'uid': Human.uid,
      'photoUrl': photoUrl,
      'displayName': displayName
    }).catchError((error) {
      print(error);
    });
  }

  void _onNext() {
    widget.refreshStageHeader();
    _focusNode.unfocus();
    _createProfile(_textEditingController.text.trim());
    Navigator.of(context)
        .pushReplacement(CupertinoPageRoute(builder: (BuildContext context) {
      return Shmoozers(
        backButtonIcon: Icons.arrow_back_rounded,
      );
    })).catchError((error) {
      print(error);
    });
  }

  void _onChangedText() {
    final String txt = _textEditingController.text.trim();
    if (txt.length < 3 && _usernameIsValid) {
      _usernameIsValid = false;
      if (mounted) {
        setState(() {});
      }
    }
    if (txt.length >= 3 && !_usernameIsValid) {
      _usernameIsValid = true;
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _deleteOrCapture(bool onlyCapture) async {
    if (_hasImage() && !onlyCapture) {
      _imageFile = null;
    } else {
      _imageFile = await _getImage() ?? _imageFile;
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _usernameIsValid = false;
    _textEditingController.addListener(_onChangedText);
  }

  @override
  void dispose() {
    super.dispose();
    _focusNode.dispose();
    _textEditingController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _focusNode.unfocus();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: CupertinoColors.white,
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
            onPressed: Navigator.of(context).pop,
          ),
        ),
        body: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width / 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                  height: MediaQuery.of(context).size.height * 0.025 * 3 / 4),
              Align(
                  alignment: Alignment.center,
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: () =>
                            !_hasImage() ? _deleteOrCapture(false) : null,
                        child: SizedBox(
                          height:
                              MediaQuery.of(context).size.width / (3 - 1 / 3),
                          width:
                              MediaQuery.of(context).size.width / (3 - 1 / 3),
                          child: ClipOval(
                            child: Stack(
                              children: [
                                Positioned.fill(
                                    child: Material(
                                  color: Color(kNorthStar).withOpacity(1 / 3),
                                  child: Center(
                                    child: Icon(
                                      Icons.person,
                                      color: CupertinoColors.systemGrey2,
                                      size: MediaQuery.of(context).size.width /
                                          10,
                                    ),
                                  ),
                                )),
                                !_hasImage()
                                    ? Container()
                                    : Positioned.fill(
                                        child: Image.file(
                                          _imageFile,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Align(
                            alignment: Alignment.bottomRight,
                            child: FloatingActionButton(
                              heroTag: 'image_upload',
                              backgroundColor: CupertinoColors.activeBlue,
                              child: Icon(
                                !_hasImage()
                                    ? Icons.camera_alt_rounded
                                    : MaterialCommunityIcons.delete,
                                color: Colors.white,
                                size: 18.0,
                              ),
                              onPressed: () => _deleteOrCapture(false),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              mini: true,
                              elevation: 1 / 3,
                            )),
                      )
                    ],
                  )),
              SizedBox(
                  height: MediaQuery.of(context).size.height * 0.025 * 0.875),
              TextField(
                focusNode: _focusNode,
                cursorColor: CupertinoColors.activeBlue,
                textAlign: TextAlign.left,
                buildCounter: (BuildContext context,
                        {int currentLength, int maxLength, bool isFocused}) =>
                    null,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: CupertinoColors.black,
                  fontSize: 20.0,
                  fontWeight: FontWeight.w400,
                ),
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                controller: _textEditingController,
                maxLength: kNameMaxLength,
                decoration: InputDecoration(
                  hintText: 'Enter your name here',
                  counterStyle: TextStyle(
                    fontFamily: 'Roboto',
                    color: CupertinoColors.systemGrey2,
                    fontWeight: FontWeight.w500,
                  ),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                    color: CupertinoColors.systemGrey2,
                  )),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                    color: CupertinoColors.activeBlue,
                  )),
                  hintStyle: TextStyle(
                      fontFamily: 'Roboto',
                      color: CupertinoColors.systemGrey2,
                      fontWeight: FontWeight.w400,
                      fontSize: 20.0),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.025 / 2),
              Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: _showErrorMsg,
                    child: TextButton(
                        onPressed: !_usernameIsValid ? null : _onNext,
                        child: Text(
                          'Next',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            color: CupertinoColors.activeBlue,
                            fontWeight: FontWeight.w500,
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
