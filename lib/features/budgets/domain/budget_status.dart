/// Ciclo de vida do orçamento (`features/budget/domain/entities/budget_entity.go`).
///
/// O swagger lista só 6 valores; o backend aceita os 8 abaixo.
enum BudgetStatus {
  draft('draft', 'Rascunho'),
  sent('sent', 'Enviado'),
  approved('approved', 'Aprovado'),
  printing('printing', 'Imprimindo'),
  completed('completed', 'Concluído'),
  rejected('rejected', 'Rejeitado'),
  expired('expired', 'Expirado'),
  cancelled('cancelled', 'Cancelado');

  const BudgetStatus(this.value, this.label);

  final String value;
  final String label;

  static BudgetStatus fromValue(String? value) {
    for (final s in values) {
      if (s.value == value) return s;
    }
    return BudgetStatus.draft;
  }

  /// Transições permitidas — fonte única de verdade para o kanban e menus.
  Set<BudgetStatus> get allowedTransitions => switch (this) {
    draft => const {sent, cancelled},
    sent => const {approved, rejected, expired, cancelled},
    approved => const {printing, cancelled},
    printing => const {completed},
    completed => const {},
    rejected || expired || cancelled => const {draft},
  };

  bool canTransitionTo(BudgetStatus to) => allowedTransitions.contains(to);

  /// Só rascunhos podem ser editados/recalculados (409 `budget_not_editable`).
  bool get isEditable => this == draft;

  /// Imprimindo/concluído não podem ser excluídos (409 `budget_not_deletable`).
  bool get isDeletable => this != printing && this != completed;

  /// Status a partir dos quais o link público pode ser gerado.
  bool get isShareable =>
      const {draft, sent, approved, rejected, expired}.contains(this);

  /// Rótulo da ação que leva a este status ("Marcar como enviado"…).
  String get actionLabel => switch (this) {
    draft => 'Voltar para rascunho',
    sent => 'Marcar como enviado',
    approved => 'Marcar como aprovado',
    printing => 'Iniciar impressão',
    completed => 'Concluir',
    rejected => 'Marcar como rejeitado',
    expired => 'Marcar como expirado',
    cancelled => 'Cancelar orçamento',
  };

  /// Colunas principais do quadro (os terminais negativos ficam recolhidos).
  static const List<BudgetStatus> board = [
    draft,
    sent,
    approved,
    printing,
    completed,
  ];
  static const List<BudgetStatus> archived = [rejected, expired, cancelled];
}
