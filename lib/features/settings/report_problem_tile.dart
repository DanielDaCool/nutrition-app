// The "Report a problem" row in Settings: a dialog with a description
// field that sends either to the report-relay Worker (report_problem.dart)
// or, if the user opts in and it's available, directly to GitHub under
// their own account via the OAuth device flow (github_report.dart).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../core/app_features.dart';
import '../../core/app_version.dart';
import 'github_report.dart';
import 'report_problem.dart';

/// HTTP client for sending problem reports; override with a `MockClient` in
/// tests.
final reportProblemClientProvider = Provider<http.Client>(
  (ref) => http.Client(),
);

/// The report relay's URL; override in tests, since [reportRelayUrl] is
/// always empty without a build-time `--dart-define`.
final reportRelayUrlProvider = Provider<String>((ref) => reportRelayUrl);

/// The GitHub OAuth App's client id; override in tests, since
/// [githubOAuthClientId] is always empty without a build-time
/// `--dart-define`.
final githubOAuthClientIdProvider = Provider<String>(
  (ref) => githubOAuthClientId,
);

enum _ReportMode { relay, github }

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
  _ReportMode _mode = _ReportMode.relay;
  bool _sending = false;
  String? _error;

  // Set once the device flow finishes, so re-sending in the same dialog
  // doesn't re-authorize.
  String? _githubAccessToken;

  // Non-null while waiting for the user to authorize in their browser.
  GithubDeviceCode? _deviceCode;
  bool _cancelPolling = false;

  // The timer between polls, so canceling can actually stop it instead of
  // leaving a dangling delay.
  Timer? _pollDelayTimer;

  @override
  void dispose() {
    _cancelPolling = true;
    _pollDelayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// A cancelable version of `Future.delayed`: resolves after [duration],
  /// unless [_pollDelayTimer] is canceled first (by [_cancelAuthorization]
  /// or [dispose]), in which case it never resolves.
  Future<void> _delay(Duration duration) {
    final completer = Completer<void>();
    _pollDelayTimer = Timer(duration, () {
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
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

    if (_mode == _ReportMode.github && _githubAccessToken == null) {
      await _authorizeWithGithub();
      if (!mounted || _githubAccessToken == null) return;
    }

    final versionLabel = appVersionLabel(appVersion);
    final platform = reportProblemPlatform(isWeb: ref.read(isWebProvider));
    final client = ref.read(reportProblemClientProvider);
    final ok = _mode == _ReportMode.github
        ? await createGithubIssueAsUser(
            client,
            accessToken: _githubAccessToken!,
            description: description,
            versionLabel: versionLabel,
            platform: platform,
          )
        : await sendProblemReport(
            client,
            description: description,
            versionLabel: versionLabel,
            platform: platform,
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

  /// Runs the device flow end to end: requests a code, shows it, and polls
  /// until the user authorizes (or the flow fails). Leaves
  /// [_githubAccessToken] set on success; otherwise sets [_error] and
  /// clears [_sending].
  Future<void> _authorizeWithGithub() async {
    final client = ref.read(reportProblemClientProvider);
    final clientId = ref.read(githubOAuthClientIdProvider);
    final code = await requestGithubDeviceCode(client, clientId: clientId);
    if (!mounted) return;
    if (code == null) {
      setState(() {
        _sending = false;
        _error = "Couldn't start GitHub sign-in. Try again.";
      });
      return;
    }
    setState(() => _deviceCode = code);

    final deadline = DateTime.now().add(
      Duration(seconds: code.expiresInSeconds),
    );
    var interval = Duration(seconds: code.intervalSeconds);
    while (!_cancelPolling && DateTime.now().isBefore(deadline)) {
      await _delay(interval);
      if (_cancelPolling) return;
      final result = await pollGithubAccessToken(
        client,
        deviceCode: code.deviceCode,
        clientId: clientId,
      );
      if (!mounted || _cancelPolling) return;
      switch (result.outcome) {
        case GithubPollOutcome.authorized:
          setState(() {
            _githubAccessToken = result.accessToken;
            _deviceCode = null;
          });
          return;
        case GithubPollOutcome.pending:
        case GithubPollOutcome.error:
          continue;
        case GithubPollOutcome.slowDown:
          interval += const Duration(seconds: 5);
          continue;
        case GithubPollOutcome.deniedOrExpired:
          setState(() {
            _sending = false;
            _deviceCode = null;
            _error = "GitHub sign-in wasn't completed. Try again.";
          });
          return;
      }
    }
    if (!mounted || _cancelPolling) return;
    setState(() {
      _sending = false;
      _deviceCode = null;
      _error = "GitHub sign-in timed out. Try again.";
    });
  }

  void _cancelAuthorization() {
    _pollDelayTimer?.cancel();
    setState(() {
      _cancelPolling = true;
      _deviceCode = null;
      _sending = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final githubAvailable =
        ref.watch(featureEnabledProvider(AppFeature.githubReport)) &&
        githubReportAvailable(clientId: ref.watch(githubOAuthClientIdProvider));

    if (_deviceCode != null) {
      return _DeviceAuthDialog(
        code: _deviceCode!,
        onCancel: _cancelAuthorization,
      );
    }

    return AlertDialog(
      title: const Text('Report a problem'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (githubAvailable) ...[
            RadioGroup<_ReportMode>(
              groupValue: _mode,
              onChanged: (value) => setState(() => _mode = value!),
              child: Column(
                children: [
                  RadioListTile<_ReportMode>(
                    key: const Key('reportModeRelay'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    enabled: !_sending,
                    title: const Text('Send anonymously'),
                    value: _ReportMode.relay,
                  ),
                  RadioListTile<_ReportMode>(
                    key: const Key('reportModeGithub'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    enabled: !_sending,
                    title: const Text('Post with my GitHub account'),
                    value: _ReportMode.github,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
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
}

/// Shown while waiting for the user to authorize in their browser: the
/// code to type in, a link to open it, and a way to back out.
class _DeviceAuthDialog extends StatelessWidget {
  const _DeviceAuthDialog({required this.code, required this.onCancel});

  final GithubDeviceCode code;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Sign in with GitHub'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Enter this code on GitHub to continue:'),
        const SizedBox(height: 12),
        SelectableText(
          code.userCode,
          key: const Key('githubUserCode'),
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const Key('githubOpenLink'),
          onPressed: () => launchUrl(
            Uri.parse(code.verificationUri),
            mode: LaunchMode.externalApplication,
          ),
          icon: const Icon(Icons.open_in_new),
          label: Text('Open ${code.verificationUri}'),
        ),
        const SizedBox(height: 16),
        const Row(
          children: [
            SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(child: Text('Waiting for you to authorize…')),
          ],
        ),
      ],
    ),
    actions: [
      TextButton(
        key: const Key('githubCancelAuth'),
        onPressed: onCancel,
        child: const Text('Cancel'),
      ),
    ],
  );
}
