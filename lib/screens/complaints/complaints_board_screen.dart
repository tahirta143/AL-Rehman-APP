import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../core/services/complaints_api_service.dart';
import '../../custum widgets/custom_loader.dart';
import '../../custum widgets/drawer/base_scaffold.dart';

class ComplaintsBoardScreen extends StatefulWidget {
  const ComplaintsBoardScreen({super.key});

  @override
  State<ComplaintsBoardScreen> createState() => _ComplaintsBoardScreenState();
}

class _ComplaintsBoardScreenState extends State<ComplaintsBoardScreen> {
  final ComplaintsApiService _apiService = ComplaintsApiService();

  bool _isLoading = true;
  bool _isSyncing = false;
  String _layoutMode = 'tree'; // 'tree' or 'free'
  String _searchQuery = '';
  String _statusFilter = 'all'; // 'all' or 'open'
  String _priorityFilter = 'all'; // 'all' or 'critical'

  Map<String, dynamic>? _graphData;
  List<dynamic> _visibleNodes = [];
  List<dynamic> _visibleEdges = [];
  final Map<String, Offset> _nodePositions = {};

  Timer? _dragSaveTimer;
  final ValueNotifier<Matrix4> _canvasTransform = ValueNotifier(Matrix4.identity());
  final TransformationController _transformationController = TransformationController();
  bool _isDraggingNode = false;
  Size _lastViewportSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _loadGraph();
  }

  @override
  void dispose() {
    _dragSaveTimer?.cancel();
    _canvasTransform.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _loadGraph() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final res = await _apiService.getGraph(mode: _layoutMode);
      if (res['success'] == true && res['data'] != null) {
        _graphData = res['data'];
        _processGraphData();
      } else {
        _showSnackBar(res['message'] ?? 'Failed to load graph data', isError: true);
      }
    } catch (e) {
      _showSnackBar('Network error: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _syncSidebar() async {
    setState(() {
      _isSyncing = true;
    });
    try {
      final res = await _apiService.syncSidebar();
      if (res['success'] == true) {
        final count = res['data']?['synced'] ?? 0;
        _showSnackBar('Synced $count sidebar nodes successfully');
        _loadGraph();
      } else {
        _showSnackBar(res['message'] ?? 'Failed to sync sidebars', isError: true);
      }
    } catch (e) {
      _showSnackBar('Network error: $e', isError: true);
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  void _processGraphData() {
    if (_graphData == null) return;

    final allNodes = List<dynamic>.from(_graphData!['nodes'] ?? []);
    final allEdges = List<dynamic>.from(_graphData!['edges'] ?? []);

    final search = _searchQuery.trim().toLowerCase();
    final onlyOpen = _statusFilter == 'open';
    final onlyCritical = _priorityFilter == 'critical';

    // 1. Filter Nodes
    _visibleNodes = allNodes.filter((node) {
      final label = String.fromCharCodes(node['label']?.toString().codeUnits ?? []).toLowerCase();
      final path = (node['route_path'] ?? '').toString().toLowerCase();
      final matchesSearch = search.isEmpty || label.contains(search) || path.contains(search);

      final openCount = node['metrics']?['open'] ?? 0;
      final matchesOpen = !onlyOpen || openCount > 0;

      final criticalCount = node['metrics']?['critical'] ?? 0;
      final matchesCritical = !onlyCritical || criticalCount > 0;

      return matchesSearch && matchesOpen && matchesCritical;
    }).toList();

    final visibleKeys = _visibleNodes.map((n) => n['node_key'].toString()).toSet();

    // 2. Filter Edges
    _visibleEdges = allEdges.where((edge) {
      return visibleKeys.contains(edge['source'].toString()) &&
          visibleKeys.contains(edge['target'].toString());
    }).toList();

    // 3. Compute Positions
    if (_layoutMode == 'free') {
      for (final node in _visibleNodes) {
        final key = node['node_key'].toString();
        final pos = node['position'];
        if (pos != null && pos['x'] != null && pos['y'] != null) {
          _nodePositions[key] = Offset(double.parse(pos['x'].toString()), double.parse(pos['y'].toString()));
        } else {
          _nodePositions[key] = Offset(100.0 + _visibleNodes.indexOf(node) * 60, 100.0 + _visibleNodes.indexOf(node) * 60);
        }
      }
    } else {
      // Tree / Hierarchical Horizontal Column Layout based on depth layer
      final Map<int, List<dynamic>> depthGroups = {};
      for (final node in _visibleNodes) {
        final depth = node['depth'] ?? 0;
        depthGroups.putIfAbsent(depth, () => []).add(node);
      }

      double minY = double.infinity;

      depthGroups.forEach((depth, list) {
        // Sort items at each depth
        list.sort((a, b) {
          final pa = a['parent_node_key'] ?? '';
          final pb = b['parent_node_key'] ?? '';
          if (pa != pb) return pa.compareTo(pb);
          return (a['sort_order'] ?? 0).compareTo(b['sort_order'] ?? 0);
        });

        for (int i = 0; i < list.length; i++) {
          final node = list[i];
          final key = node['node_key'].toString();
          
          final double x = depth * 320.0 + 80.0;
          final double centerYOffset = (list.length - 1) * 140.0 / 2.0;
          final double y = i * 160.0 - centerYOffset + 1000.0;
          
          _nodePositions[key] = Offset(x, y);
          if (y < minY) {
            minY = y;
          }
        }
      });

      if (minY < double.infinity && minY < 80.0) {
        final double shift = 80.0 - minY;
        _nodePositions.forEach((key, offset) {
          _nodePositions[key] = Offset(offset.dx, offset.dy + shift);
        });
      }
    }
    _triggerFitView();
  }

  void _onNodeDragged(String nodeKey, Offset delta) {
    if (_layoutMode != 'free') return;
    setState(() {
      final currentPos = _nodePositions[nodeKey] ?? Offset.zero;
      final newPos = currentPos + delta;
      _nodePositions[nodeKey] = newPos;
      _onNodeDragStopDebounced(nodeKey, newPos);
    });
  }

  void _onNodeDragStopDebounced(String nodeKey, Offset pos) {
    _dragSaveTimer?.cancel();
    _dragSaveTimer = Timer(const Duration(milliseconds: 450), () async {
      try {
        await _apiService.saveNodePositions({
          'layoutMode': 'free',
          'nodeKey': nodeKey,
          'x': pos.dx,
          'y': pos.dy,
        });
      } catch (e) {
        debugPrint("Error auto-saving position: $e");
      }
    });
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.teal,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Lucide icon mapping to Material icons
  IconData _getIconData(String? key) {
    switch (key) {
      case 'Bug':
        return Icons.bug_report_rounded;
      case 'AlertCircle':
        return Icons.error_outline_rounded;
      case 'FileText':
        return Icons.description_rounded;
      case 'LayoutDashboard':
        return Icons.dashboard_rounded;
      case 'MessageSquare':
        return Icons.chat_bubble_outline_rounded;
      case 'Activity':
        return Icons.local_activity_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _getToneColor(String tone) {
    switch (tone) {
      case 'critical':
        return Colors.red.shade600;
      case 'active':
        return const Color(0xFF00B5AD);
      case 'resolved':
        return Colors.teal.shade600;
      default:
        return Colors.grey.shade400;
    }
  }

  String _getToneString(Map<String, dynamic> metrics) {
    final int critical = metrics['critical'] ?? 0;
    final int open = metrics['open'] ?? 0;
    final int resolved = metrics['resolved'] ?? 0;
    if (critical > 0) return 'critical';
    if (open > 0) return 'active';
    if (resolved > 0) return 'resolved';
    return 'quiet';
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'Complaints Board',
      drawerIndex: 23,
      body: Column(
        children: [
          // Toolbar
          _buildToolbar(),
          
          Expanded(
            child: Stack(
              children: [
                _isLoading
                    ? const CustomLoader(color: Color(0xFF00B5AD),)
                    : _visibleNodes.isEmpty
                        ? _buildEmptyState()
                        : _buildCanvas(),
                _buildLegend(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hub_outlined, color: Color(0xFF00B5AD), size: 48),
            const SizedBox(height: 12),
            const Text(
              'No menu nodes found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try syncing or clearing your search filters.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _syncSidebar,
              icon: const Icon(Icons.sync),
              label: const Text('Sync Sidebar Catalog'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00B5AD),
                foregroundColor: Colors.white,
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 20),
                    hintText: 'Search menu nodes...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF00B5AD)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                      _processGraphData();
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: const Icon(Icons.filter_list, color: Color(0xFF00B5AD)),
                onSelected: (val) {
                  setState(() {
                    if (val == 'open') {
                      _statusFilter = _statusFilter == 'open' ? 'all' : 'open';
                    } else if (val == 'critical') {
                      _priorityFilter = _priorityFilter == 'critical' ? 'all' : 'critical';
                    }
                    _processGraphData();
                  });
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'open',
                    child: Row(
                      children: [
                        Checkbox(
                          value: _statusFilter == 'open',
                          onChanged: null,
                          activeColor: const Color(0xFF00B5AD),
                        ),
                        const Text('Only with Open Items'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'critical',
                    child: Row(
                      children: [
                        Checkbox(
                          value: _priorityFilter == 'critical',
                          onChanged: null,
                          activeColor: Colors.red,
                        ),
                        const Text('Only Critical'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Layout Mode Toggle Button
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    _buildToggleItem('tree', 'Tree Layout'),
                    _buildToggleItem('free', 'Free Layout'),
                  ],
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _isSyncing ? null : _syncSidebar,
                icon: _isSyncing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.sync_outlined, size: 16),
                label: const Text('Sync Menu Catalog', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00B5AD),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildToggleItem(String mode, String label) {
    final active = _layoutMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _layoutMode = mode;
          _processGraphData();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF00B5AD) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.grey.shade600,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildCanvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (_lastViewportSize != size) {
          _lastViewportSize = size;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _fitView(size);
          });
        }

        return Stack(
          children: [
            InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.18,
              maxScale: 1.6,
              constrained: false,
              panEnabled: !_isDraggingNode,
              boundaryMargin: const EdgeInsets.all(3000),
              child: SizedBox(
                width: 4000,
                height: 4000,
                child: Stack(
                  children: [
                    // Grid Background
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _GridBackgroundPainter(),
                      ),
                    ),
                    // Custom Painter to Draw Edges
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _EdgePainter(
                          edges: _visibleEdges,
                          positions: _nodePositions,
                          nodeWidth: 244,
                          nodeHeight: 92,
                        ),
                      ),
                    ),
                    // Positioned nodes
                    ..._visibleNodes.map((node) {
                      final key = node['node_key'].toString();
                      final pos = _nodePositions[key] ?? const Offset(100, 100);
                      final tone = _getToneString(node['metrics'] ?? {});

                      return Positioned(
                        left: pos.dx,
                        top: pos.dy,
                        child: GestureDetector(
                          onPanStart: _layoutMode == 'free'
                              ? (_) => setState(() => _isDraggingNode = true)
                              : null,
                          onPanUpdate: _layoutMode == 'free'
                              ? (details) => _onNodeDragged(key, details.delta)
                              : null,
                          onPanEnd: _layoutMode == 'free'
                              ? (_) => setState(() => _isDraggingNode = false)
                              : null,
                          onPanCancel: _layoutMode == 'free'
                              ? () => setState(() => _isDraggingNode = false)
                              : null,
                          onTap: () => _openInspector(node),
                          child: _buildNodeCard(node, tone),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            // Floating Zoom and Fit Controls (ReactFlow Style)
            Positioned(
              bottom: 24,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildControlButton(
                    icon: Icons.center_focus_strong,
                    tooltip: 'Center View (Fit)',
                    onTap: _triggerFitView,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Tooltip(
            message: tooltip,
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Icon(icon, size: 20, color: const Color(0xFF00B5AD)),
            ),
          ),
        ),
      ),
    );
  }

  void _fitView(Size viewportSize) {
    if (_nodePositions.isEmpty) return;

    double minX = double.infinity;
    double maxX = -double.infinity;
    double minY = double.infinity;
    double maxY = -double.infinity;

    for (final pos in _nodePositions.values) {
      if (pos.dx < minX) minX = pos.dx;
      if (pos.dx > maxX) maxX = pos.dx;
      if (pos.dy < minY) minY = pos.dy;
      if (pos.dy > maxY) maxY = pos.dy;
    }

    final double boardWidth = maxX - minX + 244.0;
    final double boardHeight = maxY - minY + 92.0;

    final double centerX = minX + boardWidth / 2;
    final double centerY = minY + boardHeight / 2;

    final double scaleX = viewportSize.width / (boardWidth + 100.0);
    final double scaleY = viewportSize.height / (boardHeight + 100.0);
    double scale = scaleX < scaleY ? scaleX : scaleY;

    if (scale < 0.18) scale = 0.18;
    if (scale > 1.0) scale = 1.0;

    final double tx = viewportSize.width / 2 - centerX * scale;
    final double ty = viewportSize.height / 2 - centerY * scale;

    final Matrix4 matrix = Matrix4.identity()
      ..translate(tx, ty)
      ..scale(scale);

    _transformationController.value = matrix;
  }

  void _triggerFitView() {
    if (_lastViewportSize != Size.zero) {
      _fitView(_lastViewportSize);
    }
  }

  void _zoom(double factor) {
    if (_lastViewportSize == Size.zero) return;

    final currentMatrix = _transformationController.value;
    final double currentScale = currentMatrix.getMaxScaleOnAxis();
    double newScale = currentScale * factor;

    if (newScale < 0.18) newScale = 0.18;
    if (newScale > 1.6) newScale = 1.6;

    final double scaleMultiplier = newScale / currentScale;

    final double centerX = _lastViewportSize.width / 2;
    final double centerY = _lastViewportSize.height / 2;

    final translation = currentMatrix.getTranslation();
    final double tx = centerX - (centerX - translation.x) * scaleMultiplier;
    final double ty = centerY - (centerY - translation.y) * scaleMultiplier;

    final Matrix4 newMatrix = Matrix4.identity()
      ..translate(tx, ty)
      ..scale(newScale);

    _transformationController.value = newMatrix;
  }

  Widget _buildNodeCard(Map<String, dynamic> node, String tone) {
    final label = node['label'] ?? 'Node';
    final path = node['route_path'] ?? 'Sidebar group';
    final iconKey = node['icon_key'];
    final open = node['metrics']?['open'] ?? 0;
    final critical = node['metrics']?['critical'] ?? 0;
    final total = node['metrics']?['total'] ?? 0;
    final latestAct = node['metrics']?['latestActivityAt'];

    return Container(
      width: 244,
      height: 92,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _getToneColor(tone).withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF00B5AD).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(_getIconData(iconKey), color: const Color(0xFF00B5AD), size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, overflow: TextOverflow.ellipsis),
                    ),
                    Text(
                      path,
                      style: const TextStyle(fontSize: 10, color: Colors.grey, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              )
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF00B5AD).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.circle_outlined, size: 10, color: Color(0xFF007A76)),
                    const SizedBox(width: 3),
                    Text(
                      '$open',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF007A76)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              if (critical > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: Text(
                    '$critical Critical',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.red.shade700),
                  ),
                ),
              if (total == 0)
                const Text('clear', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(
                latestAct != null ? _formatDate(latestAct.toString()) : 'No activity',
                style: const TextStyle(fontSize: 9, color: Colors.grey),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Positioned(
      bottom: 24,
      left: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: const Text(
          'Drag nodes to organize (Free layout) · Tap node to inspect',
          style: TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return DateFormat('MMM dd, hh:mm a').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  void _openInspector(Map<String, dynamic> node) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _InspectorWidget(
        node: node,
        apiService: _apiService,
        onRefreshNeeded: _loadGraph,
      ),
    );
  }
}

class _GridBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1.0;

    const double step = 22.0;

    for (double i = 0; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EdgePainter extends CustomPainter {
  final List<dynamic> edges;
  final Map<String, Offset> positions;
  final double nodeWidth;
  final double nodeHeight;

  _EdgePainter({
    required this.edges,
    required this.positions,
    required this.nodeWidth,
    required this.nodeHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00B5AD).withOpacity(0.38)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    for (final edge in edges) {
      final srcKey = edge['source'].toString();
      final tgtKey = edge['target'].toString();

      final srcPos = positions[srcKey];
      final tgtPos = positions[tgtKey];

      if (srcPos != null && tgtPos != null) {
        // Output pin is middle of right edge of source card
        final outPin = Offset(srcPos.dx + nodeWidth, srcPos.dy + nodeHeight / 2);
        // Input pin is middle of left edge of target card
        final inPin = Offset(tgtPos.dx, tgtPos.dy + nodeHeight / 2);

        final path = Path()..moveTo(outPin.dx, outPin.dy);
        final controlX1 = outPin.dx + 60.0;
        final controlX2 = inPin.dx - 60.0;

        path.cubicTo(controlX1, outPin.dy, controlX2, inPin.dy, inPin.dx, inPin.dy);
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EdgePainter oldDelegate) => true;
}

// Inspector bottom sheet
class _InspectorWidget extends StatefulWidget {
  final Map<String, dynamic> node;
  final ComplaintsApiService apiService;
  final VoidCallback onRefreshNeeded;

  const _InspectorWidget({
    required this.node,
    required this.apiService,
    required this.onRefreshNeeded,
  });

  @override
  State<_InspectorWidget> createState() => _InspectorWidgetState();
}

class _InspectorWidgetState extends State<_InspectorWidget> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _commentController = TextEditingController();

  String _priority = 'medium';
  String _category = 'bug';
  List<PlatformFile> _selectedFiles = [];

  bool _isLoadingComplaints = true;
  bool _isCreatingComplaint = false;
  bool _isSubmittingComment = false;
  List<dynamic> _complaints = [];
  Map<String, dynamic>? _selectedComplaintDetail;

  @override
  void initState() {
    super.initState();
    _loadComplaints();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComplaints() async {
    setState(() {
      _isLoadingComplaints = true;
    });
    try {
      final key = widget.node['node_key'].toString();
      final res = await widget.apiService.getNodeComplaints(key);
      if (res['success'] == true && res['data'] != null) {
        setState(() {
          _complaints = List<dynamic>.from(res['data']);
          if (_complaints.isNotEmpty) {
            _selectComplaint(_complaints[0]['id'].toString());
          } else {
            _selectedComplaintDetail = null;
          }
        });
      }
    } catch (_) {}
    setState(() {
      _isLoadingComplaints = false;
    });
  }

  Future<void> _selectComplaint(String id) async {
    try {
      final res = await widget.apiService.getComplaint(id);
      if (res['success'] == true && res['data'] != null) {
        setState(() {
          _selectedComplaintDetail = res['data'];
        });
      }
    } catch (_) {}
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        withData: false,
      );
      if (result != null) {
        setState(() {
          _selectedFiles = result.files;
        });
      }
    } catch (e) {
      debugPrint("Error picking files: $e");
      if (mounted) {
        _showSnack("Error picking files: $e", isError: true);
      }
    }
  }

  Future<void> _createComplaint() async {
    if (_titleController.text.trim().isEmpty || _descController.text.trim().isEmpty) {
      _showSnack('Title and Description are required', isError: true);
      return;
    }
    setState(() {
      _isCreatingComplaint = true;
    });
    try {
      final key = widget.node['node_key'].toString();
      final res = await widget.apiService.createComplaint({
        'nodeKey': key,
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'priority': _priority,
        'category': _category,
      });

      if (res['success'] == true) {
        final id = res['data']?['id']?.toString();
        if (id != null && _selectedFiles.isNotEmpty) {
          await widget.apiService.uploadAttachments(id, _selectedFiles);
        }
        _titleController.clear();
        _descController.clear();
        _selectedFiles.clear();
        _showSnack('Complaint created successfully');
        widget.onRefreshNeeded();
        _loadComplaints();
      } else {
        _showSnack(res['message'] ?? 'Failed to create complaint', isError: true);
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      setState(() {
        _isCreatingComplaint = false;
      });
    }
  }

  Future<void> _updateStatus(String status) async {
    final complaint = _selectedComplaintDetail?['complaint'];
    if (complaint == null) return;
    final id = complaint['id'].toString();

    try {
      final res = await widget.apiService.updateStatus(id, status);
      if (res['success'] == true) {
        _showSnack('Status updated to ${status.replaceAll('_', ' ')}');
        _selectComplaint(id);
        _loadComplaints();
        widget.onRefreshNeeded();
      }
    } catch (e) {
      _showSnack('Error updating status: $e', isError: true);
    }
  }

  Future<void> _submitComment() async {
    final complaint = _selectedComplaintDetail?['complaint'];
    if (complaint == null || _commentController.text.trim().isEmpty) return;
    final id = complaint['id'].toString();

    setState(() {
      _isSubmittingComment = true;
    });

    try {
      final res = await widget.apiService.createComment(id, _commentController.text.trim());
      if (res['success'] == true) {
        _commentController.clear();
        _selectComplaint(id);
      }
    } catch (e) {
      _showSnack('Error submitting reply: $e', isError: true);
    } finally {
      setState(() {
        _isSubmittingComment = false;
      });
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.teal,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final label = widget.node['label'] ?? 'Node';
    final path = widget.node['route_path'] ?? 'Sidebar group';

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selected Node Details',
                        style: TextStyle(color: Color(0xFF00B5AD), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      Text(path, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                )
              ],
            ),
          ),
          const Divider(),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Metrics summary
                  _buildQuickMetrics(),
                  const SizedBox(height: 20),

                  // Create Complaint Card
                  _buildCreateForm(),
                  const SizedBox(height: 20),

                  // Node History list
                  const Text('Node History & Complaints', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  _isLoadingComplaints
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF00B5AD)))
                      : _complaints.isEmpty
                          ? _buildNoComplaintsState()
                          : _buildComplaintsList(),

                  if (_selectedComplaintDetail != null) ...[
                    const SizedBox(height: 20),
                    _buildSelectedComplaintDetail(),
                  ]
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildQuickMetrics() {
    final metrics = widget.node['metrics'] ?? {};
    final open = metrics['open'] ?? 0;
    final resolved = metrics['resolved'] ?? 0;
    final critical = metrics['critical'] ?? 0;

    return Row(
      children: [
        _buildMetricBox('Open', '$open', const Color(0xFFE0F7F6), const Color(0xFF007A76)),
        const SizedBox(width: 8),
        _buildMetricBox('Resolved', '$resolved', Colors.green.shade50, Colors.green.shade700),
        const SizedBox(width: 8),
        _buildMetricBox('Critical', '$critical', Colors.red.shade50, Colors.red.shade700),
      ],
    );
  }

  Widget _buildMetricBox(String label, String value, Color bg, Color textCol) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textCol)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: textCol.withOpacity(0.7), fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateForm() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.add_comment_outlined, color: Color(0xFF00B5AD), size: 18),
              const SizedBox(width: 8),
              const Text('Create Complaint on this Node', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              hintText: 'Short title / headline',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Description of the issue, affected workflow...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _priority,
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Low Priority')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium Priority')),
                    DropdownMenuItem(value: 'high', child: Text('High Priority')),
                    DropdownMenuItem(value: 'critical', child: Text('Critical')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _priority = val;
                      });
                    }
                  },
                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _category,
                  items: const [
                    DropdownMenuItem(value: 'bug', child: Text('Bug')),
                    DropdownMenuItem(value: 'workflow', child: Text('Workflow')),
                    DropdownMenuItem(value: 'data', child: Text('Data')),
                    DropdownMenuItem(value: 'ui', child: Text('UI')),
                    DropdownMenuItem(value: 'performance', child: Text('Performance')),
                    DropdownMenuItem(value: 'access', child: Text('Access')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _category = val;
                      });
                    }
                  },
                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // File Picker Row
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _pickFiles,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300, style: BorderStyle.none),
              ),
              child: Row(
                children: [
                  const Icon(Icons.upload_file, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    _selectedFiles.isEmpty
                        ? 'Attach screenshots or files'
                        : '${_selectedFiles.length} file(s) attached',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isCreatingComplaint ? null : _createComplaint,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00B5AD),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isCreatingComplaint
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Submit Complaint'),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildNoComplaintsState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: const Column(
        children: [
          Icon(Icons.check_circle_outline, color: Colors.green, size: 28),
          SizedBox(height: 6),
          Text('No complaints on this node', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildComplaintsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _complaints.length,
      itemBuilder: (context, index) {
        final c = _complaints[index];
        final id = c['id'].toString();
        final isSelected = _selectedComplaintDetail != null &&
            _selectedComplaintDetail!['complaint']?['id']?.toString() == id;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: isSelected ? const Color(0xFF00B5AD) : Colors.grey.shade200),
          ),
          color: isSelected ? const Color(0xFF00B5AD).withOpacity(0.04) : Colors.white,
          child: ListTile(
            title: Text(
              c['title'] ?? 'Untitled',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            subtitle: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: _getStatusBg(c['status']?.toString()),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    c['status']?.toString().replaceAll('_', ' ').toUpperCase() ?? 'OPEN',
                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: _getStatusTextCol(c['status']?.toString())),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDate(c['updated_at']?.toString() ?? ''),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => _selectComplaint(id),
          ),
        );
      },
    );
  }

  Widget _buildSelectedComplaintDetail() {
    final complaint = _selectedComplaintDetail!['complaint'];
    final comments = List<dynamic>.from(_selectedComplaintDetail!['comments'] ?? []);
    final attachments = List<dynamic>.from(_selectedComplaintDetail!['attachments'] ?? []);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  complaint['title'] ?? 'Detail',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              // Status changer
              DropdownButton<String>(
                value: complaint['status'],
                onChanged: (val) {
                  if (val != null) {
                    _updateStatus(val);
                  }
                },
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'open', child: Text('Open')),
                  DropdownMenuItem(value: 'triaged', child: Text('Triaged')),
                  DropdownMenuItem(value: 'in_progress', child: Text('In Progress')),
                  DropdownMenuItem(value: 'blocked', child: Text('Blocked')),
                  DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                  DropdownMenuItem(value: 'closed', child: Text('Closed')),
                ],
              )
            ],
          ),
          const SizedBox(height: 6),
          Text(
            complaint['description'] ?? '',
            style: const TextStyle(fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 12),

          // Attachments
          if (attachments.isNotEmpty) ...[
            const Text('Attachments:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: attachments.map((a) {
                return Chip(
                  avatar: const Icon(Icons.attach_file, size: 12, color: Colors.teal),
                  label: Text(a['file_name'] ?? 'File', style: const TextStyle(fontSize: 10)),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],

          // Comments list
          if (comments.isNotEmpty) ...[
            const Text('Discussion Thread', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 6),
            ...comments.map((comment) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          comment['created_by_name'] ?? 'User',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Color(0xFF007A76)),
                        ),
                        const Spacer(),
                        Text(
                          _formatDate(comment['created_at'] ?? ''),
                          style: const TextStyle(fontSize: 9, color: Colors.grey),
                        )
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(comment['body'] ?? '', style: const TextStyle(fontSize: 11)),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
          ],

          // Add reply textfield
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    hintText: 'Write a response...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    fillColor: Colors.white,
                    filled: true,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ElevatedButton(
                onPressed: _isSubmittingComment ? null : _submitComment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00B5AD),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isSubmittingComment
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send, size: 16),
              )
            ],
          )
        ],
      ),
    );
  }

  Color _getStatusBg(String? status) {
    switch (status) {
      case 'open':
        return const Color(0xFFE0F7F6);
      case 'triaged':
        return Colors.blue.shade50;
      case 'in_progress':
        return Colors.amber.shade50;
      case 'blocked':
        return Colors.red.shade50;
      case 'resolved':
        return Colors.green.shade50;
      default:
        return Colors.grey.shade100;
    }
  }

  Color _getStatusTextCol(String? status) {
    switch (status) {
      case 'open':
        return const Color(0xFF007A76);
      case 'triaged':
        return Colors.blue.shade700;
      case 'in_progress':
        return Colors.amber.shade700;
      case 'blocked':
        return Colors.red.shade700;
      case 'resolved':
        return Colors.green.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return DateFormat('MMM dd, hh:mm a').format(date);
    } catch (_) {
      return dateStr;
    }
  }
}

extension _FilterExtension<T> on Iterable<T> {
  Iterable<T> filter(bool Function(T) test) {
    return where(test);
  }
}
