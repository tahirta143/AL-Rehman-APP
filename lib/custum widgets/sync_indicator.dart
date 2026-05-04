import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/sync_provider.dart';

class SyncIndicator extends StatelessWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncProvider>(
      builder: (context, syncProv, child) {
        final bool isOnline = syncProv.isOnline;
        final int pending = syncProv.pendingCount;
        final bool isSyncing = syncProv.isSyncing;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: syncProv.toggleOfflineOverride,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: syncProv.isOfflineForced
                    ? Colors.red.withOpacity(0.2)
                    : (isOnline 
                        ? Colors.green.withOpacity(0.2) 
                        : Colors.orange.withOpacity(0.2)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      isOnline ? Icons.wifi : Icons.wifi_off,
                      size: 14,
                      color: syncProv.isOfflineForced 
                        ? Colors.red 
                        : (isOnline ? Colors.green : Colors.orange),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      syncProv.isOfflineForced ? 'Forced Offline' : (isOnline ? 'Online' : 'Offline'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: syncProv.isOfflineForced 
                          ? Colors.red 
                          : (isOnline ? Colors.green : Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Pending Count / Sync Button
            if (pending > 0 || isSyncing)
              GestureDetector(
                onLongPress: () => _showBootstrapDialog(context, syncProv),
                onTap: isOnline && !isSyncing ? () => syncProv.syncData() : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      if (isSyncing)
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      else
                        const Icon(Icons.sync, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        isSyncing ? 'Syncing...' : '$pending Pending',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showBootstrapDialog(BuildContext context, SyncProvider syncProv) {
    final TextEditingController campIdController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Camp Bootstrap'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter Camp ID (UUID) to download master data.'),
            TextField(
              controller: campIdController,
              decoration: const InputDecoration(labelText: 'Camp ID'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final campId = campIdController.text.trim();
              if (campId.isNotEmpty) {
                Navigator.pop(context);
                await syncProv.bootstrap(campId);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(syncProv.lastErrorMessage ?? 'Master data updated successfully'),
                    backgroundColor: syncProv.lastErrorMessage == null ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }
}
