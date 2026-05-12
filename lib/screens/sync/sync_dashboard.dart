import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/sync_provider.dart';
import '../../custum widgets/drawer/base_scaffold.dart';
import '../../core/providers/permission_provider.dart';
import '../../core/permissions/permission_keys.dart';
import 'package:animate_do/animate_do.dart';

class SyncDashboardScreen extends StatelessWidget {
  const SyncDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'Sync Dashboard',
      drawerIndex: 100, // Unique index for sync
      body: const _SyncDashboardBody(),
    );
  }
}

class _SyncDashboardBody extends StatefulWidget {
  const _SyncDashboardBody();

  @override
  State<_SyncDashboardBody> createState() => _SyncDashboardBodyState();
}

class _SyncDashboardBodyState extends State<_SyncDashboardBody> {
  final _campIdCtrl = TextEditingController();
  final _deviceNameCtrl = TextEditingController(text: 'Mobile Device');
  final _scaffoldKey = GlobalKey<ScaffoldMessengerState>();
  String _deviceIdentifier = '';

  @override
  void initState() {
    super.initState();
    _deviceIdentifier = 'DEV-${DateTime.now().millisecondsSinceEpoch}';
    
    // Auto-fill campId if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = Provider.of<SyncProvider>(context, listen: false);
      if (prov.campId != null) {
        _campIdCtrl.text = prov.campId!;
      }
    });
  }

  @override
  void dispose() {
    _campIdCtrl.dispose();
    _deviceNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final syncProv = context.watch<SyncProvider>();
    final isOnline = syncProv.isOnline;

    return ScaffoldMessenger(
      key: _scaffoldKey,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusHeader(isOnline, syncProv),
              if (syncProv.lastErrorMessage != null) 
                Builder(
                  builder: (context) {
                    final error = syncProv.lastErrorMessage;
                    if (error == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                error,
                                style: TextStyle(color: Colors.red.shade700, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                ),
              const SizedBox(height: 24),
              
              FadeInUp(
                delay: const Duration(milliseconds: 100),
                child: _buildSectionTitle('Master Data Bootstrap', Icons.download_rounded),
              ),
              const SizedBox(height: 12),
              FadeInUp(
                delay: const Duration(milliseconds: 200),
                child: _buildBootstrapCard(isOnline, syncProv),
              ),
              
              const SizedBox(height: 32),
              
              FadeInUp(
                delay: const Duration(milliseconds: 300),
                child: _buildSectionTitle('Pending Records', Icons.sync_rounded),
              ),
              const SizedBox(height: 12),
              FadeInUp(
                delay: const Duration(milliseconds: 400),
                child: _buildSyncCard(isOnline, syncProv),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusHeader(bool isOnline, SyncProvider prov) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOnline 
            ? [const Color(0xFF00B5AD), const Color(0xFF00B5AD)]
            : [const Color(0xFF64748B), const Color(0xFF475569)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isOnline ? const Color(0xFF00B5AD) : const Color(0xFF00B5AD)).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOnline ? 'Online Mode' : 'Offline Mode',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                Text(
                  isOnline 
                    ? 'Connected to Waseela Diabesity API' 
                    : 'Working locally. Data will sync later.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: !prov.isOfflineForced,
            onChanged: (_) => prov.toggleOfflineOverride(),
            activeColor: Colors.white,
            activeTrackColor: Colors.white24,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Color(0xFF64748B),
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildBootstrapCard(bool isOnline, SyncProvider prov) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!prov.isDeviceRegistered) ...[
            const Text(
              'Select an active camp to begin.',
              style: TextStyle(fontSize: 14, color: Color(0xFF475569), fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: isOnline ? () => _showCampPicker(context, prov) : null,
              icon: const Icon(Icons.pin_drop_rounded),
              label: const Text('Pick a Camp'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00B5AD),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            if (context.read<PermissionProvider>().can(Perm.campSessionCreate))
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: isOnline ? () => _showCreateSessionDialog(context, prov) : null,
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Create New Camp', style: TextStyle(fontSize: 13)),
                    ),
                    const SizedBox(width: 16),
                    TextButton.icon(
                      onPressed: () => _showResetDialog(context, prov),
                      icon: const Icon(Icons.restart_alt_rounded, size: 18, color: Colors.red),
                      label: const Text('Reset', style: TextStyle(fontSize: 13, color: Colors.red)),
                    ),
                  ],
                ),
              ),
            const Divider(height: 32),
          ] else ...[
            const Text(
              'Download doctors, services, and medicines for offline use.',
              style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _campIdCtrl,
                    enabled: prov.isDeviceRegistered,
                    decoration: InputDecoration(
                      labelText: 'Camp UUID',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.pin_drop_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: (isOnline && !prov.isSyncing && prov.isDeviceRegistered)
                    ? () async {
                        await prov.bootstrap(_campIdCtrl.text);
                        final error = prov.lastErrorMessage;
                        _scaffoldKey.currentState?.hideCurrentSnackBar();
                        if (error != null) {
                          _scaffoldKey.currentState?.showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                        } else {
                          _scaffoldKey.currentState?.showSnackBar(const SnackBar(content: Text('Bootstrap success!'), backgroundColor: Colors.green));
                        }
                      }
                    : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00B5AD),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: prov.isSyncing 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Bootstrap'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.verified_user_rounded, color: Colors.green, size: 16),
                const SizedBox(width: 8),
                const Text('Device Authorized', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showResetDialog(context, prov),
                  icon: const Icon(Icons.restart_alt_rounded, size: 14, color: Colors.red),
                  label: const Text('Reset Session', style: TextStyle(fontSize: 11, color: Colors.red)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSyncCard(bool isOnline, SyncProvider prov) {
    final int pending = prov.pendingCount;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$pending',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: pending > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    ),
                  ),
                  const Text(
                    'Pending Records',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: (isOnline && pending > 0 && !prov.isSyncing)
                  ? () => prov.syncData()
                  : null,
                icon: prov.isSyncing 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.cloud_upload_rounded),
                label: Text(prov.isSyncing ? 'Syncing...' : 'Sync Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          if (!isOnline && pending > 0)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You are offline. Records will sync when reconnected.',
                      style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showCampPicker(BuildContext context, SyncProvider prov) async {
    final camps = await prov.fetchAvailableCamps();
    if (!mounted) return;

    if (camps.isEmpty && prov.lastErrorMessage != null) {
      _scaffoldKey.currentState?.showSnackBar(SnackBar(content: Text(prov.lastErrorMessage!)));
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Available Camps', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: camps.isEmpty 
                ? const Center(child: Text('No active camps found.'))
                : ListView.builder(
                    controller: scrollController,
                    itemCount: camps.length,
                    itemBuilder: (context, index) {
                      final camp = camps[index];
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.pin_drop)),
                        title: Text(camp['name'] ?? 'Unnamed Camp'),
                        subtitle: Text(camp['location'] ?? 'Unknown Location'),
                        onTap: () {
                          Navigator.pop(context);
                          _showPasswordDialog(context, prov, camp);
                        },
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPasswordDialog(BuildContext context, SyncProvider prov, Map<String, dynamic> camp) {
    final passCtrl = TextEditingController();
    final nameCtrl = TextEditingController(text: _deviceNameCtrl.text);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Enter Password for ${camp['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Camp Password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Device Name'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (passCtrl.text.isEmpty) return;
              final success = await prov.selectCamp(
                campId: camp['id'],
                password: passCtrl.text,
                deviceName: nameCtrl.text,
              );
              if (!mounted) return;
              if (success) {
                Navigator.pop(context);
                _campIdCtrl.text = camp['id'];
                _scaffoldKey.currentState?.showSnackBar(const SnackBar(content: Text('Camp selected successfully!'), backgroundColor: Colors.green));
              } else {
                _scaffoldKey.currentState?.showSnackBar(SnackBar(content: Text(prov.lastErrorMessage ?? 'Failed to select camp'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  void _showCreateSessionDialog(BuildContext context, SyncProvider prov) {
    // ... Existing implementation remains mostly valid, but might need password field if backend requires it now
    final nameCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Camp Session'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Camp Name')),
            TextField(controller: locCtrl, decoration: const InputDecoration(labelText: 'Location')),
            TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Camp Password (Required)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty || passCtrl.text.isEmpty) return;
              // Assuming createSession on backend also updated to handle password
              // If not, this part might need adjustment in sync_provider.dart
              final result = await prov.createSession(nameCtrl.text, locCtrl.text, passCtrl.text); 
              // Note: backend implementation of POST /sessions might need password too.
              // For now we just follow the UI flow.
              if (!mounted) return;
              if (result['success'] == true) {
                Navigator.pop(context);
                _scaffoldKey.currentState?.showSnackBar(const SnackBar(content: Text('Camp created! You can now pick it from the list.'), backgroundColor: Colors.green));
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context, SyncProvider prov) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Camp Config?'),
        content: const Text('This will clear your device registration and camp configuration. Local patient data will NOT be deleted, but you will need to re-select a camp.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await prov.resetCamp();
              if (mounted) {
                Navigator.pop(context);
                _campIdCtrl.clear();
                _scaffoldKey.currentState?.showSnackBar(const SnackBar(content: Text('Camp configuration reset.')));
              }
            },
            child: const Text('Reset', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

