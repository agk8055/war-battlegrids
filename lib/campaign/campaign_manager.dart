import 'package:flutter_riverpod/flutter_riverpod.dart';

class CampaignState {
  final Set<String> conqueredKingdomIds;
  final String? selectedKingdomId;

  const CampaignState({
    this.conqueredKingdomIds = const {},
    this.selectedKingdomId,
  });

  CampaignState copyWith({
    Set<String>? conqueredKingdomIds,
    String? selectedKingdomId,
  }) {
    return CampaignState(
      conqueredKingdomIds: conqueredKingdomIds ?? this.conqueredKingdomIds,
      selectedKingdomId: selectedKingdomId ?? this.selectedKingdomId,
    );
  }

  bool isUnlocked(String kingdomId, List<String> unlockedBy) {
    if (unlockedBy.isEmpty) return true;
    return unlockedBy.every((id) => conqueredKingdomIds.contains(id));
  }

  bool isConquered(String kingdomId) {
    return conqueredKingdomIds.contains(kingdomId);
  }
}

class CampaignNotifier extends Notifier<CampaignState> {
  @override
  CampaignState build() {
    return const CampaignState();
  }

  void selectKingdom(String kingdomId) {
    state = state.copyWith(selectedKingdomId: kingdomId);
  }

  void conquerKingdom(String kingdomId) {
    state = state.copyWith(
      conqueredKingdomIds: {...state.conqueredKingdomIds, kingdomId},
    );
  }
}

final campaignProvider = NotifierProvider<CampaignNotifier, CampaignState>(() {
  return CampaignNotifier();
});
