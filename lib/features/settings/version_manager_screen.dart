import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/phase_constants.dart';

// ── Firebase Realtime Database REST endpoint ──────────────────────────────────
const _dbBase = 'https://luna-8ce40-default-rtdb.asia-southeast1.firebasedatabase.app/luna/versions';

class VersionManagerScreen extends StatefulWidget {
  final PhaseColors colors;
  final VoidCallback onClose;
  const VersionManagerScreen({super.key, required this.colors, required this.onClose});

  @override
  State<VersionManagerScreen> createState() => _VersionManagerScreenState();
}

class _VersionManagerScreenState extends State<VersionManagerScreen> {
  List<_VersionEntry> _versions = [];
  bool _loading = true;
  bool _timedOut = false;
  String? _error;

  // Admin mode (unlocked by tapping ❓ 5×)
  bool _isAdmin = false;
  int _helpTapCount = 0;
  bool _showHelp = false;

  // Download state
  bool _isDownloading = false;
  String _downloadingId = '';
  double _downloadProgress = 0;

  // Admin form
  final _verCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchVersions();
  }

  @override
  void dispose() {
    _verCtrl.dispose();
    _descCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  // ── Fetch versions from Firebase REST API ─────────────────────────────────
  Future<void> _fetchVersions() async {
    setState(() { _loading = true; _timedOut = false; _error = null; });
    try {
      final res = await http
          .get(Uri.parse('$_dbBase.json'))
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        if (body == null) {
          setState(() { _versions = []; _loading = false; });
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
        list.sort((a, b) => b.date.compareTo(a.date)); // newest first
        setState(() { _versions = list; _loading = false; });
      } else {
        setState(() { _error = 'Server error ${res.statusCode}'; _loading = false; });
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

  // ── Publish new version (admin only) ─────────────────────────────────────
  Future<void> _publishVersion() async {
    final version = _verCtrl.text.trim();
    final url = _urlCtrl.text.trim();
    if (version.isEmpty || url.isEmpty) {
      _showSnack('Version and URL are required');
      return;
    }
    try {
      final payload = json.encode({
        'version': version,
        'description': _descCtrl.text.trim(),
        'url': url,
        'date': DateTime.now().toIso8601String(),
      });
      final res = await http
          .post(Uri.parse('$_dbBase.json'),
              headers: {'Content-Type': 'application/json'}, body: payload)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200 || res.statusCode == 201) {
        _verCtrl.clear(); _descCtrl.clear(); _urlCtrl.clear();
        _showSnack('Published ✓');
        _fetchVersions();
      } else {
        _showSnack('Error ${res.statusCode}');
      }
    } catch (e) {
      _showSnack('Failed: ${e.toString().split('\n').first}');
    }
  }

  // ── Delete version (admin only) ───────────────────────────────────────────
  Future<void> _deleteVersion(String id) async {
    await http.delete(Uri.parse('$_dbBase/$id.json'));
    _fetchVersions();
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

    setState(() { _isDownloading = true; _downloadingId = ver.id; _downloadProgress = 0; });

    try {
      final dir = await getTemporaryDirectory();
      final safeName = 'Luna_${ver.version.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.apk';
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
        setState(() { _isDownloading = false; _downloadProgress = 0; });
        await OpenFilex.open(file.path, type: 'application/vnd.android.package-archive');
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isDownloading = false; _downloadProgress = 0; });
        _showSnack('Download failed: ${e.toString().split('\n').first}');
      }
    }
  }

  void _onHelpTap() {
    final n = _helpTapCount + 1;
    if (n >= 5) {
      setState(() { _isAdmin = true; _helpTapCount = 0; _showHelp = false; });
    } else {
      setState(() { _helpTapCount = n; _showHelp = !_showHelp; });
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

  // ─────────────────────────────────────────────────────────────────────────
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
                  icon: Icon(Icons.arrow_back_ios_rounded, size: 18,
                      color: c.onSurface.withValues(alpha: 0.45)),
                  onPressed: widget.onClose,
                ),
                const Spacer(),
                Column(children: [
                  Text('Luna Updates',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 22, fontWeight: FontWeight.w700, color: c.onSurface)),
                  Text('tap a version to install',
                      style: GoogleFonts.dmSans(
                        fontSize: 10, color: c.onSurface.withValues(alpha: 0.3))),
                ]),
                const Spacer(),
                GestureDetector(
                  onTap: _onHelpTap,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(Icons.help_outline_rounded, size: 20,
                        color: c.onSurface.withValues(alpha: 0.2)),
                  ),
                ),
              ]),
            ),

            // ── Help banner ───────────────────────────────────────────────
            if (_showHelp)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.surface.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'View and install Luna updates.\nTap a version card to download and install — no cables, no computer needed.',
                    style: GoogleFonts.dmSans(
                        fontSize: 12, color: c.onSurface.withValues(alpha: 0.5), height: 1.5)),
                ),
              ).animate().fadeIn(),

            // ── Admin: Publish panel ──────────────────────────────────────
            if (_isAdmin)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: c.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: c.primary.withValues(alpha: 0.25)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.rocket_launch_rounded, size: 14, color: c.accent),
                      const SizedBox(width: 6),
                      Text('Publish new version',
                          style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: c.accent)),
                    ]),
                    const SizedBox(height: 12),
                    _AdminField(ctrl: _verCtrl, hint: 'Version  (e.g. v1.1.0)', colors: c),
                    const SizedBox(height: 8),
                    _AdminField(ctrl: _descCtrl, hint: "What's new in this version", colors: c),
                    const SizedBox(height: 8),
                    _AdminField(
                        ctrl: _urlCtrl,
                        hint: 'Direct APK URL (Google Drive / Dropbox)',
                        colors: c),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _publishVersion,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [c.primary, c.secondary]),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text('Publish 🚀',
                              style: GoogleFonts.dmSans(
                                  fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                      ),
                    ),
                  ]),
                ),
              ).animate().fadeIn(),

            // ── Download progress banner ──────────────────────────────────
            if (_isDownloading)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.primary.withValues(alpha: 0.25)),
                  ),
                  child: Column(children: [
                    Row(children: [
                      SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                          value: _downloadProgress > 0 ? _downloadProgress : null,
                          strokeWidth: 2, color: c.accent),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _downloadProgress > 0
                            ? 'Downloading ${(_downloadProgress * 100).toStringAsFixed(0)}%  —  hang tight'
                            : 'Downloading...',
                        style: GoogleFonts.dmSans(
                            fontSize: 13, fontWeight: FontWeight.w500, color: c.onSurface)),
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

            // ── Versions list ─────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: c.accent)),
                        const SizedBox(height: 14),
                        Text('Checking for updates...',
                            style: GoogleFonts.dmSans(
                                fontSize: 12, color: c.onSurface.withValues(alpha: 0.35))),
                      ]))
                  : _timedOut
                      ? _EmptyState(
                          emoji: '📵',
                          title: 'No internet connection',
                          subtitle: 'Connect to Wi-Fi or mobile data to fetch updates',
                          colors: c,
                          onRetry: _fetchVersions)
                      : _error != null
                          ? _EmptyState(
                              emoji: '⚠️',
                              title: 'Something went wrong',
                              subtitle: _error!,
                              colors: c,
                              onRetry: _fetchVersions)
                          : _versions.isEmpty
                              ? _EmptyState(
                                  emoji: '🌙',
                                  title: 'No updates yet',
                                  subtitle: "You're on the latest build",
                                  colors: c)
                               : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 60),
                                  itemCount: _versions.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                                  itemBuilder: (_, i) => _VersionCard(
                                    ver: _versions[i],
                                    colors: c,
                                    isAdmin: _isAdmin,
                                    isDownloading: _isDownloading && _downloadingId == _versions[i].id,
                                    downloadProgress:
                                        _downloadingId == _versions[i].id ? _downloadProgress : 0,
                                    isLatest: i == 0,
                                    onInstall: () => _downloadAndInstall(_versions[i]),
                                    onDelete: () => _deleteVersion(_versions[i].id),
                                    onEdit: (updated) => _editVersion(_versions[i].id, updated),
                                  ),
                                ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editVersion(String id, _VersionEntry updated) async {
    try {
      final payload = json.encode({
        'version': updated.version,
        'description': updated.description,
        'url': updated.url,
        'date': updated.date,
      });
      await http
          .patch(Uri.parse('$_dbBase/$id.json'),
              headers: {'Content-Type': 'application/json'}, body: payload)
          .timeout(const Duration(seconds: 10));
      _fetchVersions();
    } catch (e) {
      _showSnack('Update failed: ${e.toString().split('\n').first}');
    }
  }
}

