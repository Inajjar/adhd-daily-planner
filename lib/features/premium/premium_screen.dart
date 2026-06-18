import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/iap_service.dart';
import '../../state/app_state.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key, required this.appState});

  final AppState appState;

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  static final Uri _termsUrl = Uri.parse(
    'https://adhd-daily-planner-d0fc6.web.app/terms.html',
  );
  static final Uri _privacyUrl = Uri.parse(
    'https://adhd-daily-planner-d0fc6.web.app/privacy.html',
  );

  final IAPService _iapService = IAPService();

  bool _isLoading = true;
  bool _isPurchasing = false;
  bool _isRestoring = false;
  SubscriptionPlan _selectedPlan = SubscriptionPlan.monthly;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    await _iapService.initialize(widget.appState.anonymousUserId);
    await _iapService.loadOfferings();

    if (_iapService.yearlyPackage == null && _iapService.monthlyPackage != null) {
      _selectedPlan = SubscriptionPlan.monthly;
    } else if (_iapService.monthlyPackage == null &&
        _iapService.yearlyPackage != null) {
      _selectedPlan = SubscriptionPlan.yearly;
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Package? _getPackage(SubscriptionPlan plan) {
    return plan == SubscriptionPlan.monthly
        ? _iapService.monthlyPackage
        : _iapService.yearlyPackage;
  }

  bool _isAvailable(SubscriptionPlan plan) {
    return _getPackage(plan) != null;
  }

  String _price(SubscriptionPlan plan) {
    return _getPackage(plan)?.storeProduct.priceString ?? 'Unavailable';
  }

  String _caption(SubscriptionPlan plan) {
    return plan == SubscriptionPlan.monthly
        ? 'Billed monthly'
        : 'Billed yearly';
  }

  String _trial(SubscriptionPlan plan) {
    final intro = _getPackage(plan)?.storeProduct.introductoryPrice;
    if (intro == null || intro.price != 0) {
      return '';
    }

    final unit = intro.periodUnit.toString().split('.').last;
    return '${intro.periodNumberOfUnits} $unit free trial';
  }

  String _cta() {
    return 'Continue';
  }

  Future<void> _handleAccessGranted() async {
    await widget.appState.refreshPremiumOfferings();
    await widget.appState.syncPremiumStateToCloud();
    if (!mounted) {
      return;
    }
    Navigator.pop(context, true);
  }

  Future<void> _purchase() async {
    if (_isPurchasing || !_isAvailable(_selectedPlan)) {
      return;
    }

    setState(() => _isPurchasing = true);
    HapticFeedback.mediumImpact();

    final success = await _iapService.purchase(_selectedPlan);

    if (!mounted) {
      return;
    }

    setState(() => _isPurchasing = false);

    if (success) {
      await _handleAccessGranted();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Unable to start the purchase right now.'),
      ),
    );
  }

  Future<void> _restorePurchases() async {
    if (_isRestoring) {
      return;
    }

    setState(() => _isRestoring = true);

    final restored = await _iapService.restore();

    if (!mounted) {
      return;
    }

    setState(() => _isRestoring = false);

    if (restored) {
      await _handleAccessGranted();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No active subscription was found to restore.'),
      ),
    );
  }

  Future<void> _openUrl(Uri url) async {
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open link right now.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _iapService,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded, size: 30),
                          ),
                        ],
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                          child: Column(
                            children: [
                              _buildHeader(),
                              const SizedBox(height: 28),
                              _buildPricingOptions(),
                              const SizedBox(height: 20),
                              _buildCTAButton(),
                              const SizedBox(height: 14),
                              _buildSecurityNote(),
                              const SizedBox(height: 14),
                              _buildSubscriptionDisclosure(),
                              if (!_isAvailable(SubscriptionPlan.monthly) &&
                                  !_isAvailable(SubscriptionPlan.yearly)) ...[
                                const SizedBox(height: 14),
                                _buildStatusNote(),
                              ],
                              const SizedBox(height: 16),
                              _buildLegalLinks(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          'Go Premium',
          style: GoogleFonts.inter(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.2,
            color: const Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'More focus. Less friction.',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF667085),
          ),
        ),
      ],
    );
  }

  Widget _buildPricingOptions() {
    return Column(
      children: [
        _buildPlanOption(
          plan: SubscriptionPlan.monthly,
          title: 'Monthly',
        ),
        const SizedBox(height: 12),
        _buildPlanOption(
          plan: SubscriptionPlan.yearly,
          title: 'Yearly',
          badgeText: 'BEST VALUE',
        ),
      ],
    );
  }

  Widget _buildPlanOption({
    required SubscriptionPlan plan,
    required String title,
    String? badgeText,
  }) {
    final isSelected = _selectedPlan == plan;
    final isAvailable = _isAvailable(plan);

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: isAvailable ? () => setState(() => _selectedPlan = plan) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFF1F7FF)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0A84FF)
                : const Color(0xFFDDE4F0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.circle_outlined,
              color: isAvailable
                  ? const Color(0xFF0A84FF)
                  : const Color(0xFF98A2B3),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      if (badgeText != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            badgeText,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0A84FF),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_price(plan)}/${plan == SubscriptionPlan.monthly ? "month" : "year"}',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isAvailable
                          ? const Color(0xFF111827)
                          : const Color(0xFF98A2B3),
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _caption(plan),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF667085),
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

  Widget _buildCTAButton() {
    final trial = _trial(_selectedPlan);

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton(
            onPressed:
                _isPurchasing || !_isAvailable(_selectedPlan) ? null : _purchase,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0A84FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            child: _isPurchasing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    _cta(),
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
        if (trial.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '$trial, then ${_price(_selectedPlan)}',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF667085),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSecurityNote() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.lock_outline, size: 16, color: Color(0xFF98A2B3)),
        const SizedBox(width: 4),
        Text(
          'Cancel anytime. Secured by App Store',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF98A2B3),
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionDisclosure() {
    final monthlyPrice = _price(SubscriptionPlan.monthly);
    final yearlyPrice = _price(SubscriptionPlan.yearly);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE4F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Subscription details',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Monthly subscription: $monthlyPrice every month.',
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.4,
              color: const Color(0xFF667085),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Yearly subscription: $yearlyPrice every year.',
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.4,
              color: const Color(0xFF667085),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Auto-renewable subscription. Cancel anytime in your App Store account settings.',
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.4,
              color: const Color(0xFF667085),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE4F0)),
      ),
      child: Text(
        'Plans not loading yet. Try again soon.',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF667085),
        ),
      ),
    );
  }

  Widget _buildLegalLinks() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _isRestoring ? null : _restorePurchases,
          child: _isRestoring
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF0A84FF),
                  ),
                )
              : Text(
                  'Restore',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF667085),
                    decoration: TextDecoration.underline,
                  ),
                ),
        ),
        const Text(' • ', style: TextStyle(color: Color(0xFF98A2B3))),
        GestureDetector(
          onTap: () => _openUrl(_termsUrl),
          child: Text(
            'Terms of Use',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF667085),
              decoration: TextDecoration.underline,
            ),
          ),
        ),
        const Text(' • ', style: TextStyle(color: Color(0xFF98A2B3))),
        GestureDetector(
          onTap: () => _openUrl(_privacyUrl),
          child: Text(
            'Privacy',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF667085),
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}
