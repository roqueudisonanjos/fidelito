import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../pages/customer/history_page.dart';
import '../../pages/customer/notifications_page.dart';
import '../../pages/auth/login_page.dart';
import '../../pages/auth/register_page.dart';
import '../../pages/customer/customer_home_page.dart';
import '../../pages/customer/explore_page.dart';
import '../../pages/customer/my_loyalty_programs_page.dart';
import '../../pages/customer/company_details_page.dart';
import '../../pages/customer/loyalty_program_page.dart';
import '../../pages/company/company_home_page.dart';
import '../../pages/company/company_setup_page.dart';
import '../../pages/company/generate_qr_page.dart';
import '../../pages/company/validate_benefit_page.dart';
import '../../pages/customer/qr_scanner_page.dart';
import '../../pages/customer/benefit_qr_page.dart';
import '../../services/auth_service.dart';
import '../../services/company_service.dart';
import '../../pages/customer/promotions_page.dart';
import '../../pages/customer/my_benefits_page.dart';
import '../../pages/customer/benefit_detail_page.dart';
import '../../pages/company/benefit_scanner_page.dart';
import '../../pages/customer/transactions_page.dart';
import '../../pages/company/company_dashboard_page.dart';
import '../../pages/company/company_reports_page.dart';
import '../../pages/profile/edit_profile_page.dart';
import '../../pages/admin/admin_home_page.dart';
import '../../pages/auth/reset_password_page.dart';

import '../../pages/company/company_customers_page.dart';
import '../../pages/company/company_pending_page.dart';
import '../../pages/company/company_suspended_page.dart';

final authService = AuthService();
final companyService = CompanyService();

