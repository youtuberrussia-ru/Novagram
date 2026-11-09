import 'package:flutter_test/flutter_test.dart';
import 'package:novagram/app.dart';

void main() {
  testWidgets('Novagram shows setup instructions before configuration',
      (tester) async {
    await tester.pumpWidget(const NovagramApp(isConfigured: false));
    expect(find.text('Novagram'), findsOneWidget);
    expect(find.textContaining('SUPABASE_URL'), findsOneWidget);
  });
}
