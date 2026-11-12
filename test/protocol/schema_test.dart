import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'schema.dart';

void main() {
  test('every recorded roundResolved payload matches RoundResolvedDTO', () {
    final payloads = jsonDecode(File('test/fixtures/round_resolved.json').readAsStringSync()) as List;

    expect(payloads, isNotEmpty);
    for (var i = 0; i < payloads.length; i++) {
      expectValid('RoundResolvedDTO', payloads[i], reason: 'payload $i');
    }
  });

  test('every recorded start board matches GameStateDTO', () {
    final boards = jsonDecode(File('test/fixtures/round_start.json').readAsStringSync()) as List;

    expect(boards, isNotEmpty);
    for (var i = 0; i < boards.length; i++) {
      expectValid('GameStateDTO', boards[i], reason: 'board $i');
    }
  });

  test('the schema accepts a valid ErrorPayload and rejects the same one with an unknown field', () {
    final valid = {'code': 'INTERNAL', 'message': 'boom'};

    expectValid('ErrorPayload', valid);
    expect(schemaFor('ErrorPayload').validate({...valid, 'extra': 1}).isValid, isFalse);
  });
}
