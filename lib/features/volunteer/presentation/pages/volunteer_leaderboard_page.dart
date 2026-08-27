import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:loqma/core/services/supabase_service.dart';
import '../bloc/volunteer_bloc.dart';
import '../bloc/volunteer_event.dart';
import '../bloc/volunteer_state.dart';
import '../widgets/volunteer_podium.dart';
import '../widgets/volunteer_rank_card.dart';
import '../widgets/volunteer_list_item.dart';
import '../widgets/volunteer_filter_chips.dart';

class VolunteerLeaderboardPage extends StatefulWidget {
  const VolunteerLeaderboardPage({super.key});

  @override
  State<VolunteerLeaderboardPage> createState() =>
      _VolunteerLeaderboardPageState();
}

class _VolunteerLeaderboardPageState extends State<VolunteerLeaderboardPage> {
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _getCurrentUserId();
    context.read<VolunteerBloc>().add(const VolunteerStarted());
  }

  Future<void> _getCurrentUserId() async {
    try {
      final user = await SupabaseService().getCurrentUser();
      setState(() {
        _currentUserId = user?.id;
      });
    } catch (e) {
      print('❌ Error getting current user: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          '🏆 المتطوعين',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              context.read<VolunteerBloc>().add(const VolunteerRefresh());
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: BlocConsumer<VolunteerBloc, VolunteerState>(
        listener: (context, state) {
          if (state is VolunteerError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is VolunteerLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is VolunteerLoaded) {
            return RefreshIndicator(
              onRefresh: () async {
                context.read<VolunteerBloc>().add(const VolunteerRefresh());
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // ✅ Podium (أفضل 3)
                  SliverToBoxAdapter(
                    child: VolunteerPodium(
                      top1: state.top1,
                      top2: state.top2,
                      top3: state.top3,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),

                  // ✅ User Rank Card
                  if (state.userRank != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: VolunteerRankCard(
                          userRank: state.userRank!,
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),

                  // ✅ Filter Chips
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: VolunteerFilterChips(
                        selectedFilter: state.selectedFilter,
                        onFilterSelected: (filter) {
                          context
                              .read<VolunteerBloc>()
                              .add(VolunteerFilterChanged(filter));
                        },
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),

                  // ✅ Leaderboard List
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final volunteer = state.volunteers[index];
                          final isCurrentUser = _currentUserId != null &&
                              volunteer.id == _currentUserId;

                          return VolunteerListItem(
                            volunteer: volunteer,
                            isCurrentUser: isCurrentUser,
                          );
                        },
                        childCount: state.volunteers.length,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            );
          }

          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
