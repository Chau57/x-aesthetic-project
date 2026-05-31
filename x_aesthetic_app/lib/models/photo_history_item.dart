import 'aesthetic_result.dart';

class PhotoHistoryItem {
  final String imageUrl;
  final AestheticResult result;
  final DateTime createdAt;

  const PhotoHistoryItem({
    required this.imageUrl,
    required this.result,
    required this.createdAt,
  });
}
