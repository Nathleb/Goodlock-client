import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema/json_schema.dart';

/// The backend's protocol schema, copied by `tool/sync_protocol.sh`.
final _root = jsonDecode(
  File('test/protocol/protocol.schema.json').readAsStringSync(),
) as Map<String, dynamic>;

/// A validator for one named definition of the schema (a DTO, e.g. `RoundResolvedDTO`).
JsonSchema schemaFor(String definition) =>
    JsonSchema.create({..._root, r'$ref': '#/definitions/$definition'});

/// Fails with the schema errors when [payload] is not a valid [definition].
void expectValid(String definition, Object? payload, {String? reason}) {
  final result = schemaFor(definition).validate(payload);
  expect(
    result.isValid,
    isTrue,
    reason: '${reason ?? definition}: ${result.errors.join('; ')}',
  );
}