// ── Version Card ──────────────────────────────────────────────────────────────
class _VersionCard extends StatefulWidget {
  final _VersionEntry ver;
  final PhaseColors colors;
  final bool isAdmin;
  final bool isDownloading;
  final double downloadProgress;
  final bool isLatest;
  final VoidCallback onInstall;
  final VoidCallback onDelete;
  final void Function(_VersionEntry updated) onEdit;

  const _VersionCard({
    required this.ver,
    required this.colors,
    required this.isAdmin,
    required this.isDownloading,
    required this.downloadProgress,
    required this.isLatest,
    required this.onInstall,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  State<_VersionCard> createState() => _VersionCardState();
}

class _VersionCardState extends State<_VersionCard> {
  bool _editing = false;
  late TextEditingController _eVer;
  late TextEditingController _eDesc;
  late TextEditingController _eUrl;

  static const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

  @override
  void initState() {
    super.initState();
    _eVer = TextEditingController(text: widget.ver.version);
    _eDesc = TextEditingController(text: widget.ver.description);
    _eUrl = TextEditingController(text: widget.ver.url);
  }

  @override
  void dispose() {
    _eVer.dispose(); _eDesc.dispose(); _eUrl.dispose();
    super.dispose();
  }

  String _formatDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso);
      return '${d.day} ${_months[d.month - 1]} ${d.year}';
    } catch (_) { return iso; }
  }

  void _saveEdit() {
    widget.onEdit(_VersionEntry(
      id: widget.ver.id,
      version: _eVer.text.trim(),
      description: _eDesc.text.trim(),
      url: _eUrl.text.trim(),
      date: widget.ver.date,
    ));
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final dateStr = _formatDate(widget.ver.date);

    if (_editing) {
      // ── Edit mode ─────────────────────────────────────────────────────
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.primary.withValues(alpha: 0.3)),
        ),
        child: Column(children: [
          _AdminField(ctrl: _eVer, hint: 'Version (e.g. v1.1.0)', colors: c),
          const SizedBox(height: 8),
          _AdminField(ctrl: _eDesc, hint: "What's new", colors: c),
          const SizedBox(height: 8),
          _AdminField(ctrl: _eUrl, hint: 'APK URL', colors: c),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: _saveEdit,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [c.primary, c.secondary]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(child: Text('Save',
                    style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white))),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _editing = false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: c.onSurface.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(child: Text('Cancel',
                    style: GoogleFonts.dmSans(fontSize: 13, color: c.onSurface.withValues(alpha: 0.5)))),
                ),
              ),
            ),
          ]),
        ]),
      );
    }

    // ── View mode ──────────────────────────────────────────────────────────
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isLatest ? c.primary.withValues(alpha: 0.3) : c.onSurface.withValues(alpha: 0.05)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (widget.isLatest)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: c.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10)),
              child: Text('LATEST',
                  style: GoogleFonts.dmSans(fontSize: 9, fontWeight: FontWeight.w800, color: c.accent, letterSpacing: 1)),
            ),
          Text(widget.ver.version,
              style: GoogleFonts.dmSans(fontSize: 17, fontWeight: FontWeight.w700, color: c.onSurface)),
          const Spacer(),
          if (dateStr.isNotEmpty)
            Text(dateStr, style: GoogleFonts.dmSans(fontSize: 11, color: c.onSurface.withValues(alpha: 0.3))),
          if (widget.isAdmin) ...[ 
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() => _editing = true),
              child: Icon(Icons.edit_outlined, size: 15, color: c.accent.withValues(alpha: 0.5)),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: widget.onDelete,
              child: Icon(Icons.delete_outline_rounded, size: 15, color: Colors.red.withValues(alpha: 0.4)),
            ),
          ],
        ]),

        if (widget.ver.description.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(widget.ver.description,
              style: GoogleFonts.dmSans(fontSize: 12, color: c.onSurface.withValues(alpha: 0.4), height: 1.5)),
        ],

        const SizedBox(height: 14),

        GestureDetector(
          onTap: widget.isDownloading ? null : widget.onInstall,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              gradient: widget.isDownloading
                  ? null
                  : LinearGradient(colors: [c.primary.withValues(alpha: 0.85), c.secondary.withValues(alpha: 0.85)]),
              color: widget.isDownloading ? c.primary.withValues(alpha: 0.08) : null,
              borderRadius: BorderRadius.circular(14),
              border: widget.isDownloading ? Border.all(color: c.primary.withValues(alpha: 0.2)) : null,
            ),
            child: Center(
              child: widget.isDownloading
                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: c.accent,
                          value: widget.downloadProgress > 0 ? widget.downloadProgress : null)),
                      const SizedBox(width: 10),
                      Text(
                        widget.downloadProgress > 0
                            ? 'Downloading ${(widget.downloadProgress * 100).toStringAsFixed(0)}%'
                            : 'Starting...',
                        style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: c.accent)),
                    ])
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.download_rounded, size: 16, color: Colors.white),
                      const SizedBox(width: 8),
                      Text('Install ${widget.ver.version}',
                          style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                    ]),
            ),
          ),
        ),
      ]),
    ).animate().fadeIn(delay: Duration(milliseconds: 50 * (widget.isLatest ? 0 : 1)));
  }
}

// ── Admin text field ──────────────────────────────────────────────────────────
class _AdminField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final PhaseColors colors;
  const _AdminField({required this.ctrl, required this.hint, required this.colors});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      style: GoogleFonts.dmSans(fontSize: 13, color: colors.onSurface),
      decoration: InputDecoration(
        filled: true,
        fillColor: colors.background.withValues(alpha: 0.6),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colors.accent, width: 1.5)),
        hintText: hint,
        hintStyle: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.28)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                  fontSize: 15, fontWeight: FontWeight.w600, color: c.onSurface)),
          const SizedBox(height: 5),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                  fontSize: 12, color: c.onSurface.withValues(alpha: 0.38), height: 1.5)),
          if (onRetry != null) ...[
            const SizedBox(height: 22),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                decoration: BoxDecoration(
                  color: c.surface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Try again',
                    style: GoogleFonts.dmSans(
                        fontSize: 13, color: c.onSurface.withValues(alpha: 0.55))),
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
