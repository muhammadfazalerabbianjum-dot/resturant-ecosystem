import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';

class LogsScreen extends ConsumerStatefulWidget {
  const LogsScreen({super.key});

  @override
  ConsumerState<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends ConsumerState<LogsScreen> {
  List<String> _logs = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final logs = await ref.read(loggerProvider).readLogs();
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _loading = false;
      });
    } catch (e, stack) {
      await ref
          .read(loggerProvider)
          .error(e, 'logs_screen_load_failed', stack: stack);
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load logs: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs', key: Key('logsTitle')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadLogs,
            tooltip: 'Refresh logs',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _logs.isEmpty
          ? const Center(child: Text('No logs available'))
          : ListView.builder(
              itemCount: _logs.length,
              itemBuilder: (context, i) => ListTile(
                dense: true,
                title: Text(_logs[i], style: const TextStyle(fontSize: 12)),
              ),
            ),
    );
  }
}
