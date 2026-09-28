import 'dart:convert';

enum Mark {
  fresh,
  glass,
  cabin;

  String get token {
    if (this == Mark.glass) return 'glass';
    if (this == Mark.cabin) return 'cabin';
    return 'fresh';
  }

  static Mark read(String? raw) {
    if (raw == 'glass') return Mark.glass;
    if (raw == 'cabin') return Mark.cabin;
    return Mark.fresh;
  }
}

class Reply {
  const Reply({
    required this.approved,
    this.url,
    this.expiresAt,
    this.note,
  });

  factory Reply.rejected(String note) => Reply(approved: false, note: note);

  factory Reply.fromJson(Map<String, dynamic> json) {
    final expiry = json['expires'];
    int? until;
    if (expiry is num) {
      until = expiry.toInt();
    } else if (expiry != null) {
      until = int.tryParse(expiry.toString());
    }
    final rawUrl = json['url'];
    return Reply(
      approved: json['ok'] == true,
      url: rawUrl is String ? rawUrl : null,
      expiresAt: until,
      note: json['message']?.toString(),
    );
  }

  final bool approved;
  final String? url;
  final int? expiresAt;
  final String? note;

  bool get hasDestination {
    if (!approved) return false;
    final dest = url;
    return dest != null && dest.isNotEmpty;
  }

  static Reply decodeBody(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return Reply.rejected('bad_json');
    return Reply.fromJson(Map<String, dynamic>.from(decoded));
  }
}

sealed class Landing {
  const Landing();
}

final class CabinLanding extends Landing {
  const CabinLanding();
}

final class GlassLanding extends Landing {
  const GlassLanding(this.url, {this.coldTap = false});

  final String url;
  final bool coldTap;
}

final class GapLanding extends Landing {
  const GapLanding({required this.backToCabin});

  final bool backToCabin;
}