final appRouter = GoRouter(
  initialLocation: '/login',

  redirect: (context, state) async {
    final session = Supabase.instance.client.auth.currentSession;

    final loggedIn = session != null;

    final location = state.matchedLocation;

    final isAuthPage = location == '/login' || location == '/register';

    // Link de recuperação do Supabase precisa abrir mesmo antes do usuário
    // concluir a redefinição da senha. A página valida a sessão/token.
    if (location == '/reset-password') return null;

    // =========================================================
    // USUÁRIO NÃO AUTENTICADO
    // =========================================================

    if (!loggedIn) {
      if (isAuthPage) {
        return null;
      }

      return '/login';
    }

    // =========================================================
    // BUSCAR ROLE
    // =========================================================

    final role = await authService.getCurrentUserRole();

    if (role == null) {
      return '/login';
    }

    // =========================================================
    // PÁGINAS DE LOGIN / CADASTRO
    // =========================================================

    if (isAuthPage) {
      if (role == 'admin') {
        return '/admin';
      }

      if (role == 'customer') {
        return '/home';
      }

      if (role == 'company_owner') {
        final company = await companyService.getMyCompany();

        if (company == null) return '/company/setup';

        if (company['active'] != true) {
          return company['suspended_at'] != null
              ? '/company/suspended'
              : '/company/pending';
        }

        return '/company';
      }

      return '/login';
    }

    // =========================================================
    // ADMINISTRADOR DO FIDELITO
    // =========================================================

    if (role == 'admin') {
      if (location == '/admin') return null;
      return '/admin';
    }

    if (location == '/admin') {
      if (role == 'customer') return '/home';
      if (role == 'company_owner') return '/company';
      return '/login';
    }

    // =========================================================
    // CLIENTE
    // =========================================================

    if (role == 'customer') {
      // Páginas permitidas para o cliente
      if (location == '/home' ||
          location == '/customer/scan' ||
          location == '/customer/explore' ||
          location == '/customer/my-loyalties' ||
          location == '/customer/company-details' ||
          location == '/customer/loyalty-program' ||
          location == '/customer/promotions' ||
          location == '/customer/my-benefits' ||
          location == '/customer/benefit-detail' ||
          location == '/customer/benefit-qr' ||
          location == '/customer/scan-benefit' ||
          location == '/customer/history' ||
          location == '/customer/transactions' ||
          location == '/customer/notifications' ||
          location == '/profile/edit') {
        return null;
      }

      // Cliente não pode acessar páginas da empresa
      if (location.startsWith('/company')) {
        return '/home';
      }

      // Qualquer outra rota desconhecida
      return '/home';
    }

    // =========================================================
    // EMPRESA
    // =========================================================

    if (role == 'company_owner') {
      final company = await companyService.getMyCompany();

      // -------------------------------------------------------
      // Empresa ainda não cadastrada
      // -------------------------------------------------------

      if (company == null) {
        if (location == '/company/setup') {
          return null;
        }

        return '/company/setup';
      }

      if (company['active'] != true) {
        final suspended = company['suspended_at'] != null;
        final blockedLocation = suspended
            ? '/company/suspended'
            : '/company/pending';
        if (location == blockedLocation) return null;
        return blockedLocation;
      }

      // -------------------------------------------------------
      // Empresa já cadastrada
      // -------------------------------------------------------

      if (location == '/company/setup') {
        return '/company';
      }

      if (location == '/company' ||
          location == '/company/generate-qr' ||
          location == '/company/validate-benefit' ||
          location == '/company/scan-benefit' ||
          location == '/company/dashboard' ||
          location == '/company/rewards' ||
          location == '/company/reports' ||
          location == '/profile/editCompany' ||
          location == '/company/customers') {
        return null;
      }

      if (location == '/home' || location == '/customer/scan') {
        return '/company';
      }

      return '/company';
    }

    return '/login';
  },

  routes: [
    GoRoute(path: '/admin', builder: (context, state) => const AdminHomePage()),
    GoRoute(
      path: '/reset-password',
      builder: (context, state) => const ResetPasswordPage(),
    ),

    // =========================================================
    // AUTH
    // =========================================================
    GoRoute(
      path: '/login',
      builder: (context, state) {
        return const LoginPage();
      },
    ),

    GoRoute(
      path: '/register',
      builder: (context, state) {
        return const RegisterPage();
      },
    ),

    // =========================================================
    // CLIENTE
    // =========================================================
    GoRoute(
      path: '/home',
      builder: (context, state) {
        return const CustomerHomePage();
      },
    ),

    GoRoute(
      path: '/customer/explore',
      builder: (context, state) => const ExplorePage(),
    ),
    GoRoute(
      path: '/customer/my-loyalties',
      builder: (context, state) => const MyLoyaltyProgramsPage(),
    ),
    GoRoute(
      path: '/customer/company-details',
      builder: (context, state) => CompanyDetailsPage(
        company: Map<String, dynamic>.from(state.extra as Map),
      ),
    ),
    GoRoute(
      path: '/customer/loyalty-program',
      builder: (context, state) => LoyaltyProgramPage(
        company: Map<String, dynamic>.from(state.extra as Map),
      ),
    ),

    GoRoute(
      path: '/customer/scan',
      builder: (context, state) {
        return const QrScannerPage();
      },
    ),

    // =========================================================
    // EMPRESA
    // =========================================================
    GoRoute(
      path: '/company/pending',
      builder: (context, state) => const CompanyPendingPage(),
    ),
    GoRoute(
      path: '/company/suspended',
      builder: (context, state) => const CompanySuspendedPage(),
    ),

    GoRoute(
      path: '/company/setup',
      builder: (context, state) {
        return const CompanySetupPage();
      },
    ),

    GoRoute(
      path: '/company',
      builder: (context, state) {
        return const CompanyHomePage();
      },
    ),

    GoRoute(
      path: '/company/generate-qr',
      builder: (context, state) {
        return const GenerateQrPage();
      },
    ),

    GoRoute(
      path: '/customer/promotions',
      builder: (context, state) {
        final companyId = state.uri.queryParameters['companyId'];

        if (companyId == null) {
          return const Scaffold(
            body: Center(child: Text('Empresa não informada.')),
          );
        }

        return PromotionsPage(companyId: companyId);
      },
    ),

    GoRoute(
      path: '/customer/my-benefits',
      builder: (context, state) {
        return const MyBenefitsPage();
      },
    ),

    GoRoute(
      path: '/customer/benefit-detail',
      builder: (context, state) {
        final benefit = state.extra as Map<String, dynamic>;

        return BenefitDetailPage(benefit: benefit);
      },
    ),

    GoRoute(
      path: '/company/validate-benefit',
      builder: (context, state) {
        return const ValidateBenefitPage();
      },
    ),

    GoRoute(
      path: '/customer/benefit-qr',
      builder: (context, state) {
        final benefit = state.extra as Map<String, dynamic>;

        return BenefitQrPage(benefit: benefit);
      },
    ),

    GoRoute(
      path: '/company/scan-benefit',
      builder: (context, state) {
        return const BenefitScannerPage();
      },
    ),

    GoRoute(
      path: '/customer/history',
      builder: (context, state) {
        return const HistoryPage();
      },
    ),

    GoRoute(
      path: '/customer/transactions',
      builder: (context, state) {
        return const TransactionsPage();
      },
    ),

    GoRoute(
      path: '/company/dashboard',
      builder: (context, state) {
        return const CompanyDashboardPage();
      },
    ),
    GoRoute(
      path: '/company/rewards',
      builder: (context, state) {
        return const CompanyHomePage(showOnlyPromotions: true);
      },
    ),

    GoRoute(
      path: '/company/reports',
      builder: (context, state) {
        final companyId = state.uri.queryParameters['companyId'];

        if (companyId == null) {
          return const Scaffold(
            body: Center(child: Text('Empresa não informada.')),
          );
        }

        return CompanyReportsPage(companyId: companyId);
      },
    ),
    GoRoute(
      path: '/customer/notifications',
      builder: (context, state) => const NotificationsPage(),
    ),

    GoRoute(
      path: '/profile/edit',
      builder: (context, state) => const EditProfilePage(),
    ),

    GoRoute(
      path: '/profile/editCompany',
      builder: (context, state) => const CompanySetupPage(),
    ),

    GoRoute(
      path: '/company/customers',
      builder: (context, state) {
        return const CompanyCustomersPage();
      },
    ),
  ],
);
