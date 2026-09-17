import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_providers.dart';
import '../../features/auth/login_page.dart';
import '../../features/cash/cash_page.dart';
import '../../features/customer/customer_eyeview_page.dart';
import '../../features/day_check/day_check_page.dart';
import '../../features/factory/factory_page.dart';
import '../../features/factory/recipe_details_page.dart';
import '../../features/home/home_page.dart';
import '../../features/inventory/inventory_page.dart';
import '../../features/inventory/item_details_page.dart';
import '../../features/invoices/invoices_page.dart';
import '../../features/khata/bill_details_page.dart';
import '../../features/khata/khata_page.dart';
import '../../features/khata/party_details_page.dart';
import '../../features/more/more_page.dart';
import '../../features/qr/qr_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/shell/main_shell.dart';

final _rootKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/home',
    redirect: (context, state) {
      final onLogin = state.matchedLocation == '/login';
      if (auth == null && !onLogin) return '/login';
      if (auth != null && onLogin) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/stock',
                builder: (context, state) => const InventoryPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/khata',
                builder: (context, state) => const KhataPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/factory',
                builder: (context, state) => const FactoryPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (context, state) => const MorePage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/stock/item/:id',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => ItemDetailsPage(
          itemId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/udhaar/party/:id',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => PartyDetailsPage(
          partyId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/udhaar/bill/:id',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => BillDetailsPage(
          billId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/factory/recipe/:id',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => RecipeDetailsPage(
          recipeId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/cash',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const CashPage(),
      ),
      GoRoute(
        path: '/day-check',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const DayCheckPage(),
      ),
      GoRoute(
        path: '/invoices',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const InvoicesPage(),
      ),
      GoRoute(
        path: '/qr',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const QrPage(),
      ),
      GoRoute(
        path: '/customer',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const CustomerEyeviewPage(),
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const SettingsPage(),
      ),
    ],
  );
});
