import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../theme/signage_theme.dart';

/// A square-cornered placard panel with a 2px Ink frame, zero shadow,
/// optional uppercase condensed header strip, and optional wall-grey footer.
class PlacardPanel extends StatelessWidget {
  const PlacardPanel({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.footer,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor = SignageColors.paper,
  });

  final Widget child;
  final String? title;
  final Widget? trailing;
  final Widget? footer;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: SignageColors.ink, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            DecoratedBox(
              decoration: const BoxDecoration(
                color: SignageColors.paper,
                border: Border(
                  bottom: BorderSide(color: SignageColors.ink, width: 2),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title!.toUpperCase(),
                        style: SignageTypography.label(fontSize: 13),
                      ),
                    ),
                    ?trailing,
                  ],
                ),
              ),
            ),
          Padding(
            padding: padding,
            child: child,
          ),
          if (footer != null)
            DecoratedBox(
              decoration: const BoxDecoration(
                color: SignageColors.wall,
                border: Border(
                  top: BorderSide(color: SignageColors.lineSoft, width: 1),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: footer!,
              ),
            ),
        ],
      ),
    );
  }
}

enum PlacardButtonVariant { primary, secondary, destructive, ink }

/// Square-cornered signage button with 2px keyline and condensed uppercase label.
class PlacardButton extends StatelessWidget {
  const PlacardButton({
    super.key,
    required this.label,
    required this.onPress,
    this.variant = PlacardButtonVariant.primary,
    this.isLoading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPress;
  final PlacardButtonVariant variant;
  final bool isLoading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPress != null && !isLoading;

    final (Color bg, Color fg, Color border) = switch (variant) {
      PlacardButtonVariant.primary => (
          SignageColors.signBlue,
          SignageColors.paper,
          SignageColors.signBlue,
        ),
      PlacardButtonVariant.secondary => (
          SignageColors.paper,
          SignageColors.ink,
          SignageColors.ink,
        ),
      PlacardButtonVariant.destructive => (
          SignageColors.signRed,
          SignageColors.paper,
          SignageColors.signRed,
        ),
      PlacardButtonVariant.ink => (
          SignageColors.ink,
          SignageColors.paper,
          SignageColors.ink,
        ),
    };

    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: FTappable(
        onPress: enabled ? onPress : null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border, width: 2),
          ),
          child: SizedBox(
            width: expand ? double.infinity : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Center(
                widthFactor: expand ? null : 1.0,
                child: Text(
                  isLoading ? 'LOADING...' : label.toUpperCase(),
                  style: SignageTypography.label(fontSize: 14, color: fg),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum PlacardBadgeVariant { info, success, warning, danger, muted }

/// Small painted plate badge with 1px keyline and condensed caps + tabular numerals.
class PlacardBadge extends StatelessWidget {
  const PlacardBadge({
    super.key,
    required this.label,
    this.variant = PlacardBadgeVariant.info,
  });

  const PlacardBadge.info(String label, {Key? key})
      : this(key: key, label: label, variant: PlacardBadgeVariant.info);

  const PlacardBadge.success(String label, {Key? key})
      : this(key: key, label: label, variant: PlacardBadgeVariant.success);

  const PlacardBadge.warning(String label, {Key? key})
      : this(key: key, label: label, variant: PlacardBadgeVariant.warning);

  const PlacardBadge.danger(String label, {Key? key})
      : this(key: key, label: label, variant: PlacardBadgeVariant.danger);

  const PlacardBadge.muted(String label, {Key? key})
      : this(key: key, label: label, variant: PlacardBadgeVariant.muted);

  final String label;
  final PlacardBadgeVariant variant;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, Color border) = switch (variant) {
      PlacardBadgeVariant.info => (
          SignageColors.signBlue,
          SignageColors.paper,
          SignageColors.ink,
        ),
      PlacardBadgeVariant.success => (
          SignageColors.signGreen,
          SignageColors.paper,
          SignageColors.ink,
        ),
      PlacardBadgeVariant.warning => (
          SignageColors.signGold,
          SignageColors.ink,
          SignageColors.ink,
        ),
      PlacardBadgeVariant.danger => (
          SignageColors.signRed,
          SignageColors.paper,
          SignageColors.ink,
        ),
      PlacardBadgeVariant.muted => (
          SignageColors.paper,
          SignageColors.inkMuted,
          SignageColors.lineSoft,
        ),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label.toUpperCase(),
          style: SignageTypography.label(fontSize: 11, color: fg).copyWith(
            fontFeatures: SignageTypography.tabularFigures,
          ),
        ),
      ),
    );
  }
}

enum PlacardAlertVariant { info, success, warning, danger }

/// Notice placard with a 2px keyline on all four sides around a pale status wash.
class PlacardAlert extends StatelessWidget {
  const PlacardAlert({
    super.key,
    required this.title,
    this.subtitle,
    this.variant = PlacardAlertVariant.info,
  });

