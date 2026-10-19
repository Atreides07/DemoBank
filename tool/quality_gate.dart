import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Syntax-aware policy, including numbers hidden behind local aliases/arithmetic.
List<String> inspectUiSource(String source, String path) {
  final unit = parseString(content: source, path: path).unit;
  final values = <String, Expression>{};
  unit.accept(_Variables(values));
  final issues = <String>[];
  unit.accept(_VisualPolicy(values, issues, path));
  if (source.contains('ignore_for_file:') || source.contains('// ignore:')) {
    issues.add('$path: feature UI cannot suppress architecture/design rules');
  }
  return issues;
}

/// User-facing words live in catalogues, so every language gets them: the
/// application ARB files, the design system's own few words, and the demo
/// backend's server texts. A Cyrillic string literal anywhere else is a
/// phrase only Russian readers would see.
const textCatalogues = [
  '/packages/app_localizations/lib/',
  '/packages/design_system/lib/src/localizations.dart',
  '/packages/network_simulation/lib/src/demo_texts.dart',
];

List<String> inspectUntranslatedText(String source, String path) {
  if (textCatalogues.any(path.contains)) return const [];
  final issues = <String>[];
  parseString(content: source, path: path).unit.accept(_Literals(issues, path));
  return issues;
}

final class _Literals extends RecursiveAstVisitor<void> {
  _Literals(this.issues, this.path);
  final List<String> issues;
  final String path;
  static final _cyrillic = RegExp('[\u0400-\u04ff]');

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    if (_cyrillic.hasMatch(node.value)) {
      issues.add(
        '$path:${node.offset}: untranslated text "${node.value}"; '
        'add it to a catalogue',
      );
    }
  }

  @override
  void visitInterpolationString(InterpolationString node) {
    if (_cyrillic.hasMatch(node.value)) {
      issues.add(
        '$path:${node.offset}: untranslated text "${node.value}"; '
        'add it to a catalogue',
      );
    }
  }
}

final class _Variables extends RecursiveAstVisitor<void> {
  _Variables(this.values);
  final Map<String, Expression> values;
  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    if (node.initializer != null) values[node.name.lexeme] = node.initializer!;
    super.visitVariableDeclaration(node);
  }
}

final class _VisualPolicy extends RecursiveAstVisitor<void> {
  _VisualPolicy(this.values, this.issues, this.path);
  final Map<String, Expression> values;
  final List<String> issues;
  final String path;
  static const visualNames = {
    'width',
    'height',
    'padding',
    'margin',
    'spacing',
    'runSpacing',
    'fontSize',
    'iconSize',
    'radius',
    'borderRadius',
    'strokeWidth',
    'elevation',
    'letterSpacing',
    'top',
    'bottom',
    'left',
    'right',
    'duration',
    'reverseDuration',
    'minHeight',
    'maxHeight',
    'minWidth',
    'maxWidth',
    'cacheExtent',
    'scrollCacheExtent',
    'itemExtent',
  };
  static const forbidden = {
    'Padding',
    'EdgeInsets',
    'EdgeInsetsDirectional',
    'SizedBox',
    'Size',
    'BoxConstraints',
    'BorderRadius',
    'Radius',
    'TextStyle',
    'Color',
    'BoxShadow',
    'BorderSide',
    'ThemeExtension',
    'Tween',
    'Transform',
    'Offset',
    'ScrollCacheExtent',
  };
  bool numeric(Expression expression, [Set<String> visited = const {}]) {
    if (expression is IntegerLiteral || expression is DoubleLiteral) {
      return true;
    }
    if (expression is SimpleIdentifier) {
      final name = expression.name;
      if (visited.contains(name) || !values.containsKey(name)) return false;
      return numeric(values[name]!, {...visited, name});
    }
    if (expression is InstanceCreationExpression) {
      return expression.argumentList.arguments.any(
        (argument) => numeric(argument, visited),
      );
    }
    for (final child in expression.childEntities.whereType<Expression>()) {
      if (numeric(child, visited)) return true;
    }
    return false;
  }

