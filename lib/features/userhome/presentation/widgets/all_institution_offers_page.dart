// lib/features/userhome/presentation/pages/all_institution_offers_page.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:loqma/features/institutions/domain/entities/institution_offer.dart';
import 'package:loqma/features/institutions/presentation/pages/institution_offer_details_page.dart';

class AllInstitutionOffersPage extends StatelessWidget {
  final List<InstitutionOffer> offers;
  final bool loading;
  final Future<void> Function() onRefresh;

  const AllInstitutionOffersPage({
    super.key,
    required this.offers,
    required this.loading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'عروض المحلات والمؤسسات',
          ),
          centerTitle: true,
        ),
        body: loading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : RefreshIndicator(
                onRefresh: onRefresh,
                child: offers.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 230),
                          Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Text(
                                'لا توجد عروض متاحة حاليًا',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: offers.length,
                        separatorBuilder: (_, __) => const SizedBox(
                          height: 12,
                        ),
                        itemBuilder: (context, index) {
                          final offer = offers[index];

                          return _InstitutionCard(
                            offer: offer,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => InstitutionOfferDetailsPage(
                                    offer: offer,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
      ),
    );
  }
}

// ============================================================
// INSTITUTION CARD
// ============================================================

class _InstitutionCard extends StatelessWidget {
  final InstitutionOffer offer;
  final VoidCallback onTap;

  const _InstitutionCard({
    required this.offer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    String? image;
    String title = 'عرض';

    try {
      image = (offer as dynamic).image?.toString();
    } catch (_) {}

    try {
      title = (offer as dynamic).title?.toString() ?? 'عرض';
    } catch (_) {}

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 82,
                height: 82,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: image == null || image.isEmpty
                      ? Container(
                          color: colors.primaryContainer,
                          child: Icon(
                            Icons.storefront_rounded,
                            color: colors.primary,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: image,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) {
                            return Container(
                              color: colors.primaryContainer,
                              child: Icon(
                                Icons.storefront_rounded,
                                color: colors.primary,
                              ),
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'عرض متاح حاليًا',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_left_rounded,
                color: colors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
