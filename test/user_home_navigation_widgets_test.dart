import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loqma/features/userhome/presentation/widgets/user_home_navigation_widgets.dart';

void main() {
  testWidgets('location notice exposes an explicit location action', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: UserHomeLocationNotice(
          cardColor: Colors.white,
          orangeColor: Colors.orange,
          textPrimaryColor: Colors.black,
          primaryColor: Colors.red,
          onChooseLocation: () => tapped = true,
        ),
      ),
    );

    expect(find.text('حدّد موقعك علشان نعرض العروض والخدمات القريبة منك.'),
        findsOneWidget);
    await tester.tap(find.text('تحديد'));
    expect(tapped, isTrue);
  });

  testWidgets('bottom navigation reports the selected tab', (tester) async {
    var selected = -1;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: UserHomeBottomNavigationBar(
            currentIndex: 0,
            cardColor: Colors.white,
            borderColor: Colors.grey,
            isDark: false,
            onTap: (index) => selected = index,
          ),
        ),
      ),
    );

    await tester.tap(find.text('الأقسام'));
    expect(selected, 1);
    await tester.tap(find.text('حسابي'));
    expect(selected, 4);
  });
}
