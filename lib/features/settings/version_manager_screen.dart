import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/phase_constants.dart';
import '../../core/services/deepseek_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/telemetry_service.dart';

// ── Firebase Realtime Database REST endpoints ────────────────────────────────
const _dbBase =
    'https://luna-8ce40-default-rtdb.asia-southeast1.firebasedatabase.app/luna/versions';

class VersionManagerScreen extends StatefulWidget {
  final PhaseColors colors;
  final VoidCallback onClose;
  const VersionManagerScreen(
      {super.key, required this.colors, required this.onClose});

  @override
  State<VersionManagerScreen> createState() => _VersionManagerScreenState();
}

class _VersionManagerScreenState extends State<VersionManagerScreen> {
  List<_VersionEntry> _versions = [];
  bool _loading = true;
  bool _timedOut = false;
  String? _error;

  // Admin Mode state (unlocked by tapping title 5 times)
  bool _isAdmin = false;
  int _tapCount = 0;
  DateTime? _lastTapTime;

  // Telemetry state
  TokenMetrics _metrics = TokenMetrics.empty();
  bool _loadingMetrics = false;

  // Remote API Key state
  final _apiKeyCtrl = TextEditingController();
  bool _loadingApiKey = false;
  bool _obscureKey = true;

  // Remote AI Persona state (Admin)
  final _personaInstructionsCtrl = TextEditingController();
  final _personaChatRulesCtrl = TextEditingController();
  double _personaTemperature = 0.65;
  bool _loadingPersona = false;
  bool _savingPersona = false;

  // Add Version Form state
  bool _showAddForm = false;
  final _verCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  bool _publishing = false;

  // Download state
  bool _isDownloading = false;
  String _downloadingId = '';
  double _downloadProgress = 0;

