import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../sms/models/parsed_transaction.dart';
import '../../../sms/models/sms_message.dart';
import '../../../sms/providers/sms_tracking_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/user_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _editName(BuildContext context) async {
    final userProvider = context.read<UserProvider>();
    final controller = TextEditingController(text: userProvider.name);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final cs = Theme.of(sheetContext).colorScheme;
        final bottomInset = MediaQuery.viewInsetsOf(sheetContext).bottom;

        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Edit Name',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'Enter your name',
                    filled: true,
                    fillColor: cs.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: <Color>[Color(0xFF6E3EFF), Color(0xFF8B5CFF)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TextButton(
                      onPressed: () async {
                        final newName = controller.text;
                        if (newName.trim().isEmpty) return;
                        Navigator.of(sheetContext).pop();
                        await userProvider.updateName(newName);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Consumer<UserProvider>(
              builder: (context, userProvider, _) => _ProfileHeaderCard(
                name: userProvider.name,
                subtitle: 'Track your expenses',
                onEditTap: () => _editName(context),
              ),
            ),
            const SizedBox(height: 18),
            _SettingsItem(
              icon: Icons.person_outline_rounded,
              title: 'Edit Name',
              onTap: () => _editName(context),
            ),
            const SizedBox(height: 10),
            _SettingsItem(
              icon: Icons.notifications_none_rounded,
              title: 'Notifications',
              onTap: () {},
            ),
            const SizedBox(height: 10),
            _SettingsItem(
              icon: Icons.ios_share_outlined,
              title: 'Export Data',
              onTap: () {},
            ),
            const SizedBox(height: 10),
            _SettingsItem(
              icon: Icons.link_rounded,
              title: 'Connect Notion',
              onTap: () {},
            ),
            const SizedBox(height: 10),
            Consumer<SmsTrackingProvider>(
              builder: (context, sms, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _SettingsToggleItem(
                      icon: Icons.sms_outlined,
                      title: 'Enable SMS Tracking',
                      subtitle: sms.isSupported
                          ? (sms.statusMessage ?? 'Android only')
                          : 'Available on Android only',
                      value: sms.isEnabled,
                      onChanged: sms.isSupported
                          ? (value) async {
                              await sms.setEnabled(value);
                              if (!context.mounted) return;
                              if (value) {
                                await context
                                    .read<ExpenseProvider>()
                                    .fetchExpenses();
                              }
                            }
                          : null,
                    ),
                    if (sms.recentParsed.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      _SmsParsedPreview(transactions: sms.recentParsed),
                    ],
                    if (sms.isEnabled) ...<Widget>[
                      const SizedBox(height: 8),
                      _SmsDebugPanel(
                        inboxCount: sms.inboxCount,
                        lastSms: sms.lastReceivedSms,
                        lastFailure: sms.lastFailureReason,
                        lastParsed: sms.recentParsed.isNotEmpty
                            ? sms.recentParsed.first
                            : null,
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            Consumer<ThemeProvider>(
              builder: (context, themeProvider, _) => _SettingsToggleItem(
                icon: Icons.dark_mode_outlined,
                title: 'Dark Mode',
                value: themeProvider.isDark,
                onChanged: (value) => themeProvider.toggleTheme(value),
              ),
            ),
            const SizedBox(height: 26),
            _LogoutButton(onTap: () {}),
          ],
        ),
      ),
    );
  }
}

// ─── Profile header card ──────────────────────────────────────────────────────

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.name,
    required this.subtitle,
    required this.onEditTap,
  });

  final String name;
  final String subtitle;
  final VoidCallback onEditTap;

  String get _initial => name.isNotEmpty ? name.trim()[0].toUpperCase() : 'U';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: <Color>[Color(0xFF6E3EFF), Color(0xFF8B5CFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Text(
                _initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEditTap,
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF6E3EFF), size: 20),
            tooltip: 'Edit name',
          ),
        ],
      ),
    );
  }
}

// ─── Settings item ────────────────────────────────────────────────────────────

class _SettingsItem extends StatelessWidget {
  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: <Widget>[
              Icon(icon, color: cs.onSurface.withValues(alpha: 0.75)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: cs.onSurface.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Settings toggle item ─────────────────────────────────────────────────────

class _SettingsToggleItem extends StatelessWidget {
  const _SettingsToggleItem({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: <Widget>[
            Icon(icon, color: cs.onSurface.withValues(alpha: 0.75)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

// ─── SMS debug panel ──────────────────────────────────────────────────────────

class _SmsDebugPanel extends StatelessWidget {
  const _SmsDebugPanel({
    required this.inboxCount,
    this.lastSms,
    this.lastFailure,
    this.lastParsed,
  });

  final int inboxCount;
  final SmsMessage? lastSms;
  final String? lastFailure;
  final ParsedTransaction? lastParsed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'SMS Debug',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text('Inbox scanned: $inboxCount', style: _style(cs)),
          if (lastSms != null) ...<Widget>[
            const SizedBox(height: 4),
            Text('Last SMS from: ${lastSms!.sender}', style: _style(cs)),
            Text(
              lastSms!.body,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: _style(cs),
            ),
          ],
          if (lastParsed != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              'Last parsed: ₹${lastParsed!.amount} ${lastParsed!.type} '
              '• ${lastParsed!.merchant}',
              style: _style(cs).copyWith(color: const Color(0xFF059669)),
            ),
          ],
          if (lastFailure != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              'Last failure: $lastFailure',
              style: _style(cs).copyWith(color: cs.error),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Keep app in foreground for adb emu sms send',
            style: _style(cs).copyWith(
              fontSize: 11,
              color: cs.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _style(ColorScheme cs) => TextStyle(
        fontSize: 12,
        color: cs.onSurface.withValues(alpha: 0.75),
      );
}

// ─── SMS parsed preview ───────────────────────────────────────────────────────

class _SmsParsedPreview extends StatelessWidget {
  const _SmsParsedPreview({required this.transactions});

  final List<ParsedTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Recent parsed SMS',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          ...transactions.take(3).map((tx) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '₹${tx.amount} ${tx.type} • ${tx.merchant}',
                style: TextStyle(fontSize: 13, color: cs.onSurface),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Logout button ────────────────────────────────────────────────────────────

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        side: const BorderSide(color: Color(0xFFF1B9C5)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      icon: const Icon(Icons.logout_rounded, color: Color(0xFFD6456F)),
      label: const Text(
        'Logout',
        style: TextStyle(
          color: Color(0xFFD6456F),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
