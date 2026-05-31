import 'package:flutter/material.dart';
import '../models/photo_history_item.dart';
import 'score_badge.dart';

class RecentPhotoTile extends StatelessWidget {
  final PhotoHistoryItem item;

  const RecentPhotoTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Thumbnail Image with modern rounded edges
        Container(
          width: 90,
          height: 110,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            image: DecorationImage(
              image: NetworkImage(item.imageUrl),
              fit: BoxFit.cover,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
        // Unified Star Score Badge positioned bottom-left
        Positioned(
          bottom: 6,
          left: 6,
          child: ScoreBadge(
            score: item.result.overallScore,
            fontSize: 9,
            iconSize: 11,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          ),
        ),
      ],
    );
  }
}