  @override
  void initState() {
    super.initState();
    _fetchVersions();
    _apiKeyCtrl.text = DeepSeekService.apiKey;
    final initialPersona = StorageService.getAiPersona();
    _personaInstructionsCtrl.text = initialPersona.systemInstructions;
    _personaChatRulesCtrl.text = initialPersona.chatRules;
    _personaTemperature = initialPersona.temperature;
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _personaInstructionsCtrl.dispose();
    _personaChatRulesCtrl.dispose();
    _verCtrl.dispose();
    _descCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  // ── Secret 5-Tap Admin Unlock ─────────────────────────────────────────────
  void _onTitleTap() {
    final now = DateTime.now();
    if (_lastTapTime == null || now.difference(_lastTapTime!).inSeconds > 2) {
      _tapCount = 1;
    } else {
      _tapCount++;
    }
    _lastTapTime = now;

    if (_tapCount >= 5) {
      _tapCount = 0;
      HapticFeedback.heavyImpact();
      setState(() => _isAdmin = !_isAdmin);
      _showSnack(_isAdmin ? 'Admin Mode Unlocked 🛠️' : 'Admin Mode Closed');
      if (_isAdmin) {
        _fetchTelemetry();
        _fetchRemoteKey();
        _fetchRemotePersona();
      }
    } else if (_tapCount >= 3) {
      HapticFeedback.selectionClick();
    }
  }

  // ── Fetch Telemetry Metrics ───────────────────────────────────────────────
  Future<void> _fetchTelemetry() async {
    setState(() => _loadingMetrics = true);
    final metrics = await TelemetryService.fetchTokenMetrics();
    if (mounted) {
      setState(() {
        _metrics = metrics;
        _loadingMetrics = false;
      });
    }
  }

  // ── Fetch Remote API Key ──────────────────────────────────────────────────
  Future<void> _fetchRemoteKey() async {
    setState(() => _loadingApiKey = true);
    final key = await TelemetryService.fetchRemoteApiKey();
    if (mounted) {
      setState(() {
        if (key != null && key.isNotEmpty) {
          _apiKeyCtrl.text = key;
        } else {
          _apiKeyCtrl.text = DeepSeekService.apiKey;
        }
        _loadingApiKey = false;
      });
    }
  }

  // ── Save Remote API Key ───────────────────────────────────────────────────
  Future<void> _saveRemoteKey() async {
    final key = _apiKeyCtrl.text.trim();
    if (key.isEmpty) {
      _showSnack('Please enter a valid key');
      return;
    }

    setState(() => _loadingApiKey = true);
    // Always save locally immediately so AI works on this device right away
    DeepSeekService.setApiKey(key);

    final success = await TelemetryService.updateRemoteApiKey(key);
    if (success) {
      _showSnack('API key active & synced to all devices ✓');
    } else {
      _showSnack('API key saved locally on this device ✓');
    }
    if (mounted) setState(() => _loadingApiKey = false);
  }

  // ── Fetch Remote AI Persona ───────────────────────────────────────────────
  Future<void> _fetchRemotePersona() async {
    setState(() => _loadingPersona = true);
    final persona = await TelemetryService.fetchRemoteAiPersona();
    if (mounted) {
      setState(() {
        if (persona != null) {
          _personaInstructionsCtrl.text = persona.systemInstructions;
          _personaChatRulesCtrl.text = persona.chatRules;
          _personaTemperature = persona.temperature;
          StorageService.saveAiPersona(persona);
        }
        _loadingPersona = false;
      });
    }
  }

  // ── Save Remote AI Persona ────────────────────────────────────────────────
  Future<void> _saveRemotePersona() async {
    final instructions = _personaInstructionsCtrl.text.trim();
    final rules = _personaChatRulesCtrl.text.trim();
    if (instructions.isEmpty || rules.isEmpty) {
      _showSnack('Instructions and rules cannot be empty');
      return;
    }

    setState(() => _savingPersona = true);
    final current = StorageService.getAiPersona();
    final updatedConfig = AiPersonaConfig(
      systemInstructions: instructions,
      chatRules: rules,
      temperature: _personaTemperature,
      forbiddenPhrases: current.forbiddenPhrases,
      version: '1.${DateTime.now().millisecondsSinceEpoch}',
    );

    // Save locally immediately
    await StorageService.saveAiPersona(updatedConfig);

    final success = await TelemetryService.updateRemoteAiPersona(updatedConfig);
    if (success) {
      _showSnack('AI Persona updated & live to all users! 🧠✨');
    } else {
      _showSnack('AI Persona saved locally on this device ✓');
    }
    if (mounted) setState(() => _savingPersona = false);
  }

  // ── Open Link in External Browser ────────────────────────────────────────
  Future<void> _openInBrowser(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      _showSnack('No URL provided');
      return;
    }
    try {
      final uri = Uri.parse(trimmed);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri);
      }
    } catch (e) {
      _showSnack('Could not open in browser: $e');
    }
  }

  // ── Fetch versions from Firebase REST API ─────────────────────────────────
  Future<void> _fetchVersions() async {
    setState(() {
      _loading = true;
      _timedOut = false;
      _error = null;
    });
    try {
      final res = await http
          .get(Uri.parse('$_dbBase.json'))
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        if (body == null) {
          setState(() {
            _versions = [];
            _loading = false;
          });
          return;
        }
        final data = Map<String, dynamic>.from(body as Map);
        final list = data.entries.map((e) {
          final v = Map<String, dynamic>.from(e.value as Map);
          return _VersionEntry(
            id: e.key,
            version: v['version'] as String? ?? '',
            description: v['description'] as String? ?? '',
            url: v['url'] as String? ?? '',
            date: v['date'] as String? ?? '',
          );
        }).toList();

        // Sort semantically (e.g., v1.1.0 > v1.0.9)
        list.sort((a, b) {
          final RegExp semverRegExp = RegExp(r'v?(\d+)\.(\d+)\.(\d+)');
          final matchA = semverRegExp.firstMatch(a.version);
          final matchB = semverRegExp.firstMatch(b.version);

          if (matchA != null && matchB != null) {
            final aMajor = int.parse(matchA.group(1)!);
            final aMinor = int.parse(matchA.group(2)!);
            final aPatch = int.parse(matchA.group(3)!);

            final bMajor = int.parse(matchB.group(1)!);
            final bMinor = int.parse(matchB.group(2)!);
            final bPatch = int.parse(matchB.group(3)!);

            if (aMajor != bMajor) return bMajor.compareTo(aMajor);
            if (aMinor != bMinor) return bMinor.compareTo(aMinor);
            if (aPatch != bPatch) return bPatch.compareTo(aPatch);
          }
          return b.date.compareTo(a.date);
        });

        setState(() {
          _versions = list;
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Server error ${res.statusCode}';
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      final isTimeout = e.toString().contains('TimeoutException') ||
          e.toString().contains('SocketException');
      setState(() {
        _timedOut = isTimeout;
        _error = isTimeout ? null : e.toString().split('\n').first;
        _loading = false;
      });
    }
  }

  // ── Publish new version (Admin) ───────────────────────────────────────────
  Future<void> _publishVersion() async {
    final ver = _verCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    final url = _urlCtrl.text.trim();

    if (ver.isEmpty || url.isEmpty) {
      _showSnack('Version and download URL are required');
      return;
    }

    setState(() => _publishing = true);
    try {
      final id = 'v_${DateTime.now().millisecondsSinceEpoch}';
      final res = await http.put(
        Uri.parse('$_dbBase/$id.json'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'version': ver,
          'description': desc,
          'url': url,
          'date': DateTime.now().toIso8601String(),
        }),
      );

      if (res.statusCode == 200) {
        _verCtrl.clear();
        _descCtrl.clear();
        _urlCtrl.clear();
        setState(() => _showAddForm = false);
        _showSnack('$ver published successfully! 🎉');
        await _fetchVersions();
      } else {
        _showSnack('Failed to publish: HTTP ${res.statusCode}');
      }
    } catch (e) {
      _showSnack('Publish error: ${e.toString().split('\n').first}');
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  // ── Edit version (Admin) ──────────────────────────────────────────────────
  Future<void> _editVersion(
      _VersionEntry entry, String newVer, String newDesc, String newUrl) async {
    try {
      final res = await http.patch(
        Uri.parse('$_dbBase/${entry.id}.json'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'version': newVer,
          'description': newDesc,
          'url': newUrl,
        }),
      );

      if (res.statusCode == 200) {
        _showSnack('Version updated ✓');
        await _fetchVersions();
      } else {
        _showSnack('Failed to update: ${res.statusCode}');
      }
    } catch (e) {
      _showSnack('Error updating: $e');
    }
  }

  // ── Delete version (Admin) ────────────────────────────────────────────────
  Future<void> _deleteVersion(_VersionEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Delete ${entry.version}?',
            style: GoogleFonts.cormorantGaramond(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: widget.colors.onSurface)),
        content: Text('This will remove it from Firebase permanently.',
            style: GoogleFonts.dmSans(
                fontSize: 13,
                color: widget.colors.onSurface.withValues(alpha: 0.6))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: GoogleFonts.dmSans(
                    color: widget.colors.onSurface.withValues(alpha: 0.4))),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete',
                style: GoogleFonts.dmSans(
                    color: Colors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await http.delete(Uri.parse('$_dbBase/${entry.id}.json'));
      if (res.statusCode == 200) {
        _showSnack('${entry.version} deleted');
        await _fetchVersions();
      } else {
        _showSnack('Failed to delete: ${res.statusCode}');
      }
    } catch (e) {
      _showSnack('Delete error: $e');
    }
  }

  // ── Download + install APK ────────────────────────────────────────────────
  Future<void> _downloadAndInstall(_VersionEntry ver) async {
    if (ver.url.isEmpty) return;

    if (Platform.isAndroid) {
      final status = await Permission.requestInstallPackages.request();
      if (!status.isGranted) {
        _showSnack('Enable "Install unknown apps" in settings first');
        return;
      }
    }

    setState(() {
      _isDownloading = true;
      _downloadingId = ver.id;
      _downloadProgress = 0;
    });

    try {
      final dir = await getTemporaryDirectory();
      final safeName =
          'Luna_${ver.version.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.apk';
      final file = File('${dir.path}/$safeName');

      final request = http.Request('GET', Uri.parse(ver.url));
      final response = await http.Client().send(request);
      final total = response.contentLength ?? 0;
      int received = 0;

      final sink = file.openWrite();
      await response.stream.forEach((chunk) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0 && mounted) {
          setState(() => _downloadProgress = received / total);
        }
      });
      await sink.close();

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0;
        });
        await OpenFilex.open(file.path,
            type: 'application/vnd.android.package-archive');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0;
        });
        _showSnack('Download failed: ${e.toString().split('\n').first}');
      }
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.dmSans(fontSize: 13)),
        backgroundColor: const Color(0xFF2A1F3D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
              child: Row(children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios_rounded,
                      size: 18, color: c.onSurface.withValues(alpha: 0.45)),
                  onPressed: widget.onClose,
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _onTitleTap,
                  child: Column(children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Luna Updates',
                            style: GoogleFonts.cormorantGaramond(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: c.onSurface)),
                        if (_isAdmin) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.amber.withValues(alpha: 0.4)),
                            ),
                            child: Text('ADMIN',
                                style: GoogleFonts.dmSans(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.amber)),
                          ),
                        ],
                      ],
                    ),
                    Text(
                        _isAdmin
                            ? 'Admin console active'
                            : 'tap a version to install',
                        style: GoogleFonts.dmSans(
                            fontSize: 10,
                            color: _isAdmin
                                ? Colors.amber.withValues(alpha: 0.7)
                                : c.onSurface.withValues(alpha: 0.3))),
                  ]),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.refresh_rounded,
                      size: 20, color: c.onSurface.withValues(alpha: 0.4)),
                  onPressed: () {
                    _fetchVersions();
                    if (_isAdmin) {
                      _fetchTelemetry();
                      _fetchRemoteKey();
                      _fetchRemotePersona();
                    }
                  },
                ),
              ]),
            ),

            // ── Download progress banner ──────────────────────────────────
            if (_isDownloading)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: c.primary.withValues(alpha: 0.25)),
                  ),
                  child: Column(children: [
                    Row(children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            value:
                                _downloadProgress > 0 ? _downloadProgress : null,
                            strokeWidth: 2,
                            color: c.accent),
                      ),
                      const SizedBox(width: 12),
                      Text(
                          _downloadProgress > 0
                              ? 'Downloading ${(_downloadProgress * 100).toStringAsFixed(0)}%  —  hang tight'
                              : 'Downloading...',
                          style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: c.onSurface)),
                    ]),
                    if (_downloadProgress > 0) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _downloadProgress,
                          backgroundColor: c.onSurface.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(c.accent),
                          minHeight: 3,
                        ),
                      ),
                    ],
                  ]),
                ),
              ),

            // ── Main Content Area ─────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 60),
                children: [
                  // ── ADMIN SECTION ─────────────────────────────────────────
                  if (_isAdmin) ...[
                    // 1. AI Token Consumption Telemetry
                    _AdminTelemetryCard(
                      metrics: _metrics,
                      loading: _loadingMetrics,
                      colors: c,
                      onRefresh: _fetchTelemetry,
                    ),
                    const SizedBox(height: 16),

                    // 2. Active Remote API Key Management
                    _AdminApiKeyCard(
                      ctrl: _apiKeyCtrl,
                      loading: _loadingApiKey,
                      obscure: _obscureKey,
                      colors: c,
                      onToggleObscure: () =>
                          setState(() => _obscureKey = !_obscureKey),
                      onSave: _saveRemoteKey,
                    ),
                    const SizedBox(height: 16),

                    // 3. Remote AI Persona & Behaviour Management
                    _AdminAiPersonaCard(
                      instructionsCtrl: _personaInstructionsCtrl,
                      chatRulesCtrl: _personaChatRulesCtrl,
                      temperature: _personaTemperature,
                      onTemperatureChanged: (v) =>
                          setState(() => _personaTemperature = v),
                      loading: _loadingPersona,
                      saving: _savingPersona,
                      colors: c,
                      onRefresh: _fetchRemotePersona,
                      onSave: _saveRemotePersona,
                    ),
                    const SizedBox(height: 16),

                    // 4. Add Version Trigger
                    GestureDetector(
                      onTap: () => setState(() => _showAddForm = !_showAddForm),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: c.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: c.primary.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                                _showAddForm
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.add_rounded,
                                size: 18,
                                color: c.accent),
                            const SizedBox(width: 8),
                            Text(
                              _showAddForm
                                  ? 'Close Add Build Form'
                                  : '+ Add New Release Build',
                              style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: c.accent),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (_showAddForm) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: c.surface.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: c.onSurface.withValues(alpha: 0.08)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Publish New Release',
                                style: GoogleFonts.cormorantGaramond(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: c.onSurface)),
                            const SizedBox(height: 12),
                            _AdminField(
                                ctrl: _verCtrl,
                                hint: 'Version tag (e.g. v1.0.1)',
                                colors: c),
                            const SizedBox(height: 8),
                            _AdminField(
                                ctrl: _descCtrl,
                                hint: 'Release highlights / changelog',
                                colors: c,
                                maxLines: 2),
                            const SizedBox(height: 8),
                            _AdminField(
                                ctrl: _urlCtrl,
                                hint: 'Direct APK download URL',
                                colors: c),
                            const SizedBox(height: 14),
                            GestureDetector(
                              onTap: _publishing ? null : _publishVersion,
                              child: Container(
                                width: double.infinity,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                      colors: [c.primary, c.secondary]),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: _publishing
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white))
                                      : Text('Publish Version to Firebase 🚀',
                                          style: GoogleFonts.dmSans(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Text('DISTRIBUTED BUILDS',
                            style: GoogleFonts.dmSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: c.onSurface.withValues(alpha: 0.35),
                                letterSpacing: 1.2)),
                        const Spacer(),
                        Text('${_versions.length} versions',
                            style: GoogleFonts.dmSans(
                                fontSize: 11,
                                color: c.onSurface.withValues(alpha: 0.35))),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── VERSIONS LIST ──────────────────────────────────────────
                  if (_loading)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Column(children: [
                          SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: c.accent)),
                          const SizedBox(height: 14),
                          Text('Checking for updates...',
                              style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color:
                                      c.onSurface.withValues(alpha: 0.35))),
                        ]),
                      ),
                    )
                  else if (_timedOut)
                    _EmptyState(
                        emoji: '📵',
                        title: 'No internet connection',
                        subtitle:
                            'Connect to Wi-Fi or mobile data to fetch updates',
                        colors: c,
                        onRetry: _fetchVersions)
                  else if (_error != null)
                    _EmptyState(
                        emoji: '⚠️',
                        title: 'Something went wrong',
                        subtitle: _error!,
                        colors: c,
                        onRetry: _fetchVersions)
                  else if (_versions.isEmpty)
                    _EmptyState(
                        emoji: '🌙',
                        title: 'No updates yet',
                        subtitle: "You're on the latest build",
                        colors: c)
                  else
                    ..._versions.asMap().entries.map((entry) {
                      final i = entry.key;
                      final ver = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _VersionCard(
                          ver: ver,
                          colors: c,
                          isAdmin: _isAdmin,
                          isDownloading:
                              _isDownloading && _downloadingId == ver.id,
                          downloadProgress: _downloadingId == ver.id
                              ? _downloadProgress
                              : 0,
                          isLatest: i == 0,
                          onInstall: () => _downloadAndInstall(ver),
                          onOpenBrowser: () => _openInBrowser(ver.url),
                          onEdit: (v, d, u) => _editVersion(ver, v, d, u),
                          onDelete: () => _deleteVersion(ver),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Admin Telemetry Card ──────────────────────────────────────────────────────
class _AdminTelemetryCard extends StatelessWidget {
  final TokenMetrics metrics;
  final bool loading;
  final PhaseColors colors;
  final VoidCallback onRefresh;

  const _AdminTelemetryCard({
    required this.metrics,
    required this.loading,
    required this.colors,
    required this.onRefresh,
  });

  String _formatNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(2)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    final c = colors;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('⚡', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                'AI Usage & Token Consumption',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: c.onSurface,
                ),
              ),
              const Spacer(),
              if (loading)
                const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.amber))
              else
                GestureDetector(
                  onTap: onRefresh,
                  child: Icon(Icons.refresh_rounded,
                      size: 16, color: Colors.amber.withValues(alpha: 0.8)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Aggregated telemetry reported from all installed devices',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: c.onSurface.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 14),

          // 3 Metric Stat Pillars
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  title: 'TODAY',
                  value: _formatNum(metrics.todayTokens),
                  subtitle: '${metrics.todayRequests} requests',
                  accentColor: Colors.amber,
                  colors: c,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTile(
                  title: 'THIS WEEK',
                  value: _formatNum(metrics.weekTokens),
                  subtitle: 'past 7 days',
                  accentColor: c.accent,
                  colors: c,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTile(
                  title: 'ALL-TIME',
                  value: _formatNum(metrics.totalTokens),
                  subtitle: '~\$${metrics.estimatedCostUsd.toStringAsFixed(3)}',
                  accentColor: const Color(0xFF4CAF87),
                  colors: c,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color accentColor;
  final PhaseColors colors;

  const _MetricTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accentColor,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: colors.background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: accentColor,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.dmSans(
              fontSize: 10,
              color: colors.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Admin API Key Card ────────────────────────────────────────────────────────
class _AdminApiKeyCard extends StatelessWidget {
  final TextEditingController ctrl;
  final bool loading;
  final bool obscure;
  final PhaseColors colors;
  final VoidCallback onToggleObscure;
  final VoidCallback onSave;

  const _AdminApiKeyCard({
    required this.ctrl,
    required this.loading,
    required this.obscure,
    required this.colors,
    required this.onToggleObscure,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🔑', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text('Active DeepSeek API Key',
                  style: GoogleFonts.cormorantGaramond(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: c.onSurface)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Syncs via Firebase RTDB to all app users without exposing keys in git',
            style: GoogleFonts.dmSans(
                fontSize: 11, color: c.onSurface.withValues(alpha: 0.45)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            obscureText: obscure,
            style: GoogleFonts.dmSans(fontSize: 13, color: c.onSurface),
            decoration: InputDecoration(
              filled: true,
              fillColor: c.background.withValues(alpha: 0.6),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.accent, width: 1.5)),
              hintText: 'sk-xxxxxxxxxxxxxxxxxxxxxxxx',
              hintStyle: TextStyle(
                  fontSize: 12, color: c.onSurface.withValues(alpha: 0.3)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              suffixIcon: IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_off : Icons.visibility,
                  size: 16,
                  color: c.onSurface.withValues(alpha: 0.4),
                ),
                onPressed: onToggleObscure,
              ),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: loading ? null : onSave,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: c.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.primary.withValues(alpha: 0.4)),
              ),
              child: Center(
                child: loading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(
                        'Sync Key to All Devices 🚀',
                        style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: c.accent),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Admin AI Persona & Behaviour Card ─────────────────────────────────────────
class _AdminAiPersonaCard extends StatefulWidget {
  final TextEditingController instructionsCtrl;
  final TextEditingController chatRulesCtrl;
  final double temperature;
  final ValueChanged<double> onTemperatureChanged;
  final bool loading;
  final bool saving;
  final PhaseColors colors;
  final VoidCallback onRefresh;
  final VoidCallback onSave;

  const _AdminAiPersonaCard({
    required this.instructionsCtrl,
    required this.chatRulesCtrl,
    required this.temperature,
    required this.onTemperatureChanged,
    required this.loading,
    required this.saving,
    required this.colors,
    required this.onRefresh,
    required this.onSave,
  });

  @override
  State<_AdminAiPersonaCard> createState() => _AdminAiPersonaCardState();
}

class _AdminAiPersonaCardState extends State<_AdminAiPersonaCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: const Color(0xFF9C27B0).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🧠', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cloud AI Persona & Behaviour',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: c.onSurface,
                  ),
                ),
              ),
              if (widget.loading)
                const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFFCE93D8)))
              else
                GestureDetector(
                  onTap: widget.onRefresh,
                  child: Icon(Icons.refresh_rounded,
                      size: 16,
                      color: const Color(0xFFCE93D8).withValues(alpha: 0.8)),
                ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: c.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Updates AI personality, tone, & guardrails live across all app installs without rebuilding APKs',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: c.onSurface.withValues(alpha: 0.45),
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 14),
            Text(
              'SYSTEM INSTRUCTIONS (TONE & IDENTITY)',
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFCE93D8),
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            _AdminField(
              ctrl: widget.instructionsCtrl,
              hint: 'Base persona and core identity instructions',
              colors: c,
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            Text(
              'CONVERSATIONAL RULES & BOUNDARIES',
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFCE93D8),
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            _AdminField(
              ctrl: widget.chatRulesCtrl,
              hint:
                  'Specific conversational rules, greeting behaviors, and anti-robot guardrails',
              colors: c,
              maxLines: 6,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'TEMPERATURE: ${widget.temperature.toStringAsFixed(2)}',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFCE93D8),
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                Text(
                  widget.temperature <= 0.4
                      ? 'Precise & Clinical'
                      : widget.temperature <= 0.7
                          ? 'Empathetic & Natural (Default)'
                          : 'Creative & Spontaneous',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    color: c.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: const Color(0xFFAB47BC),
                inactiveTrackColor: c.onSurface.withValues(alpha: 0.1),
                thumbColor: const Color(0xFFCE93D8),
                overlayColor: const Color(0xFFAB47BC).withValues(alpha: 0.2),
                trackHeight: 2.5,
              ),
              child: Slider(
                value: widget.temperature,
                min: 0.1,
                max: 1.0,
                divisions: 18,
                onChanged: widget.onTemperatureChanged,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: widget.saving ? null : widget.onSave,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8E24AA), Color(0xFFAB47BC)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8E24AA).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: widget.saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(
                          'Sync Persona to All Devices 🧠🚀',
                          style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Version Card (with Admin Edit/Delete support) ─────────────────────────────
class _VersionCard extends StatefulWidget {
  final _VersionEntry ver;
  final PhaseColors colors;
  final bool isAdmin;
  final bool isDownloading;
  final double downloadProgress;
  final bool isLatest;
  final VoidCallback onInstall;
  final VoidCallback onOpenBrowser;
  final Function(String ver, String desc, String url) onEdit;
  final VoidCallback onDelete;

  const _VersionCard({
    required this.ver,
    required this.colors,
    required this.isAdmin,
    required this.isDownloading,
    required this.downloadProgress,
    required this.isLatest,
    required this.onInstall,
    required this.onOpenBrowser,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_VersionCard> createState() => _VersionCardState();
}

class _VersionCardState extends State<_VersionCard> {
  bool _editing = false;
  late TextEditingController _editVer;
  late TextEditingController _editDesc;
  late TextEditingController _editUrl;

  @override
  void initState() {
    super.initState();
    _editVer = TextEditingController(text: widget.ver.version);
    _editDesc = TextEditingController(text: widget.ver.description);
    _editUrl = TextEditingController(text: widget.ver.url);
  }

  @override
  void dispose() {
    _editVer.dispose();
    _editDesc.dispose();
    _editUrl.dispose();
    super.dispose();
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  String _formatDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso);
      return '${d.day} ${_months[d.month - 1]} ${d.year}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final dateStr = _formatDate(widget.ver.date);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isLatest
              ? c.primary.withValues(alpha: 0.3)
              : c.onSurface.withValues(alpha: 0.05),
        ),
      ),
      child: _editing
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('Edit ${widget.ver.version}',
                      style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: c.onSurface)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() => _editing = false),
                  ),
                ]),
                const SizedBox(height: 8),
                _AdminField(ctrl: _editVer, hint: 'Version tag', colors: c),
                const SizedBox(height: 6),
                _AdminField(
                    ctrl: _editDesc,
                    hint: 'Description',
                    colors: c,
                    maxLines: 2),
                const SizedBox(height: 6),
                _AdminField(
                    ctrl: _editUrl, hint: 'Download APK URL', colors: c),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          widget.onEdit(
                            _editVer.text.trim(),
                            _editDesc.text.trim(),
                            _editUrl.text.trim(),
                          );
                          setState(() => _editing = false);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: c.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text('Save Changes',
                                style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  if (widget.isLatest)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: c.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10)),
                      child: Text('LATEST',
                          style: GoogleFonts.dmSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: c.accent,
                              letterSpacing: 1)),
                    ),
                  Text(widget.ver.version,
                      style: GoogleFonts.dmSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: c.onSurface)),
                  const Spacer(),
                  if (dateStr.isNotEmpty)
                    Text(dateStr,
                        style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: c.onSurface.withValues(alpha: 0.3))),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: widget.onOpenBrowser,
                    child: Tooltip(
                      message: 'Open download in browser',
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: c.surface.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: c.onSurface.withValues(alpha: 0.08)),
                        ),
                        child: Icon(Icons.open_in_browser_rounded,
                            size: 14, color: c.accent),
                      ),
                    ),
                  ),
                  if (widget.isAdmin) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _editing = true),
                      child: Icon(Icons.edit_outlined,
                          size: 16, color: c.accent.withValues(alpha: 0.7)),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: widget.onDelete,
                      child: Icon(Icons.delete_outline_rounded,
                          size: 16, color: Colors.red.withValues(alpha: 0.6)),
                    ),
                  ],
                ]),

                if (widget.ver.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(widget.ver.description,
                      style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: c.onSurface.withValues(alpha: 0.4),
                          height: 1.5)),
                ],

                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: widget.isDownloading ? null : widget.onInstall,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            gradient: widget.isDownloading
                                ? null
                                : LinearGradient(colors: [
                                    c.primary.withValues(alpha: 0.85),
                                    c.secondary.withValues(alpha: 0.85)
                                  ]),
                            color: widget.isDownloading
                                ? c.primary.withValues(alpha: 0.08)
                                : null,
                            borderRadius: BorderRadius.circular(14),
                            border: widget.isDownloading
                                ? Border.all(
                                    color: c.primary.withValues(alpha: 0.2))
                                : null,
                          ),
                          child: Center(
                            child: widget.isDownloading
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: c.accent,
                                              value: widget.downloadProgress > 0
                                                  ? widget.downloadProgress
                                                  : null)),
                                      const SizedBox(width: 10),
                                      Text(
                                          widget.downloadProgress > 0
                                              ? 'Downloading ${(widget.downloadProgress * 100).toStringAsFixed(0)}%'
                                              : 'Starting...',
                                          style: GoogleFonts.dmSans(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: c.accent)),
                                    ],
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.download_rounded,
                                          size: 16, color: Colors.white),
                                      const SizedBox(width: 8),
                                      Text('Install APK',
                                          style: GoogleFonts.dmSans(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white)),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: widget.onOpenBrowser,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(
                          color: c.surface.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: c.onSurface.withValues(alpha: 0.12)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.open_in_new_rounded,
                                size: 15, color: c.accent),
                            const SizedBox(width: 6),
                            Text('Browser',
                                style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: c.onSurface)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

