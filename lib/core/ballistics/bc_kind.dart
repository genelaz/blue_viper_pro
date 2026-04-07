enum BcKind {
  g1,
  g7,
}

extension BcKindLabel on BcKind {
  String get label => switch (this) {
        BcKind.g1 => 'G1 (standart)',
        BcKind.g7 => 'G7 (uzun boattail)',
      };
}
