import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../config/colors.dart';
import '../../../services/fcm_service.dart';
import '../../../shared/widgets/widgets.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  late Box _prefsBox;
  bool _friendRequest = true;
  bool _like = true;
  bool _calendar = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      _prefsBox = await Hive.openBox('notification_prefs');
      if (mounted) {
        setState(() {
          _friendRequest = _prefsBox.get('friend_request', defaultValue: true);
          _like = _prefsBox.get('like', defaultValue: true);
          _calendar = _prefsBox.get('calendar', defaultValue: true);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _save(String key, bool value) async {
    await _prefsBox.put(key, value);
    await FcmService.instance.updateTopic(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('알림 설정')),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: DuckColors.primary),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                DuckCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _toggleItem(
                        icon: PhosphorIconsBold.userPlus,
                        label: '친구 요청 알림',
                        subtitle: '새로운 친구 요청이 오면 알려드려요',
                        value: _friendRequest,
                        onChanged: (v) {
                          setState(() => _friendRequest = v);
                          _save('friend_request', v);
                        },
                      ),
                      const Divider(height: 1),
                      _toggleItem(
                        icon: PhosphorIconsBold.heart,
                        label: '좋아요 알림',
                        subtitle: '내 굿즈에 좋아요가 달리면 알려드려요',
                        value: _like,
                        onChanged: (v) {
                          setState(() => _like = v);
                          _save('like', v);
                        },
                      ),
                      const Divider(height: 1),
                      _toggleItem(
                        icon: PhosphorIconsBold.calendarDots,
                        label: '캘린더 알림',
                        subtitle: '방영/출시 일정이 있으면 알려드려요',
                        value: _calendar,
                        onChanged: (v) {
                          setState(() => _calendar = v);
                          _save('calendar', v);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _toggleItem({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: DuckColors.text),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: DuckColors.primary,
            activeThumbColor: DuckColors.background,
          ),
        ],
      ),
    );
  }
}
