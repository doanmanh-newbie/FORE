import 'package:flutter_test/flutter_test.dart';
import 'package:fore/core/errors/app_failure.dart';
import 'package:fore/features/inventory/application/count_controller.dart';
import 'package:fore/features/inventory/application/po_form_controller.dart';
import 'package:fore/features/inventory/domain/kho_models.dart';
import 'package:fore/features/inventory/domain/kho_repository.dart';

class _FakeKho implements KhoRepository {
  final List<String> log = [];
  PoDraft? lastDraft;
  bool? lastWithPrice;
  Map<String, int?>? lastSaved;
  CountSheet sheet = const CountSheet(
    id: 'k1',
    code: 'KK-0711',
    status: StocktakeStatus.draft,
    lines: [
      CountLine(ingredientId: 'milk', name: 'Sữa', unit: 'ml', editable: true, recountRequested: false),
      CountLine(ingredientId: 'sugar', name: 'Đường', unit: 'g', editable: true, recountRequested: false),
    ],
  );

  @override
  Future<PoDetail> saveOrder(String? id, PoDraft draft,
      {required bool confirm, required bool withPrice}) async {
    log.add('saveOrder:${id ?? 'new'}:$confirm');
    lastDraft = draft;
    lastWithPrice = withPrice;
    return PoDetail(
      id: id ?? 'p1',
      code: 'PN-0711',
      status: confirm ? PoStatus.confirmed : PoStatus.draft,
      vatIncluded: true,
      needsPricing: !withPrice,
      lines: draft.lines,
    );
  }

  @override
  Future<PoImpact> orderImpact(String id) async {
    log.add('impact:$id');
    return const PoImpact(code: 'PN-0711', items: [], sizes: []);
  }

  @override
  Future<({String id, String code, bool resumed})> startStocktake() async {
    log.add('start');
    return (id: 'k1', code: 'KK-0711', resumed: false);
  }

  @override
  Future<CountSheet> countSheet(String id) async => sheet;

  @override
  Future<void> saveCounts(String id, Map<String, int?> q) async {
    log.add('saveCounts');
    lastSaved = q;
  }

  @override
  Future<void> submitStocktake(String id) async {
    log.add('submit');
    sheet = CountSheet(
        id: sheet.id,
        code: sheet.code,
        status: StocktakeStatus.submitted,
        lines: sheet.lines);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _milk = PickerItem(id: 'milk', name: 'Sữa tươi', unit: 'ml');

void main() {
  group('PoFormController', () {
    test('chủ chỉ xác nhận được khi có nhà cung cấp, số lượng và giá', () {
      final c = PoFormController(_FakeKho(), isOwner: true);
      expect(c.canConfirm, isFalse);
      c.addLine(_milk);
      c.setSupplier('s1');
      expect(c.canConfirm, isFalse, reason: 'chưa có số lượng và giá');
      c.updateLine(0, c.lines[0].copyWith(qty: 30000));
      expect(c.canConfirm, isFalse, reason: 'chưa có giá');
      c.updateLine(0, c.lines[0].copyWith(unitPrice: 50));
      expect(c.canConfirm, isTrue);
      expect(c.linesTotal, 1500000);
      c.setShipping(30000);
      expect(c.grandTotal, 1530000);
    });

    test('nhân viên chỉ cần số lượng, không gửi giá', () async {
      final repo = _FakeKho();
      final c = PoFormController(repo, isOwner: false);
      c
        ..addLine(_milk)
        ..setSupplier('s1');
      c.updateLine(0, c.lines[0].copyWith(qty: 2000, unitPrice: 999));
      expect(c.canConfirm, isTrue);
      final saved = await c.confirm();
      expect(saved?.status, PoStatus.confirmed);
      expect(repo.lastWithPrice, isFalse);
      expect(c.id, 'p1');
      expect(c.code, 'PN-0711');
    });

    test('không thêm trùng một nguyên liệu', () {
      final c = PoFormController(_FakeKho(), isOwner: true)
        ..addLine(_milk)
        ..addLine(_milk);
      expect(c.lines, hasLength(1));
    });

    test('xác nhận khi thiếu dữ liệu thì báo lỗi nghiệp vụ, không gọi database', () async {
      final repo = _FakeKho();
      final c = PoFormController(repo, isOwner: true)..addLine(_milk);
      await expectLater(c.confirm(), throwsA(isA<DatabaseFailure>()));
      expect(repo.log, isEmpty);
    });

    test('lưu nháp rồi xem tác động giá dùng đúng mã phiếu', () async {
      final repo = _FakeKho();
      final c = PoFormController(repo, isOwner: true)
        ..addLine(_milk)
        ..setSupplier('s1');
      c.updateLine(0, c.lines[0].copyWith(qty: 1000, unitPrice: 50));
      final impact = await c.previewImpact();
      expect(impact?.code, 'PN-0711');
      expect(repo.log, ['saveOrder:new:false', 'impact:p1']);
    });
  });

  group('CountController', () {
    test('bắt đầu, đếm đủ rồi gửi; chưa đếm khác với 0', () async {
      final repo = _FakeKho();
      final c = CountController(repo);
      await c.start();
      expect(c.totalCount, 2);
      expect(c.countedCount, 0);
      c.setQty('milk', 0);
      expect(c.countedCount, 1, reason: 'số 0 vẫn là đã đếm');
      expect(c.complete, isFalse);
      await expectLater(c.submit(), throwsA(isA<DatabaseFailure>()));
      c.setQty('sugar', 5000);
      expect(c.complete, isTrue);
      expect(await c.submit(), isTrue);
      expect(repo.lastSaved, {'milk': 0, 'sugar': 5000});
      expect(repo.log.last, 'submit');
      expect(c.locked, isTrue);
    });

    test('đếm lại chỉ gồm các dòng chủ yêu cầu', () async {
      final repo = _FakeKho()
        ..sheet = const CountSheet(
          id: 'k1',
          code: 'KK-0711',
          status: StocktakeStatus.recount,
          lines: [
            CountLine(ingredientId: 'milk', name: 'Sữa', unit: 'ml', countedQty: 11000, editable: true, recountRequested: true),
            CountLine(ingredientId: 'sugar', name: 'Đường', unit: 'g', countedQty: 5000, editable: false, recountRequested: false),
          ],
        );
      final c = CountController(repo);
      await c.openExisting('k1');
      expect(c.activeLines.map((l) => l.ingredientId), ['milk']);
      expect(c.totalCount, 1);
      expect(c.complete, isTrue);
    });

    test('lưu nháp chỉ gửi các dòng đã sửa', () async {
      final repo = _FakeKho();
      final c = CountController(repo);
      await c.start();
      c.setQty('milk', 12000);
      expect(c.hasUnsaved, isTrue);
      expect(await c.saveDraft(), isTrue);
      expect(repo.lastSaved, {'milk': 12000});
      expect(c.hasUnsaved, isFalse);
    });
  });
}
