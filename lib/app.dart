import 'package:flutter/material.dart';
import 'package:my_app/features/fraud_radar/presentation/pages/betrugsradar_page.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Betrugsradar',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const BetrugsradarPage(),
    );
  }
}
