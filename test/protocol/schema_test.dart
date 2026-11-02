import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema/json_schema.dart';

/// The backend's protocol schema, copied by `tool/sync_protocol.sh`.
final _root = jsonDecode(File('test/protocol/protocol.schema.json').readAsStringSync()) as Map<String, dynamic>;

/// A validator for one named definition of the schema (a DTO, e.g. `RoundResolvedDTO`).
JsonSchema schemaFor(String definition) => JsonSchema.create({..._root, r'$ref': '#/definitions/$definition'});

void main() {
  test('every recorded roundResolved payload matches RoundResolvedDTO', () {
    final payloads = jsonDecode(File('test/fixtures/round_resolved.json').readAsStringSync()) as List;
    final schema = schemaFor('RoundResolvedDTO');

    expect(payloads, isNotEmpty);
    for (var i = 0; i < payloads.length; i++) {
      final result = schema.validate(payloads[i]);
      expect(result.isValid, isTrue, reason: 'payload $i: ${result.errors.join('; ')}');
    }
  });

  test('the schema rejects a payload with an unknown field', () {
    final bad = {'message': 'boom', 'extra': 1};

    expect(schemaFor('ErrorPayload').validate(bad).isValid, isFalse);
  });
}
