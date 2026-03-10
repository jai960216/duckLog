import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tcg_types.dart';
import 'pokemon_tcg_service.dart';
import 'yugioh_service.dart';
import 'mtg_service.dart';
import 'digimon_tcg_service.dart';

/// TCG 타입별 세트 목록 provider
AutoDisposeFutureProvider<List<TcgSet>> tcgSetsProvider(TcgType type) {
  return switch (type) {
    TcgType.pokemon => pokemonSetsProvider,
    TcgType.yugioh => yugiohSetsProvider,
    TcgType.mtg => mtgSetsProvider,
    TcgType.digimon => digimonSetsProvider,
  };
}

/// TCG 타입별 세트 검색 provider
AutoDisposeFutureProviderFamily<List<TcgSet>, String> tcgSetSearchProvider(
    TcgType type) {
  return switch (type) {
    TcgType.pokemon => pokemonSetSearchProvider,
    TcgType.yugioh => yugiohSetSearchProvider,
    TcgType.mtg => mtgSetSearchProvider,
    TcgType.digimon => digimonSetSearchProvider,
  };
}

/// TCG 타입별 카드 검색 provider
AutoDisposeFutureProviderFamily<List<TcgCard>, String> tcgCardSearchProvider(
    TcgType type) {
  return switch (type) {
    TcgType.pokemon => pokemonCardSearchProvider,
    TcgType.yugioh => yugiohCardSearchProvider,
    TcgType.mtg => mtgCardSearchProvider,
    TcgType.digimon => digimonCardSearchProvider,
  };
}

/// TCG 타입별 세트 카드 목록 provider
AutoDisposeFutureProviderFamily<List<TcgCard>, String> tcgCardsProvider(
    TcgType type) {
  return switch (type) {
    TcgType.pokemon => pokemonCardsProvider,
    TcgType.yugioh => yugiohCardsProvider,
    TcgType.mtg => mtgCardsProvider,
    TcgType.digimon => digimonCardsProvider,
  };
}
