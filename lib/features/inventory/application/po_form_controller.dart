import '../../../core/application/action_notifier.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/kho_models.dart';
import '../domain/kho_repository.dart';

/// Soạn phiếu nhập nhiều dòng. Chủ nhập giá; nhân viên chỉ ghi đúng lượng nhận (không có giá).
class PoFormController extends ActionNotifier {
  PoFormController(this._repo, {required this.isOwner, PoDetail? existing})
      : _id = existing?.id,
        code = existing?.code,
        supplierId = existing?.supplierId,
        note = existing?.note ?? '',
        vatIncluded = existing?.vatIncluded ?? true,
        shippingFee = existing?.shippingFee ?? 0,
        lines = List.of(existing?.lines ?? const []);

  final KhoRepository _repo;
  final bool isOwner;

  String? _id;
  String? code;
  String? supplierId;
  String note;
  bool vatIncluded;
  int shippingFee;
  List<PoLine> lines;
  DateTime? savedAt;

  String? get id => _id;

  void setSupplier(String? id) {
    supplierId = id;
    notify();
  }

  void setNote(String v) => note = v;

  void setVat(bool v) {
    vatIncluded = v;
    notify();
  }

  void setShipping(int v) {
    shippingFee = v;
    notify();
  }

  void addLine(PickerItem item, {int qty = 0}) {
    if (lines.any((l) => l.ingredientId == item.id)) return;
    lines = [
      ...lines,
      PoLine(ingredientId: item.id, name: item.name, unit: item.unit, qty: qty),
    ];
    notify();
  }

  void updateLine(int index, PoLine line) {
    lines = [...lines]..[index] = line;
    notify();
  }

  void removeLine(int index) {
    lines = [...lines]..removeAt(index);
    notify();
  }

  /// Dòng đã điền đủ để ghi vào kho (số lượng > 0; chủ cần thêm giá).
  bool lineReady(PoLine l) => l.qty > 0 && (!isOwner || l.unitPrice != null);

  bool get allReady => lines.isNotEmpty && lines.every(lineReady);

  int? get linesTotal {
    if (!isOwner || lines.any((l) => l.unitPrice == null)) return null;
    return lines.fold<int>(0, (a, l) => a + l.lineTotal!);
  }

  int? get grandTotal => linesTotal == null ? null : linesTotal! + shippingFee;

  bool get canConfirm => !busy && supplierId != null && allReady;

  bool get canSaveDraft => !busy && lines.isNotEmpty;

  PoDraft _draft() => PoDraft(
        supplierId: supplierId,
        note: note.trim().isEmpty ? null : note.trim(),
        vatIncluded: vatIncluded,
        shippingFee: isOwner ? shippingFee : 0,
        lines: [for (final l in lines) l.copyWith()],
      );

  Future<PoDetail?> _save({required bool confirm}) async {
    if (lines.isEmpty) throw const DatabaseFailure('LINES_REQUIRED');
    if (confirm && supplierId == null) {
      throw const DatabaseFailure('SUPPLIER_REQUIRED');
    }
    if (confirm && !allReady) {
      throw DatabaseFailure(isOwner ? 'PRICE_REQUIRED' : 'QTY_INVALID');
    }
    return runAction<PoDetail>(() async {
      final saved = await _repo.saveOrder(_id, _draft(),
          confirm: confirm, withPrice: isOwner);
      _id = saved.id;
      code = saved.code;
      savedAt = DateTime.now();
      return saved;
    });
  }

  Future<PoDetail?> saveDraft() => _save(confirm: false);

  Future<PoDetail?> confirm() => _save(confirm: true);

  /// Lưu nháp rồi lấy tác động giá (chỉ chủ).
  Future<PoImpact?> previewImpact() async {
    final saved = await saveDraft();
    if (saved == null) return null;
    return runAction<PoImpact>(() => _repo.orderImpact(saved.id));
  }
}
