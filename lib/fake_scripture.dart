import 'package:flutter/material.dart';
import 'fake_verse.dart';

class FakeScripture extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverList(
          delegate:
              SliverChildBuilderDelegate((BuildContext context, int index) {
            return FakeVerse(index: index, length: 100);
          }, childCount: 100),
        ),
      ],
    );
  }
}
