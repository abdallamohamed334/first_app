// lib/features/marketplace/presentation/pages/marketplace_results_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/marketplace_bloc.dart';
import '../bloc/marketplace_event.dart';
import '../bloc/marketplace_state.dart';
import '../widgets/marketplace_offer_card.dart';

class MarketplaceResultsPage extends StatelessWidget {
  const MarketplaceResultsPage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'النتائج',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: BlocConsumer<MarketplaceBloc, MarketplaceState>(
        listener: (context, state) {
          // ------------------------------------------------------
          // Show errors while the page is already displaying data.
          // ------------------------------------------------------

          if (state.errorMessage != null &&
              state.errorMessage!.isNotEmpty &&
              state.offers.isNotEmpty &&
              !state.isLoadingResults) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    state.errorMessage!,
                    textAlign: TextAlign.right,
                  ),
                ),
              );
          }
        },
        builder: (context, state) {
          // ------------------------------------------------------
          // Initial / full loading
          // ------------------------------------------------------

          if (state.isLoadingResults && state.offers.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // ------------------------------------------------------
          // Error with no results
          // ------------------------------------------------------

          if (state.errorMessage != null &&
              state.errorMessage!.isNotEmpty &&
              state.offers.isEmpty &&
              !state.isLoadingResults) {
            return _ErrorView(
              message: state.errorMessage!,
              onRetry: () {
                context.read<MarketplaceBloc>().add(
                      const LoadMarketplaceResults(),
                    );
              },
            );
          }

          // ------------------------------------------------------
          // No matching offers
          // ------------------------------------------------------

          if (state.offers.isEmpty) {
            return const _NoResultsView();
          }

          // ------------------------------------------------------
          // Results
          // ------------------------------------------------------

          return RefreshIndicator(
            onRefresh: () async {
              final bloc = context.read<MarketplaceBloc>();

              bloc.add(
                const LoadMarketplaceResults(),
              );

              // Wait until the current request finishes instead of
              // using an arbitrary Future.delayed().
              //
              // This makes pull-to-refresh reliable even if the
              // network request takes longer than 500ms.

              await bloc.stream.firstWhere(
                (nextState) => !nextState.isLoadingResults,
              );
            },
            child: Stack(
              children: [
                ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    30,
                  ),
                  itemCount: state.offers.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(
                        bottom: 12,
                      ),
                      child: MarketplaceOfferCard(
                        offer: state.offers[index],
                      ),
                    );
                  },
                ),

                // ------------------------------------------------
                // Refresh/loading indicator while existing offers
                // remain visible.
                // ------------------------------------------------

                if (state.isLoadingResults)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ================================================================
// NO RESULTS
// ================================================================

class _NoResultsView extends StatelessWidget {
  const _NoResultsView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 70,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 18),
            const Text(
              'لا توجد عروض مطابقة',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'جرب تغيير المواصفات التي اخترتها.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// ERROR
// ================================================================

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 60,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onRetry,
              child: const Text(
                'إعادة المحاولة',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
