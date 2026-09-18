import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Bank extends ChangeNotifier {
  Bank._();

  static const stakes = [50, 100, 200, 500, 1000, 2500, 5000, 10000];
  static const startChips = 25000;
  static const startJackpot = 8450000;
  static const daily = [2000, 4000, 7000, 10000, 15000, 25000, 50000];

  static const _kChips = 'chips';
  static const _kJack = 'jackpot';
  static const _kStake = 'stake';
  static const _kStreak = 'streak';
  static const _kClaim = 'claim';
  static const _kRefillDay = 'refill_day';
  static const _kRefills = 'refills';
  static const _kLife = 'life';

  late SharedPreferences _db;

  int chips = startChips;
  int jackpot = startJackpot;
  int stakeIndex = 1;
  int streak = 0;
  String? lastClaim;
  String? refillDay;
  int refills = 0;
  int lifetime = 0;

  int freeLeft = 0;
  int freeTotal = 0;
  int freeBucket = 0;
  int lastPaid = 0;
  bool auto = false;

  int get stake => stakes[stakeIndex.clamp(0, stakes.length - 1)];
  bool get canSpin => freeLeft > 0 || chips >= stake;
  bool get dailyReady => lastClaim != _today();

  int get dailyIndex {
    if (!dailyReady) return streak;
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final y = '${yesterday.year}-${yesterday.month}-${yesterday.day}';
    if (lastClaim == y) {
      final n = streak + 1;
      return n > 6 ? 0 : n;
    }
    return 0;
  }

  static Future<Bank> open() async {
    final b = Bank._();
    b._db = await SharedPreferences.getInstance();
    b.chips = b._db.getInt(_kChips) ?? startChips;
    b.jackpot = b._db.getInt(_kJack) ?? startJackpot;
    b.stakeIndex = (b._db.getInt(_kStake) ?? 1).clamp(0, stakes.length - 1);
    b.streak = b._db.getInt(_kStreak) ?? 0;
    b.lastClaim = b._db.getString(_kClaim);
    b.refillDay = b._db.getString(_kRefillDay);
    b.refills = b._db.getInt(_kRefills) ?? 0;
    b.lifetime = b._db.getInt(_kLife) ?? 0;
    if (b.refillDay != _today()) b.refills = 0;
    if (b.chips <= 0) b.chips = 500;
    return b;
  }

  static String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  Future<void> _flush() async {
    await _db.setInt(_kChips, chips);
    await _db.setInt(_kJack, jackpot);
    await _db.setInt(_kStake, stakeIndex);
    await _db.setInt(_kStreak, streak);
    await _db.setInt(_kRefills, refills);
    await _db.setInt(_kLife, lifetime);
    if (lastClaim != null) await _db.setString(_kClaim, lastClaim!);
    if (refillDay != null) await _db.setString(_kRefillDay, refillDay!);
  }

  void bumpStake(int dir) {
    stakeIndex = (stakeIndex + dir).clamp(0, stakes.length - 1);
    notifyListeners();
    _flush();
  }

  void tickJack(int n) {
    jackpot += n;
    if (jackpot > 999999999) jackpot = startJackpot;
    notifyListeners();
  }

  bool takeStake() {
    if (freeLeft > 0) {
      freeLeft--;
      notifyListeners();
      return true;
    }
    if (chips < stake) return false;
    chips -= stake;
    jackpot += (stake ~/ 18).clamp(1, 500);
    notifyListeners();
    _flush();
    return true;
  }

  void credit(int n) {
    if (n <= 0) return;
    lastPaid = n;
    if (freeTotal > 0) {
      freeBucket += n;
    } else {
      chips += n;
    }
    lifetime += n;
    notifyListeners();
    _flush();
  }

  void grantFree(int n) {
    if (n <= 0) return;
    if (freeTotal == 0) freeBucket = 0;
    freeLeft += n;
    freeTotal += n;
    notifyListeners();
  }

  int closeBonus() {
    final dumped = freeBucket;
    chips += dumped;
    freeBucket = 0;
    freeTotal = 0;
    freeLeft = 0;
    notifyListeners();
    _flush();
    return dumped;
  }

  int claimDaily() {
    if (!dailyReady) return 0;
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final y = '${yesterday.year}-${yesterday.month}-${yesterday.day}';
    streak = lastClaim == y ? (streak + 1) : 0;
    if (streak > 6) streak = 0;
    final pay = daily[streak];
    chips += pay;
    lastClaim = _today();
    notifyListeners();
    _flush();
    return pay;
  }

  int refill() {
    if (chips >= stakes.first) return 0;
    if (refillDay != _today()) {
      refillDay = _today();
      refills = 0;
    }
    if (refills >= 3) return 0;
    const drop = 5000;
    chips += drop;
    refills++;
    notifyListeners();
    _flush();
    return drop;
  }

  void inject(int n) {
    chips += n;
    if (chips < 0) chips = 0;
    notifyListeners();
    _flush();
  }

  Future<void> wipe() async {
    chips = startChips;
    jackpot = startJackpot;
    stakeIndex = 1;
    streak = 0;
    lastClaim = null;
    refillDay = null;
    refills = 0;
    lifetime = 0;
    freeLeft = 0;
    freeTotal = 0;
    freeBucket = 0;
    lastPaid = 0;
    auto = false;
    await _db.clear();
    notifyListeners();
  }
}
