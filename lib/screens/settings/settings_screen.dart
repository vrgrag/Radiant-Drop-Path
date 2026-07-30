import 'package:flutter/material.dart';
import '../../app.dart';
import '../../services/audio_service.dart';
import '../../services/save_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/sound_paths.dart';
import '../webview/simple_webview_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final save = SaveService.instance;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionLabel('Audio'),
          SwitchListTile(
            value: save.musicEnabled,
            onChanged: (v) async {
              await save.setMusicEnabled(v);
              await AudioService.instance.refreshMusicState();
              AudioService.instance.playSfx(SoundPaths.buttonClick);
              setState(() {});
            },
            title: const Text('Music', style: TextStyle(color: AppColors.textPrimary)),
            secondary: const Icon(Icons.music_note, color: AppColors.accentCyan),
            activeThumbColor: AppColors.accentCyan,
          ),
          _VolumeSlider(
            icon: Icons.volume_up_rounded,
            value: save.musicVolume,
            enabled: save.musicEnabled,
            onChanged: (v) async {
              await save.setMusicVolume(v);
              await AudioService.instance.setMusicVolume(v);
              setState(() {});
            },
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: save.sfxEnabled,
            onChanged: (v) async {
              await save.setSfxEnabled(v);
              if (v) AudioService.instance.playSfx(SoundPaths.buttonClick);
              setState(() {});
            },
            title: const Text('Sound Effects', style: TextStyle(color: AppColors.textPrimary)),
            secondary: const Icon(Icons.graphic_eq, color: AppColors.accentCyan),
            activeThumbColor: AppColors.accentCyan,
          ),
          _VolumeSlider(
            icon: Icons.volume_up_rounded,
            value: save.sfxVolume,
            enabled: save.sfxEnabled,
            onChanged: (v) async {
              await save.setSfxVolume(v);
              setState(() {});
            },
            onChangeEnd: (v) => AudioService.instance.playSfx(SoundPaths.buttonClick),
          ),
          const SizedBox(height: 16),
          _SectionLabel('Simulation'),
          ListTile(
            title: const Text('Default simulation speed', style: TextStyle(color: AppColors.textPrimary)),
            subtitle: Slider(
              value: save.defaultSimSpeed,
              min: 1,
              max: 4,
              divisions: 2,
              label: '${save.defaultSimSpeed.toStringAsFixed(0)}x',
              onChanged: (v) async {
                await save.setDefaultSimSpeed(v);
                setState(() {});
              },
            ),
          ),
          const SizedBox(height: 16),
          _SectionLabel('About'),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.accentCyan),
            title: const Text('Privacy Policy', style: TextStyle(color: AppColors.textPrimary)),
            trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            onTap: () => Navigator.of(context).pushNamed(
              Routes.webview,
              arguments: const WebViewArgs(
                url: 'https://radiantdroppath.com/privacy-policy.html',
                title: 'Privacy Policy',
                whiteBackground: true,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.support_agent, color: AppColors.accentCyan),
            title: const Text('Support', style: TextStyle(color: AppColors.textPrimary)),
            trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            onTap: () => Navigator.of(context).pushNamed(
              Routes.webview,
              arguments: const WebViewArgs(
                url: 'https://radiantdroppath.com/support.html',
                title: 'Support',
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text('Radiant Drop Path  ·  v1.0.0', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _VolumeSlider extends StatelessWidget {
  final IconData icon;
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  const _VolumeSlider({
    required this.icon,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    final active = enabled ? AppColors.accentCyan : AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: active.withValues(alpha: enabled ? 1 : 0.5)),
          Expanded(
            child: Slider(
              value: value.clamp(0.0, 1.0),
              min: 0,
              max: 1,
              divisions: 20,
              activeColor: AppColors.accentCyan,
              inactiveColor: AppColors.gridLine,
              label: '${(value * 100).round()}%',
              onChanged: enabled ? onChanged : null,
              onChangeEnd: enabled ? onChangeEnd : null,
            ),
          ),
          SizedBox(
            width: 42,
            child: Text(
              '${(value * 100).round()}%',
              textAlign: TextAlign.end,
              style: TextStyle(
                color: enabled ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 4, left: 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(color: AppColors.accentGold, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.2),
      ),
    );
  }
}
