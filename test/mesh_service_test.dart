import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3x_mesh/m3x_mesh.dart';
import 'package:ptk/engine.dart';
import 'package:ptk/services/mesh_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PtkMeshService registers 7 tools into M3xMeshClient', () {
    final engine = AppEngine();
    final service = PtkMeshService(engine);
    final client = M3xMeshClient(localAppId: 'ptk', enableSimulation: true);

    service.registerTools(client);

    final tools = client.localRegistry.tools;
    expect(tools.length, equals(7));

    final toolNames = tools.map((t) => t.name).toSet();
    expect(
      toolNames,
      containsAll([
        'ptk_list_statuspages',
        'ptk_get_statuspage_details',
        'ptk_list_incidents',
        'ptk_get_incident_details',
        'ptk_ping',
        'ptk_list_servers',
        'ptk_get_server_telemetry',
      ]),
    );
  });

  test('ptk_list_statuspages returns statuspages array', () async {
    final engine = AppEngine();
    final service = PtkMeshService(engine);
    final res = await service.listStatusPages({});
    expect(res['statuspages'], isA<List>());
    expect(res['count'], isA<int>());
  });

  test('ptk_list_servers returns servers array', () async {
    final engine = AppEngine();
    final service = PtkMeshService(engine);
    final res = await service.listServers({});
    expect(res['servers'], isA<List>());
    expect(res['count'], isA<int>());
  });

  test('assets/mesh_tools.json matches PtkMeshService declared tool schemas', () async {
    final raw = await rootBundle.loadString('assets/mesh_tools.json');
    final decoded = jsonDecode(raw) as List<dynamic>;
    final manifestTools = decoded
        .map((e) => M3xTool.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    final engine = AppEngine();
    final service = PtkMeshService(engine);
    final runtimeTools = service.tools;

    expect(manifestTools.length, equals(runtimeTools.length));
    for (var i = 0; i < runtimeTools.length; i++) {
      expect(manifestTools[i].name, equals(runtimeTools[i].name));
      expect(manifestTools[i].description, equals(runtimeTools[i].description));
      expect(manifestTools[i].parameters, equals(runtimeTools[i].parameters));
    }
  });
}
