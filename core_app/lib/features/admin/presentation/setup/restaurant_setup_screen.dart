import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart'
    show CoreConfigHolder, DayHours, OperatingHoursModel, UserRole;
import 'package:core_ui/core_ui.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:labs/app/config/restaurant_config_service.dart';
import 'package:labs/app/config/tax_rates_repository.dart';
import 'package:labs/app/models/restaurant_config_model.dart';
import 'package:labs/features/admin/presentation/role_gate.dart';

class RestaurantSetupScreen extends ConsumerStatefulWidget {
  const RestaurantSetupScreen({super.key});

  @override
  ConsumerState<RestaurantSetupScreen> createState() =>
      _RestaurantSetupScreenState();
}

class _RestaurantSetupScreenState extends ConsumerState<RestaurantSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  // Brand fields
  final _nameController = TextEditingController();
  final _taglineController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _currencyController = TextEditingController();
  final _languageController = TextEditingController();

  // Delivery fields
  final _minOrderController = TextEditingController();
  final _deliveryFeeController = TextEditingController();
  final _freeDeliveryController = TextEditingController();
  final _prepTimeController = TextEditingController();
  final _serviceChargeController = TextEditingController();
  bool _tipEnabled = true;
  String _deliveryFeeType = 'flat';

  // Loyalty fields
  final _loyaltyNameController = TextEditingController();
  final _pointsPerDollarController = TextEditingController();
  final _redemptionThresholdController = TextEditingController();
  final _redemptionValueController = TextEditingController();
  final _signupBonusController = TextEditingController();

  // Notification fields
  String _notificationTone = 'casual';
  String _notificationOptIn = 'after_first_order';

  // Social & Legal fields
  final _termsUrlController = TextEditingController();
  final _privacyUrlController = TextEditingController();
  final _appStoreNameController = TextEditingController();
  final _appDescriptionController = TextEditingController();
  final _instagramController = TextEditingController();
  final _tiktokController = TextEditingController();

  // Hours fields
  final _openTimeController = TextEditingController();
  final _closeTimeController = TextEditingController();

  // Tax fields (PERF-6b) — entered as PERCENT in the UI, stored as a
  // fraction of 1 in settings/taxRates (server contract). Dynamic rows are
  // parallel controller lists; disposal mirrors them in dispose().
  final _defaultTaxRateController = TextEditingController();
  final List<TextEditingController> _taxStateControllers = [];
  final List<TextEditingController> _taxRateControllers = [];
  bool _taxPopulated = false;
  bool _mondayEnabled = true;
  bool _tuesdayEnabled = true;
  bool _wednesdayEnabled = true;
  bool _thursdayEnabled = true;
  bool _fridayEnabled = true;
  bool _saturdayEnabled = false;
  bool _sundayEnabled = false;

  bool _isSaving = false;
  bool _formPopulated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadConfig());
  }

  void _loadConfig() {
    final config = ref.read(restaurantConfigProvider).valueOrNull;
    if (config == null) return;
    _populateForm(config);
  }

  /// Populates the form from the Firestore config. Guarded by [_formPopulated]
  /// so a user's in-progress edits are never clobbered by a provider re-emit.
  void _populateForm(RestaurantConfigModel config) {
    if (_formPopulated) return;
    _formPopulated = true;

    _nameController.text = config.restaurantName;
    _taglineController.text = config.tagline;
    _emailController.text = config.contactEmail;
    _phoneController.text = config.contactPhone;
    _addressController.text = config.address;
    _currencyController.text = config.currency;
    _languageController.text = config.defaultLanguage;
    _minOrderController.text = config.minimumOrderCents.toString();
    _deliveryFeeController.text = config.deliveryFeeCents.toString();
    _freeDeliveryController.text = config.freeDeliveryThresholdCents.toString();
    _prepTimeController.text = config.estimatedPrepTimeMinutes.toString();
    _serviceChargeController.text = config.serviceChargePercent.toString();
    _tipEnabled = config.tipEnabled;
    _deliveryFeeType = config.deliveryFeeType;
    _loyaltyNameController.text = config.loyaltyProgramName;
    _pointsPerDollarController.text = config.pointsPerDollar.toString();
    _redemptionThresholdController.text = config.redemptionThresholdPoints
        .toString();
    _redemptionValueController.text = config.redemptionValueCents.toString();
    _signupBonusController.text = config.signupBonusPoints.toString();
    _notificationTone = config.notificationTone;
    _notificationOptIn = config.notificationOptIn;
    _termsUrlController.text = config.termsUrl ?? '';
    _privacyUrlController.text = config.privacyUrl ?? '';
    _appStoreNameController.text = config.appStoreName ?? '';
    _appDescriptionController.text = config.appDescription ?? '';
    _instagramController.text = config.socialLinks['instagram'] ?? '';
    _tiktokController.text = config.socialLinks['tiktok'] ?? '';
    // Restore the hours tab state so saved hours appear on reload (Law 25).
    if (config.operatingHours.isNotEmpty) {
      final hours = OperatingHoursModel.fromMap(config.operatingHours);
      _mondayEnabled = hours.monday.isOpen;
      _tuesdayEnabled = hours.tuesday.isOpen;
      _wednesdayEnabled = hours.wednesday.isOpen;
      _thursdayEnabled = hours.thursday.isOpen;
      _fridayEnabled = hours.friday.isOpen;
      _saturdayEnabled = hours.saturday.isOpen;
      _sundayEnabled = hours.sunday.isOpen;
      _openTimeController.text = hours.monday.openTime;
      _closeTimeController.text = hours.monday.closeTime;
    }
  }

  /// PERF-6b: populates the tax tab once (guarded like [_formPopulated] so a
  /// stream re-emit never clobbers in-progress edits). Called from
  /// [_buildTaxTab] while the provider is WATCHED — a late first emission
  /// still lands on the next rebuild. Percent display derives from stored
  /// fractions (x100).
  void _populateTaxRowOnce(ClientTaxRates? row) {
    if (_taxPopulated || row == null) return;
    _taxPopulated = true;
    _defaultTaxRateController.text = _fractionToPercent(row.defaultRate);
    for (final entry in row.stateRates.entries) {
      _taxStateControllers.add(TextEditingController(text: entry.key));
      _taxRateControllers.add(
        TextEditingController(text: _fractionToPercent(entry.value)),
      );
    }
  }

  String _fractionToPercent(double fraction) {
    final percent = fraction * 100;
    return percent % 1 == 0
        ? percent.toStringAsFixed(0)
        : percent.toStringAsFixed(2);
  }

  double _percentToFraction(String text, String what) {
    final v = double.tryParse(text.trim().replaceAll('%', ''));
    if (v == null || v < 0 || v > 100) {
      throw TaxRateValidationException(
        '$what must be a percentage between 0 and 100, got "$text"',
      );
    }
    return v / 100;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final config = RestaurantConfigModel(
        restaurantName: _nameController.text,
        tagline: _taglineController.text,
        contactEmail: _emailController.text,
        contactPhone: _phoneController.text,
        address: _addressController.text,
        currency: _currencyController.text.isEmpty
            ? 'USD'
            : _currencyController.text,
        defaultLanguage: _languageController.text.isEmpty
            ? 'en'
            : _languageController.text,
        minimumOrderCents: int.tryParse(_minOrderController.text) ?? 0,
        deliveryFeeCents: int.tryParse(_deliveryFeeController.text) ?? 299,
        freeDeliveryThresholdCents:
            int.tryParse(_freeDeliveryController.text) ?? 3000,
        estimatedPrepTimeMinutes: int.tryParse(_prepTimeController.text) ?? 20,
        serviceChargePercent: int.tryParse(_serviceChargeController.text) ?? 0,
        tipEnabled: _tipEnabled,
        deliveryFeeType: _deliveryFeeType,
        loyaltyProgramName: _loyaltyNameController.text.isEmpty
            ? 'Rewards'
            : _loyaltyNameController.text,
        pointsPerDollar: int.tryParse(_pointsPerDollarController.text) ?? 10,
        redemptionThresholdPoints:
            int.tryParse(_redemptionThresholdController.text) ?? 500,
        redemptionValueCents:
            int.tryParse(_redemptionValueController.text) ?? 500,
        signupBonusPoints: int.tryParse(_signupBonusController.text) ?? 0,
        notificationTone: _notificationTone,
        notificationOptIn: _notificationOptIn,
        termsUrl: _termsUrlController.text.isEmpty
            ? null
            : _termsUrlController.text,
        privacyUrl: _privacyUrlController.text.isEmpty
            ? null
            : _privacyUrlController.text,
        appStoreName: _appStoreNameController.text.isEmpty
            ? null
            : _appStoreNameController.text,
        appDescription: _appDescriptionController.text.isEmpty
            ? null
            : _appDescriptionController.text,
        socialLinks: {
          if (_instagramController.text.isNotEmpty)
            'instagram': _instagramController.text,
          if (_tiktokController.text.isNotEmpty)
            'tiktok': _tiktokController.text,
        },
        // P5-07 FIX: persist the hours tab — previously silent data loss.
        // The single open/close time applies to every enabled day.
        // DayHours per-day granularity lives in OperatingHoursScreen.
        operatingHours: _buildOperatingHoursMap(),
      );
      await ref.read(restaurantConfigRepositoryProvider).save(config);

      // PERF-6b: persist the tax table (separate settings doc, same
      // owner-only lane). Skipped when the owner left the tab untouched;
      // validation failures surface through the same error snackbar.
      final hasTaxInput =
          _defaultTaxRateController.text.trim().isNotEmpty ||
          _taxStateControllers.any((c) => c.text.trim().isNotEmpty);
      if (hasTaxInput) {
        final stateRates = <String, double>{};
        for (var i = 0; i < _taxStateControllers.length; i++) {
          final state = _taxStateControllers[i].text.trim().toUpperCase();
          if (state.isEmpty) continue;
          stateRates[state] = _percentToFraction(
            _taxRateControllers[i].text,
            'rate for $state',
          );
        }
        final defaultText = _defaultTaxRateController.text.trim();
        final defaultRate = defaultText.isEmpty
            ? 0.05
            : _percentToFraction(defaultText, 'default rate');
        await ref
            .read(taxRatesRepositoryProvider)
            .saveClientRates(
              ClientTaxRates(
                clientId: CoreConfigHolder.instance.clientId,
                stateRates: stateRates,
                defaultRate: defaultRate,
              ),
            );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).settingsSavedSuccessfully,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).saveFailedWithError(e.toString()),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _taglineController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _currencyController.dispose();
    _languageController.dispose();
    _minOrderController.dispose();
    _deliveryFeeController.dispose();
    _freeDeliveryController.dispose();
    _prepTimeController.dispose();
    _serviceChargeController.dispose();
    _loyaltyNameController.dispose();
    _pointsPerDollarController.dispose();
    _redemptionThresholdController.dispose();
    _redemptionValueController.dispose();
    _signupBonusController.dispose();
    _termsUrlController.dispose();
    _privacyUrlController.dispose();
    _appStoreNameController.dispose();
    _appDescriptionController.dispose();
    _instagramController.dispose();
    _tiktokController.dispose();
    _openTimeController.dispose();
    _closeTimeController.dispose();
    for (final c in _taxStateControllers) {
      c.dispose();
    }
    for (final c in _taxRateControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RoleGate(
      allowedRoles: const {UserRole.owner},
      builder: (_) => _buildScreen(context),
    );
  }

  Widget _buildScreen(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final configAsync = ref.watch(restaurantConfigProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.restaurantSetup),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                // E1 F3-09: the library busy indicator in the action slot.
                ? const SkeletonLoader(width: 20, height: 20, borderRadius: 10)
                : Text(loc.save),
          ),
        ],
      ),
      body: configAsync.when(
        loading: () => Center(
          child: SkeletonLoader.block(width: double.infinity, height: 64),
        ),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (config) {
          // Populate the form once the config arrives (the initState call may
          // have run before the async provider emitted).
          _populateForm(config);
          final form = Form(
            key: _formKey,
            child: DefaultTabController(
              length: 7,
              child: Column(
                children: [
                  const TabBar(
                    isScrollable: true,
                    tabs: [
                      Tab(text: 'Brand'),
                      Tab(text: 'Delivery'),
                      Tab(text: 'Loyalty'),
                      Tab(text: 'Notifications'),
                      Tab(text: 'Social & Legal'),
                      Tab(text: 'Hours'),
                      Tab(text: 'Tax'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Brand Tab
                        _buildBrandTab(),
                        // Delivery Tab
                        _buildDeliveryTab(),
                        // Loyalty Tab
                        _buildLoyaltyTab(),
                        // Notifications Tab
                        _buildNotificationsTab(),
                        // Social & Legal Tab
                        _buildSocialLegalTab(),
                        // Hours Tab
                        _buildHoursTab(),
                        // Tax Tab (PERF-6b)
                        _buildTaxTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
          if (configAsync.isRefreshing) {
            return Stack(
              children: [
                form,
                const PositionedDirectional(
                  top: 8,
                  end: 8,
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: SkeletonLoader(
                      width: 24,
                      height: 24,
                      borderRadius: 12,
                    ),
                  ),
                ),
              ],
            );
          }
          return form;
        },
      ),
    );
  }

  /// PERF-6b: the per-client tax table tab. Percent inputs are converted to
  /// fractions on save (server contract); unknown states fail closed on the
  /// server, so a typo can never charge zero tax.
  Widget _buildTaxTab() {
    final loc = AppLocalizations.of(context);
    // Watching activates the stream so a late first emission lands; the
    // guarded one-time populate mirrors the config form's pattern.
    final taxRow = ref.watch(taxRatesRowProvider).valueOrNull;
    _populateTaxRowOnce(taxRow);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(loc.setupTaxHint, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 16),
        TextFormField(
          controller: _defaultTaxRateController,
          decoration: InputDecoration(
            labelText: loc.setupLabelDefaultTaxRate,
            border: const OutlineInputBorder(),
            suffixText: '%',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < _taxStateControllers.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _taxStateControllers[i],
                    decoration: InputDecoration(
                      labelText: loc.setupLabelState,
                      border: const OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _taxRateControllers[i],
                    decoration: InputDecoration(
                      labelText: loc.setupLabelStateRate,
                      border: const OutlineInputBorder(),
                      suffixText: '%',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => setState(() {
                    _taxStateControllers.removeAt(i).dispose();
                    _taxRateControllers.removeAt(i).dispose();
                  }),
                ),
              ],
            ),
          ),
        TextButton.icon(
          onPressed: () => setState(() {
            _taxStateControllers.add(TextEditingController());
            _taxRateControllers.add(TextEditingController());
          }),
          icon: const Icon(Icons.add),
          label: Text(loc.setupAddState),
        ),
      ],
    );
  }

  Widget _buildBrandTab() {
    final loc = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionHeader(title: loc.sectionIdentity),
        const SizedBox(height: 16),
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: loc.setupLabelRestaurantName,
            border: const OutlineInputBorder(),
          ),
          validator: (v) => (v == null || v.isEmpty) ? loc.required : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _taglineController,
          decoration: InputDecoration(
            labelText: loc.setupLabelTagline,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _emailController,
          decoration: InputDecoration(
            labelText: loc.setupLabelSupportEmail,
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _phoneController,
          decoration: InputDecoration(
            labelText: loc.setupLabelContactPhone,
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _addressController,
          decoration: InputDecoration(
            labelText: loc.setupLabelAddress,
            border: const OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        SectionHeader(title: loc.sectionRegional),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _currencyController,
                decoration: InputDecoration(
                  labelText: loc.setupLabelCurrency,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _languageController,
                decoration: InputDecoration(
                  labelText: loc.setupLabelDefaultLanguage,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDeliveryTab() {
    final loc = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionHeader(title: loc.sectionOrderRules),
        const SizedBox(height: 16),
        TextFormField(
          controller: _minOrderController,
          decoration: InputDecoration(
            labelText: loc.setupLabelMinimumOrderCents,
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _prepTimeController,
          decoration: InputDecoration(
            labelText: loc.setupLabelEstimatedPrepTimeMinutes,
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        SectionHeader(title: loc.sectionDeliveryFee),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _deliveryFeeType,
          decoration: InputDecoration(
            labelText: loc.setupLabelDeliveryFeeType,
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem(
              value: 'flat',
              child: Text(loc.deliveryFeeTypeFlat),
            ),
            DropdownMenuItem(
              value: 'distance',
              child: Text(loc.deliveryFeeTypeDistance),
            ),
            DropdownMenuItem(
              value: 'free_above',
              child: Text(loc.deliveryFeeTypeFreeAbove),
            ),
          ],
          onChanged: (v) => setState(() => _deliveryFeeType = v ?? 'flat'),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _deliveryFeeController,
          decoration: InputDecoration(
            labelText: loc.setupLabelDeliveryFeeCents,
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _freeDeliveryController,
          decoration: InputDecoration(
            labelText: loc.setupLabelFreeDeliveryThresholdCents,
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        SectionHeader(title: loc.sectionChargesTips),
        const SizedBox(height: 16),
        TextFormField(
          controller: _serviceChargeController,
          decoration: InputDecoration(
            labelText: loc.setupLabelServiceChargePercent,
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        SettingTile(
          icon: Icons.percent,
          title: loc.enableTipPrompt,
          trailing: Switch.adaptive(
            value: _tipEnabled,
            onChanged: (v) => setState(() => _tipEnabled = v),
          ),
        ),
      ],
    );
  }

  Widget _buildLoyaltyTab() {
    final loc = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionHeader(title: loc.sectionLoyaltyProgram),
        const SizedBox(height: 16),
        TextFormField(
          controller: _loyaltyNameController,
          decoration: InputDecoration(
            labelText: loc.setupLabelLoyaltyProgramName,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        SectionHeader(title: loc.sectionPointsRules),
        const SizedBox(height: 16),
        TextFormField(
          controller: _pointsPerDollarController,
          decoration: InputDecoration(
            labelText: loc.setupLabelPointsPerDollar,
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _redemptionThresholdController,
          decoration: InputDecoration(
            labelText: loc.setupLabelRedemptionThresholdPoints,
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _redemptionValueController,
          decoration: InputDecoration(
            labelText: loc.setupLabelRedemptionValueCents,
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _signupBonusController,
          decoration: InputDecoration(
            labelText: loc.setupLabelSignupBonusPoints,
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  Widget _buildNotificationsTab() {
    final loc = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionHeader(title: loc.sectionMessageTone),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _notificationTone,
          decoration: InputDecoration(
            labelText: loc.setupLabelNotificationTone,
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem(value: 'casual', child: Text(loc.toneCasual)),
            DropdownMenuItem(value: 'formal', child: Text(loc.toneFormal)),
          ],
          onChanged: (v) => setState(() => _notificationTone = v ?? 'casual'),
        ),
        const SizedBox(height: 16),
        SectionHeader(title: loc.sectionNotificationTiming),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _notificationOptIn,
          decoration: InputDecoration(
            labelText: loc.setupLabelNotificationOptIn,
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem(
              value: 'on_launch',
              child: Text(loc.askOnAppLaunch),
            ),
            DropdownMenuItem(
              value: 'after_first_order',
              child: Text(loc.askAfterFirstOrder),
            ),
          ],
          onChanged: (v) =>
              setState(() => _notificationOptIn = v ?? 'after_first_order'),
        ),
      ],
    );
  }

  Widget _buildSocialLegalTab() {
    final loc = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionHeader(title: loc.sectionAppStore),
        const SizedBox(height: 16),
        TextFormField(
          controller: _appStoreNameController,
          decoration: InputDecoration(
            labelText: loc.setupLabelAppStoreName,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _appDescriptionController,
          decoration: InputDecoration(
            labelText: loc.setupLabelAppDescription,
            border: const OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        SectionHeader(title: loc.sectionLegalLinks),
        const SizedBox(height: 16),
        TextFormField(
          controller: _termsUrlController,
          decoration: InputDecoration(
            labelText: loc.setupLabelTermsUrl,
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _privacyUrlController,
          decoration: InputDecoration(
            labelText: loc.setupLabelPrivacyUrl,
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 16),
        SectionHeader(title: loc.sectionSocialMedia),
        const SizedBox(height: 16),
        TextFormField(
          controller: _instagramController,
          decoration: InputDecoration(
            labelText: loc.setupLabelInstagramUrl,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _tiktokController,
          decoration: InputDecoration(
            labelText: loc.setupLabelTiktokUrl,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  /// Builds the Firestore-shape operatingHours map from the Hours tab state.
  /// Every enabled day uses the single open/close time from the tab.
  Map<String, dynamic> _buildOperatingHoursMap() {
    final open = _openTimeController.text.trim().isEmpty
        ? '09:00'
        : _openTimeController.text.trim();
    final close = _closeTimeController.text.trim().isEmpty
        ? '22:00'
        : _closeTimeController.text.trim();
    DayHours hours(bool enabled) =>
        DayHours(isOpen: enabled, openTime: open, closeTime: close);
    return OperatingHoursModel(
      monday: hours(_mondayEnabled),
      tuesday: hours(_tuesdayEnabled),
      wednesday: hours(_wednesdayEnabled),
      thursday: hours(_thursdayEnabled),
      friday: hours(_fridayEnabled),
      saturday: hours(_saturdayEnabled),
      sunday: hours(_sundayEnabled),
    ).toMap();
  }

  /// The Hours-tab day rows in week order: localised label, current value and
  /// setter. Defaults are unchanged from the pre-p22 checkboxes — Monday to
  /// Friday start open, the weekend starts closed.
  List<({String label, bool value, ValueChanged<bool> onChanged})>
  get _dayRows {
    final loc = AppLocalizations.of(context);
    return [
      (
        label: loc.dayMonday,
        value: _mondayEnabled,
        onChanged: (v) => setState(() => _mondayEnabled = v),
      ),
      (
        label: loc.dayTuesday,
        value: _tuesdayEnabled,
        onChanged: (v) => setState(() => _tuesdayEnabled = v),
      ),
      (
        label: loc.dayWednesday,
        value: _wednesdayEnabled,
        onChanged: (v) => setState(() => _wednesdayEnabled = v),
      ),
      (
        label: loc.dayThursday,
        value: _thursdayEnabled,
        onChanged: (v) => setState(() => _thursdayEnabled = v),
      ),
      (
        label: loc.dayFriday,
        value: _fridayEnabled,
        onChanged: (v) => setState(() => _fridayEnabled = v),
      ),
      (
        label: loc.daySaturday,
        value: _saturdayEnabled,
        onChanged: (v) => setState(() => _saturdayEnabled = v),
      ),
      (
        label: loc.daySunday,
        value: _sundayEnabled,
        onChanged: (v) => setState(() => _sundayEnabled = v),
      ),
    ];
  }

  Widget _buildHoursTab() {
    final loc = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionHeader(title: loc.operatingHours),
        const SizedBox(height: 16),
        for (final day in _dayRows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SettingTile(
              icon: Icons.calendar_today,
              title: day.label,
              trailing: Switch.adaptive(
                value: day.value,
                onChanged: day.onChanged,
              ),
            ),
          ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _openTimeController,
          decoration: InputDecoration(
            labelText: loc.setupLabelOpenTimeExample,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _closeTimeController,
          decoration: InputDecoration(
            labelText: loc.setupLabelCloseTimeExample,
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}