  void report(AstNode node, String message) =>
      issues.add('$path:${node.offset}: $message');
  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final namedType = node.constructorName.type;
    // Before resolution, a named constructor can be parsed as prefix.Type.
    final candidates = {
      namedType.name.lexeme,
      ?namedType.importPrefix?.name.lexeme,
    };
    for (final type in candidates.intersection(forbidden)) {
      report(
        node,
        '$type belongs inside design_system; select a semantic component',
      );
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // A parse-only AST represents an implicit constructor as a method call.
    // Both Padding(...) and EdgeInsets.all(...) must be checked before name
    // resolution, including calls qualified by an import prefix.
    final candidates = {
      node.methodName.name,
      if (node.target is SimpleIdentifier)
        (node.target! as SimpleIdentifier).name,
      if (node.target is PrefixedIdentifier)
        (node.target! as PrefixedIdentifier).identifier.name,
    };
    for (final type in candidates.intersection(forbidden)) {
      report(
        node,
        '$type belongs inside design_system; select a semantic component',
      );
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if ({'Colors', 'Icons', 'DsTokens'}.contains(node.prefix.name)) {
      report(
        node,
        'raw visual token ${node.prefix.name} belongs inside design_system',
      );
    }
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitNamedExpression(NamedExpression node) {
    final name = node.name.label.name;
    if (visualNames.contains(name) && numeric(node.expression)) {
      report(
        node,
        'numeric visual parameter "$name" must be owned by design_system',
      );
    }
    super.visitNamedExpression(node);
  }
}

bool isUiFile(String path, String source) =>
    path.endsWith('_view.dart') ||
    path.contains('/apps/') ||
    path.contains('/bank_experience/lib/') ||
    path.contains('/app_foundation/lib/') ||
    source.contains('extends StatelessWidget') ||
    source.contains('extends StatefulWidget');

Future<void> main() async {
  final root = Directory.current;
  final failures = <String>[];
  final packageDirs = <String, Directory>{};
  final deps = <String, Set<String>>{};
  for (final folder in ['apps', 'packages', 'services']) {
    for (final entity in Directory(
      '${root.path}/$folder',
    ).listSync(recursive: true, followLinks: false)) {
      if (entity is! File ||
          !entity.path.endsWith('/pubspec.yaml') ||
          _excluded(entity.path)) {
        continue;
      }
      final source = entity.readAsStringSync();
      final name = RegExp(
        r'^name:\s*(\S+)',
        multiLine: true,
      ).firstMatch(source)!.group(1)!;
      packageDirs[name] = entity.parent;
      final section = source.split(
        RegExp(r'^dependencies:\s*$', multiLine: true),
      );
      deps[name] = section.length < 2
          ? {}
          : RegExp(r'^  ([a-zA-Z_]\w*):', multiLine: true)
                .allMatches(
                  section[1].split(RegExp(r'^\w', multiLine: true)).first,
                )
                .map((m) => m.group(1)!)
                .toSet();
    }
  }
  final stack = <String>[];
  final done = <String>{};
  void visit(String name) {
    if (stack.contains(name)) {
      failures.add('dependency cycle: ${[...stack, name].join(' → ')}');
      return;
    }
    if (done.contains(name)) return;
    stack.add(name);
    for (final next in deps[name] ?? <String>{}) {
      if (packageDirs.containsKey(next)) visit(next);
    }
    stack.removeLast();
    done.add(name);
  }

  for (final name in packageDirs.keys) {
    visit(name);
  }
  final fineDeps = <String>{};
  void collect(String name) {
    for (final next in deps[name] ?? <String>{}) {
      if (fineDeps.add(next)) collect(next);
    }
  }

  collect('fines_app');
  final forbiddenFine = {
    'accounts',
    'transactions',
    'spending_analytics',
    'utilities',
    'mobile',
    'cinema',
    'bank_experience',
  };
  for (final name in fineDeps.intersection(forbiddenFine)) {
    failures.add('fines_app transitively imports $name');
  }
  final featurePackages = {
    for (final entry in packageDirs.entries)
      if (entry.value.path.contains('/packages/features/')) entry.key,
  };
  var uiFiles = 0;
  for (final item in packageDirs.entries) {
    final lib = Directory('${item.value.path}/lib');
    if (!lib.existsSync()) continue;
    for (final entity in lib.listSync(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      failures.addAll(inspectUntranslatedText(source, entity.path));
      final ast = parseString(content: source, path: entity.path).unit;
      for (final directive in ast.directives.whereType<UriBasedDirective>()) {
        final uri = directive.uri.stringValue ?? '';
        if (uri.startsWith('package:')) {
          final parts = uri.substring('package:'.length).split('/');
          if (featurePackages.contains(item.key) &&
              featurePackages.contains(parts.first) &&
              parts.first != item.key) {
            failures.add(
              '${entity.path}: feature imports neighboring feature $uri',
            );
          }
          if (item.key == 'app_foundation' &&
              (featurePackages.contains(parts.first) ||
                  parts.first == 'bank_experience')) {
            failures.add(
              '${entity.path}: infrastructure root imports bank feature $uri',
            );
          }
          if (item.key == 'design_system' &&
              packageDirs.containsKey(parts.first) &&
              parts.first != 'design_system') {
            failures.add(
              '${entity.path}: design_system imports business/infrastructure $uri',
            );
          }
          if (parts.first != item.key && parts.contains('src')) {
            failures.add('${entity.path}: imports private API $uri');
          }
          if ({'bank_core', 'payment_domain'}.contains(item.key) &&
              {
                'flutter',
                'dio',
                'drift',
                'network_client',
                'design_system',
                'local_storage',
                'ledger_data',
                'network_simulation',
              }.contains(parts.first)) {
            failures.add('${entity.path}: domain depends on $uri');
          }
        }
      }
      if (item.key != 'design_system' && isUiFile(entity.path, source)) {
        uiFiles++;
        failures.addAll(inspectUiSource(source, entity.path));
      }
    }
  }
  if (failures.isNotEmpty) {
    stderr.writeln(failures.join('\n'));
    exitCode = 1;
    return;
  }
  stdout.writeln(
    'Architecture/design gate passed: ${packageDirs.length} packages, $uiFiles UI files; acyclic imports, domain isolation, independent fines, semantic geometry, translated text.',
  );
}

bool _excluded(String path) =>
    ['/.dart_tool/', '/build/', '/.gradle/'].any(path.contains);
