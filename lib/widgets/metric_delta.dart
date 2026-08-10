/// Last-vs-previous percent change; null when there is no real trend.
///
/// Honesty rule: fewer than 2 points, previous == 0 (division guard), or a
/// flat series (== no change) all return null — no fake deltas.
double? metricDelta(List<num> series) {
  if (series.length < 2) return null;
  final prev = series[series.length - 2];
  final last = series[series.length - 1];
  if (prev == 0 || last == prev) return null;
  return (last - prev) / prev * 100;
}
