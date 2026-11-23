import 'package:flutter/material.dart';

/// Fixture screen (p26 d9_fire): three raw ListTile constructor calls.
Widget fixtureScreen() {
  return const Column(
    children: <Widget>[
      ListTile(title: Text('one')),
      ListTile(title: Text('two')),
      ListTile(title: Text('three')),
    ],
  );
}
