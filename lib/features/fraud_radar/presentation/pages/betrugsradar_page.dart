import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/core/utils/validators.dart';
import 'package:my_app/features/fraud_radar/data/fraud_database.dart';
import 'package:my_app/features/fraud_radar/domain/models/call_check_result.dart';
import 'package:my_app/features/fraud_radar/domain/models/recent_check.dart';

class BetrugsradarPage extends StatefulWidget {
  const BetrugsradarPage({super.key});

  @override
  State<BetrugsradarPage> createState() => _BetrugsradarPageState();
}

class _BetrugsradarPageState extends State<BetrugsradarPage> {
  final TextEditingController _controller = TextEditingController();
  final Random _random = Random();
  static const Duration _popupDuration = Duration(seconds: 3);

  FraudDatabase? _database;
  String? _loadError;
  String? _phoneValidationError;
  CallCheckResult? _result;
  bool _showPopup = false;
  Timer? _popupHideTimer;

  bool _isIncomingCallVisible = false;
  String _simulatedNumber = '';
  bool _isChecking = false;
  CallCheckResult? _simulatedResult;

  List<RecentCheck> _recentChecks = const [
    RecentCheck(
      number: '017625443992',
      status: 'Betrug',
      category: 'Spam-Messenger',
      risk: 92,
      subtitle: 'Hohe Wahrscheinlichkeit für Betrug',
    ),
    RecentCheck(
      number: '08001824834',
      status: 'Betrug',
      category: 'Internet PopUp',
      risk: 88,
      subtitle: 'In offizieller Liste gefunden',
    ),
    RecentCheck(
      number: '015999999999',
      status: 'Safe',
      category: 'Keine Auffälligkeit',
      risk: 8,
      subtitle: 'Nicht in der Datenbank gefunden',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadDatabase();
  }

  @override
  void dispose() {
    _popupHideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _dismissPopup() {
    _popupHideTimer?.cancel();
    _popupHideTimer = null;
    if (!mounted || !_showPopup) {
      return;
    }
    setState(() {
      _showPopup = false;
    });
  }

  void _showPopupWithAutoDismiss() {
    _popupHideTimer?.cancel();
    setState(() {
      _showPopup = true;
    });

    _popupHideTimer = Timer(_popupDuration, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _showPopup = false;
      });
    });
  }

  void _validatePhoneInput([String? rawInput]) {
    final value = rawInput ?? _controller.text;
    setState(() {
      _phoneValidationError = GermanPhoneValidator.validateGermanPhoneNumber(
        value,
      );
    });
  }

  Future<void> _loadDatabase() async {
    try {
      final database = await FraudDatabase.load();
      if (!mounted) {
        return;
      }
      setState(() {
        _database = database;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadError = error.toString();
      });
    }
  }

  void _analyzeNumber() {
    final validationError = GermanPhoneValidator.validateGermanPhoneNumber(
      _controller.text,
      allowEmpty: false,
    );

    if (validationError != null) {
      setState(() {
        _phoneValidationError = validationError;
      });
      return;
    }

    if (_database == null || _controller.text.trim().isEmpty) {
      return;
    }
    final sanitizedInput = GermanPhoneValidator.sanitize(_controller.text);
    final checked = _database!.checkNumber(sanitizedInput);
    _popupHideTimer?.cancel();
    setState(() {
      _phoneValidationError = null;
      _result = checked;
      _recentChecks = [
        RecentCheck(
          number: checked.number,
          status: checked.isFraud ? 'Betrug' : 'Safe',
          category: checked.category ?? 'Keine Auffälligkeit',
          risk: checked.riskScore,
          subtitle: checked.reasonText,
        ),
        ..._recentChecks,
      ];
    });
    _showPopupWithAutoDismiss();
  }

  Future<void> _startSimulation() async {
    if (_database == null) {
      return;
    }
    const testNumbers = ['017625443992', '08001824834', '015999999999'];
    final simulatedNumber = testNumbers[_random.nextInt(testNumbers.length)];

    setState(() {
      _simulatedNumber = simulatedNumber;
      _isIncomingCallVisible = true;
      _isChecking = true;
      _simulatedResult = null;
    });

    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) {
      return;
    }

    final checked = _database!.checkNumber(simulatedNumber);
    setState(() {
      _simulatedResult = checked;
      _isChecking = false;
      _recentChecks = [
        RecentCheck(
          number: checked.number,
          status: checked.isFraud ? 'Betrug' : 'Safe',
          category: checked.category ?? 'Keine Auffälligkeit',
          risk: checked.riskScore,
          subtitle: checked.reasonText,
        ),
        ..._recentChecks,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFF1F5FF), Color(0xFFE4E8FF)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _headerView(),
                    const SizedBox(height: 14),
                    _warningBanner(),
                    const SizedBox(height: 14),
                    _statsGrid(),
                    const SizedBox(height: 14),
                    _analyzerCard(),
                    const SizedBox(height: 14),
                    _simulationCard(),
                    if (_result != null) ...[
                      const SizedBox(height: 14),
                      _resultCard(_result!),
                    ],
                    const SizedBox(height: 14),
                    _recentChecksCard(),
                    const SizedBox(height: 14),
                    _tipsCard(),
                    const SizedBox(height: 14),
                    _infoFooter(colorScheme),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              if (_showPopup && _result != null)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _dismissPopup,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                ),
              if (_showPopup && _result != null)
                Positioned(
                  top: 20,
                  left: 20,
                  right: 20,
                  child: AnimatedOpacity(
                    opacity: _showPopup ? 1 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: _analysisPopup(
                      _result!,
                      onClose: _dismissPopup,
                    ),
                  ),
                ),
              if (_isIncomingCallVisible) _incomingCallSimulationOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerView() {
    return _card(
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.indigo,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.shield, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Betrugsradar',
                style: TextStyle(
                  color: Colors.indigo,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              Text(
                'Schutz für eingehende Anrufe',
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _warningBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aktuelle Warnung',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                SizedBox(height: 4),
                Text(
                  'Neue Welle von Spam- und Messenger-Betrugsnummern erkannt.',
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsGrid() {
    final entries = _database?.entries;
    final totalChecks = entries?.length ?? 0;
    final dangerous =
        entries?.where((entry) => entry.riskScore >= 70).length ?? 0;
    final spam =
        entries
            ?.where((entry) => entry.category.toLowerCase().contains('spam'))
            .length ??
        0;
    final hacking =
        entries
            ?.where((entry) => entry.category.toLowerCase().contains('hacking'))
            .length ??
        0;

    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _statCard('Gesamtprüfungen', '$totalChecks', Icons.call, Colors.blue),
        _statCard(
          'Gefährliche Nummern',
          '$dangerous',
          Icons.gpp_bad,
          Colors.red,
        ),
        _statCard('Spam / SMS', '$spam', Icons.message, Colors.orange),
        _statCard('Hacking', '$hacking', Icons.lock, Colors.purple),
      ],
    );
  }

  Widget _analyzerCard() {
    final hasInput = _controller.text.trim().isNotEmpty;
    final isInvalidInput = hasInput && _phoneValidationError != null;
    final isDisabled = _database == null || !hasInput || isInvalidInput;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Risk Analyzer',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 21),
          ),
          const SizedBox(height: 8),
          const Text(
            'Geben Sie eine Telefonnummer ein, um zu prüfen, ob ein eingehender Anruf sicher oder verdächtig ist.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s]')),
            ],
            decoration: InputDecoration(
              hintText: 'Beispiel: 017625443992',
              helperText: 'Example: +4915123456789 or 015123456789',
              errorText: _phoneValidationError,
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isInvalidInput
                      ? Colors.red
                      : Colors.transparent,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isInvalidInput ? Colors.red : Colors.indigo,
                  width: 1.4,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 1.6),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: _validatePhoneInput,
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _quickChip(
                  'Spam-Messenger',
                  onTap: () {
                    _controller.text = '017625443992';
                    _validatePhoneInput(_controller.text);
                  },
                ),
                const SizedBox(width: 8),
                _quickChip(
                  'Internet PopUp',
                  onTap: () {
                    _controller.text = '08001824834';
                    _validatePhoneInput(_controller.text);
                  },
                ),
                const SizedBox(width: 8),
                _quickChip(
                  'Sichere Nummer',
                  onTap: () {
                    _controller.text = '015999999999';
                    _validatePhoneInput(_controller.text);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: isDisabled ? Colors.grey : Colors.indigo,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            onPressed: isDisabled ? null : _analyzeNumber,
            icon: const Icon(Icons.monitor_heart),
            label: const Text('Nummer analysieren'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _secondaryActionButton(
                  title: 'Popup schließen',
                  onTap: _dismissPopup,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _secondaryActionButton(
                  title: 'Feld leeren',
                  onTap: () {
                    setState(() {
                      _controller.clear();
                      _phoneValidationError = null;
                    });
                  },
                ),
              ),
            ],
          ),
          if (_database == null && _loadError == null)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(),
            ),
          if (_loadError != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Fehler beim Laden der Daten: $_loadError',
                style: const TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }

  Widget _simulationCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Incoming Call Simulation',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 21),
          ),
          const SizedBox(height: 8),
          const Text(
            'Simulieren Sie einen eingehenden Anruf, um zu zeigen, wie das System eine Nummer in Echtzeit überprüft.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.phone_callback, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live-Demo',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Eingehender Anruf wird automatisch analysiert',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            onPressed: _database == null ? null : _startSimulation,
            icon: const Icon(Icons.phone_in_talk),
            label: const Text('Anruf simulieren'),
          ),
        ],
      ),
    );
  }

  Widget _resultCard(CallCheckResult result) {
    final mainColor = result.isFraud ? Colors.red : Colors.green;
    final icon = result.isFraud ? Icons.gpp_bad : Icons.verified_user;
    final badgeText = result.isFraud ? 'BETRUGSVERDACHT' : 'SICHER';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: mainColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Icon(icon, size: 62, color: mainColor),
          const SizedBox(height: 8),
          Text(
            badgeText,
            style: TextStyle(
              color: mainColor,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            result.number,
            style: const TextStyle(color: Colors.black54, fontSize: 20),
          ),
          const SizedBox(height: 12),
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: mainColor.withValues(alpha: 0.12),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${result.riskScore}%',
                    style: TextStyle(
                      color: mainColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 34,
                    ),
                  ),
                  const Text('Risiko', style: TextStyle(color: Colors.black54)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow('Grund', result.reasonText),
                if (result.category != null)
                  _infoRow('Kategorie', result.category!),
                if (result.sourceYear != null)
                  _infoRow('Quelle / Jahr', '${result.sourceYear}'),
                if (result.action != null && result.action!.isNotEmpty)
                  _infoRow('Maßnahme', result.action!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _recentChecksCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Checks',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 21),
          ),
          const SizedBox(height: 10),
          ..._recentChecks.take(5).map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      item.status == 'Betrug'
                          ? Icons.dangerous
                          : Icons.check_circle,
                      color: item.status == 'Betrug' ? Colors.red : Colors.green,
                      size: 26,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.number,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            item.category,
                            style: const TextStyle(color: Colors.black54),
                          ),
                          Text(
                            item.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${item.risk}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: item.status == 'Betrug' ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tipsCard() {
    return _card(
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Tips',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 21),
          ),
          SizedBox(height: 10),
          _TipRow('Keine unbekannten Nummern zurückrufen.'),
          _TipRow('Bei Bank- oder Zahlungsforderungen immer direkt prüfen.'),
          _TipRow('Verdächtige Nummern blockieren und melden.'),
        ],
      ),
    );
  }

  Widget _infoFooter(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hinweis', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text(
            'Diese Ansicht ist eine Simulation auf Basis geladener Betrugsdaten. Die Incoming-Call-Ansicht demonstriert, wie eine Echtzeit-Erkennung in einer realen Umgebung aussehen könnte.',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _analysisPopup(CallCheckResult result, {required VoidCallback onClose}) {
    return Material(
      elevation: 10,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Analyse abgeschlossen',
                    style: TextStyle(color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: onClose,
                  borderRadius: BorderRadius.circular(999),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, color: Colors.black54, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              result.number,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
            ),
            const SizedBox(height: 10),
            Icon(
              result.isFraud ? Icons.warning : Icons.verified,
              color: result.isFraud ? Colors.red : Colors.green,
              size: 54,
            ),
            const SizedBox(height: 8),
            Text(
              result.isFraud ? 'Betrugsverdacht' : 'Sicher',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: result.isFraud ? Colors.red : Colors.green,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              result.reasonText,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _incomingCallSimulationOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 22),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(34),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '📞 Eingehender Anruf',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 8),
              Text(
                _simulatedNumber,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              if (_isChecking)
                const Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text('Wird überprüft...'),
                  ],
                )
              else if (_simulatedResult != null)
                Column(
                  children: [
                    Icon(
                      _simulatedResult!.isFraud
                          ? Icons.warning
                          : Icons.verified,
                      size: 60,
                      color: _simulatedResult!.isFraud
                          ? Colors.red
                          : Colors.green,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _simulatedResult!.isFraud
                          ? 'Betrugsverdacht'
                          : 'Sicherer Anruf',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _simulatedResult!.isFraud
                            ? Colors.red
                            : Colors.green,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _simulatedResult!.reasonText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    if (_simulatedResult!.category != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (_simulatedResult!.isFraud
                                      ? Colors.red
                                      : Colors.green)
                                  .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _simulatedResult!.category!,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                        minimumSize: const Size.fromHeight(52),
                      ),
                      onPressed: () {
                        setState(() {
                          _isIncomingCallVisible = false;
                        });
                      },
                      child: const Text('Ablehnen'),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                        minimumSize: const Size.fromHeight(52),
                      ),
                      onPressed: () {
                        setState(() {
                          _isIncomingCallVisible = false;
                        });
                      },
                      child: const Text('Annehmen'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
          ),
          Text(title, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _quickChip(String title, {required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _secondaryActionButton({
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.indigo.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.indigo,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified, color: Colors.indigo),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.black54)),
          ),
        ],
      ),
    );
  }
}
