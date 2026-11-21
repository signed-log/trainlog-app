import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:trainlog_app/l10n/app_localizations.dart';

/// Full-screen "loading data" view with the Lottie train animation.
///
/// Shown while the saved session is checked at startup, then as the overlay
/// of [TripsLoader] while trips load, so both steps look like one screen.
class DataLoadingScreen extends StatefulWidget {
  const DataLoadingScreen({super.key});

  @override
  State<DataLoadingScreen> createState() => _DataLoadingScreenState();
}

class _DataLoadingScreenState extends State<DataLoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..forward();
    _fade = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Container(
      color: theme.colorScheme.surfaceContainer,
      child: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  // Brand wordmark, consistent with the login/signup screens.
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 260,
                      maxHeight: 60,
                    ),
                    child: Image.asset(
                      'assets/logo/wide_cutted.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.dataLoading,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Lottie.asset('assets/animations/loading.json'),
                  ),
                  const SizedBox(height: 8),
                  // Indeterminate progress tied to the actual loading step.
                  const SizedBox(
                    width: 180,
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      borderRadius: BorderRadius.all(Radius.circular(2)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
