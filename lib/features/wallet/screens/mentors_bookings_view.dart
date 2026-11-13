import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../../theme/signage_theme.dart';
import '../../../widgets/signage_primitives.dart';
import '../../auth/auth_provider.dart';
import '../../context/learner_context_provider.dart';
import '../mentor_models.dart';
import '../mentor_providers.dart';
import '../wallet_providers.dart';

/// *Mentors & Bookings* sub-tab inside `WALLET`.
class MentorsBookingsView extends ConsumerStatefulWidget {
  const MentorsBookingsView({super.key});

  @override
  ConsumerState<MentorsBookingsView> createState() =>
      _MentorsBookingsViewState();
}

class _MentorsBookingsViewState extends ConsumerState<MentorsBookingsView> {
  int? _bookingMentorId;
  MentorBooking? _ratingBooking;

  @override
  Widget build(BuildContext context) {
    if (_bookingMentorId != null) {
      return _BookMentorView(
        mentorId: _bookingMentorId!,
        onClose: () => setState(() => _bookingMentorId = null),
      );
    }
    if (_ratingBooking != null) {
      return _RateBookingView(
        booking: _ratingBooking!,
        onClose: () => setState(() => _ratingBooking = null),
      );
    }

    final mentorsAsync = ref.watch(mentorsListProvider);
    final bookingsAsync = ref.watch(mentorBookingsProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PlacardPanel(
          title: 'MENTORS DIRECTORY',
          padding: EdgeInsets.zero,
          child: mentorsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: FCircularProgress()),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Failed to load mentors: $err',
                style: SignageTypography.body(
                  fontSize: 14,
                  color: SignageColors.signRed,
                ),
              ),
            ),
            data: (mentors) {
              if (mentors.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No mentors available for this certificate.',
                    style: SignageTypography.body(
                      fontSize: 14,
                      color: SignageColors.inkMuted,
                    ),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < mentors.length; i++) ...[
                    if (i > 0)
                      Container(height: 1, color: SignageColors.lineSoft),
                    _MentorRow(
                      mentor: mentors[i],
                      onBook: () =>
                          setState(() => _bookingMentorId = mentors[i].id),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        PlacardPanel(
          title: 'MY BOOKINGS',
          padding: EdgeInsets.zero,
          child: bookingsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: FCircularProgress()),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Failed to load bookings: $err',
                style: SignageTypography.body(
                  fontSize: 14,
                  color: SignageColors.signRed,
                ),
              ),
            ),
            data: (bookings) {
              if (bookings.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No mentor bookings yet.',
                    style: SignageTypography.body(
                      fontSize: 14,
                      color: SignageColors.inkMuted,
                    ),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < bookings.length; i++) ...[
                    if (i > 0)
                      Container(height: 1, color: SignageColors.lineSoft),
                    _BookingRow(
                      booking: bookings[i],
                      onRate: () =>
                          setState(() => _ratingBooking = bookings[i]),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MentorRow extends StatelessWidget {
  const _MentorRow({
    required this.mentor,
    required this.onBook,
  });

  final MentorProfile mentor;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  mentor.displayName,
                  style: SignageTypography.condensedSentence(fontSize: 17),
                ),
              ),
              PlacardBadge(
                label: mentor.isAi ? 'AI MENTOR' : 'HUMAN',
                variant: mentor.isAi
                    ? PlacardBadgeVariant.info
                    : PlacardBadgeVariant.muted,
              ),
            ],
          ),
          if (mentor.headline.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              mentor.headline,
              style: SignageTypography.body(
                fontSize: 13,
                color: SignageColors.inkMuted,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  mentor.summaryLabel,
                  style: SignageTypography.data(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              PlacardButton(
                key: Key('open-mentor-${mentor.id}'),
                label: 'BOOK',
                expand: false,
                onPress: onBook,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BookingRow extends ConsumerStatefulWidget {
  const _BookingRow({
    required this.booking,
    required this.onRate,
  });

  final MentorBooking booking;
  final VoidCallback onRate;

  @override
  ConsumerState<_BookingRow> createState() => _BookingRowState();
}

class _BookingRowState extends ConsumerState<_BookingRow> {
  bool _isCancelling = false;
  String? _launchError;
  String? _cancelError;
  String? _cancelNotice;

  Future<void> _joinMeeting(String url) async {
    final launched =
        await ref.read(urlLauncherAdapterProvider).launchExternalUrl(url);
    if (!mounted) return;
    setState(() {
      _launchError = launched
          ? null
          : 'Could not open the meeting link. Copy it into a browser: $url';
    });
  }

  Future<void> _cancel() async {
    setState(() {
      _isCancelling = true;
      _cancelError = null;
      _cancelNotice = null;
    });
    try {
      final result =
          await ref.read(mentorRepositoryProvider).cancelBooking(widget.booking.id);
      // The booking is cancelled and the ledger refunded; refresh both so the
      // refunded credit is visible on the wallet placard straight away.
      await Future.wait([
        ref.read(mentorBookingsProvider.notifier).refresh(),
        ref.read(walletSummaryProvider.notifier).refresh(),
        ref.read(learnerContextProvider.notifier).refreshContext(),
      ]);
      if (!mounted) return;
      setState(() {
        _isCancelling = false;
        _cancelNotice = result.refundedCredits > 0
            ? 'Booking cancelled. ${result.refundedCredits} credits refunded.'
            : 'Booking cancelled. No credits were refunded.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCancelling = false;
        _cancelError = extractApiError(
          e,
          fallback: 'Could not cancel this booking.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  booking.mentorName,
                  style: SignageTypography.condensedSentence(fontSize: 16),
                ),
              ),
              PlacardBadge(
                label: booking.status.toUpperCase(),
                variant: switch (booking.status) {
                  'confirmed' => PlacardBadgeVariant.info,
                  'done' => PlacardBadgeVariant.success,
                  'cancelled' => PlacardBadgeVariant.danger,
                  _ => PlacardBadgeVariant.muted,
                },
              ),
            ],
          ),
          if (booking.focusArea != null) ...[
            const SizedBox(height: 4),
            Text(
              'Focus: ${booking.focusArea}',
              style: SignageTypography.body(
                fontSize: 13,
                color: SignageColors.inkMuted,
              ),
            ),
          ],
          if (booking.review != null) ...[
            const SizedBox(height: 4),
            Text(
              'Rated: ${booking.review!.rating}/5'
              '${booking.reviewText != null ? ' — ${booking.reviewText}' : ''}',
              key: Key('booking-review-${booking.id}'),
              style: SignageTypography.data(
                fontSize: 12,
                color: SignageColors.signGreen,
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (_launchError != null) ...[
            PlacardAlert(
              variant: PlacardAlertVariant.danger,
              title: 'Could not open link',
              subtitle: _launchError,
            ),
            const SizedBox(height: 10),
          ],
          if (_cancelError != null) ...[
            PlacardAlert(
              key: Key('cancel-error-${booking.id}'),
              variant: PlacardAlertVariant.danger,
              title: 'Could not cancel booking',
              subtitle: _cancelError,
            ),
            const SizedBox(height: 10),
          ],
          if (_cancelNotice != null) ...[
            PlacardAlert(
              key: Key('cancel-notice-${booking.id}'),
              variant: PlacardAlertVariant.success,
              title: _cancelNotice!,
            ),
            const SizedBox(height: 10),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Only a live session with a link offers JOIN MEET.
              if (booking.canJoinMeet)
                PlacardButton(
                  key: Key('join-meet-button-${booking.id}'),
                  label: 'JOIN MEET',
                  expand: false,
                  onPress: () => _joinMeeting(booking.meetLink!),
                ),
              if (booking.canCancel)
                PlacardButton(
                  key: Key('cancel-booking-button-${booking.id}'),
                  label: 'CANCEL BOOKING',
                  expand: false,
                  variant: PlacardButtonVariant.destructive,
                  isLoading: _isCancelling,
                  onPress: _cancel,
                ),
              if (booking.canRate)
                PlacardButton(
                  key: Key('rate-booking-button-${booking.id}'),
                  label: 'RATE SESSION',
                  expand: false,
                  variant: PlacardButtonVariant.secondary,
                  onPress: widget.onRate,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BookMentorView extends ConsumerStatefulWidget {
  const _BookMentorView({
    required this.mentorId,
    required this.onClose,
  });

  final int mentorId;
  final VoidCallback onClose;

  @override
  ConsumerState<_BookMentorView> createState() => _BookMentorViewState();
}

class _BookMentorViewState extends ConsumerState<_BookMentorView> {
  MentorDetail? _detail;
  MentorSlot? _selectedSlot;
  final _focusController = TextEditingController();
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  MentorProfile? get _mentor => _detail?.mentor;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _focusController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final detail = await ref
          .read(mentorRepositoryProvider)
          .getMentorDetail(widget.mentorId);
      if (mounted) {
        setState(() {
          _detail = detail;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = extractApiError(e, fallback: 'Could not load this mentor.');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _book() async {
    final mentor = _mentor;
    if (mentor == null) return;
    if (!mentor.isAi && _selectedSlot == null) {
      setState(() => _error = 'Please select an available time slot.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final focus = _focusController.text.trim();
      await ref.read(mentorRepositoryProvider).bookMentor(
            mentor.id,
            slotId: mentor.isAi ? null : _selectedSlot?.id,
            focusArea: focus.isEmpty ? null : focus,
          );
      await Future.wait([
        ref.read(mentorBookingsProvider.notifier).refresh(),
        ref.read(walletSummaryProvider.notifier).refresh(),
        ref.read(learnerContextProvider.notifier).refreshContext(),
      ]);
      if (mounted) {
        widget.onClose();
      }
    } catch (e) {
      // The backend's own message, and the button stays usable for a retry.
      if (mounted) {
        setState(() {
          _error = extractApiError(e, fallback: 'Could not book this mentor.');
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mentor = _mentor;
    final balance = ref.watch(learnerContextProvider).value?.creditBalance;
    final shortOfCredits =
        mentor != null && balance != null && balance < mentor.priceCredits;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: PlacardButton(
            label: 'BACK TO MENTORS',
            expand: false,
            variant: PlacardButtonVariant.secondary,
            onPress: widget.onClose,
          ),
        ),
        const SizedBox(height: 16),
        if (_isLoading)
          const Center(child: FCircularProgress())
        else if (mentor != null)
          PlacardPanel(
            title: mentor.isAi ? 'BOOK AI MENTOR' : 'BOOK HUMAN MENTOR',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  mentor.displayName,
                  style: SignageTypography.headline(),
                ),
                const SizedBox(height: 4),
                Text(
                  '${mentor.sessionMinutes} MIN · ${mentor.priceCredits} CREDITS',
                  key: const Key('booking-price'),
                  style: SignageTypography.data(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: SignageColors.signBlue,
                  ),
                ),
                if (balance != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'YOUR BALANCE: $balance CREDITS',
                    style: SignageTypography.label(
                      fontSize: 12,
                      color: shortOfCredits
                          ? SignageColors.signRed
                          : SignageColors.inkMuted,
                    ),
                  ),
                ],
                if (shortOfCredits) ...[
                  const SizedBox(height: 12),
                  PlacardAlert(
                    variant: PlacardAlertVariant.warning,
                    title: 'Not enough credits',
                    subtitle:
                        'This session costs ${mentor.priceCredits} credits and '
                        'you have $balance. Top up in CREDITS & ORDERS first.',
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  PlacardAlert(
                    key: const Key('booking-error'),
                    variant: PlacardAlertVariant.danger,
                    title: _error!,
                  ),
                ],
                if (!mentor.isAi) ...[
                  const SizedBox(height: 16),
                  Text('SELECT A SLOT', style: SignageTypography.label()),
                  const SizedBox(height: 8),
                  if (_detail!.availableSlots.isEmpty)
                    Text(
                      'This mentor has no open times right now.',
                      style: SignageTypography.body(
                        fontSize: 14,
                        color: SignageColors.inkMuted,
                      ),
                    ),
                  for (final slot in _detail!.availableSlots)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: FTappable(
                        key: Key('mentor-slot-${slot.id}'),
                        onPress: slot.isOpen
                            ? () => setState(() => _selectedSlot = slot)
                            : null,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: _selectedSlot?.id == slot.id
                                ? SignageColors.ink
                                : SignageColors.paper,
                            border: Border.all(
                              color: SignageColors.ink,
                              width: 2,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              describeSlotTime(slot),
                              style: SignageTypography.data(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _selectedSlot?.id == slot.id
                                    ? SignageColors.paper
                                    : SignageColors.ink,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ] else ...[
                  const SizedBox(height: 12),
                  const PlacardAlert(
                    variant: PlacardAlertVariant.info,
                    title: 'Immediate AI session',
                    subtitle: 'AI mentors book immediately without a time slot.',
                  ),
                ],
                const SizedBox(height: 16),
                FTextField(
                  key: const Key('booking-focus-area-field'),
                  control:
                      FTextFieldControl.managed(controller: _focusController),
                  label: Text(
                    'FOCUS AREA',
                    style: SignageTypography.label(),
                  ),
                  hint: 'e.g. Part 7 inference or Speaking Part 3',
                ),
                const SizedBox(height: 16),
                PlacardButton(
                  key: const Key('confirm-booking-button'),
                  label: 'CONFIRM BOOKING',
                  isLoading: _isSubmitting,
                  onPress: shortOfCredits ? null : _book,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RateBookingView extends ConsumerStatefulWidget {
  const _RateBookingView({
    required this.booking,
    required this.onClose,
  });

  final MentorBooking booking;
  final VoidCallback onClose;

  @override
  ConsumerState<_RateBookingView> createState() => _RateBookingViewState();
}

class _RateBookingViewState extends ConsumerState<_RateBookingView> {
  int _rating = 5;
  final _reviewController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final text = _reviewController.text.trim();
      await ref.read(mentorRepositoryProvider).rateBooking(
            widget.booking.id,
            rating: _rating,
            text: text.isEmpty ? null : text,
          );
      await ref.read(mentorBookingsProvider.notifier).refresh();
      if (mounted) {
        widget.onClose();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = extractApiError(e, fallback: 'Could not submit this rating.');
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: PlacardButton(
            label: 'BACK TO BOOKINGS',
            expand: false,
            variant: PlacardButtonVariant.secondary,
            onPress: widget.onClose,
          ),
        ),
        const SizedBox(height: 16),
        PlacardPanel(
          title: 'RATE SESSION',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.booking.mentorName,
                style: SignageTypography.headline(),
              ),
              const SizedBox(height: 12),
              if (_error != null) ...[
                PlacardAlert(
                  variant: PlacardAlertVariant.danger,
                  title: _error!,
                ),
                const SizedBox(height: 12),
              ],
              Text(
                'RATING (1–5)',
                style: SignageTypography.label(),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var star = 1; star <= 5; star++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: star < 5 ? 6 : 0),
                        child: FTappable(
                          key: Key('rate-star-$star'),
                          onPress: () => setState(() => _rating = star),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: _rating == star
                                  ? SignageColors.ink
                                  : SignageColors.paper,
                              border: Border.all(
                                color: SignageColors.ink,
                                width: 2,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Center(
                                child: Text(
                                  '$star ★',
                                  style: SignageTypography.data(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _rating == star
                                        ? SignageColors.paper
                                        : SignageColors.ink,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              FTextField(
                key: const Key('rate-review-field'),
                control:
                    FTextFieldControl.managed(controller: _reviewController),
                label: Text(
                  'REVIEW',
                  style: SignageTypography.label(),
                ),
                hint: 'Share feedback on this session',
              ),
              const SizedBox(height: 16),
              PlacardButton(
                key: const Key('submit-rating-button'),
                label: 'SUBMIT RATING',
                isLoading: _isSubmitting,
                onPress: _submit,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
