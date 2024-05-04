final Map<String, int> policyTypeToNumberMap = {
  'A': 1,
  'B': 2,
  'C': 3,
  'D': 4,
};
final Map<String, int> MaterialTypeToNumberMap = {
  'metal': 1,
  'rubber': 2,
  'fiber': 3,
  'glass': 4,
};

String? getKeyFromValue(Map<String, int> map, int value) {
  for (var entry in map.entries) {
    if (entry.value == value) {
      return entry.key;
    }
  }
  return null; // Return null if the value is not found in the map
}
