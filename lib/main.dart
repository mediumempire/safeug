import 'package:flutter/material.dart';
import 'local/local_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SafeUgLocalApp());
}

class SafeUgApp extends StatelessWidget {
  const SafeUgApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeUgLocalApp();
  }
}
