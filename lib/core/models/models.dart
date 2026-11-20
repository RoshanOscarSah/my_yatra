import 'package:cloud_firestore/cloud_firestore.dart';

import 'experience.dart';

export 'experience.dart';

DateTime? _date(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  return null;
}

/// Converts DateTime to a Firestore Timestamp (or null).
Timestamp? ts(DateTime? d) => d == null ? null : Timestamp.fromDate(d);

List<String> _strings(dynamic raw) =>
    raw is List ? raw.map((e) => e.toString()).toList() : <String>[];

// ---------------------------------------------------------------------------
// District (static, shared, admin-managed)
// ---------------------------------------------------------------------------

class Festival {
  final String name;
  final String month;
  const Festival(this.name, this.month);

  Map<String, dynamic> toMap() => {'name': name, 'month': month};
  factory Festival.fromMap(Map<String, dynamic> m) =>
      Festival(m['name']?.toString() ?? '', m['month']?.toString() ?? '');
}

class District {
  final String id;
  final String name;
  final String svgLabel;
  final int province;
  final double lat;
  final double lng;
  final String description;
  final List<Experience> experienceTypes;
  final List<Season> bestSeasons;
  final int costLevel;
  final String transport;
  final String safetyNotes;
  final List<Festival> festivals;
  final List<String> foods;
  final bool lessExplored;
  final DateTime? updatedAt;

  const District({
    required this.id,
    required this.name,
    required this.svgLabel,
    required this.province,
    this.lat = 0,
    this.lng = 0,
    this.description = '',
    this.experienceTypes = const [],
    this.bestSeasons = const [],
    this.costLevel = 1,
    this.transport = '',
    this.safetyNotes = '',
    this.festivals = const [],
    this.foods = const [],
    this.lessExplored = false,
    this.updatedAt,
  });

  String get provinceName => Province.nameOf(province);

  /// Required fields for the admin "missing fields" check (US-15.3).
  List<String> get missingFields => [
        if (description.trim().isEmpty) 'description',
        if (experienceTypes.isEmpty) 'experience types',
        if (bestSeasons.isEmpty) 'best seasons',
        if (transport.trim().isEmpty) 'transport',
        if (safetyNotes.trim().isEmpty) 'safety notes',
        if (festivals.isEmpty) 'festivals',
        if (foods.isEmpty) 'foods',
      ];

  Map<String, dynamic> toMap() => {
        'name': name,
        'svgLabel': svgLabel,
        'province': province,
        'lat': lat,
        'lng': lng,
        'description': description,
        'experienceTypes': experienceTypes.map((e) => e.name).toList(),
        'bestSeasons': bestSeasons.map((e) => e.name).toList(),
        'costLevel': costLevel,
        'transport': transport,
        'safetyNotes': safetyNotes,
        'festivals': festivals.map((f) => f.toMap()).toList(),
        'foods': foods,
        'lessExplored': lessExplored,
        'updatedAt': ts(updatedAt) ?? FieldValue.serverTimestamp(),
      };

  factory District.fromMap(String id, Map<String, dynamic> m) => District(
        id: id,
        name: m['name']?.toString() ?? id,
        svgLabel: m['svgLabel']?.toString() ?? '',
        province: (m['province'] as num?)?.toInt() ?? 1,
        lat: (m['lat'] as num?)?.toDouble() ?? 0,
        lng: (m['lng'] as num?)?.toDouble() ?? 0,
        description: m['description']?.toString() ?? '',
        experienceTypes: Experience.listFrom(m['experienceTypes']),
        bestSeasons: Season.listFrom(m['bestSeasons']),
        costLevel: (m['costLevel'] as num?)?.toInt() ?? 1,
        transport: m['transport']?.toString() ?? '',
        safetyNotes: m['safetyNotes']?.toString() ?? '',
        festivals: (m['festivals'] is List)
            ? (m['festivals'] as List)
                .whereType<Map>()
                .map((f) => Festival.fromMap(Map<String, dynamic>.from(f)))
                .toList()
            : const [],
        foods: _strings(m['foods']),
        lessExplored: m['lessExplored'] == true,
        updatedAt: _date(m['updatedAt']),
      );

