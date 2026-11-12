import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design/app_sheet.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/primary_button.dart';
import '../../../core/design/secondary_button.dart';
import '../../../core/design/spacing.dart';
import '../../../core/design/typography.dart';
import '../../../core/format.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/notify.dart';
import '../../../core/widgets/status_chip.dart';
import '../../inventory/application/async_data.dart';
import '../../inventory/presentation/kho_widgets.dart';
import '../domain/settings_models.dart';
import '../domain/settings_repository.dart';

class _TeamData {
  const _TeamData(this.team, this.me);

  final TeamOverview team;
  final MyPermissions me;
}

/// Quyền thao tác lên một thành viên, khớp với luật ở database (`_can_manage_member`):
/// không động vào chủ quán, vào chính mình; quản lý khác chỉ chủ mới đổi được.
bool canManageMember(MyPermissions me, TeamMember target) =>
    me.can('members.manage') &&
    !target.isOwner &&
    !target.isMe &&
    (me.isOwner || target.jobRole != JobRole.manager);

class TeamHubScreen extends StatefulWidget {
  const TeamHubScreen({super.key});

  @override
  State<TeamHubScreen> createState() => _TeamHubScreenState();
}

class _TeamHubScreenState extends State<TeamHubScreen> {
  late final SettingsRepository _repo = context.read<SettingsRepository>();
  late final AsyncData<_TeamData> _data = AsyncData(() async {
    final me = await _repo.myPermissions();
    final team = await _repo.team();
    return _TeamData(team, me);
  })
    ..load();
  final _search = TextEditingController();
  int _tab = 0;

  @override
  void dispose() {
    _data.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context)
        .push<void>(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) _data.load(silent: true);
  }

  Future<void> _resend(TeamInvite i) async {
    final ok = await guarded(context, () async {
      await _repo.resendInvite(i.id);
      return true;
    });
    if (ok == true && mounted) {
      showNotice(context, 'Đã gia hạn lời mời thêm 7 ngày.');
      _data.load(silent: true);
    }
  }

  Future<void> _cancel(TeamInvite i) async {
    final ok = await guarded(context, () async {
      await _repo.cancelInvite(i.id);
      return true;
    });
    if (ok == true && mounted) {
      showNotice(context, 'Đã hủy lời mời cho ${i.fullName}.');
      _data.load(silent: true);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _data,
        builder: (context, _) {
          final d = _data.data;
          return KhoPage(
            title: 'Nhân sự',
            subtitle: d == null
                ? null
                : '${d.team.working.length} người đang làm · ${d.team.invites.length} lời mời',
            bottom: d != null && d.me.isOwner
                ? PrimaryButton(
                    label: 'Mời nhân viên',
                    onPressed: () => _open(const InviteMemberScreen()))
                : null,
            body: ListenableBuilder(
              listenable: _search,
              builder: (context, _) => AsyncView<_TeamData>(
                source: _data,
                builder: (context, d) => _content(d),
              ),
            ),
          );
        },
      );

  List<Widget> _content(_TeamData d) {
    final q = _search.text.trim().toLowerCase();
    bool match(TeamMember m) =>
        q.isEmpty ||
        m.fullName.toLowerCase().contains(q) ||
        (m.phone ?? '').replaceAll(' ', '').contains(q.replaceAll(' ', ''));
    final members = (_tab == 0 ? d.team.working : d.team.revoked).where(match);
    return [
      KhoSearchField(controller: _search, hint: 'Tìm tên hoặc số điện thoại…'),
      const SizedBox(height: 12),
      KhoChipBar(
        labels: [
          'Đang làm · ${d.team.working.length}',
          'Lời mời · ${d.team.invites.length}',
          'Đã nghỉ · ${d.team.revoked.length}',
        ],
        selected: _tab == 0 ? 0 : (_tab == 1 ? 1 : 2),
        onSelected: (i) => setState(() => _tab = i),
      ),
      const SizedBox(height: 12),
      if (_tab == 1) ...[
        if (d.team.invites.isEmpty)
          const KhoNote('Không có lời mời nào đang chờ.'),
        for (final i in d.team.invites)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: KhoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text(i.fullName, style: AppTextStyles.cardTitle)),
                    StatusChip(
                      label: i.expired ? 'Hết hạn' : 'Chờ nhận',
                      severity: i.expired
                          ? StatusSeverity.attention
                          : StatusSeverity.neutral,
                      compact: true,
                    ),
                  ]),
                  Text(
                    [
                      i.jobRole.label,
                      if (i.phone != null) i.phone!,
                      if (i.email != null) i.email!,
                    ].join(' · '),
                    style: AppTextStyles.caption,
                  ),
                  if (i.expiresAt != null)
                    Text(
                        i.expired
                            ? 'Đã hết hạn ${formatDmy(i.expiresAt!)}'
                            : 'Còn hiệu lực đến ${formatDmy(i.expiresAt!)}',
                        style: AppTextStyles.caption),
                  if (d.me.isOwner)
                    Row(children: [
                      TextButton(
                          onPressed: () => _resend(i),
                          child: const Text('Gửi lại')),
                      TextButton(
                          onPressed: () => _cancel(i),
                          child: const Text('Hủy lời mời')),
                    ]),
                ],
              ),
            ),
          ),
      ] else ...[
        if (members.isEmpty)
          KhoNote(_tab == 0
              ? 'Chưa có ai khớp. Thử bỏ bớt từ khóa.'
              : 'Chưa có ai nghỉ.'),
        for (final m in members)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: KhoCard(
              onTap: () =>
                  _open(MemberProfileScreen(member: m, me: d.me)),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${m.fullName}${m.isMe ? ' (bạn)' : ''}',
                          style: AppTextStyles.cardTitle),
                      Text(
                        [
                          m.roleLabel,
                          if (m.phone != null) m.phone!,
                        ].join(' · '),
                        style: AppTextStyles.caption,
                      ),
                      if (!m.isOwner && m.active && !m.hasPin)
                        const Text('Chưa đặt PIN', style: AppTextStyles.caption),
                    ],
                  ),
                ),
                if (m.onShift)
                  const StatusChip(
                      label: 'Đang giữ ca',
                      severity: StatusSeverity.healthy,
                      compact: true),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSecondary),
              ]),
            ),
          ),
      ],
    ];
  }
}

