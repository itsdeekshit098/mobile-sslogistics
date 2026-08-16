/// Postgres `numeric` and `bigint` columns are returned by PostgREST as JSON
/// strings (to avoid the precision loss a JS/Dart double would introduce),
/// while `integer`/`smallint` columns come through as JSON numbers. A plain
/// `json['x'] as num` on a `numeric` or `bigint` field throws the moment the
/// server actually sends a string — these helpers accept either shape.
library;

/// Parses a `numeric` (or any number-or-string) JSON value.
num? parseNum(dynamic value) {
  if (value == null) return null;
  if (value is num) return value;
  if (value is String) return num.tryParse(value);
  return null;
}

/// Parses a `numeric` (or any number-or-string) JSON value, defaulting to 0.
num parseNumOr0(dynamic value) => parseNum(value) ?? 0;

/// Parses a `bigint`/`integer` (or any int-or-string) JSON value.
int? parseId(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

/// Parses a `bigint`/`integer` JSON value, defaulting to 0.
int parseIdOr0(dynamic value) => parseId(value) ?? 0;
