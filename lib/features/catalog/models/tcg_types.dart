import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/material.dart';

/// 지원하는 TCG 종류
enum TcgType {
  pokemon,
  yugioh,
  mtg,
  digimon,
}

extension TcgTypeX on TcgType {
  String get label => switch (this) {
        TcgType.pokemon => '포켓몬 카드',
        TcgType.yugioh => '유희왕',
        TcgType.mtg => '매직 더 개더링',
        TcgType.digimon => '디지몬 카드',
      };

  String get subtitle => switch (this) {
        TcgType.pokemon => 'Pokémon TCG',
        TcgType.yugioh => 'Yu-Gi-Oh!',
        TcgType.mtg => 'Magic: The Gathering',
        TcgType.digimon => 'Digimon Card Game',
      };

  IconData get icon => switch (this) {
        TcgType.pokemon => PhosphorIconsBold.lightning,
        TcgType.yugioh => PhosphorIconsBold.star,
        TcgType.mtg => PhosphorIconsBold.diamondsFour,
        TcgType.digimon => PhosphorIconsBold.circlesFour,
      };

  Color get color => switch (this) {
        TcgType.pokemon => const Color(0xFFFFCB05),
        TcgType.yugioh => const Color(0xFF8B5CF6),
        TcgType.mtg => const Color(0xFFE67E22),
        TcgType.digimon => const Color(0xFF3B82F6),
      };

  String get searchHint => switch (this) {
        TcgType.pokemon => '카드 이름 검색 (영문)\n예: Pikachu, Charizard',
        TcgType.yugioh => '카드 이름 검색 (영문)\n예: Dark Magician, Blue-Eyes',
        TcgType.mtg => '카드 이름 검색 (영문)\n예: Lightning Bolt, Black Lotus',
        TcgType.digimon => '카드 이름 검색 (영문)\n예: Agumon, Omnimon',
      };
}

/// 공통 카드 세트 모델
class TcgSet {
  final String id;
  final String name;
  final String? imageUrl;
  final int totalCards;
  final String? releaseDate;

  const TcgSet({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.totalCards,
    this.releaseDate,
  });
}

/// 공통 카드 모델
class TcgCard {
  final String id;
  final String name;
  final String? imageUrl;
  final String? localId;

  const TcgCard({
    required this.id,
    required this.name,
    this.imageUrl,
    this.localId,
  });
}
