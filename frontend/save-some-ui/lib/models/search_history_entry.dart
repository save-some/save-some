import 'json.dart';

// ---- SearchHistoryEntry ----
// GET /v1/user/{id}/history — written by POST /v1/products/search whenever a
// user_id accompanies the search.

class SearchHistoryEntry {
  final String id;
  final String query;
  final DateTime searchedAt;

  SearchHistoryEntry({
    required this.id,
    required this.query,
    required this.searchedAt,
  });

  factory SearchHistoryEntry.fromJson(Map<String, dynamic> json) =>
      SearchHistoryEntry(
        id: json['id'] as String,
        query: json['query'] as String,
        searchedAt: parseDate(json['searched_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'query': query,
        'searched_at': searchedAt.toIso8601String(),
      };
}
