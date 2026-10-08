/**
 * Pareto membership for the overview charts.
 * The frontier uses the same axes the chart draws:
 * ops view maximizes avg_ops_per_sec; latency view minimizes avg_time_total_ns.
 * Both views minimize median_size_bytes.
 * Averaged ops/sec is not the inverse of averaged latency, so the two fronts differ.
 */

export function paretoObjective(metric) {
  if (metric === 'time') {
    return { key: 'avg_time_total_ns', higherIsBetter: false };
  }
  return { key: 'avg_ops_per_sec', higherIsBetter: true };
}

function finite(value) {
  return typeof value === 'number' && Number.isFinite(value);
}

export function isParetoDominated(group, groups, metric = 'ops') {
  const { key, higherIsBetter } = paretoObjective(metric);
  const speed = group?.[key];
  const size = group?.median_size_bytes;
  if (!finite(speed) || !finite(size)) return true;
  return (groups || []).some((other) => {
    if (!other || other === group) return false;
    const otherSpeed = other[key];
    const otherSize = other.median_size_bytes;
    if (!finite(otherSpeed) || !finite(otherSize)) return false;
    const betterOrEqualSpeed = higherIsBetter ? otherSpeed >= speed : otherSpeed <= speed;
    const betterOrEqualSize = otherSize <= size;
    const strictlyBetter =
      (higherIsBetter ? otherSpeed > speed : otherSpeed < speed) || otherSize < size;
    return betterOrEqualSpeed && betterOrEqualSize && strictlyBetter;
  });
}

export function paretoOptimalGroups(groups, metric = 'ops') {
  return (groups || []).filter((group) => !isParetoDominated(group, groups, metric));
}