  District copyWith({
    String? description,
    List<Experience>? experienceTypes,
    List<Season>? bestSeasons,
    int? costLevel,
    String? transport,
    String? safetyNotes,
    List<Festival>? festivals,
    List<String>? foods,
    bool? lessExplored,
    int? province,
    DateTime? updatedAt,
  }) =>
      District(
        id: id,
        name: name,
        svgLabel: svgLabel,
        province: province ?? this.province,
        lat: lat,
        lng: lng,
        description: description ?? this.description,
        experienceTypes: experienceTypes ?? this.experienceTypes,
        bestSeasons: bestSeasons ?? this.bestSeasons,
        costLevel: costLevel ?? this.costLevel,
        transport: transport ?? this.transport,
        safetyNotes: safetyNotes ?? this.safetyNotes,
        festivals: festivals ?? this.festivals,
        foods: foods ?? this.foods,
        lessExplored: lessExplored ?? this.lessExplored,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class Place {
  final String id;
  final String districtId;
  final String name;
  final Experience experienceType;
  final String description;

  const Place({
    required this.id,
    required this.districtId,
    required this.name,
    required this.experienceType,
    this.description = '',
  });

  Map<String, dynamic> toMap() => {
        'districtId': districtId,
        'name': name,
        'experienceType': experienceType.name,
        'description': description,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory Place.fromMap(String id, Map<String, dynamic> m) => Place(
        id: id,
        districtId: m['districtId']?.toString() ?? '',
        name: m['name']?.toString() ?? '',
        experienceType:
            Experience.fromName(m['experienceType']?.toString()) ??
                Experience.nature,
        description: m['description']?.toString() ?? '',
      );
}

// ---------------------------------------------------------------------------
// User data (private, users/{uid}/...)
// ---------------------------------------------------------------------------

class TravelHabits {
  final String? frequency; // rarely / sometimes / frequently
  final String? style; // relaxed / balanced / packed
  final List<String> companions; // family / friends / solo / others

  const TravelHabits({this.frequency, this.style, this.companions = const []});

  bool get isComplete =>
      frequency != null && style != null && companions.isNotEmpty;

  Map<String, dynamic> toMap() =>
      {'frequency': frequency, 'style': style, 'companions': companions};

  factory TravelHabits.fromMap(Map<String, dynamic>? m) => m == null
      ? const TravelHabits()
      : TravelHabits(
          frequency: m['frequency']?.toString(),
          style: m['style']?.toString(),
          companions: _strings(m['companions']),
        );

  TravelHabits copyWith(
          {String? frequency, String? style, List<String>? companions}) =>
      TravelHabits(
        frequency: frequency ?? this.frequency,
        style: style ?? this.style,
        companions: companions ?? this.companions,
      );
}

class PlanningPrefs {
  final int? budget; // 1..3, matches CostLevel
  final String? distance; // near / medium / far
  final Season? season;
  final String? startDistrictId;

  const PlanningPrefs(
      {this.budget, this.distance, this.season, this.startDistrictId});

  bool get isComplete =>
      budget != null &&
      distance != null &&
      season != null &&
      startDistrictId != null;

  Map<String, dynamic> toMap() => {
        'budget': budget,
        'distance': distance,
        'season': season?.name,
        'startDistrictId': startDistrictId,
      };

  factory PlanningPrefs.fromMap(Map<String, dynamic>? m) => m == null
      ? const PlanningPrefs()
      : PlanningPrefs(
          budget: (m['budget'] as num?)?.toInt(),
          distance: m['distance']?.toString(),
          season: Season.fromName(m['season']?.toString()),
          startDistrictId: m['startDistrictId']?.toString(),
        );

  PlanningPrefs copyWith({
    int? budget,
    String? distance,
    Season? season,
    String? startDistrictId,
  }) =>
      PlanningPrefs(
        budget: budget ?? this.budget,
        distance: distance ?? this.distance,
        season: season ?? this.season,
        startDistrictId: startDistrictId ?? this.startDistrictId,
      );
}

class EmergencyContact {
  final String name;
  final String phone;
  const EmergencyContact(this.name, this.phone);
  Map<String, dynamic> toMap() => {'name': name, 'phone': phone};
  static EmergencyContact? fromMap(Map<String, dynamic>? m) {
    if (m == null || (m['phone']?.toString() ?? '').isEmpty) return null;
    return EmergencyContact(
        m['name']?.toString() ?? '', m['phone']?.toString() ?? '');
  }
}

class UserProfile {
  final String uid;
  final String name;
  final String email;
  final String role; // traveller / admin
  final String? ageRange;
  final String? occupation;
  final DateTime? policyAcceptedAt;
  final List<Experience> interests;
  final TravelHabits habits;
  final PlanningPrefs planning;
  final bool gamificationOn;
  final bool onboardingComplete;
  final EmergencyContact? emergencyContact;
  final List<String> dismissedChallenges;
  final List<String> acceptedChallenges;

  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    this.role = 'traveller',
    this.ageRange,
    this.occupation,
    this.policyAcceptedAt,
    this.interests = const [],
    this.habits = const TravelHabits(),
    this.planning = const PlanningPrefs(),
    this.gamificationOn = true,
    this.onboardingComplete = false,
    this.emergencyContact,
    this.dismissedChallenges = const [],
    this.acceptedChallenges = const [],
  });

  bool get isAdmin => role == 'admin';

  /// Display name shown with public reviews (US-1.5): first name + initial.
  String get displayName {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'Traveller';
    if (parts.length == 1) return parts.first;
    return '${parts.first} ${parts.last[0]}.';
  }

  factory UserProfile.fromMap(String uid, Map<String, dynamic> m) =>
      UserProfile(
        uid: uid,
        name: m['name']?.toString() ?? '',
        email: m['email']?.toString() ?? '',
        role: m['role']?.toString() ?? 'traveller',
        ageRange: m['ageRange']?.toString(),
        occupation: m['occupation']?.toString(),
        policyAcceptedAt: _date(m['policyAcceptedAt']),
        interests: Experience.listFrom(m['interests']),
        habits: TravelHabits.fromMap(
            (m['habits'] as Map?)?.cast<String, dynamic>()),
        planning: PlanningPrefs.fromMap(
            (m['planning'] as Map?)?.cast<String, dynamic>()),
        gamificationOn: m['gamificationOn'] != false,
        onboardingComplete: m['onboardingComplete'] == true,
        emergencyContact: EmergencyContact.fromMap(
            (m['emergencyContact'] as Map?)?.cast<String, dynamic>()),
        dismissedChallenges: _strings(m['dismissedChallenges']),
        acceptedChallenges: _strings(m['acceptedChallenges']),
      );
}

class VisitPlace {
  final String name;
  final String? placeId;
  final List<Experience> activities;
  const VisitPlace({required this.name, this.placeId, this.activities = const []});

