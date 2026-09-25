import 'dart:convert';
import 'dart:io';

/// Raw text of a JSON fixture in test/features/food/fixtures.
String fixtureText(String name) =>
    File('test/features/food/fixtures/$name').readAsStringSync();

Map<String, dynamic> fixtureJson(String name) =>
    jsonDecode(fixtureText(name)) as Map<String, dynamic>;
