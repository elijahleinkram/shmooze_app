import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Human {
  static String displayName;
  static String uid;
  static String photoUrl;
  static List<DocumentSnapshot> others;
  static bool accountExists;
  static User currentUser;
}