  Map<String, dynamic> toMap() => {
        'name': name,
        'placeId': placeId,
        'activities': activities.map((e) => e.name).toList(),
      };

  factory VisitPlace.fromMap(Map<String, dynamic> m) => VisitPlace(
        name: m['name']?.toString() ?? '',
        placeId: m['placeId']?.toString(),
        activities: Experience.listFrom(m['activities']),
      );
}

/// One visit record per district: users/{uid}/visits/{districtId}.
class Visit {
  final String districtId;
  final DateTime? date; // null = "before MyYatra"
  final List<VisitPlace> places;
  final DateTime? createdAt;

  const Visit({
    required this.districtId,
    this.date,
    this.places = const [],
    this.createdAt,
  });

  /// All activity types recorded across the places of this visit.
  List<Experience> get activities =>
      places.expand((p) => p.activities).toSet().toList();

  Map<String, dynamic> toMap() => {
        'districtId': districtId,
        'date': ts(date),
        'places': places.map((p) => p.toMap()).toList(),
        'activities': activities.map((e) => e.name).toList(),
        'createdAt': ts(createdAt) ?? FieldValue.serverTimestamp(),
      };

  factory Visit.fromMap(String id, Map<String, dynamic> m) => Visit(
        districtId: m['districtId']?.toString() ?? id,
        date: _date(m['date']),
        places: (m['places'] is List)
            ? (m['places'] as List)
                .whereType<Map>()
                .map((p) => VisitPlace.fromMap(Map<String, dynamic>.from(p)))
                .toList()
            : const [],
        createdAt: _date(m['createdAt']),
      );