// ── Admin text field ──────────────────────────────────────────────────────────
class _AdminField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final PhaseColors colors;
  final int maxLines;

  const _AdminField({
    required this.ctrl,
    required this.hint,
    required this.colors,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: GoogleFonts.dmSans(fontSize: 13, color: colors.onSurface),
      decoration: InputDecoration(
        filled: true,
        fillColor: colors.background.withValues(alpha: 0.6),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colors.accent, width: 1.5)),
        hintText: hint,
        hintStyle: TextStyle(
            fontSize: 12, color: colors.onSurface.withValues(alpha: 0.28)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

// ── Empty / error state ───────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final PhaseColors colors;
  final VoidCallback? onRetry;

  const _EmptyState({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.colors,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 14),
          Text(title,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: c.onSurface)),
          const SizedBox(height: 5),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: c.onSurface.withValues(alpha: 0.38),
                  height: 1.5)),
          if (onRetry != null) ...[
            const SizedBox(height: 22),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                decoration: BoxDecoration(
                  color: c.surface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Try again',
                    style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: c.onSurface.withValues(alpha: 0.55))),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────────────
class _VersionEntry {
  final String id;
  final String version;
  final String description;
  final String url;
  final String date;

  const _VersionEntry({
    required this.id,
    required this.version,
    required this.description,
    required this.url,
    required this.date,
  });
}
