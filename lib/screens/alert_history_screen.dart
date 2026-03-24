import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

class AlertHistoryScreen extends StatefulWidget {
  const AlertHistoryScreen({super.key});

  @override
  State<AlertHistoryScreen> createState() => _AlertHistoryScreenState();
}

class _AlertHistoryScreenState extends State<AlertHistoryScreen> {
  List<Map<String, dynamic>> _alerts = [];
  bool _isLoading = true;
  static const String _bucketName = 'threat_images';

  @override
  void initState() {
    super.initState();
    _fetchAlerts();
  }

  int? _tryParseThreatMsFromName(String name) {
    // Expected: threat_<millisecondsSinceEpoch>.png/mp4
    final match = RegExp(r'^threat_(\d+)\.(png|mp4)$').firstMatch(name);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  Future<Map<int, String>> _listAllMediaByExt(SupabaseClient supabase, String ext) async {
    final map = <int, String>{};
    try {
      final folders = await supabase.storage.from(_bucketName).list();
      for (final f in folders) {
        if (f.id == null || f.id!.isEmpty) { // It's a folder (like UID)
          try {
            final subitems = await supabase.storage.from(_bucketName).list(path: f.name);
            for (final sub in subitems) {
              if (sub.name.endsWith('.$ext')) {
                final ms = _tryParseThreatMsFromName(sub.name);
                if (ms != null) {
                  final key = '${f.name}/${sub.name}';
                  map[ms] = supabase.storage.from(_bucketName).getPublicUrl(key);
                }
              } else if (sub.id == null || sub.id!.isEmpty) {
                // Subfolder like "images" or "videos"
                try {
                  final subsub = await supabase.storage.from(_bucketName).list(path: '${f.name}/${sub.name}');
                  for (final ss in subsub) {
                     if (ss.name.endsWith('.$ext')) {
                       final ms = _tryParseThreatMsFromName(ss.name);
                       if (ms != null) {
                         final key = '${f.name}/${sub.name}/${ss.name}';
                         map[ms] = supabase.storage.from(_bucketName).getPublicUrl(key);
                       }
                     }
                  }
                } catch (_) {}
              }
            }
          } catch (_) {}
        } else if (f.name.endsWith('.$ext')) {
          // File at root
          final ms = _tryParseThreatMsFromName(f.name);
          if (ms != null) {
            map[ms] = supabase.storage.from(_bucketName).getPublicUrl(f.name);
          }
        }
      }
    } catch (e) {
      debugPrint('Error listing $ext: $e');
    }
    return map;
  }

  int? _closestMs(int target, Iterable<int> candidates) {
    int? best;
    int bestDiff = 1 << 30;
    for (final c in candidates) {
      final diff = (c - target).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = c;
      }
    }
    return best;
  }

  Future<void> _fetchAlerts() async {
    try {
      final supabase = Supabase.instance.client;
      String? uid = supabase.auth.currentUser?.id;
      if (uid == null) {
        await supabase.auth.signInAnonymously();
        uid = supabase.auth.currentUser?.id;
      }
      if (uid == null) {
        if (mounted) setState(() { _isLoading = false; });
        return;
      }

      List<dynamic> response = [];
      try {
        response = await supabase
            .from('threats')
            .select()
            .order('created_at', ascending: false);
      } catch (e) {
        // If RLS blocks table reads, we can still show items from Storage.
        debugPrint('Threats table read blocked: $e');
      }

      // Also retrieve media directly from the Storage bucket and attach URLs if missing.
      // This ensures the history still shows images/videos even if URLs weren't stored in DB.
      Map<int, String> imageUrlsByMs = {};
      Map<int, String> videoUrlsByMs = {};
      try {
        imageUrlsByMs = await _listAllMediaByExt(supabase, 'png');
        videoUrlsByMs = await _listAllMediaByExt(supabase, 'mp4');
      } catch (e) {
        debugPrint('Error listing storage media: $e');
      }

      // Build fallback alerts directly from storage objects (datastore).
      final mediaKeys = <int>{...imageUrlsByMs.keys, ...videoUrlsByMs.keys};
      final storageAlerts = mediaKeys.map((ms) {
        return <String, dynamic>{
          'detected_class': 'Recorded Evidence',
          'created_at': DateTime.fromMillisecondsSinceEpoch(ms).toIso8601String(),
          'image_url': imageUrlsByMs[ms],
          'video_url': videoUrlsByMs[ms],
        };
      }).toList()
        ..sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));

