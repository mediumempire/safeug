import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/models.dart';

class GuidesScreen extends StatelessWidget {
  const GuidesScreen({super.key});

  static const guides = [
    GuideProfile(
      name: 'Jalia Nakato',
      description: 'Friendly and knowledgeable local guide.',
      imageUrl: 'https://picsum.photos/seed/guide1/400/400',
      rating: 4.8,
      reviews: 76,
    ),
    GuideProfile(
      name: 'David Okello',
      description: 'Expert in wildlife and nature tours.',
      imageUrl: 'https://picsum.photos/seed/guide2/400/400',
      rating: 4.6,
      reviews: 51,
    ),
    GuideProfile(
      name: 'Maria Mbabazi',
      description: 'Specializes in city tours and cultural experiences.',
      imageUrl: 'https://picsum.photos/seed/guide3/400/400',
      rating: 4.9,
      reviews: 92,
    ),
    GuideProfile(
      name: 'Robert Mugabe',
      description: 'Adventurous guide for hiking and trekking.',
      imageUrl: 'https://picsum.photos/seed/guide4/400/400',
      rating: 4.7,
      reviews: 38,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
      children: [
        const PageIntro(
          title: 'Local Guides',
          subtitle: 'Connect with certified experts for a safer, more authentic Ugandan experience.',
        ),
        ...guides.map(
          (guide) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GuideCard(guide: guide),
          ),
        ),
      ],
    );
  }
}

class GuideCard extends StatelessWidget {
  const GuideCard({super.key, required this.guide});
  final GuideProfile guide;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 132,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(22),
              ),
              child: Image.network(
                guide.imageUrl,
                width: 120,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 120,
                  color: AppColors.primary,
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            guide.name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: .18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: Color(0xFFB87900),
                                size: 13,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                guide.rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      guide.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                        height: 1.25,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Text(
                          '${guide.reviews} reviews',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          height: 30,
                          child: FilledButton.icon(
                            onPressed: () => showSafeSnackBar(
                              context,
                              'Guide connection request started for ${guide.name}.',
                            ),
                            icon: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 14,
                            ),
                            label: const Text(
                              'Connect',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
