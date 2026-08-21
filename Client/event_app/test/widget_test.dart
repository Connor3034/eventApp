// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:event_app/auth_service.dart';
import 'package:event_app/pages/login.dart';

void main() {
  testWidgets('renders the login form', (WidgetTester tester) async {
    final authService = AuthService();
    await tester.pumpWidget(
      MaterialApp(home: Login(authService: authService)),
    );

    expect(find.text('Log in'), findsNWidgets(2));
    expect(find.text('Create an account'), findsOneWidget);
  });
}
