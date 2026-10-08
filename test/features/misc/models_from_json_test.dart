import 'package:flutter_test/flutter_test.dart';
import 'package:spooliq_desktop/features/admin/domain/admin.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_status.dart';
import 'package:spooliq_desktop/features/catalog/domain/catalog.dart';
import 'package:spooliq_desktop/features/company/domain/company.dart';
import 'package:spooliq_desktop/features/customers/domain/customer.dart';
import 'package:spooliq_desktop/features/dashboard/domain/dashboard.dart';
import 'package:spooliq_desktop/features/models3d/domain/model3d.dart';
import 'package:spooliq_desktop/features/presets/domain/preset.dart';
import 'package:spooliq_desktop/features/subscription/domain/billing.dart';
import 'package:spooliq_desktop/features/users/domain/app_user.dart';

void main() {
  group('Customer', () {
    test('reads the list wrapper with budget aggregates', () {
      final c = Customer.fromJson(const {
        'customer': {
          'id': 'c1',
          'name': 'Ana Maria Souza',
          'email': 'ana@x.com',
          'city': 'Maceió',
          'state': 'AL',
          'is_active': true,
        },
        'budget_count': 3,
        'total_budgets': 40129,
        'budgets': [
          {
            'id': 'b1',
            'name': 'Vaso',
            'status': 'completed',
            'total_cost': 1990,
          },
        ],
      });
      expect(c.name, 'Ana Maria Souza');
      expect(c.initials, 'AS');
      expect(c.location, 'Maceió / AL');
      expect(c.budgetCount, 3);
      expect(c.totalSpentCents, 40129);
      expect(c.budgets.single.status, BudgetStatus.completed);
    });

    test('reads a plain customer object', () {
      final c = Customer.fromJson(const {'id': 'c2', 'name': 'Jadir'});
      expect(c.id, 'c2');
      expect(c.isActive, isTrue);
      expect(c.budgetCount, 0);
    });

    test('input JSON trims and uppercases the state', () {
      const input = CustomerInput(name: ' Ana ', state: 'al', email: ' ');
      final json = input.toJson();
      expect(json['name'], 'Ana');
      expect(json['state'], 'AL');
      expect(json['email'], isNull);
    });
  });

  group('Filament', () {
    test('reads nested brand/material and price in cents', () {
      final f = Filament.fromJson(const {
        'id': 'f1',
        'name': 'PLA Basic',
        'brand_id': 'b',
        'material_id': 'm',
        'brand': {'id': 'b', 'name': 'Voolt 3D'},
        'material': {'id': 'm', 'name': 'PLA Premium'},
        'color': 'Preto',
        'color_hex': '#000000',
        'color_type': 'solid',
        'diameter': 1.75,
        'price_per_kg': 11990,
        'track_stock': true,
        'stock_grams': 2000,
        'low_stock_threshold_grams': 500,
        'is_low_stock': false,
      });
      expect(f.brandName, 'Voolt 3D');
      expect(f.materialName, 'PLA Premium');
      expect(f.pricePerKgCents, 11990);
      expect(f.displayName, 'PLA Basic · Preto');
      expect(f.stockGrams, 2000);
    });

    test('unknown color types fall back to solid', () {
      expect(ColorType.fromValue('neon'), ColorType.solid);
      expect(ColorType.fromValue('wood-fill'), ColorType.woodFill);
    });

    test('stock movement keeps the sign', () {
      final m = StockMovement.fromJson(const {
        'id': 's',
        'type': 'consumption',
        'grams': -380.5,
        'budget_quote_number': 20,
      });
      expect(m.type, StockMovementType.consumption);
      expect(m.grams, -380.5);
      expect(m.budgetQuoteNumber, 20);
    });
  });

  group('Preset', () {
    test('keeps only schema fields for the type', () {
      final p = Preset.fromJson(const {
        'id': 'p',
        'name': 'Bambu A1',
        'type': 'machine',
        'is_default': true,
        'power_consumption': 150,
        'cost_per_hour': 1.2,
        'unrelated': 'x',
      });
      expect(p.type, PresetType.machine);
      expect(p.number('power_consumption'), 150);
      expect(p.values.containsKey('unrelated'), isFalse);
    });

    test('reads values nested under the type key', () {
      final p = Preset.fromJson(const {
        'id': 'p',
        'name': 'Equatorial',
        'type': 'energy',
        'energy': {'energy_cost_per_kwh': 0.89, 'currency': 'BRL'},
      }, type: PresetType.energy);
      expect(p.number('energy_cost_per_kwh'), 0.89);
      expect(p.text('currency'), 'BRL');
    });
  });

  group('Company', () {
    test('current_plan comes as an object', () {
      final c = Company.fromJson(const {
        'id': 'c',
        'name': 'Artesier',
        'subscription_status': 'payment_pending',
        'current_plan': {'id': 'p', 'name': 'Pro'},
      });
      expect(c.currentPlan, 'Pro');
      expect(c.subscriptionStatus, SubscriptionStatus.paymentPending);
    });

    test('branding round-trips the color slots', () {
      final b = CompanyBranding.fromJson(const {
        'template_name': 'coral',
        'primary_color': '#FF6B6B',
      }).withColor('accent_color', '#26C5C5');
      expect(b.toJson(), {
        'template_name': 'coral',
        'primary_color': '#FF6B6B',
        'accent_color': '#26C5C5',
      });
    });
  });

  group('Billing & admin', () {
    test('plan features and cycle label', () {
      final p = Plan.fromJson(const {
        'id': 'p',
        'name': 'Pro',
        'price': 49.9,
        'cycle': 'YEARLY',
        'features': [
          {'name': 'Orçamentos ilimitados', 'is_active': true},
        ],
      });
      expect(p.cycleLabel, '/ano');
      expect(p.features.single.available, isTrue);
    });

    test('payment status labels', () {
      expect(
        Payment.fromJson(const {'id': 'x', 'status': 'RECEIVED'}).isPaid,
        isTrue,
      );
      expect(
        Payment.fromJson(const {'id': 'x', 'status': 'OVERDUE'}).statusLabel,
        'Vencido',
      );
    });

    test('admin company reads plan object and company_name alias', () {
      final c = AdminCompany.fromJson(const {
        'organization_id': 'o',
        'company_name': 'Artesier',
        'subscription_status': 'trial',
        'current_plan': {'name': 'Starter'},
      });
      expect(c.name, 'Artesier');
      expect(c.plan, 'Starter');
      expect(c.status, SubscriptionStatus.trial);
    });

    test('financial report and migration', () {
      final r = PlanFinancialReport.fromJson(const {
        'revenue': {'current_period': 990, 'growth_percentage': 12.5},
        'trends': [
          {'period': '2026-09', 'revenue': 800, 'subscriptions': 16},
        ],
      });
      expect(r.current, 990);
      expect(r.trends.single.subscriptions, 16);
      expect(
        PlanMigration.fromJson(const {
          'migration_id': 'm',
          'status': 'completed',
        }).statusLabel,
        'Concluída',
      );
    });
  });

  group('Dashboard, users and slicer', () {
    test('overview groups counts by status', () {
      final o = Overview.fromJson(const {
        'total_revenue': 8029,
        'budgets_by_status': [
          {'status': 'sent', 'count': 2},
        ],
      });
      expect(o.revenueCents, 8029);
      expect(o.byStatus[BudgetStatus.sent], 2);
    });

    test('app user types', () {
      final u = AppUser.fromJson(const {
        'id': 'u',
        'name': 'Ana',
        'email': 'a@b.c',
        'user_type': 'owner',
      });
      expect(u.type, UserType.owner);
      expect(u.isActive, isTrue);
    });

    test('slice analysis reads plates and catalog suggestions', () {
      final a = SliceAnalysis.fromJson(const {
        'slicer': {'name': 'BambuStudio', 'version': '2.8'},
        'plates': [
          {
            'index': 1,
            'name': 'Plate 1',
            'print_time_seconds': 5400,
            'filaments': [
              {
                'slot': 2,
                'grams': 120.5,
                'color_hex': '#0ACC38',
                'suggestion': {'filament_id': 'f1', 'name': 'PLA Verde'},
              },
            ],
          },
        ],
        'warnings': ['estimado'],
      });
      expect(a.slicer, 'BambuStudio 2.8');
      final plate = a.plates.single;
      expect(plate.hours, 1);
      expect(plate.minutes, 30);
      expect(plate.filaments.single.suggestedFilamentId, 'f1');
      expect(a.warnings, ['estimado']);
    });

    test('model 3D size label and tags', () {
      final m = Model3D.fromJson(const {
        'id': 'm',
        'name': 'Hulk',
        'file_name': 'hulk.3mf',
        'file_format': '.3mf',
        'file_size_bytes': 15465186,
        'tags': 'Action Figure, Marvel',
      });
      expect(m.format, '3MF');
      expect(m.sizeLabel, '14.7 MB');
      expect(m.tags, ['Action Figure', 'Marvel']);
    });
  });
}
