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

  test('the schema rejects a payload with an unknown field', () {
    final bad = {'message': 'boom', 'extra': 1};

    expect(schemaFor('ErrorPayload').validate(bad).isValid, isFalse);
  });
}