// ======================================================================
// Mời nhân viên (chủ quán)
// ======================================================================
class InviteMemberScreen extends StatefulWidget {
  const InviteMemberScreen({super.key});

  @override
  State<InviteMemberScreen> createState() => _InviteMemberScreenState();
}

class _InviteMemberScreenState extends State<InviteMemberScreen> {
  late final SettingsRepository _repo = context.read<SettingsRepository>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  JobRole _role = JobRole.staff;
  final Map<JobRole, RoleConfig> _configs = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadConfig(_role);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _loadConfig(JobRole role) async {
    if (_configs.containsKey(role)) return;
    final c = await guarded(context, () => _repo.roleConfig(role));
    if (c != null && mounted) setState(() => _configs[role] = c);
  }

  Future<void> _send() async {
    if (_name.text.trim().isEmpty) {
      return showNotice(context, 'Hãy nhập tên người được mời.');
    }
    if (_phone.text.trim().isEmpty) {
      return showNotice(context, 'Hãy nhập số điện thoại để người đó nhận lời mời.');
    }
    setState(() => _busy = true);
    final id = await guarded(
      context,
      () => _repo.invite(
        fullName: _name.text,
        role: _role,
        phone: _phone.text,
        email: _email.text,
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (id != null) {
      showNotice(context,
          'Đã mời ${_name.text.trim()}. Lời mời hiện trong Hộp thư khi họ đăng nhập bằng số này, hiệu lực 7 ngày.');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _configs[_role];
    return KhoPage(
      title: 'Mời nhân viên',
      subtitle: 'Chọn vai trò trước, quyền chi tiết chỉnh ở "Vai trò và phân quyền"',
      bottom: PrimaryButton(label: 'Gửi lời mời', loading: _busy, onPressed: _send),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.pagePadding),
        children: [
          AppTextField(label: 'Tên người được mời *', controller: _name),
          const SizedBox(height: 12),
          AppTextField(
              label: 'Số điện thoại *',
              controller: _phone,
              keyboardType: TextInputType.phone),
          const SizedBox(height: 12),
          AppTextField(
              label: 'Email (không bắt buộc)',
              controller: _email,
              keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 16),
          Text('Vai trò *', style: AppTextStyles.label),
          const SizedBox(height: 6),
          SegmentedButton<JobRole>(
            segments: [
              for (final r in JobRole.values)
                ButtonSegment(value: r, label: Text(r.label)),
            ],
            selected: {_role},
            onSelectionChanged: (s) {
              setState(() => _role = s.first);
              _loadConfig(s.first);
            },
          ),
          const SizedBox(height: 12),
          KhoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const KhoEyebrow('Vai trò này được phép'),
                const SizedBox(height: 8),
                const Text('Bán hàng, in hóa đơn, mở và chốt ca của mình (luôn có).',
                    style: AppTextStyles.caption),
                if (cfg == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Đang tải quyền…', style: AppTextStyles.caption),
                  )
                else
                  for (final p in permissionCatalog)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(children: [
                        Icon(
                          cfg.allowed(p.key)
                              ? Icons.check_circle_outline_rounded
                              : Icons.block_rounded,
                          size: 18,
                          color: cfg.allowed(p.key)
                              ? AppColors.statusHealthy
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(p.label, style: AppTextStyles.body)),
                      ]),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const KhoNote(
              'Người được mời xác nhận bằng số điện thoại. Bạn có thể đổi vai trò hoặc thu hồi bất cứ lúc nào, lịch sử vẫn được giữ.'),
        ],
      ),
    );
  }
}

// ======================================================================
// Hồ sơ thành viên: đổi vai trò, thu hồi
// ======================================================================
class MemberProfileScreen extends StatefulWidget {
  const MemberProfileScreen({super.key, required this.member, required this.me});

