/// 161 seconds -> "2:41". Negative durations show as "0:00".
String formatCountdown(Duration remaining) {
  final totalSeconds = remaining.isNegative ? 0 : remaining.inSeconds;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
