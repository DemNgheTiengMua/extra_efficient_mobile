import 'dart:convert';
import 'dart:io';

/// Loads one recorded backend payload from `test/contract/fixtures/<name>.json`.
///
/// Fixtures are recorded from the running backend, never hand-shaped, so this
/// suite runs with no backend and catches a field rename as a real failure.
/// To pin a new endpoint, drop its recorded bytes in as `<name>.json` and add a
/// group that parses it in `contract_test.dart`.
dynamic loadFixture(String name) {
  final file = File('test/contract/fixtures/$name.json');
  return jsonDecode(file.readAsStringSync());
}
