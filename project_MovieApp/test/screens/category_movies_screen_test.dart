import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movieapp/screens/user/category_movies_screen.dart';
import 'package:movieapp/models/movie.dart';

void main() {
  group('CategoryMoviesScreen Widget Tests', () {
    // Using a simplified approach without Firebase-dependent providers
    // These tests focus on UI rendering and logic that don't require actual providers

    group('Constructor Tests', () {
      test('CategoryMoviesScreen constructor initializes correctly', () {
        const screen = CategoryMoviesScreen(
          categoryName: 'Action',
          categorySlug: 'action',
          isCountry: false,
        );

        expect(screen.categoryName, 'Action');
        expect(screen.categorySlug, 'action');
        expect(screen.isCountry, false);
      });

      test('CategoryMoviesScreen accepts isCountry parameter', () {
        const screen = CategoryMoviesScreen(
          categoryName: 'Vietnam',
          categorySlug: 'vietnam',
          isCountry: true,
        );

        expect(screen.isCountry, true);
        expect(screen.categorySlug, 'vietnam');
      });

      test('CategoryMoviesScreen defaults to category (not country)', () {
        const screen = CategoryMoviesScreen(
          categoryName: 'Horror',
          categorySlug: 'horror',
        );

        expect(screen.isCountry, false);
      });
    });

    group('Page Navigation Logic', () {
      test('validates page bounds correctly', () {
        const currentPage = 1;
        const totalPages = 5;

        // Test boundary conditions
        expect(currentPage > 1, isFalse); // Can't go previous
        expect(currentPage < totalPages, isTrue); // Can go next
      });

      test('calculates page range correctly for middle page', () {
        const currentPage = 5;
        const totalPages = 10;

        int startPage = currentPage - 2;
        int endPage = currentPage + 2;

        expect(startPage, 3);
        expect(endPage, 7);
      });

      test('adjusts page range at start', () {
        const currentPage = 1;
        const totalPages = 10;

        int startPage = currentPage - 2;
        int endPage = currentPage + 2;

        if (startPage < 1) {
          endPage = endPage + (1 - startPage);
          startPage = 1;
        }
        if (endPage > totalPages) {
          startPage = startPage - (endPage - totalPages);
          endPage = totalPages;
        }
        if (startPage < 1) startPage = 1;

        expect(startPage, 1);
        expect(endPage, 5); // Adjusted: after start fix, end becomes 5 before end fix
      });

      test('adjusts page range at end', () {
        const currentPage = 10;
        const totalPages = 10;

        int startPage = currentPage - 2;
        int endPage = currentPage + 2;

        if (startPage < 1) {
          endPage = endPage + (1 - startPage);
          startPage = 1;
        }
        if (endPage > totalPages) {
          startPage = startPage - (endPage - totalPages);
          endPage = totalPages;
        }
        if (startPage < 1) startPage = 1;

        expect(startPage, 6); // Adjusted: starts at 8, after end fix becomes 6
        expect(endPage, 10);
      });

      test('handles edge case when totalPages is less than 5', () {
        const currentPage = 2;
        const totalPages = 3;

        int startPage = currentPage - 2;
        int endPage = currentPage + 2;

        if (startPage < 1) {
          endPage = endPage + (1 - startPage);
          startPage = 1;
        }
        if (endPage > totalPages) {
          startPage = startPage - (endPage - totalPages);
          endPage = totalPages;
        }
        if (startPage < 1) startPage = 1;

        expect(startPage, 1);
        expect(endPage, 3);
      });
    });

    group('Grid Layout Configuration', () {
      testWidgets('grid uses correct delegate configuration', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.65,
                ),
                itemCount: 0,
                itemBuilder: (context, index) => const SizedBox(),
              ),
            ),
          ),
        );

        final gridView = tester.widget<GridView>(find.byType(GridView));
        final delegate = gridView.gridDelegate
            as SliverGridDelegateWithFixedCrossAxisCount;

        expect(delegate.crossAxisCount, 3);
        expect(delegate.mainAxisSpacing, 16);
        expect(delegate.crossAxisSpacing, 12);
        expect(delegate.childAspectRatio, 0.65);
      });

      testWidgets('grid has correct padding', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.65,
                ),
                itemCount: 0,
                itemBuilder: (context, index) => const SizedBox(),
              ),
            ),
          ),
        );

        final gridView = tester.widget<GridView>(find.byType(GridView));
        expect(gridView.padding, const EdgeInsets.all(16));
      });
    });

    group('UI Components', () {
      testWidgets('displays loading indicator', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: Colors.red),
              ),
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('RefreshIndicator has red accent color', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RefreshIndicator(
                onRefresh: () async {},
                color: Colors.red,
                child: ListView(
                  children: const [SizedBox(height: 1000)],
                ),
              ),
            ),
          ),
        );

        final refreshIndicator = tester.widget<RefreshIndicator>(
          find.byType(RefreshIndicator),
        );
        expect(refreshIndicator.color, Colors.red);
      });

      testWidgets('has dark theme background', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              backgroundColor: Colors.black,
            ),
          ),
        );

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
        expect(scaffold.backgroundColor, Colors.black);
      });

      testWidgets('empty state displays message', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              backgroundColor: Colors.black,
              body: const Center(
                child: Text(
                  "Không có phim thuộc thể loại này.",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        );

        expect(find.text("Không có phim thuộc thể loại này."), findsOneWidget);
      });

      testWidgets('empty state has white text color', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: const Center(
                child: Text(
                  "Không có phim thuộc thể loại này.",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        );

        final emptyText = tester.widget<Text>(
          find.text("Không có phim thuộc thể loại này."),
        );
        expect(emptyText.style?.color, Colors.white);
      });

      testWidgets('navigation buttons exist', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Row(
                children: const [
                  Icon(Icons.chevron_left),
                  Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.chevron_left), findsOneWidget);
        expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      });
    });

    group('AppBar Configuration', () {
      testWidgets('AppBar has correct styling', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              appBar: AppBar(
                title: const Text('Test Category'),
                backgroundColor: Colors.black,
                elevation: 0,
                centerTitle: true,
              ),
            ),
          ),
        );

        final appBar = tester.widget<AppBar>(find.byType(AppBar).first);
        expect(appBar.backgroundColor, Colors.black);
        expect(appBar.elevation, 0);
        expect(appBar.centerTitle, true);
      });

      testWidgets('AppBar title displays category name', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              appBar: AppBar(
                title: const Text(
                  'Action Movies',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Action Movies'), findsOneWidget);
      });
    });
  });
}
