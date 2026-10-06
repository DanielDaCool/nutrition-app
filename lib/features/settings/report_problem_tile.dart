// The "Report a problem" row in Settings: a dialog with a description
// field that sends to the report-relay Worker (see report_problem.dart).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../app/providers.dart';
import '../../core/app_version.dart';
import 'report_problem.dart';

/// HTTP client for sending problem reports; override with a `MockClient` in
/// tests.
final reportProblemClientProvider = Provider<http.Client>(
  (ref) => http.Client(),
);

/// The report relay's URL; override in tests, since [reportRelayUrl] is
/// always empty without a build-time `--dart-define`.
final reportRelayUrlProvider = Provider<String>((ref) => reportRelayUrl);

class ReportProblemTile extends ConsumerWidget {
  const ReportProblemTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
    leading: const Icon(Icons.bug_report_outlined),
    title: const Text('Report a problem'),
    subtitle: const Text('Tell us what went wrong'),
    onTap: () => showDialog<void>(
      context: context,
      builder: (context) => const _ReportProblemDialog(),
    ),
  );
}

class _ReportProblemDialog extends ConsumerStatefulWidget {
  const _ReportProblemDialog();

  @override
  ConsumerState<_ReportProblemDialog> createState() =>
      _ReportProblemDialogState();
}

class _ReportProblemDialogState extends ConsumerState<_ReportProblemDialog> {
  final _controller = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final description = _controller.text.trim();
    if (description.isEmpty) {
      setState(() => _error = 'Describe what went wrong first.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final ok = await sendProblemReport(
      ref.read(reportProblemClientProvider),
      description: description,
      versionLabel: appVersionLabel(appVersion),
      platform: reportProblemPlatform(isWeb: ref.read(isWebProvider)),
      url: ref.read(reportRelayUrlProvider),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks — your report was sent.')),
      );
    } else {
      setState(() {
        _sending = false;
        _error = "Couldn't send that. Check your connection and try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Report a problem'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('reportProblemDescription'),
          controller: _controller,
          autofocus: true,
          maxLines: 5,
          minLines: 3,
          enabled: !_sending,
          decoration: const InputDecoration(
            hintText: 'What happened?',
            border: OutlineInputBorder(),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    ),
    actions: [
      TextButton(
        onPressed: _sending ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('reportProblemSend'),
        onPressed: _sending ? null : _send,
        child: _sending
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Send'),
      ),
    ],
  );
}
