import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/sync_provider.dart';
import '../../custum widgets/drawer/base_scaffold.dart';
import '../../core/providers/permission_provider.dart';
import '../../core/permissions/permission_keys.dart';
import '../../custum widgets/custom_loader.dart';
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
                        _showLoadingOverlay(context);
                        await prov.bootstrap(_campIdCtrl.text);
                        Navigator.pop(context); // Close loading overlay
                        
                        final error = prov.lastErrorMessage;
                        if (error != null) {
                          _showStatusDialog(context, 'Bootstrap Failed', error, isError: true);
                        } else {
                          _showStatusDialog(context, 'Bootstrap Success', 'Master data has been successfully downloaded.');
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
                  ? () async {
                      await prov.syncData();
                      if (!mounted) return;
                      final error = prov.lastErrorMessage;
                      if (error != null) {
                        _showStatusDialog(context, 'Sync Failed', error, isError: true);
                      } else {
                        _showStatusDialog(context, 'Sync Success', 'All records have been synchronized.');
                      }
                    }
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

  void _showCampPicker(BuildContext context, SyncProvider prov) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          expand: false,
          builder: (scrollContext, scrollController) => Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text('Available Camps', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              ),
              Expanded(
                child: FutureBuilder<List<dynamic>>(
                  future: prov.fetchAvailableCamps(),
                  builder: (futureContext, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CustomLoader(size: 40,color: Color(0xFF00B5AD),));
                    }
                    
                    if (snapshot.hasError || (snapshot.data == null || snapshot.data!.isEmpty)) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.location_off_rounded, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              prov.lastErrorMessage ?? 'No active camps found.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      );
                    }

                    final camps = snapshot.data!;
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: camps.length,
                      itemBuilder: (listContext, index) {
                        final camp = camps[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00B5AD).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.pin_drop_rounded, color: Color(0xFF00B5AD)),
                            ),
                            title: Text(camp['name'] ?? 'Unnamed Camp', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(camp['location'] ?? 'Unknown Location'),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              _showPasswordDialog(context, prov, camp);
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPasswordDialog(BuildContext context, SyncProvider prov, Map<String, dynamic> camp) {
    final passCtrl = TextEditingController();
    final nameCtrl = TextEditingController(text: _deviceNameCtrl.text);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Connect to ${camp['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Camp Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Device Name',
                prefixIcon: const Icon(Icons.devices_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (passCtrl.text.isEmpty) return;
              
              Navigator.pop(dialogContext); // Close password dialog
              _showLoadingOverlay(context);
              
              final success = await prov.selectCamp(
                campId: camp['id'],
                password: passCtrl.text,
                deviceName: nameCtrl.text,
              );
              
              if (!mounted) return;
              Navigator.pop(context); // Close loading overlay (using screen context)
              
              if (success) {
                _campIdCtrl.text = camp['id'];
                _showStatusDialog(context, 'Registration Success', 'Device has been registered to ${camp['name']}');
              } else {
                _showStatusDialog(context, 'Registration Failed', prov.lastErrorMessage ?? 'Failed to select camp', isError: true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00B5AD),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  void _showCreateSessionDialog(BuildContext context, SyncProvider prov) {
    final nameCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final mrPrefixCtrl = TextEditingController();
    final limitCtrl = TextEditingController(text: '5');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('New Camp Session'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl, 
                decoration: InputDecoration(
                  labelText: 'Camp Name *',
                  prefixIcon: const Icon(Icons.drive_file_rename_outline_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locCtrl, 
                decoration: InputDecoration(
                  labelText: 'Location',
                  prefixIcon: const Icon(Icons.location_on_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: mrPrefixCtrl, 
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: 'MR Prefix',
                        prefixIcon: const Icon(Icons.tag_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        hintText: 'e.g. CAMP1',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: limitCtrl, 
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Limit *',
                        prefixIcon: const Icon(Icons.smartphone_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passCtrl, 
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Sync Password *',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  helperText: 'Required for device connection',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty || passCtrl.text.isEmpty) return;
              
              Navigator.pop(dialogContext); // Close dialog
              _showLoadingOverlay(context);
              
              final result = await prov.createSession(
                name: nameCtrl.text,
                location: locCtrl.text,
                password: passCtrl.text,
                mrPrefix: mrPrefixCtrl.text,
                deviceLimit: int.tryParse(limitCtrl.text) ?? 5,
              ); 
              
              if (!mounted) return;
              Navigator.pop(context); // Close loading overlay
              
              if (result['success'] == true) {
                _showStatusDialog(context, 'Camp Created', 'You can now pick "${nameCtrl.text}" from the list.');
              } else {
                _showStatusDialog(context, 'Creation Failed', result['message'] ?? 'Failed to create camp', isError: true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00B5AD),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Create Camp'),
          ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context, SyncProvider prov) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                _showStatusDialog(context, 'Reset Successful', 'Camp configuration has been cleared.');
              }
            },
            child: const Text('Reset', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showLoadingOverlay(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (loadingContext) => Center(
        child: Consumer<SyncProvider>(
          builder: (context, prov, child) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CustomLoader(size: 60),
              if (prov.syncStatus != null) ...[
                const SizedBox(height: 24),
                Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      prov.syncStatus!,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showStatusDialog(BuildContext context, String title, String message, {bool isError = false}) {
    showDialog(
      context: context,
      builder: (statusContext) {
        // Auto dismiss after 2 seconds on success
        if (!isError) {
          Future.delayed(const Duration(seconds: 2), () {
            if (Navigator.canPop(statusContext)) {
              Navigator.pop(statusContext);
            }
          });
        }

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: (isError ? Colors.red : const Color(0xFF00B5AD)).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                    color: isError ? Colors.red : const Color(0xFF00B5AD),
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                if (isError) ...[
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(statusContext),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 45),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Dismiss'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

