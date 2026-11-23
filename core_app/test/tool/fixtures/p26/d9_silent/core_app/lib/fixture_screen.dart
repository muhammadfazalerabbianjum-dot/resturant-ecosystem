import 'package:flutter/material.dart';

/// Fixture screen (p26 d9_silent): one raw ListTile constructor call, plus a
/// comment that mentions `ListTile(` and must never be counted as a site.
Widget fixtureScreen() {
  // pre-sweep worlds had raw ListTile( usage in comments too
  return const Column(children: <Widget>[ListTile(title: Text('one'))]);
}