      if (mounted) {
        setState(() {
          final dbAlerts = List<Map<String, dynamic>>.from(response).map((a) {
            // Attach image/video URLs from storage if missing
            final createdAt = a['created_at'] as String?;
            if ((a['image_url'] == null || (a['image_url'] as String?)?.isEmpty == true) && createdAt != null) {
              final targetMs = DateTime.parse(createdAt).millisecondsSinceEpoch;
              final best = _closestMs(targetMs, imageUrlsByMs.keys);
              if (best != null) a['image_url'] = imageUrlsByMs[best];
            }
            if ((a['video_url'] == null || (a['video_url'] as String?)?.isEmpty == true) && createdAt != null) {
              final targetMs = DateTime.parse(createdAt).millisecondsSinceEpoch;
              final best = _closestMs(targetMs, videoUrlsByMs.keys);
              if (best != null) a['video_url'] = videoUrlsByMs[best];
            }
            return a;
          }).toList();

          // Merge: DB alerts first (richer metadata), then any extra storage-only items.
          final seenMs = <int>{};
          for (final a in dbAlerts) {
            final createdAt = a['created_at'] as String?;
            if (createdAt == null) continue;
            seenMs.add(DateTime.parse(createdAt).millisecondsSinceEpoch);
          }
          final extras = storageAlerts.where((a) {
            final ms = DateTime.parse(a['created_at'] as String).millisecondsSinceEpoch;
            return !seenMs.contains(ms);
          }).toList();

          _alerts = [...dbAlerts, ...extras];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching alerts: $e');
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  IconData _getIcon(String? detectedClass) {
    if (detectedClass == null) return LucideIcons.alertTriangle;
    final dc = detectedClass.toLowerCase();
    if (dc.contains('unknown') || dc.contains('element')) return LucideIcons.userX;
    if (dc.contains('vehicle') || dc.contains('car')) return LucideIcons.car;
    return LucideIcons.alertTriangle;
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';
    final dt = DateTime.parse(timestamp);
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Alert History'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryStatusColor))
          : _alerts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.bellOff, size: 64, color: AppTheme.textSecondaryColor.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'No alerts recorded yet.',
                    style: GoogleFonts.outfit(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: _alerts.length,
              itemBuilder: (context, index) {
                final alert = _alerts[index];
                return FadeInUp(
                  delay: Duration(milliseconds: index * 100),
                  child: InkWell(
                    onTap: () async {
                      final videoUrl = alert['video_url'] as String?;
                      if (videoUrl != null && videoUrl.isNotEmpty) {
                        final uri = Uri.parse(videoUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppTheme.surfaceVariantColor,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: AppTheme.surfaceVariantColor,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: alert['image_url'] != null
                                  ? CachedNetworkImage(
                                      imageUrl: alert['image_url'],
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) =>
                                          const Icon(LucideIcons.image, color: AppTheme.textSecondaryColor),
                                      errorWidget: (context, url, error) =>
                                          const Icon(LucideIcons.alertTriangle, color: AppTheme.errorColor),
                                    )
                                  : Icon(_getIcon(alert['detected_class']), color: AppTheme.errorColor, size: 28),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      alert['detected_class'] ?? 'Unknown',
                                      style: GoogleFonts.outfit(
                                        color: AppTheme.textPrimaryColor,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (alert['video_url'] != null)
                                      const Icon(
                                        LucideIcons.playCircle,
                                        color: AppTheme.primaryStatusColor,
                                        size: 20,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _formatTime(alert['created_at']),
                                  style: GoogleFonts.outfit(
                                    color: AppTheme.textSecondaryColor,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
