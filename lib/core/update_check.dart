// Whether a newer release exists on GitHub, and how often to ask. Pure
// Dart: no Flutter, DB or http imports.

/// A release version as `major.minor.patch`, for comparing tags like
/// pubspec's `version:` (ignoring the build number after `+`).
class ReleaseVersion implements Comparable<ReleaseVersion> {
  const ReleaseVersion(this.major, this.minor, this.patch);

  final int major;
  final int minor;
  final int patch;

  @override
  int compareTo(ReleaseVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  @override
  bool operator ==(Object other) =>
      other is ReleaseVersion &&
      major == other.major &&
      minor == other.minor &&
      patch == other.patch;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() => '$major.$minor.$patch';
}

/// Parses a release tag ("v0.1", "v1.2.3") the same way
/// `.github/scripts/app-version.sh` does: a `v` prefix, up to three
/// dot-separated parts, missing parts read as 0. Null if it doesn't look
/// like a version tag.
ReleaseVersion? parseReleaseTag(String tag) {
  if (!tag.startsWith('v')) return null;
  final parts = tag.substring(1).split('.');
  if (parts.isEmpty || parts.length > 3) return null;
  final nums = <int>[];
  for (final p in parts) {
    final n = int.tryParse(p);
    if (n == null || n < 0) return null;
    nums.add(n);
  }
  while (nums.length < 3) {
    nums.add(0);
  }
  return ReleaseVersion(nums[0], nums[1], nums[2]);
}

/// Parses pubspec's `version:` form ("0.0.0+2"), ignoring the build number.
ReleaseVersion? parseAppVersion(String version) {
  final name = version.split('+').first;
  return parseReleaseTag('v$name');
}

/// Whether [latestTag] names a release newer than [currentVersion]
/// ("0.0.0+2" form). False for a dev build (empty [currentVersion]) or
/// when either side doesn't parse.
bool isUpdateAvailable({
  required String currentVersion,
  required String? latestTag,
}) {
  if (currentVersion.isEmpty || latestTag == null) return false;
  final current = parseAppVersion(currentVersion);
  final latest = parseReleaseTag(latestTag);
  if (current == null || latest == null) return false;
  return latest.compareTo(current) > 0;
}

/// How often to ask GitHub for the latest release.
const updateCheckInterval = Duration(days: 1);

/// Whether it's been long enough since [lastCheckedAt] to check again.
bool shouldCheckForUpdate({
  required DateTime? lastCheckedAt,
  required DateTime now,
}) =>
    lastCheckedAt == null ||
    now.difference(lastCheckedAt) >= updateCheckInterval;