  Visit copyWith({DateTime? date, List<VisitPlace>? places, bool clearDate = false}) => Visit(
        districtId: districtId,
        date: clearDate ? null : (date ?? this.date),
        places: places ?? this.places,
        createdAt: createdAt,
      );
}

class JournalEntry {
  final String id;
  final String districtId;
  final DateTime startDate;
  final DateTime? endDate;
  final List<Experience> activities;
  final String story;
  final List<String> photoUrls;
  final List<String> photoPaths; // storage paths, for deletion
  final bool draft;
  final DateTime? updatedAt;

  const JournalEntry({
    required this.id,
    required this.districtId,
    required this.startDate,
    this.endDate,
    this.activities = const [],
    this.story = '',
    this.photoUrls = const [],
    this.photoPaths = const [],
    this.draft = false,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'districtId': districtId,
        'startDate': ts(startDate),
        'endDate': ts(endDate),
        'activities': activities.map((e) => e.name).toList(),
        'story': story,
        'photoUrls': photoUrls,
        'photoPaths': photoPaths,
        'draft': draft,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory JournalEntry.fromMap(String id, Map<String, dynamic> m) =>
      JournalEntry(
        id: id,
        districtId: m['districtId']?.toString() ?? '',
        startDate: _date(m['startDate']) ?? DateTime.now(),
        endDate: _date(m['endDate']),
        activities: Experience.listFrom(m['activities']),
        story: m['story']?.toString() ?? '',
        photoUrls: _strings(m['photoUrls']),
        photoPaths: _strings(m['photoPaths']),
        draft: m['draft'] == true,
        updatedAt: _date(m['updatedAt']),
      );
}

class Review {
  final String id;
  final String districtId;
  final String uid;
  final String displayName;
  final int rating;
  final String text;
  final DateTime? createdAt;

  const Review({
    required this.id,
    required this.districtId,
    required this.uid,
    required this.displayName,
    required this.rating,
    required this.text,
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'districtId': districtId,
        'uid': uid,
        'displayName': displayName,
        'rating': rating,
        'text': text,
        'createdAt': ts(createdAt) ?? FieldValue.serverTimestamp(),
      };

  factory Review.fromMap(String id, Map<String, dynamic> m) => Review(
        id: id,
        districtId: m['districtId']?.toString() ?? '',
        uid: m['uid']?.toString() ?? '',
        displayName: m['displayName']?.toString() ?? 'Traveller',
        rating: (m['rating'] as num?)?.toInt() ?? 0,
        text: m['text']?.toString() ?? '',
        createdAt: _date(m['createdAt']),
      );
}

class SafetyAlert {
  final String id;
  final String districtId;
  final String message;
  final DateTime expiresAt;
  final DateTime? createdAt;
  final String createdBy;

  const SafetyAlert({
    required this.id,
    required this.districtId,
    required this.message,
    required this.expiresAt,
    this.createdAt,
    this.createdBy = '',
  });

  bool isActive([DateTime? now]) =>
      expiresAt.isAfter(now ?? DateTime.now());

  Map<String, dynamic> toMap() => {
        'districtId': districtId,
        'message': message,
        'expiresAt': ts(expiresAt),
        'createdAt': ts(createdAt) ?? FieldValue.serverTimestamp(),
        'createdBy': createdBy,
      };

  factory SafetyAlert.fromMap(String id, Map<String, dynamic> m) =>
      SafetyAlert(
        id: id,
        districtId: m['districtId']?.toString() ?? '',
        message: m['message']?.toString() ?? '',
        expiresAt: _date(m['expiresAt']) ?? DateTime.now(),
        createdAt: _date(m['createdAt']),
        createdBy: m['createdBy']?.toString() ?? '',
      );
}

class FeedbackItem {
  final String id;
  final String type; // app / recommendation / district_info
  final String uid;
  final int? rating;
  final String category;
  final String text;
  final String status; // new / reviewed / resolved
  final String? districtId;
  final String? dnaType;
  final DateTime? createdAt;

  /// Every status change, oldest first (US-15.5).
  final List<FeedbackStatusChange> history;

  const FeedbackItem({
    required this.id,
    required this.type,
    required this.uid,
    this.rating,
    required this.category,
    required this.text,
    this.status = 'new',
    this.districtId,
    this.dnaType,
    this.createdAt,
    this.history = const [],
  });

  Map<String, dynamic> toMap() => {
        'type': type,
        'uid': uid,
        'rating': rating,
        'category': category,
        'text': text,
        'status': status,
        'districtId': districtId,
        'dnaType': dnaType,
        'createdAt': ts(createdAt) ?? FieldValue.serverTimestamp(),
      };

  factory FeedbackItem.fromMap(String id, Map<String, dynamic> m) =>
      FeedbackItem(
        id: id,
        type: m['type']?.toString() ?? 'app',
        uid: m['uid']?.toString() ?? '',
        rating: (m['rating'] as num?)?.toInt(),
        category: m['category']?.toString() ?? '',
        text: m['text']?.toString() ?? '',
        status: m['status']?.toString() ?? 'new',
        districtId: m['districtId']?.toString(),
        dnaType: m['dnaType']?.toString(),
        createdAt: _date(m['createdAt']),
        history: [
          for (final h in (m['statusHistory'] as List?) ?? const [])
            if (h is Map) FeedbackStatusChange.fromMap(Map<String, dynamic>.from(h))
        ],
      );
}

class FeedbackStatusChange {
  final String from;
  final String to;
  final String adminName;
  final DateTime? at;

  const FeedbackStatusChange(
      {required this.from, required this.to, required this.adminName, this.at});

  factory FeedbackStatusChange.fromMap(Map<String, dynamic> m) => FeedbackStatusChange(
        from: m['from']?.toString() ?? '',
        to: m['to']?.toString() ?? '',
        adminName: m['adminName']?.toString() ?? '',
        at: _date(m['at']),
      );
}

class ChangeLogEntry {
  final String id;
  final String entity; // district / place / alert / review
  final String entityId;
  final String field;
  final String oldValue;
  final String newValue;
  final String adminUid;
  final String adminName;
  final DateTime? at;

  const ChangeLogEntry({
    required this.id,
    required this.entity,
    required this.entityId,
    required this.field,
    required this.oldValue,
    required this.newValue,
    required this.adminUid,
    required this.adminName,
    this.at,
  });

  factory ChangeLogEntry.fromMap(String id, Map<String, dynamic> m) =>
      ChangeLogEntry(
        id: id,
        entity: m['entity']?.toString() ?? '',
        entityId: m['entityId']?.toString() ?? '',
        field: m['field']?.toString() ?? '',
        oldValue: m['oldValue']?.toString() ?? '',
        newValue: m['newValue']?.toString() ?? '',
        adminUid: m['adminUid']?.toString() ?? '',
        adminName: m['adminName']?.toString() ?? '',
        at: _date(m['at']),
      );
}

class ItineraryDay {
  final List<String> activities;
  const ItineraryDay(this.activities);
  Map<String, dynamic> toMap() => {'activities': activities};
  factory ItineraryDay.fromMap(Map<String, dynamic> m) =>
      ItineraryDay(_strings(m['activities']));
}

class Itinerary {
  final String id;
  final String districtId;
  final DateTime startDate;
  final DateTime endDate;
  final List<String> companions;
  final int budget; // NPR total
  final List<ItineraryDay> days;
  final DateTime? updatedAt;

  const Itinerary({
    required this.id,
    required this.districtId,
    required this.startDate,
    required this.endDate,
    this.companions = const [],
    this.budget = 0,
    this.days = const [],
    this.updatedAt,
  });

  int get dayCount => endDate.difference(startDate).inDays + 1;

  Map<String, dynamic> toMap() => {
        'districtId': districtId,
        'startDate': ts(startDate),
        'endDate': ts(endDate),
        'companions': companions,
        'budget': budget,
        'days': days.map((d) => d.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'districtId': districtId,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'companions': companions,
        'budget': budget,
        'days': days.map((d) => d.toMap()).toList(),
      };

  factory Itinerary.fromMap(String id, Map<String, dynamic> m) => Itinerary(
        id: id,
        districtId: m['districtId']?.toString() ?? '',
        startDate: _date(m['startDate']) ?? DateTime.now(),
        endDate: _date(m['endDate']) ?? DateTime.now(),
        companions: _strings(m['companions']),
        budget: (m['budget'] as num?)?.toInt() ?? 0,
        days: (m['days'] is List)
            ? (m['days'] as List)
                .whereType<Map>()
                .map((d) => ItineraryDay.fromMap(Map<String, dynamic>.from(d)))
                .toList()
            : const [],
        updatedAt: _date(m['updatedAt']),
      );
}