  final TeamMember member;
  final MyPermissions me;

  @override
  State<MemberProfileScreen> createState() => _MemberProfileScreenState();
}

class _MemberProfileScreenState extends State<MemberProfileScreen> {
  late final SettingsRepository _repo = context.read<SettingsRepository>();
  late JobRole _role = widget.member.jobRole;
  late bool _active = widget.member.active;
  bool _busy = false;

  bool get _canManage => canManageMember(widget.me, widget.member);

  Future<void> _changeRole(JobRole role) async {
    final previous = _role;
    setState(() => _role = role);
    final ok = await guarded(context, () async {
      await _repo.setMemberRole(widget.member.staffId, role);
      return true;
    });
    if (!mounted) return;
    if (ok == true) {
      showNotice(context, 'Đã đổi vai trò thành ${role.label}.');
    } else {
      setState(() => _role = previous);
    }
  }

  Future<void> _revoke() async {
    var understood = false;
    final go = await AppSheet.show<bool>(
      context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AppSheet(
          title: 'Thu hồi quyền của ${widget.member.fullName}?',
          footer: PrimaryButton(
            label: 'Thu hồi',
            onPressed: understood ? () => Navigator.pop(ctx, true) : null,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text(
                'Họ sẽ không đăng nhập vào quán này được nữa. Lịch sử bán hàng, ca và kho của họ vẫn được giữ nguyên.',
                style: AppTextStyles.body),
            Material(
              color: Colors.transparent,
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: understood,
                onChanged: (v) => setS(() => understood = v ?? false),
                title: const Text('Tôi hiểu và muốn thu hồi'),
              ),
            ),
          ]),
        ),
      ),
    );
    if (go != true || !mounted) return;
    setState(() => _busy = true);
    final ok = await guarded(context, () async {
      await _repo.revokeMember(widget.member.staffId);
      return true;
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok == true) {
      setState(() => _active = false);
      showNotice(context, 'Đã thu hồi quyền của ${widget.member.fullName}.');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    return KhoPage(
      title: m.fullName,
      subtitle: '${m.isOwner ? 'Chủ quán' : _role.label}${_active ? '' : ' · Đã nghỉ'}',
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.pagePadding),
        children: [
          KhoCard(
            child: Column(children: [
              LabelValueRow('Điện thoại', m.phone ?? '—'),
              if (m.email != null) LabelValueRow('Email', m.email!),
              if (m.joinedAt != null)
                LabelValueRow('Tham gia', formatDmy(m.joinedAt!)),
              if (!m.isOwner)
                LabelValueRow('Mã PIN', m.hasPin ? 'Đã đặt' : 'Chưa đặt'),
              if (m.onShift) const LabelValueRow('Trạng thái', 'Đang giữ ca'),
              if (!_active && m.deactivatedAt != null)
                LabelValueRow('Thu hồi', formatDmy(m.deactivatedAt!)),
            ]),
          ),
          if (m.isOwner)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: KhoNote(
                  'Chủ quán luôn có mọi quyền và không thể bị hạ hay thu hồi.',
                  icon: Icons.shield_outlined),
            ),
          if (_canManage && _active) ...[
            const KhoSectionTitle('Vai trò'),
            SegmentedButton<JobRole>(
              segments: [
                for (final r in JobRole.values)
                  ButtonSegment(
                    value: r,
                    label: Text(r.label),
                    // Chỉ chủ quán mới được đặt "Quản lý".
                    enabled: r != JobRole.manager || widget.me.isOwner,
                  ),
              ],
              selected: {_role},
              onSelectionChanged: (s) => _changeRole(s.first),
            ),
            const SizedBox(height: 20),
            SecondaryButton(
                label: _busy ? 'Đang thu hồi…' : 'Thu hồi quyền truy cập',
                onPressed: _busy ? null : _revoke),
            const SizedBox(height: 6),
            const Text(
                'Không xóa lịch sử. Người đang giữ ca cần chốt ca trước khi bị thu hồi.',
                style: AppTextStyles.caption),
          ] else if (!m.isOwner && _active)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: KhoNote(
                  'Bạn chưa có quyền đổi vai trò hay thu hồi thành viên này.'),
            ),
        ],
      ),
    );
  }
}
