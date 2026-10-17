import 'dart:io';

import 'package:demo_api/demo_api.dart';
import 'package:network_simulation/network_simulation.dart';

Future<void> main(List<String> arguments) async {
  final options = <String, String>{};
  for (var index = 0; index < arguments.length; index += 2) {
    if (!arguments[index].startsWith('--') || index + 1 == arguments.length) {
      stderr.writeln('Expected --name value arguments');
      exitCode = 64;
      return;
    }
    options[arguments[index].substring(2)] = arguments[index + 1];
  }
  final profile = switch (options['profile'] ?? 'normal') {
    'normal' => NetworkProfile.normal,
    'slow' => NetworkProfile.slow,
    'unstable' => NetworkProfile.unstable,
    'offline' => NetworkProfile.offline,
    final unknown => throw ArgumentError.value(unknown, 'profile'),
  };
  SecurityContext? context;
  final certificate = options['certificate'];
  final privateKey = options['private-key'];
  if ((certificate == null) != (privateKey == null)) {
    throw ArgumentError('Both --certificate and --private-key are required');
  }
  if (certificate != null && privateKey != null) {
    context = SecurityContext()
      ..useCertificateChain(certificate)
      ..usePrivateKey(privateKey);
  }
  final transport = SimulatedTransport(
    profile: profile,
    seed: int.parse(options['seed'] ?? '42'),
  );
  final server = await startDemoServer(
    host: options['host'] ?? '127.0.0.1',
    port: int.parse(options['port'] ?? '8080'),
    transport: transport,
    securityContext: context,
  );
  stdout.writeln(
    'Demo API: ${context == null ? 'http' : 'https'}://'
    '${server.address.address}:${server.port} '
    '(profile=${profile.name}, seed=${transport.seed})',
  );
  ProcessSignal.sigint.watch().listen((_) async {
    await server.close(force: true);
    exit(0);
  });
  ProcessSignal.sigterm.watch().listen((_) async {
    await server.close(force: true);
    exit(0);
  });
}