  final String title;
  final String? subtitle;
  final PlacardAlertVariant variant;

  @override
  Widget build(BuildContext context) {
    final (Color wash, Color keyline, Color ink) = switch (variant) {
      PlacardAlertVariant.info => (
          SignageColors.blueWash,
          SignageColors.blueKeyline,
          SignageColors.blueInk,
        ),
      PlacardAlertVariant.success => (
          SignageColors.greenWash,
          SignageColors.greenKeyline,
          SignageColors.greenInk,
        ),
      PlacardAlertVariant.warning => (
          SignageColors.goldWash,
          SignageColors.goldKeyline,
          SignageColors.goldInk,
        ),
      PlacardAlertVariant.danger => (
          SignageColors.redWash,
          SignageColors.redKeyline,
          SignageColors.redInk,
        ),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: wash,
        border: Border.all(color: keyline, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: SignageTypography.condensedSentence(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: SignageTypography.body(fontSize: 14, color: ink),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shared empty/error/blocked state block with a painted stamp and sentence-case title.
class StateBlock extends StatelessWidget {
  const StateBlock({
    super.key,
    required this.stamp,
    required this.title,
    required this.description,
    this.action,
  });

  final String stamp;
  final String title;
  final String description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return PlacardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: SignageColors.ink,
              border: Border.all(color: SignageColors.ink, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Text(
                stamp.toUpperCase(),
                style: SignageTypography.label(
                  fontSize: 12,
                  color: SignageColors.paper,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: SignageTypography.condensedSentence(fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: SignageTypography.body(
              fontSize: 15,
              color: SignageColors.inkMuted,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
}

class ScoreSplit {
  const ScoreSplit({required this.label, required this.value});
  final String label;
  final String value;
}

/// Signature Score Placard: 56px mono total on Sign Blue with ruled section splits.
class ScorePlacard extends StatelessWidget {
  const ScorePlacard({
    super.key,
    required this.totalScore,
    required this.caption,
    this.splits = const [],
  });

  final String totalScore;
  final String caption;
  final List<ScoreSplit> splits;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SignageColors.paper,
        border: Border.all(color: SignageColors.ink, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              color: SignageColors.signBlue,
              border: Border(
                bottom: BorderSide(color: SignageColors.ink, width: 2),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    totalScore,
                    style: SignageTypography.displayScore(),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    caption.toUpperCase(),
                    style: SignageTypography.label(
                      fontSize: 12,
                      color: SignageColors.bandScoreCaption,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (splits.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  for (var i = 0; i < splits.length; i++) ...[
                    if (i > 0)
                      Container(
                        width: 1,
                        height: 36,
                        color: SignageColors.lineSoft,
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            splits[i].label.toUpperCase(),
                            style: SignageTypography.label(
                              fontSize: 11,
                              color: SignageColors.inkMuted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            splits[i].value,
                            style: SignageTypography.data(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Signature CEFR Band Bar: 6 bands (<A1, A1, A2, B1, B2, C1) in a 2px Ink frame.
class CefrBandBar extends StatelessWidget {
  const CefrBandBar({
    super.key,
    required this.currentBand,
  });

  static const List<String> bands = ['<A1', 'A1', 'A2', 'B1', 'B2', 'C1'];

  final String currentBand;

  @override
  Widget build(BuildContext context) {
    final normalized = currentBand.trim().toUpperCase();
    final activeIndex = bands.indexWhere((b) => b.toUpperCase() == normalized);

    return Semantics(
      label: 'CEFR Band $currentBand',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: SignageColors.track,
          border: Border.all(color: SignageColors.ink, width: 2),
        ),
        child: Row(
          children: [
            for (var i = 0; i < bands.length; i++)
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: i == activeIndex
                        ? SignageColors.ink
                        : (activeIndex >= 0 && i < activeIndex)
                            ? SignageColors.blueWash
                            : SignageColors.paper,
                    border: i < bands.length - 1
                        ? const Border(
                            right: BorderSide(
                              color: SignageColors.lineSoft,
                              width: 1,
                            ),
                          )
                        : null,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Center(
                      child: Text(
                        bands[i],
                        style: SignageTypography.data(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: i == activeIndex
                              ? SignageColors.paper
                              : (activeIndex >= 0 && i < activeIndex)
                                  ? SignageColors.blueInk
                                  : SignageColors.inkMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
