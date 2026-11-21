import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trainlog_app/providers/polyline_provider.dart';
import 'package:trainlog_app/providers/trips_provider.dart';

class TripsLoader extends StatefulWidget {
  final Widget Function(BuildContext) builder;

  const TripsLoader({super.key, required this.builder});

  @override
  State<TripsLoader> createState() => _TripsLoaderState();
}

class _TripsLoaderState extends State<TripsLoader> {
  Widget? _child;

  @override
  Widget build(BuildContext context) {
    return Consumer<TripsProvider>(
      builder: (context, trips, _) {
        // Build MyApp only once
        _child ??= widget.builder(context);

        final showLoader = trips.isLoading || trips.repository == null;

        if (!trips.isLoading && trips.repository != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            context.read<PolylineProvider>().ensureLoaded();
          });
        }

        return Stack(
          children: [
            // MyApp always stays mounted
            Positioned.fill(child: _child!),

            // Non-blocking loading cue while trips load: a thin bar under the
            // status bar, so the app (map included) stays visible and
            // scrollable instead of being covered by a full-screen loader.
            if (showLoader)
              Positioned(
                top: MediaQuery.of(context).padding.top,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    backgroundColor: Colors.transparent,
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.8),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
