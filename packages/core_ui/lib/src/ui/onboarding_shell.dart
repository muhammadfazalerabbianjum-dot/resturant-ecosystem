import 'package:flutter/material.dart';

import '../theme/brand_colors.dart';
import 'brand_button.dart';

/// Fallback live-region announcement for [OnboardingShell] page `page` of
/// `total`. Rendered ONLY when [OnboardingShell.pageLabelBuilder] is omitted;
/// every in-app call site MUST pass `pageLabelBuilder` driven by the caller's
/// localization layer (`AppLocalizations.of(context)`) — never this English
/// fallback on a localized hot path (the `GlobalErrorWidget` precedent).
String kOnboardingPageAnnouncement(int page, int total) =>
    'Page $page of $total';

/// Fallback accessibility label for the page dot of 1-based `page`. Rendered
/// ONLY when [OnboardingShell.pageDotLabelBuilder] is omitted; a localized call
/// site MUST pass `pageDotLabelBuilder`.
String kOnboardingPageDotLabel(int page) => 'Go to page $page';

/// UI-11 (p23) W-5 `OnboardingShell` — N-page onboarding carousel.
class OnboardingShell extends StatefulWidget {
  const OnboardingShell({
    super.key,
    required this.pages,
    required this.skipLabel,
    required this.nextLabel,
    required this.doneLabel,
    this.onDone,
    this.onSkip,
    this.onPageChanged,
    this.pageLabelBuilder,
    this.pageDotLabelBuilder,
  });

  final List<Widget> pages;
  final String skipLabel;
  final String nextLabel;
  final String doneLabel;
  final VoidCallback? onDone;
  final VoidCallback? onSkip;
  final ValueChanged<int>? onPageChanged;

  /// Caller-supplied (localized) live-region announcement; receives the
  /// 1-based `page` — the same numbering the fallback
  /// [kOnboardingPageAnnouncement] prints, so the announcement never changes
  /// numbering when a builder is supplied.
  final String Function(int page, int total)? pageLabelBuilder;

  /// Caller-supplied (localized) accessibility label for a page dot; it
  /// receives the 1-based page number and falls back to
  /// [kOnboardingPageDotLabel].
  final String Function(int page)? pageDotLabelBuilder;

  @override
  State<OnboardingShell> createState() => _OnboardingShellState();
}

class _OnboardingShellState extends State<OnboardingShell> {
  late final PageController _controller;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int page, {required bool reduceMotion}) {
    if (page < 0 || page >= widget.pages.length) return;
    if (reduceMotion) {
      _controller.jumpToPage(page);
    } else {
      _controller.animateToPage(
        page,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onSkipTapped({required bool reduceMotion}) {
    if (widget.onSkip != null) {
      widget.onSkip!();
    } else {
      _goTo(widget.pages.length - 1, reduceMotion: reduceMotion);
    }
  }

  void _onNextTapped({required bool reduceMotion}) {
    _goTo(_currentIndex + 1, reduceMotion: reduceMotion);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = BrandColors.of(context);
    final primary = brand.primary;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final total = widget.pages.length;
    final isLast = _currentIndex == total - 1;

    final announcement = widget.pageLabelBuilder != null
        ? widget.pageLabelBuilder!(_currentIndex + 1, total)
        : kOnboardingPageAnnouncement(_currentIndex + 1, total);

    return Scaffold(
      backgroundColor: brand.background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            SizedBox(
              height: 48,
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: !isLast
                    ? TextButton(
                        onPressed: () =>
                            _onSkipTapped(reduceMotion: reduceMotion),
                        child: Text(
                          widget.skipLabel,
                          style:
                              (theme.textTheme.labelMedium ??
                                      const TextStyle(fontSize: 12))
                                  .copyWith(
                                    color: brand.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            Expanded(
              child: Semantics(
                liveRegion: true,
                label: announcement,
                child: PageView(
                  controller: _controller,
                  onPageChanged: (index) {
                    setState(() => _currentIndex = index);
                    widget.onPageChanged?.call(index);
                  },
                  children: widget.pages,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: <Widget>[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List<Widget>.generate(total, (i) {
                      final isActive = i == _currentIndex;
                      return Semantics(
                        key: Key('brand-onboarding-dot-$i'),
                        button: true,
                        label:
                            widget.pageDotLabelBuilder?.call(i + 1) ??
                            kOnboardingPageDotLabel(i + 1),
                        child: InkWell(
                          onTap: () => _goTo(i, reduceMotion: reduceMotion),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: isActive ? 20 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isActive ? primary : brand.textPrimary12,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const Spacer(),
                  if (!isLast)
                    IntrinsicWidth(
                      child: BrandButton(
                        text: widget.nextLabel,
                        onPressed: () =>
                            _onNextTapped(reduceMotion: reduceMotion),
                      ),
                    )
                  else
                    IntrinsicWidth(
                      child: BrandButton(
                        text: widget.doneLabel,
                        onPressed: widget.onDone,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
