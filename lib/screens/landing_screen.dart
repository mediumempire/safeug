import 'package:flutter/material.dart';

import '../app_theme.dart';
import 'auth_screen.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  static const heroImage = 'https://picsum.photos/seed/silverback/1600/900';

  void _openAuth(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const AuthScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor
                .withValues(alpha: .96),
            title: const SafeUgLogo(),
            actions: [
              TextButton(
                onPressed: () => _openAuth(context),
                child: const Text('Log in'),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FilledButton(
                  onPressed: () => _openAuth(context),
                  child: const Text('Sign up'),
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(child: _Hero(onStart: () => _openAuth(context))),
          const SliverToBoxAdapter(child: _ValueProps()),
          const SliverToBoxAdapter(child: _Features()),
          const SliverToBoxAdapter(child: _Wildlife()),
          SliverToBoxAdapter(
            child: _Destinations(onStart: () => _openAuth(context)),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 560,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            LandingScreen.heroImage,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(color: AppColors.primary),
          ),
          Container(color: Colors.black.withValues(alpha: .53)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 50),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'The Pearl of Africa,\nExplored Safely.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                    letterSpacing: -1.3,
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Experience the breathtaking wildlife of Uganda. SafeUG keeps your journey secure, connected, and unforgettable.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 30),
                FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.explore_rounded),
                  label: const Text('Start your adventure'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.ink,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                  child: const Text('Learn more'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueProps extends StatelessWidget {
  const _ValueProps();

  @override
  Widget build(BuildContext context) {
    const values = [
      (Icons.shield_rounded, 'Secure tracking'),
      (Icons.bolt_rounded, 'Instant SOS'),
      (Icons.public_rounded, 'Local experts'),
      (Icons.favorite_rounded, '24/7 support'),
    ];
    final valueWidgets = <Widget>[];
    for (final value in values) {
      valueWidgets.add(
        SizedBox(
          width: 120,
          child: Column(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: .12),
                child: Icon(value.$1, color: AppColors.primary),
              ),
              const SizedBox(height: 8),
              Text(
                value.$2,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      child: Wrap(
        alignment: WrapAlignment.spaceAround,
        spacing: 18,
        runSpacing: 20,
        children: valueWidgets,
      ),
    );
  }
}

class _Features extends StatelessWidget {
  const _Features();

  @override
  Widget build(BuildContext context) {
    const features = [
      (
        Icons.bolt_rounded,
        'No bureaucracy SOS',
        'One tap alerts local responders and your emergency contacts with your latest location.',
        AppColors.danger,
      ),
      (
        Icons.location_on_rounded,
        'AI safety alerts',
        'Receive contextual safety guidance for your location, activity, and time of day.',
        AppColors.primary,
      ),
      (
        Icons.groups_rounded,
        'Certified local guides',
        'Connect with local experts who know the land, culture, and safe routes.',
        AppColors.accent,
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 34),
      child: Column(
        children: [
          Text(
            'Uncompromising safety features',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Designed for tourists, built by locals.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          ...features.map(
            (feature) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: AppCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: feature.$4.withValues(alpha: .12),
                      child: Icon(feature.$1, color: feature.$4),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            feature.$2,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            feature.$3,
                            style: const TextStyle(
                              color: AppColors.muted,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Wildlife extends StatelessWidget {
  const _Wildlife();

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        'https://picsum.photos/seed/bwindi-gorilla/800/600',
        'Mountain Gorilla Trekking',
        'Bwindi Impenetrable',
      ),
      (
        'https://picsum.photos/seed/lion-tree/800/600',
        'Tree-Climbing Lions',
        'Ishasha Sector',
      ),
      (
        'https://picsum.photos/seed/white-rhino/800/600',
        'Rhino Reintroduction',
        'Ziwa Sanctuary',
      ),
    ];
    return Container(
      color: AppColors.primary.withValues(alpha: .06),
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wildlife & conservation',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Protecting Uganda's natural heritage",
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Travel responsibly while supporting the places and communities that make Uganda extraordinary.',
            style: TextStyle(color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 230,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, index) => SizedBox(
                width: 250,
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Image.network(
                          items[index].$1,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, _, _) =>
                              Container(color: AppColors.primary),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              items[index].$3,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              items[index].$2,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Destinations extends StatelessWidget {
  const _Destinations({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(20, 36, 20, 42),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Discover the Pearl of Africa',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          const Text(
            'Navigate Uganda with confidence, from the Rwenzori Mountains to the savannahs of Queen Elizabeth Park.',
            style: TextStyle(color: Colors.white70, height: 1.45),
          ),
          const SizedBox(height: 18),
          const Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _DestinationChip('Bwindi gorilla trekking'),
              _DestinationChip('Ziwa rhino encounters'),
              _DestinationChip('Murchison Falls safaris'),
              _DestinationChip('Kampala culture'),
            ],
          ),
          const SizedBox(height: 26),
          FilledButton(
            onPressed: onStart,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
            ),
            child: const Text('Explore SafeUG'),
          ),
        ],
      ),
    );
  }
}

class _DestinationChip extends StatelessWidget {
  const _DestinationChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: const Icon(
      Icons.check_circle_outline_rounded,
      size: 16,
      color: AppColors.accent,
    ),
    label: Text(
      label,
      style: const TextStyle(color: Colors.white, fontSize: 12),
    ),
    backgroundColor: Colors.white.withValues(alpha: .12),
    side: BorderSide.none,
  );
}
