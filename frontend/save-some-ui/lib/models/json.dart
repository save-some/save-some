/// Shared JSON coercion helpers for the model layer.
///
/// These were previously copy-pasted into every model file, where most copies
/// went unused and the analyzer flagged each one.
library;

DateTime parseDate(dynamic value) => DateTime.parse(value as String);

/// Postgres `REAL` columns arrive as either int or double depending on the
/// value, so a plain `as double` cast throws on whole numbers.
double? parseDoubleOrNull(dynamic value) =>
    value == null ? null : (value as num).toDouble();

/// Absent and null lists both become empty rather than throwing, since the API
/// omits embedded collections on some endpoints.
List<T> parseList<T>(
  dynamic value,
  T Function(Map<String, dynamic>) fromJson,
) {
  if (value == null) return [];
  return (value as List)
      .map((item) => fromJson(item as Map<String, dynamic>))
      .toList();
}
