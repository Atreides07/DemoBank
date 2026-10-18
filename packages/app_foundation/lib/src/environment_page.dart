import 'dart:async';

import 'package:app_localizations/app_localizations.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:network_simulation/network_simulation.dart';

import '../app_foundation.dart';

class EnvironmentPage extends StatelessWidget {
  const EnvironmentPage({super.key, required this.environment});
  final AppEnvironment environment;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: environment,
    builder: (context, _) {
      final l10n = context.l10n;
      return DsPage(
        title: l10n.envTitle,
        subtitle: environmentSourceLabel(l10n, environment),
        children: [
          LanguageSection(environment: environment),
          DsSection(
            title: l10n.envNetworkTitle,
            subtitle: l10n.envNetworkSubtitle,
            child: DsFlow(
              children: [
                for (final profile in [
                  NetworkProfile.normal,
                  NetworkProfile.slow,
                  NetworkProfile.unstable,
                  NetworkProfile.offline,
                ])
                  DsChoice(
                    label: l10n.envNetworkProfile(profile.name),
                    selected: environment.simulation.profile == profile,
                    onSelected: environment.http
                        ? null
                        : (_) => environment.setProfile(profile),
                  ),
              ],
            ),
          ),
          DsCard(
            child: DsColumn(
              children: [
                DsText(l10n.envAppearance, style: DsTextStyle.title),
                DsCheckbox(
                  label: l10n.envDarkTheme,
                  value: environment.theme == ThemeMode.dark,
                  onChanged: environment.setTheme,
                ),
                DsCheckbox(
                  label: l10n.envReduceMotion,
                  value: environment.reduceMotion,
                  onChanged: environment.setReducedMotion,
                ),
                DsCheckbox(
                  label: l10n.envCompareHistory,
                  value: environment.motionComparison,
                  onChanged: environment.setComparison,
                ),
              ],
            ),
          ),
          DsSection(
            title: l10n.envCacheTitle,
            subtitle: switch (environment.cacheNotice) {
              CacheNotice.automatic => l10n.envCacheAutomatic,
              CacheNotice.cleared => l10n.envCacheCleared,
              CacheNotice.clearFailed => l10n.envCacheClearFailed,
              CacheNotice.expired => l10n.envCacheExpired,
              CacheNotice.expireFailed => l10n.envCacheExpireFailed,
            },
            child: DsFlow(
              children: [
                DsButton(
                  label: l10n.envCacheClear,
                  onPressed: () => unawaited(environment.clearCache()),
                ),
                DsButton(
                  label: l10n.envCacheExpire,
                  variant: DsButtonVariant.secondary,
                  onPressed: () => unawaited(environment.expireCache()),
                ),
              ],
            ),
          ),
          DsCard(
            tone: DsCardTone.subtle,
            child: DsColumn(
              children: [
                DsText(l10n.envTestEvents, style: DsTextStyle.title),
                DsText(l10n.envTestEventsHint),
                DsButton(
                  label: l10n.envAddActivity,
                  icon: DsIcons.add,
                  onPressed: environment.activityInProgress
                      ? null
                      : () => unawaited(environment.addActivity()),
                ),
                if (environment.activityOutcome case final outcome?)
                  DsText(switch (outcome) {
                    ActivityOutcome.added => l10n.envActivityAdded,
                    ActivityOutcome.failed =>
                      switch (environment.activityFailure) {
                        final failure? => l10n.apiFailure(failure),
                        null => l10n.envActivityFailed,
                      },
                  }),
              ],
            ),
          ),
          DsSection(
            title: l10n.envDiagnostics,
            subtitle: l10n.envDiagnosticsSubtitle,
            child: DsColumn(
              children: [
                DsText(
                  l10n.envEventsCount(
                    environment.apiEvents.length,
                    l10n.envNetworkProfile(environment.simulation.profile.name),
                  ),
                ),
                DsButton(
                  label: l10n.envShowLog,
                  variant: DsButtonVariant.quiet,
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(context.l10n.envLogTitle),
                      content: SingleChildScrollView(
                        child: SelectableText(environment.diagnosticJson()),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(context.l10n.envClose),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          DsText(l10n.envHttpHint),
        ],
      );
    },
  );
}

/// The data source in the reader's language.
String environmentSourceLabel(
  AppLocalizations l10n,
  AppEnvironment environment,
) => environment.http
    ? l10n.envSourceHttp
    : l10n.envSourceSimulation(environment.simulation.transport.seed);
