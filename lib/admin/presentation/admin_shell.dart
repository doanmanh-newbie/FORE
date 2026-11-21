import 'package:flutter/material.dart';

import '../../core/design/colors.dart';
import '../../core/design/spacing.dart';
import '../../core/design/typography.dart';
import '../../core/theme/theme_mode_toggle.dart';
import '../admin_app.dart';
import '../admin_theme.dart';
import '../domain/admin_models.dart';
import 'config_screen.dart';
import 'errors_screen.dart';
import 'events_screen.dart';
import 'logins_screen.dart';
import 'shops_screen.dart';
import 'users_screen.dart';

enum _AdminTab {
  shops('Quán', Icons.storefront_outlined),
  users('Người dùng', Icons.people_outline_rounded),
  errors('Nhật ký lỗi', Icons.bug_report_outlined),
  events('Thống kê', Icons.bar_chart_rounded),
  logins('IP đăng nhập', Icons.router_outlined),
  config('Cấu hình', Icons.tune_rounded);

  const _AdminTab(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Khung điều hướng chính của Admin Web theo tone màu Xanh rừng (#0D3B2E) +
/// Xanh ngọc (#1F6E58 / #51A19B) và logo biểu trưng Fore (`AdminBrandMark`).
class AdminShell extends StatefulWidget {
  const AdminShell({
    super.key,
    required this.identity,
    required this.dependencies,
    required this.onSignOut,
    this.isDemoMode = false,
  });

  final AdminIdentity identity;
  final AdminDependencies dependencies;
  final Future<void> Function() onSignOut;
  final bool isDemoMode;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  static const _wideBreakpoint = 900.0;
  static const _maxContentWidth = 1160.0;

  _AdminTab _current = _AdminTab.shops;
  String? _loginFilterUserId;
  String? _loginFilterUserLabel;
  bool _signingOut = false;

  void _selectTab(_AdminTab tab) {
    setState(() => _current = tab);
  }

  void _openUserLogins(AdminUser user) {
    setState(() {
      _loginFilterUserId = user.userId;
      _loginFilterUserLabel = user.email ?? user.displayName;
      _current = _AdminTab.logins;
    });
  }

  Future<void> _handleSignOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await widget.onSignOut();
    } finally {
      if (mounted) {
        setState(() => _signingOut = false);
      }
    }
  }

  Widget _buildBody() => switch (_current) {
        _AdminTab.shops => AdminShopsScreen(
            repository: widget.dependencies.shopsRepository,
          ),
        _AdminTab.users => AdminUsersScreen(
            repository: widget.dependencies.usersRepository,
            onInspectLogins: _openUserLogins,
          ),
        _AdminTab.errors => AdminErrorsScreen(
            repository: widget.dependencies.errorsRepository,
          ),
        _AdminTab.events => AdminEventsScreen(
            repository: widget.dependencies.eventsRepository,
          ),
        _AdminTab.logins => AdminLoginsScreen(
            repository: widget.dependencies.loginsRepository,
            initialUserId: _loginFilterUserId,
            initialUserLabel: _loginFilterUserLabel,
            onClearInitialUser: () {
              setState(() {
                _loginFilterUserId = null;
                _loginFilterUserLabel = null;
              });
            },
          ),
        _AdminTab.config => AdminConfigScreen(
            repository: widget.dependencies.configRepository,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    final extended = MediaQuery.sizeOf(context).width >= 1220;

    final subtitle = widget.isDemoMode
        ? '${widget.identity.email} · Dữ liệu giả (Fake)'
        : 'Super-admin · ${widget.identity.email}';

    Widget buildHeader(BuildContext scaffoldContext) => DecoratedBox(
          decoration: const BoxDecoration(
            color: AdminPalette.forestDark,
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(AppRadius.panel),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.screenGutter,
                AppGaps.md,
                AppSizes.screenGutter,
                AppGaps.lg,
              ),
              child: Row(
                children: [
                  if (!wide) ...[
                    IconButton(
                      tooltip: 'Mở menu',
                      color: AdminPalette.white,
                      icon: const Icon(Icons.menu_rounded),
                      onPressed: () =>
                          Scaffold.of(scaffoldContext).openDrawer(),
                    ),
                    const SizedBox(width: AppGaps.xs),
                  ],
                  const AdminLogoBadge(size: 40),
                  const SizedBox(width: AppGaps.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Flexible(
                              child: Text(
                                'Fore Admin',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: AppFonts.body,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AdminPalette.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppGaps.sm),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AdminPalette.forestTeal,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _current.icon,
                                    size: 13,
                                    color: AdminPalette.mintSoft,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    _current.label,
                                    style: const TextStyle(
                                      fontFamily: AppFonts.body,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AdminPalette.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppFonts.body,
                            fontSize: 12,
                            color: AdminPalette.mintMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const ThemeModeToggle(color: AdminPalette.white),
                  if (wide) ...[
                    const SizedBox(width: AppGaps.xs),
                    TextButton.icon(
                      key: const Key('admin_sign_out_button'),
                      onPressed: _signingOut ? null : _handleSignOut,
                      icon: const Icon(
                        Icons.logout_rounded,
                        size: 18,
                        color: AdminPalette.mintSoft,
                      ),
                      label: const Text(
                        'Đăng xuất',
                        style: TextStyle(
                          color: AdminPalette.mintSoft,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 40),
                      ),
                    ),
                  ] else
                    IconButton(
                      key: const Key('admin_sign_out_button'),
                      tooltip: 'Đăng xuất',
                      onPressed: _signingOut ? null : _handleSignOut,
                      color: AdminPalette.mintSoft,
                      icon: const Icon(Icons.logout_rounded),
                    ),
                ],
              ),
            ),
          ),
        );

    Widget buildMainColumn(BuildContext scaffoldContext) => Column(
          children: [
            buildHeader(scaffoldContext),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                  child: _buildBody(),
                ),
              ),
            ),
          ],
        );

    if (!wide) {
      return Scaffold(
        backgroundColor: AppColors.background,
        drawer: Drawer(
          backgroundColor: AdminPalette.forestDark,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          AdminLogoBadge(size: 36),
                          SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Fore Admin',
                                style: TextStyle(
                                  color: AdminPalette.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 17,
                                ),
                              ),
                              Text(
                                'Quản lý thông minh',
                                style: TextStyle(
                                  color: AdminPalette.mintMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.identity.email,
                        style: const TextStyle(
                          color: AdminPalette.mintSoft,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(
                  color: AdminPalette.mintSoft.withValues(alpha: 0.2),
                  height: 1,
                ),
                for (final tab in _AdminTab.values)
                  ListTile(
                    selected: tab == _current,
                    selectedTileColor: AdminPalette.forestTeal,
                    leading: Icon(
                      tab.icon,
                      color: tab == _current
                          ? AdminPalette.white
                          : AdminPalette.mintMuted,
                    ),
                    title: Text(
                      tab.label,
                      style: TextStyle(
                        color: tab == _current
                            ? AdminPalette.white
                            : AdminPalette.mintSoft,
                        fontWeight: tab == _current
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      _selectTab(tab);
                    },
                  ),
              ],
            ),
          ),
        ),
        body: Builder(builder: buildMainColumn),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          NavigationRail(
            extended: extended,
            minExtendedWidth: 224,
            selectedIndex: _current.index,
            onDestinationSelected: (index) =>
                _selectTab(_AdminTab.values[index]),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AdminLogoBadge(size: 36),
                  if (extended) ...[
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Fore Admin',
                          style: TextStyle(
                            color: AdminPalette.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Quản lý thông minh',
                          style: TextStyle(
                            color: AdminPalette.mintMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            destinations: [
              for (final tab in _AdminTab.values)
                NavigationRailDestination(
                  icon: Icon(tab.icon),
                  label: Text(tab.label),
                ),
            ],
          ),
          Expanded(child: Builder(builder: buildMainColumn)),
        ],
      ),
    );
  }
}
