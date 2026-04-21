import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    bool clearSelectedKingdom = false,
  }) {
    return CampaignState(
      conqueredKingdomIds: conqueredKingdomIds ?? this.conqueredKingdomIds,
      selectedKingdomId: clearSelectedKingdom ? null : (selectedKingdomId ?? this.selectedKingdomId),
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
  static const _keyConqueredKingdoms = 'conquered_kingdoms';

  @override
  CampaignState build() {
    // Initial state will be updated by _loadCampaign
    _loadCampaign();
    return const CampaignState();
  }

  Future<void> _loadCampaign() async {
    final prefs = await SharedPreferences.getInstance();
    final conqueredList = prefs.getStringList(_keyConqueredKingdoms) ?? [];
    
    state = state.copyWith(
      conqueredKingdomIds: conqueredList.toSet(),
    );
  }

  Future<void> _saveCampaign() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyConqueredKingdoms, 
      state.conqueredKingdomIds.toList(),
    );
  }

  void selectKingdom(String? kingdomId) {
    if (kingdomId == null) {
      state = state.copyWith(clearSelectedKingdom: true);
    } else {
      state = state.copyWith(selectedKingdomId: kingdomId, clearSelectedKingdom: false);
    }
  }

  Future<void> conquerKingdom(String kingdomId) async {
    if (state.conqueredKingdomIds.contains(kingdomId)) {
      state = state.copyWith(clearSelectedKingdom: true);
      return;
    }
    
    state = state.copyWith(
      conqueredKingdomIds: {...state.conqueredKingdomIds, kingdomId},
      clearSelectedKingdom: true,
    );
    await _saveCampaign();
  }

  Future<void> resetProgress() async {
    state = state.copyWith(conqueredKingdomIds: {});
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyConqueredKingdoms);
  }
}

final campaignProvider = NotifierProvider<CampaignNotifier, CampaignState>(() {
  return CampaignNotifier();
});
