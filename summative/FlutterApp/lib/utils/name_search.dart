/// Finds the items whose name contains [query], ignoring case.
///
/// Names that *start with* the query come first, then names that contain it
/// somewhere else. Each group keeps the order of [items].
List<T> searchByName<T>(Iterable<T> items, String query, String Function(T item) nameOf) {
  final text = query.trim().toLowerCase();
  if (text.isEmpty) return [];

  final startsWith = <T>[];
  final contains = <T>[];
  for (final item in items) {
    final name = nameOf(item).toLowerCase();
    if (name.startsWith(text)) {
      startsWith.add(item);
    } else if (name.contains(text)) {
      contains.add(item);
    }
  }
  return [...startsWith, ...contains];
}
