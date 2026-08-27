import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/charity_bloc.dart';
import '../widgets/charity_card.dart';

class CharitiesPage extends StatefulWidget {
  const CharitiesPage({super.key});

  @override
  State<CharitiesPage> createState() => _CharitiesPageState();
}

class _CharitiesPageState extends State<CharitiesPage> {
  @override
  void initState() {
    super.initState();
    context.read<CharityBloc>().add(const CharityStarted());
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBF9F9),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_forward),
          color: colorScheme.onSurfaceVariant,
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primaryContainer.withValues(alpha: 0.1),
              ),
              child: Icon(
                Icons.volunteer_activism,
                color: colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Logma',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: Icon(
              Icons.search,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      body: BlocConsumer<CharityBloc, CharityState>(
        listener: (context, state) {
          if (state is CharityError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is CharityLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Color(0xFF0D631B),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'جاري تحميل الجمعيات...',
                    style: TextStyle(
                      color: Color(0xFF0D631B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          if (state is CharityLoaded) {
            if (state.charities.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.volunteer_activism,
                      size: 64,
                      color: colorScheme.primary.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'لا توجد جمعيات خيرية',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'سيتم إضافة الجمعيات قريباً',
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'البحث عن الجمعيات الخيرية',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'في طنطا والمناطق المجاورة',
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildChips(colorScheme),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: state.charities.length,
                      itemBuilder: (context, index) {
                        final charity = state.charities[index];
                        return CharityCard(charity: charity);
                      },
                    ),
                  ),
                ],
              ),
            );
          }

          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF0D631B),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChips(ColorScheme colorScheme) {
    final chips = ['الكل', 'الغذاء', 'الملابس', 'التطوع'];

    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: chips.length,
        itemBuilder: (context, index) {
          final isFirst = index == 0;
          return Padding(
            padding: EdgeInsets.only(right: index == chips.length - 1 ? 0 : 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isFirst
                    ? colorScheme.secondaryContainer
                    : colorScheme.surface,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: isFirst
                      ? colorScheme.secondaryContainer
                      : colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  chips[index],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isFirst
                        ? colorScheme.onSecondaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}


