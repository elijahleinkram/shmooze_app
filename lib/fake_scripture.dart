import 'package:flutter/material.dart';
import 'fake_verse.dart';

class FakeScripture extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverList(
          delegate: SliverChildListDelegate([
            SizedBox(
                height:
                    MediaQuery.of(context).size.width / (12.5 * (3 + 1 / 3))),
          ]),
        ),
        SliverList(
          delegate:
              SliverChildBuilderDelegate((BuildContext context, int index) {
            return FakeVerse();
          }, childCount: 100),
        ),
        SliverList(
          delegate: SliverChildListDelegate([
            SizedBox(
              height: MediaQuery.of(context).size.width / (12.5 * (3 + 1 / 3)),
            )
          ]),
        ),
      ],
    );
  }
}
