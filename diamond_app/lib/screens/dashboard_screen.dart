import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../auth/auth_gateway.dart';

const _purple = Color(0xFF6543C5);
const _ink = Color(0xFF241A3B);
const _muted = Color(0xFF817A90);
const _tabs = ['Home', 'Videos', 'Surveys', 'Tasks', 'Wallet', 'Profile'];
const _videoNetworks = ['Network A', 'Network B', 'Network C', 'Network D'];
const _tabIcons = [
  Icons.home_rounded,
  Icons.play_circle_outline_rounded,
  Icons.poll_outlined,
  Icons.check_circle_outline,
  Icons.account_balance_wallet_outlined,
  Icons.person_outline_rounded,
];

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    required this.user,
    required this.onSignOut,
    required this.signingOut,
    this.signOutNotice,
    this.client,
    super.key,
  });

  final AuthUser user;
  final SupabaseClient? client;
  final VoidCallback onSignOut;
  final bool signingOut;
  final String? signOutNotice;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selected = 0;
  int _selectedVideoNetwork = 0;
  bool _loading = true;
  String? _profileError;
  String? _balanceError;
  String? _name;
  String? _referral;
  int? _diamonds;
  int? _gummies;
  bool _tasksLoading = false;
  String? _tasksError;
  List<_Task> _tasks = const [];

  @override
  void initState() {
    super.initState();
    _loadAccountData();
  }

  Future<void> _loadAccountData() async {
    final client = widget.client;
    if (client == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _profileError = null;
      _balanceError = null;
    });
    try {
      final profile = await client
          .from('profiles')
          .select('display_name, referral_code')
          .eq('id', widget.user.id)
          .maybeSingle();
      if (profile != null) {
        _name = profile['display_name']?.toString();
        _referral = profile['referral_code']?.toString();
      }
    } catch (error) {
      _profileError = 'Profile details are unavailable: $error';
    }
    try {
      final balance = await client
          .from('reward_balances')
          .select('diamonds, gummies')
          .eq('user_id', widget.user.id)
          .maybeSingle();
      if (balance == null) {
        _diamonds = null;
        _gummies = null;
      } else {
        _diamonds = _asInt(balance['diamonds']);
        _gummies = _asInt(balance['gummies']);
      }
    } catch (error) {
      _balanceError = 'Reward balance is unavailable: $error';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _selectTab(int index) {
    setState(() => _selected = index);
    if (index == 3) _loadTasks();
  }

  Future<void> _loadTasks() async {
    final client = widget.client;
    if (client == null) {
      setState(() {
        _tasks = const [];
        _tasksError =
            'Task catalogue is unavailable because Supabase is not configured.';
        _tasksLoading = false;
      });
      return;
    }
    setState(() {
      _tasksLoading = true;
      _tasksError = null;
    });
    try {
      final rows = await client
          .from('tasks')
          .select(
            'id, title, description, image_url, estimated_minutes, '
            'diamond_reward, external_url',
          )
          .eq('is_active', true)
          .order('sort_order', ascending: true)
          .order('id', ascending: true);
      final tasks = rows
          .map((row) => _Task.fromMap(Map<String, dynamic>.from(row)))
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _tasksLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _tasks = const [];
        _tasksError = 'Unable to load tasks: $error';
        _tasksLoading = false;
      });
    }
  }

  int? _asInt(Object? value) => value is num ? value.toInt() : null;

  String get _displayName {
    final profileName = _name?.trim();
    if (profileName != null && profileName.isNotEmpty) return profileName;
    final authName = widget.user.displayName?.trim();
    if (authName != null && authName.isNotEmpty) return authName;
    final email = widget.user.email;
    return email.contains('@')
        ? email.substring(0, email.indexOf('@'))
        : 'there';
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final content = _selected == 0
        ? _homeContent()
        : _selected == 5
        ? _profileContent()
        : _selected == 1
        ? _videosContent()
        : _selected == 2
        ? _surveysContent()
        : _selected == 3
        ? _tasksContent()
        : _walletContent();
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (wide) _sideNavigation(),
            Expanded(
              child: Column(
                children: [
                  _topBar(),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1120),
                        child: content,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: wide ? null : _bottomNavigation(),
    );
  }

  Widget _topBar() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_purple, Color(0xFFE65A9B)],
            ),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.diamond_outlined, color: Colors.white),
        ),
        const SizedBox(width: 11),
        const Text(
          'Diamond Rewards',
          style: TextStyle(color: _ink, fontWeight: FontWeight.w800),
        ),
        const Spacer(),
        if (widget.signOutNotice != null)
          Flexible(
            child: Text(
              widget.signOutNotice!,
              style: const TextStyle(color: Color(0xFF9E3151), fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        const SizedBox(width: 8),
        CircleAvatar(
          backgroundColor: const Color(0xFFF0EAFE),
          child: Text(
            _displayName.isEmpty ? 'D' : _displayName[0].toUpperCase(),
            style: const TextStyle(color: _purple, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  Widget _sideNavigation() => Container(
    width: 220,
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
    child: Column(
      children: [
        const SizedBox(height: 28),
        for (var i = 0; i < _tabs.length; i++)
          ListTile(
            selected: _selected == i,
            selectedColor: _purple,
            selectedTileColor: const Color(0xFFF2EEFC),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            leading: Icon(_tabIcons[i]),
            title: Text(_tabs[i]),
            onTap: () => _selectTab(i),
          ),
      ],
    ),
  );

  Widget _bottomNavigation() => NavigationBar(
    selectedIndex: _selected,
    onDestinationSelected: _selectTab,
    backgroundColor: Colors.white,
    indicatorColor: const Color(0xFFEDE7FC),
    destinations: [
      for (var i = 0; i < _tabs.length; i++)
        NavigationDestination(icon: Icon(_tabIcons[i]), label: _tabs[i]),
    ],
  );

  Widget _homeContent() => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 740;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back, $_displayName!',
              style: const TextStyle(
                color: _ink,
                fontSize: 27,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Your rewards are waiting for you.',
              style: TextStyle(color: _muted),
            ),
            const SizedBox(height: 20),
            _balanceCard(),
            const SizedBox(height: 16),
            if (twoColumns)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _activityCard()),
                  const SizedBox(width: 16),
                  Expanded(child: _weeklyCard()),
                ],
              )
            else ...[
              _activityCard(),
              const SizedBox(height: 16),
              _weeklyCard(),
            ],
            const SizedBox(height: 16),
            _goalsCard(),
            const SizedBox(height: 16),
            if (_referral?.isNotEmpty == true)
              _referralCard()
            else
              _messageCard(
                'Referrals',
                'Your referral code is not available yet.',
              ),
            _topEarnersCard(),
          ],
        );
      },
    ),
  );

  Widget _balanceCard() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(23),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF6543C5), Color(0xFF9B59D0), Color(0xFFE65A9B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: _purple.withValues(alpha: .18),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'YOUR BALANCE',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.3,
          ),
        ),
        const SizedBox(height: 15),
        Wrap(
          spacing: 35,
          runSpacing: 18,
          children: [
            _balanceValue(
              Icons.diamond_outlined,
              _loading ? 'Loading…' : _format(_diamonds),
              'Diamonds',
            ),
            _balanceValue(
              Icons.card_giftcard_outlined,
              _loading ? 'Loading…' : _format(_gummies),
              'Gummies',
            ),
          ],
        ),
        const SizedBox(height: 17),
        const Divider(color: Colors.white30),
        const Text(
          r'1,000 diamonds = 1 gummy = $1',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        if (_balanceError != null) ...[
          const SizedBox(height: 10),
          Text(
            _balanceError!,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _loadAccountData,
              child: const Text('Retry'),
            ),
          ),
        ] else if (!_loading && _diamonds == null && _gummies == null)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Balance record not found yet.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
      ],
    ),
  );

  String _format(int? value) => value == null ? '—' : value.toString();

  Widget _balanceValue(IconData icon, String value, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: Colors.white, size: 26),
      const SizedBox(width: 10),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(label, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    ],
  );

  Widget _activityCard() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          'Your activity',
          Icons.local_fire_department_outlined,
        ),
        const SizedBox(height: 15),
        const Row(
          children: [
            Expanded(
              child: _Metric(
                label: 'Current streak',
                value: 'Unavailable',
                icon: Icons.local_fire_department,
                color: Color(0xFFF07A5A),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _Metric(
                label: "Today's activity",
                value: 'Unavailable',
                icon: Icons.bolt,
                color: _purple,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _weeklyCard() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('This week', Icons.bar_chart_rounded),
        const SizedBox(height: 20),
        SizedBox(
          height: 94,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final day in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 20,
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAE5F4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      day,
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Activity will appear here as you earn rewards.',
          style: TextStyle(color: _muted, fontSize: 12),
        ),
      ],
    ),
  );

  Widget _goalsCard() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Daily goals', Icons.flag_outlined),
        const SizedBox(height: 4),
        const Text(
          'Target: 200 diamonds today',
          style: TextStyle(color: _muted, fontSize: 13),
        ),
        const SizedBox(height: 12),
        for (final goal in [
          ('Videos', Icons.play_circle_outline),
          ('Surveys', Icons.poll_outlined),
          ('Tasks', Icons.check_circle_outline),
        ])
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(goal.$2, color: _purple),
            title: Text(goal.$1, style: const TextStyle(color: _ink)),
            trailing: const Text('No data', style: TextStyle(color: _muted)),
          ),
      ],
    ),
  );

  Widget _referralCard() => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: _card(
      child: Row(
        children: [
          const Icon(Icons.card_giftcard, color: Color(0xFFE65A9B), size: 29),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invite friends',
                  style: TextStyle(color: _ink, fontWeight: FontWeight.w700),
                ),
                Text(
                  'Your referral code',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
          SelectableText(
            _referral!,
            style: const TextStyle(color: _purple, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    ),
  );

  Widget _topEarnersCard() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _SectionTitle('Top earners', Icons.emoji_events_outlined),
        SizedBox(height: 9),
        Text(
          'Preview content · leaderboard data is not connected yet.',
          style: TextStyle(color: _muted, fontSize: 13),
        ),
      ],
    ),
  );

  Widget _profileContent() => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your profile',
          style: TextStyle(
            color: _ink,
            fontSize: 27,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 17),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFFF0EAFE),
                    foregroundImage: widget.user.avatarUrl == null
                        ? null
                        : NetworkImage(widget.user.avatarUrl!),
                    child: const Icon(Icons.person_outline, color: _purple),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayName,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          widget.user.email,
                          style: const TextStyle(color: _muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_profileError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _profileError!,
                    style: const TextStyle(color: Color(0xFF9E3151)),
                  ),
                ),
              if (_referral?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    'Referral code: $_referral',
                    style: const TextStyle(
                      color: _purple,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (_referral?.isNotEmpty != true)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text(
                    'Referral code unavailable.',
                    style: TextStyle(color: _muted),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Account',
                style: TextStyle(color: _ink, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Reward earning is managed securely by the server.',
                style: TextStyle(color: _muted),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: widget.signingOut ? null : widget.onSignOut,
                icon: widget.signingOut
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _tasksContent() => SingleChildScrollView(
    key: const Key('tasksCatalogue'),
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tasks',
          style: TextStyle(
            color: _ink,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Explore activities when verified tasks are available.',
          style: TextStyle(color: _muted),
        ),
        const SizedBox(height: 20),
        if (_tasksLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: _purple),
            ),
          )
        else if (_tasksError != null)
          _card(
            child: Column(
              children: [
                const Icon(Icons.cloud_off_outlined, color: _purple, size: 36),
                const SizedBox(height: 12),
                const Text(
                  'Task catalogue unavailable',
                  style: TextStyle(color: _ink, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  _tasksError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _muted),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _loadTasks,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          )
        else if (_tasks.isEmpty)
          _card(
            child: const Column(
              children: [
                Icon(Icons.checklist_rounded, color: _purple, size: 42),
                SizedBox(height: 12),
                Text(
                  'No tasks available right now',
                  style: TextStyle(color: _ink, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 6),
                Text(
                  'Please check back later for published tasks.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted),
                ),
              ],
            ),
          )
        else
          for (final task in _tasks) ...[
            _taskCard(task),
            if (task != _tasks.last) const SizedBox(height: 12),
          ],
        const SizedBox(height: 16),
        _card(
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.verified_user_outlined, color: _purple),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Task completion and reward verification are not available yet. Viewing a task does not complete it or earn a reward.',
                  style: TextStyle(color: _muted, height: 1.45),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _taskCard(_Task task) => _card(
    child: InkWell(
      key: Key('taskCard-${task.id}'),
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showTaskDetails(task),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Row(
          children: [
            if (task.imageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  task.imageUrl!,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const SizedBox(
                    width: 72,
                    height: 72,
                    child: Icon(Icons.image_not_supported_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (task.description?.isNotEmpty == true) ...[
                    const SizedBox(height: 5),
                    Text(
                      task.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, height: 1.4),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 14,
                    runSpacing: 5,
                    children: [
                      if (task.estimatedMinutes != null)
                        _taskFact(
                          Icons.schedule_outlined,
                          '${task.estimatedMinutes} min',
                        ),
                      _taskFact(
                        Icons.diamond_outlined,
                        '${task.diamondReward} diamonds',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: _purple),
          ],
        ),
      ),
    ),
  );

  Widget _taskFact(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: _purple, size: 16),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(color: _muted, fontSize: 12)),
    ],
  );

  Future<void> _showTaskDetails(_Task task) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(task.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.description?.isNotEmpty == true)
              Text(task.description!, style: const TextStyle(color: _muted)),
            if (task.externalUrl != null) ...[
              const SizedBox(height: 14),
              const Text(
                'External task link',
                style: TextStyle(color: _ink, fontWeight: FontWeight.w700),
              ),
              SelectableText(task.externalUrl!),
            ],
            const SizedBox(height: 14),
            Text(
              '${task.diamondReward} diamonds'
              '${task.estimatedMinutes == null ? '' : ' · ${task.estimatedMinutes} min'}',
              style: const TextStyle(
                color: _purple,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Task completion and verification are coming soon.',
              style: TextStyle(color: _muted),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Back to tasks'),
        ),
      ],
    ),
  );

  Widget _videosContent() => SingleChildScrollView(
    key: const Key('videosDesignPreview'),
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Watch Videos',
          style: TextStyle(
            color: _ink,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Choose an ad network to explore its videos.',
          style: TextStyle(color: _muted),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1ECFF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline_rounded, color: _purple, size: 17),
              SizedBox(width: 7),
              Text(
                'Design preview · not connected to ad networks',
                style: TextStyle(
                  color: _purple,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 44,
          child: ListView.separated(
            key: const Key('videoNetworkTabs'),
            scrollDirection: Axis.horizontal,
            itemCount: _videoNetworks.length,
            separatorBuilder: (context, index) => const SizedBox(width: 9),
            itemBuilder: (context, index) {
              final selected = _selectedVideoNetwork == index;
              return ChoiceChip(
                key: ValueKey('videoNetworkTab$index'),
                label: Text(_videoNetworks[index]),
                selected: selected,
                onSelected: (value) {
                  if (value) setState(() => _selectedVideoNetwork = index);
                },
                selectedColor: _purple,
                backgroundColor: Colors.white,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : _muted,
                  fontWeight: FontWeight.w700,
                ),
                side: BorderSide(
                  color: selected ? _purple : const Color(0xFFE7E1F0),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 17),
        Text(
          'Showing 5 videos for ${_videoNetworks[_selectedVideoNetwork]}',
          key: const Key('videosSelectedNetworkLabel'),
          style: const TextStyle(
            color: _ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < 5; index++) ...[
          KeyedSubtree(
            key: ValueKey('videoCard$index'),
            child: _videoPlaceholderCard(index),
          ),
          if (index < 4) const SizedBox(height: 11),
        ],
        const SizedBox(height: 15),
        _card(
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline_rounded, color: _purple),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'These cards are design placeholders only. Playback and ad-network integrations are not connected, and no reward is earned from tapping or viewing them.',
                  style: TextStyle(color: _muted, height: 1.45),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _videoPlaceholderCard(int index) => _card(
    child: Row(
      children: [
        Container(
          width: 78,
          height: 66,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: index.isEven
                  ? const [Color(0xFFE9E1FF), Color(0xFFFFE7F0)]
                  : const [Color(0xFFFFE7F0), Color(0xFFE9E1FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.diamond_outlined, color: _purple, size: 32),
              Positioned(
                right: 6,
                bottom: 5,
                child: Container(
                  width: 25,
                  height: 25,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: _purple,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Demo video ${index + 1}',
                key: ValueKey('videoTitle$index'),
                style: const TextStyle(
                  color: _ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${_videoNetworks[_selectedVideoNetwork]} · design placeholder',
                key: ValueKey('videoCardNetwork$index'),
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
              const SizedBox(height: 4),
              const Text(
                'Preview only · not playable',
                style: TextStyle(color: Color(0xFF9E3151), fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        const Icon(Icons.chevron_right_rounded, color: _purple),
      ],
    ),
  );

  Widget _surveysContent() => SingleChildScrollView(
    key: const Key('surveysUnavailableState'),
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Surveys',
          style: TextStyle(
            color: _ink,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Discover survey opportunities as they become available.',
          style: TextStyle(color: _muted),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF1ECFF), Color(0xFFFFEFF5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE9E1F6)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final visual = Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_purple, Color(0xFFE65A9B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: _purple.withValues(alpha: .2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.diamond_outlined, color: Colors.white, size: 64),
                    Positioned(
                      right: 15,
                      bottom: 15,
                      child: Icon(
                        Icons.poll_rounded,
                        color: Color(0xFFFFC2D8),
                        size: 29,
                      ),
                    ),
                  ],
                ),
              );
              final message = Column(
                crossAxisAlignment: compact
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'SURVEYS COMING SOON',
                      style: TextStyle(
                        color: _purple,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 13),
                  const Text(
                    'Surveys coming soon',
                    textAlign: TextAlign.start,
                    style: TextStyle(
                      color: _ink,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Survey opportunities will appear here when a verified catalog and provider integration are available.',
                    textAlign: TextAlign.start,
                    style: TextStyle(color: _muted, height: 1.45),
                  ),
                ],
              );
              if (compact) {
                return Column(
                  children: [visual, const SizedBox(height: 22), message],
                );
              }
              return Row(
                children: [
                  visual,
                  const SizedBox(width: 24),
                  Expanded(child: message),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        _card(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.verified_user_outlined, color: _purple),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'No survey provider or trusted completion flow is connected here. Opening or completing a client-side screen cannot confirm a reward.',
                  style: TextStyle(color: _muted, height: 1.45),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _walletContent() => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 760;
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your wallet',
              style: TextStyle(
                color: _ink,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Your rewards balance and wallet information.',
              style: TextStyle(color: _muted),
            ),
            const SizedBox(height: 20),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _walletBalanceCard()),
                  const SizedBox(width: 16),
                  Expanded(child: _walletConversionCard()),
                ],
              )
            else ...[
              _walletBalanceCard(),
              const SizedBox(height: 14),
              _walletConversionCard(),
            ],
            const SizedBox(height: 16),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _withdrawalAvailabilityCard()),
                  const SizedBox(width: 16),
                  Expanded(child: _walletHistoryCard()),
                ],
              )
            else ...[
              _withdrawalAvailabilityCard(),
              const SizedBox(height: 14),
              _walletHistoryCard(),
            ],
          ],
        ),
      );
    },
  );

  Widget _walletBalanceCard() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(23),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF6543C5), Color(0xFF985BD0), Color(0xFFE65A9B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: _purple.withValues(alpha: .18),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'AVAILABLE REWARDS',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            if (_loading)
              const SizedBox.square(
                dimension: 17,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              IconButton(
                tooltip: 'Refresh balance',
                onPressed: _loadAccountData,
                icon: const Icon(Icons.refresh, color: Colors.white),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _walletAmount(Icons.diamond_outlined, _diamonds, 'Diamonds'),
        const SizedBox(height: 14),
        Container(height: 1, color: Colors.white30),
        const SizedBox(height: 14),
        _walletAmount(Icons.card_giftcard_outlined, _gummies, 'Gummies'),
        if (_balanceError != null) ...[
          const SizedBox(height: 14),
          Text(
            'Balance could not be loaded: $_balanceError',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ] else if (!_loading && _diamonds == null && _gummies == null) ...[
          const SizedBox(height: 12),
          const Text(
            'No balance record is available for this account.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ],
    ),
  );

  Widget _walletAmount(IconData icon, int? amount, String label) => Row(
    children: [
      Icon(icon, color: Colors.white, size: 25),
      const SizedBox(width: 11),
      Expanded(
        child: Text(label, style: const TextStyle(color: Colors.white70)),
      ),
      Text(
        _loading ? 'Loading…' : _format(amount),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 23,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );

  Widget _walletConversionCard() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Conversion', Icons.swap_horiz_rounded),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 17),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F3FF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            children: [
              Expanded(child: _ConversionValue('1,000', 'diamonds')),
              Icon(Icons.arrow_forward_rounded, color: Color(0xFFE65A9B)),
              Expanded(child: _ConversionValue('1', 'gummy')),
              Icon(Icons.arrow_forward_rounded, color: Color(0xFFE65A9B)),
              Expanded(child: _ConversionValue('\$1', 'value')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Conversion shown for information. Redemptions are not available in the app yet.',
          style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
        ),
      ],
    ),
  );

  Widget _withdrawalAvailabilityCard() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          'Withdrawals',
          Icons.account_balance_wallet_outlined,
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1EC),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Not available yet',
            style: TextStyle(
              color: Color(0xFFB84C35),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Withdrawal processing has not been implemented. No payout methods or minimums are configured here.',
          style: TextStyle(color: _muted, height: 1.45),
        ),
      ],
    ),
  );

  Widget _walletHistoryCard() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Recent activity', Icons.receipt_long_outlined),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF9FF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            children: [
              Icon(Icons.history_rounded, color: _purple, size: 27),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Transaction history is unavailable until the ledger schema and read access are verified.',
                  style: TextStyle(color: _muted, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _messageCard(String label, String detail, {VoidCallback? retry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: _card(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _tabs.contains(label)
                    ? _tabIcons[_tabs.indexOf(label)]
                    : Icons.card_giftcard_outlined,
                color: _purple,
                size: 46,
              ),
              const SizedBox(height: 14),
              Text(
                label,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted, height: 1.45),
              ),
              if (retry != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFEDE9F4)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF31234B).withValues(alpha: .045),
          blurRadius: 16,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: child,
  );
}

class _Task {
  const _Task({
    required this.id,
    required this.title,
    required this.diamondReward,
    this.description,
    this.imageUrl,
    this.estimatedMinutes,
    this.externalUrl,
  });

  final String id;
  final String title;
  final String? description;
  final String? imageUrl;
  final int? estimatedMinutes;
  final int diamondReward;
  final String? externalUrl;

  factory _Task.fromMap(Map<String, dynamic> row) {
    final id = _nonEmptyString(row['id']);
    final title = _nonEmptyString(row['title']);
    final reward = row['diamond_reward'];
    if (id == null || title == null || reward is! num) {
      throw const FormatException(
        'Task row is missing required catalogue fields.',
      );
    }
    return _Task(
      id: id,
      title: title,
      description: _nonEmptyString(row['description']),
      imageUrl: _validHttpUrl(row['image_url']),
      estimatedMinutes: row['estimated_minutes'] is num
          ? (row['estimated_minutes'] as num).toInt()
          : null,
      diamondReward: reward.toInt(),
      externalUrl: _validHttpUrl(row['external_url']),
    );
  }

  static String? _nonEmptyString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static String? _validHttpUrl(Object? value) {
    final text = _nonEmptyString(value);
    if (text == null) return null;
    final uri = Uri.tryParse(text);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return null;
    }
    return uri.toString();
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, this.icon);
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: _purple),
      const SizedBox(width: 9),
      Text(
        text,
        style: const TextStyle(
          color: _ink,
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      ),
    ],
  );
}

class _ConversionValue extends StatelessWidget {
  const _ConversionValue(this.amount, this.label);

  final String amount;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(
        amount,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _purple,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(color: _muted, fontSize: 11),
      ),
    ],
  );
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFAF9FF),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(color: _ink, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
      ],
    ),
  );
}
