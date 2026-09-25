// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ProfilesTable extends Profiles with TableInfo<$ProfilesTable, Profile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _sexMeta = const VerificationMeta('sex');
  @override
  late final GeneratedColumn<int> sex = GeneratedColumn<int>(
    'sex',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _birthDateMeta = const VerificationMeta(
    'birthDate',
  );
  @override
  late final GeneratedColumn<DateTime> birthDate = GeneratedColumn<DateTime>(
    'birth_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _heightCmMeta = const VerificationMeta(
    'heightCm',
  );
  @override
  late final GeneratedColumn<double> heightCm = GeneratedColumn<double>(
    'height_cm',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activityLevelMeta = const VerificationMeta(
    'activityLevel',
  );
  @override
  late final GeneratedColumn<int> activityLevel = GeneratedColumn<int>(
    'activity_level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _goalWeightKgMeta = const VerificationMeta(
    'goalWeightKg',
  );
  @override
  late final GeneratedColumn<double> goalWeightKg = GeneratedColumn<double>(
    'goal_weight_kg',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weeklyRatePctMeta = const VerificationMeta(
    'weeklyRatePct',
  );
  @override
  late final GeneratedColumn<double> weeklyRatePct = GeneratedColumn<double>(
    'weekly_rate_pct',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.5),
  );
  static const VerificationMeta _proteinPerKgMeta = const VerificationMeta(
    'proteinPerKg',
  );
  @override
  late final GeneratedColumn<double> proteinPerKg = GeneratedColumn<double>(
    'protein_per_kg',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(2.0),
  );
  static const VerificationMeta _checkInWeekdayMeta = const VerificationMeta(
    'checkInWeekday',
  );
  @override
  late final GeneratedColumn<int> checkInWeekday = GeneratedColumn<int>(
    'check_in_weekday',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(7),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sex,
    birthDate,
    heightCm,
    activityLevel,
    goalWeightKg,
    weeklyRatePct,
    proteinPerKg,
    checkInWeekday,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<Profile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('sex')) {
      context.handle(
        _sexMeta,
        sex.isAcceptableOrUnknown(data['sex']!, _sexMeta),
      );
    } else if (isInserting) {
      context.missing(_sexMeta);
    }
    if (data.containsKey('birth_date')) {
      context.handle(
        _birthDateMeta,
        birthDate.isAcceptableOrUnknown(data['birth_date']!, _birthDateMeta),
      );
    } else if (isInserting) {
      context.missing(_birthDateMeta);
    }
    if (data.containsKey('height_cm')) {
      context.handle(
        _heightCmMeta,
        heightCm.isAcceptableOrUnknown(data['height_cm']!, _heightCmMeta),
      );
    } else if (isInserting) {
      context.missing(_heightCmMeta);
    }
    if (data.containsKey('activity_level')) {
      context.handle(
        _activityLevelMeta,
        activityLevel.isAcceptableOrUnknown(
          data['activity_level']!,
          _activityLevelMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_activityLevelMeta);
    }
    if (data.containsKey('goal_weight_kg')) {
      context.handle(
        _goalWeightKgMeta,
        goalWeightKg.isAcceptableOrUnknown(
          data['goal_weight_kg']!,
          _goalWeightKgMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_goalWeightKgMeta);
    }
    if (data.containsKey('weekly_rate_pct')) {
      context.handle(
        _weeklyRatePctMeta,
        weeklyRatePct.isAcceptableOrUnknown(
          data['weekly_rate_pct']!,
          _weeklyRatePctMeta,
        ),
      );
    }
    if (data.containsKey('protein_per_kg')) {
      context.handle(
        _proteinPerKgMeta,
        proteinPerKg.isAcceptableOrUnknown(
          data['protein_per_kg']!,
          _proteinPerKgMeta,
        ),
      );
    }
    if (data.containsKey('check_in_weekday')) {
      context.handle(
        _checkInWeekdayMeta,
        checkInWeekday.isAcceptableOrUnknown(
          data['check_in_weekday']!,
          _checkInWeekdayMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Profile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Profile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sex'],
      )!,
      birthDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}birth_date'],
      )!,
      heightCm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}height_cm'],
      )!,
      activityLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}activity_level'],
      )!,
      goalWeightKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}goal_weight_kg'],
      )!,
      weeklyRatePct: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weekly_rate_pct'],
      )!,
      proteinPerKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}protein_per_kg'],
      )!,
      checkInWeekday: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}check_in_weekday'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ProfilesTable createAlias(String alias) {
    return $ProfilesTable(attachedDatabase, alias);
  }
}

class Profile extends DataClass implements Insertable<Profile> {
  final int id;
  final int sex;
  final DateTime birthDate;
  final double heightCm;
  final int activityLevel;
  final double goalWeightKg;

  /// Desired loss per week as % of body weight (e.g. 0.5).
  final double weeklyRatePct;

  /// Protein grams per kg of reference body weight.
  final double proteinPerKg;

  /// DateTime.weekday of the weekly check-in (7 = Sunday).
  final int checkInWeekday;
  final DateTime updatedAt;
  const Profile({
    required this.id,
    required this.sex,
    required this.birthDate,
    required this.heightCm,
    required this.activityLevel,
    required this.goalWeightKg,
    required this.weeklyRatePct,
    required this.proteinPerKg,
    required this.checkInWeekday,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['sex'] = Variable<int>(sex);
    map['birth_date'] = Variable<DateTime>(birthDate);
    map['height_cm'] = Variable<double>(heightCm);
    map['activity_level'] = Variable<int>(activityLevel);
    map['goal_weight_kg'] = Variable<double>(goalWeightKg);
    map['weekly_rate_pct'] = Variable<double>(weeklyRatePct);
    map['protein_per_kg'] = Variable<double>(proteinPerKg);
    map['check_in_weekday'] = Variable<int>(checkInWeekday);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ProfilesCompanion toCompanion(bool nullToAbsent) {
    return ProfilesCompanion(
      id: Value(id),
      sex: Value(sex),
      birthDate: Value(birthDate),
      heightCm: Value(heightCm),
      activityLevel: Value(activityLevel),
      goalWeightKg: Value(goalWeightKg),
      weeklyRatePct: Value(weeklyRatePct),
      proteinPerKg: Value(proteinPerKg),
      checkInWeekday: Value(checkInWeekday),
      updatedAt: Value(updatedAt),
    );
  }

  factory Profile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Profile(
      id: serializer.fromJson<int>(json['id']),
      sex: serializer.fromJson<int>(json['sex']),
      birthDate: serializer.fromJson<DateTime>(json['birthDate']),
      heightCm: serializer.fromJson<double>(json['heightCm']),
      activityLevel: serializer.fromJson<int>(json['activityLevel']),
      goalWeightKg: serializer.fromJson<double>(json['goalWeightKg']),
      weeklyRatePct: serializer.fromJson<double>(json['weeklyRatePct']),
      proteinPerKg: serializer.fromJson<double>(json['proteinPerKg']),
      checkInWeekday: serializer.fromJson<int>(json['checkInWeekday']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sex': serializer.toJson<int>(sex),
      'birthDate': serializer.toJson<DateTime>(birthDate),
      'heightCm': serializer.toJson<double>(heightCm),
      'activityLevel': serializer.toJson<int>(activityLevel),
      'goalWeightKg': serializer.toJson<double>(goalWeightKg),
      'weeklyRatePct': serializer.toJson<double>(weeklyRatePct),
      'proteinPerKg': serializer.toJson<double>(proteinPerKg),
      'checkInWeekday': serializer.toJson<int>(checkInWeekday),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Profile copyWith({
    int? id,
    int? sex,
    DateTime? birthDate,
    double? heightCm,
    int? activityLevel,
    double? goalWeightKg,
    double? weeklyRatePct,
    double? proteinPerKg,
    int? checkInWeekday,
    DateTime? updatedAt,
  }) => Profile(
    id: id ?? this.id,
    sex: sex ?? this.sex,
    birthDate: birthDate ?? this.birthDate,
    heightCm: heightCm ?? this.heightCm,
    activityLevel: activityLevel ?? this.activityLevel,
    goalWeightKg: goalWeightKg ?? this.goalWeightKg,
    weeklyRatePct: weeklyRatePct ?? this.weeklyRatePct,
    proteinPerKg: proteinPerKg ?? this.proteinPerKg,
    checkInWeekday: checkInWeekday ?? this.checkInWeekday,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Profile copyWithCompanion(ProfilesCompanion data) {
    return Profile(
      id: data.id.present ? data.id.value : this.id,
      sex: data.sex.present ? data.sex.value : this.sex,
      birthDate: data.birthDate.present ? data.birthDate.value : this.birthDate,
      heightCm: data.heightCm.present ? data.heightCm.value : this.heightCm,
      activityLevel: data.activityLevel.present
          ? data.activityLevel.value
          : this.activityLevel,
      goalWeightKg: data.goalWeightKg.present
          ? data.goalWeightKg.value
          : this.goalWeightKg,
      weeklyRatePct: data.weeklyRatePct.present
          ? data.weeklyRatePct.value
          : this.weeklyRatePct,
      proteinPerKg: data.proteinPerKg.present
          ? data.proteinPerKg.value
          : this.proteinPerKg,
      checkInWeekday: data.checkInWeekday.present
          ? data.checkInWeekday.value
          : this.checkInWeekday,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Profile(')
          ..write('id: $id, ')
          ..write('sex: $sex, ')
          ..write('birthDate: $birthDate, ')
          ..write('heightCm: $heightCm, ')
          ..write('activityLevel: $activityLevel, ')
          ..write('goalWeightKg: $goalWeightKg, ')
          ..write('weeklyRatePct: $weeklyRatePct, ')
          ..write('proteinPerKg: $proteinPerKg, ')
          ..write('checkInWeekday: $checkInWeekday, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sex,
    birthDate,
    heightCm,
    activityLevel,
    goalWeightKg,
    weeklyRatePct,
    proteinPerKg,
    checkInWeekday,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Profile &&
          other.id == this.id &&
          other.sex == this.sex &&
          other.birthDate == this.birthDate &&
          other.heightCm == this.heightCm &&
          other.activityLevel == this.activityLevel &&
          other.goalWeightKg == this.goalWeightKg &&
          other.weeklyRatePct == this.weeklyRatePct &&
          other.proteinPerKg == this.proteinPerKg &&
          other.checkInWeekday == this.checkInWeekday &&
          other.updatedAt == this.updatedAt);
}

class ProfilesCompanion extends UpdateCompanion<Profile> {
  final Value<int> id;
  final Value<int> sex;
  final Value<DateTime> birthDate;
  final Value<double> heightCm;
  final Value<int> activityLevel;
  final Value<double> goalWeightKg;
  final Value<double> weeklyRatePct;
  final Value<double> proteinPerKg;
  final Value<int> checkInWeekday;
  final Value<DateTime> updatedAt;
  const ProfilesCompanion({
    this.id = const Value.absent(),
    this.sex = const Value.absent(),
    this.birthDate = const Value.absent(),
    this.heightCm = const Value.absent(),
    this.activityLevel = const Value.absent(),
    this.goalWeightKg = const Value.absent(),
    this.weeklyRatePct = const Value.absent(),
    this.proteinPerKg = const Value.absent(),
    this.checkInWeekday = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ProfilesCompanion.insert({
    this.id = const Value.absent(),
    required int sex,
    required DateTime birthDate,
    required double heightCm,
    required int activityLevel,
    required double goalWeightKg,
    this.weeklyRatePct = const Value.absent(),
    this.proteinPerKg = const Value.absent(),
    this.checkInWeekday = const Value.absent(),
    required DateTime updatedAt,
  }) : sex = Value(sex),
       birthDate = Value(birthDate),
       heightCm = Value(heightCm),
       activityLevel = Value(activityLevel),
       goalWeightKg = Value(goalWeightKg),
       updatedAt = Value(updatedAt);
  static Insertable<Profile> custom({
    Expression<int>? id,
    Expression<int>? sex,
    Expression<DateTime>? birthDate,
    Expression<double>? heightCm,
    Expression<int>? activityLevel,
    Expression<double>? goalWeightKg,
    Expression<double>? weeklyRatePct,
    Expression<double>? proteinPerKg,
    Expression<int>? checkInWeekday,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sex != null) 'sex': sex,
      if (birthDate != null) 'birth_date': birthDate,
      if (heightCm != null) 'height_cm': heightCm,
      if (activityLevel != null) 'activity_level': activityLevel,
      if (goalWeightKg != null) 'goal_weight_kg': goalWeightKg,
      if (weeklyRatePct != null) 'weekly_rate_pct': weeklyRatePct,
      if (proteinPerKg != null) 'protein_per_kg': proteinPerKg,
      if (checkInWeekday != null) 'check_in_weekday': checkInWeekday,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ProfilesCompanion copyWith({
    Value<int>? id,
    Value<int>? sex,
    Value<DateTime>? birthDate,
    Value<double>? heightCm,
    Value<int>? activityLevel,
    Value<double>? goalWeightKg,
    Value<double>? weeklyRatePct,
    Value<double>? proteinPerKg,
    Value<int>? checkInWeekday,
    Value<DateTime>? updatedAt,
  }) {
    return ProfilesCompanion(
      id: id ?? this.id,
      sex: sex ?? this.sex,
      birthDate: birthDate ?? this.birthDate,
      heightCm: heightCm ?? this.heightCm,
      activityLevel: activityLevel ?? this.activityLevel,
      goalWeightKg: goalWeightKg ?? this.goalWeightKg,
      weeklyRatePct: weeklyRatePct ?? this.weeklyRatePct,
      proteinPerKg: proteinPerKg ?? this.proteinPerKg,
      checkInWeekday: checkInWeekday ?? this.checkInWeekday,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sex.present) {
      map['sex'] = Variable<int>(sex.value);
    }
    if (birthDate.present) {
      map['birth_date'] = Variable<DateTime>(birthDate.value);
    }
    if (heightCm.present) {
      map['height_cm'] = Variable<double>(heightCm.value);
    }
    if (activityLevel.present) {
      map['activity_level'] = Variable<int>(activityLevel.value);
    }
    if (goalWeightKg.present) {
      map['goal_weight_kg'] = Variable<double>(goalWeightKg.value);
    }
    if (weeklyRatePct.present) {
      map['weekly_rate_pct'] = Variable<double>(weeklyRatePct.value);
    }
    if (proteinPerKg.present) {
      map['protein_per_kg'] = Variable<double>(proteinPerKg.value);
    }
    if (checkInWeekday.present) {
      map['check_in_weekday'] = Variable<int>(checkInWeekday.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProfilesCompanion(')
          ..write('id: $id, ')
          ..write('sex: $sex, ')
          ..write('birthDate: $birthDate, ')
          ..write('heightCm: $heightCm, ')
          ..write('activityLevel: $activityLevel, ')
          ..write('goalWeightKg: $goalWeightKg, ')
          ..write('weeklyRatePct: $weeklyRatePct, ')
          ..write('proteinPerKg: $proteinPerKg, ')
          ..write('checkInWeekday: $checkInWeekday, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $FoodsTable extends Foods with TableInfo<$FoodsTable, Food> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FoodsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _externalIdMeta = const VerificationMeta(
    'externalId',
  );
  @override
  late final GeneratedColumn<String> externalId = GeneratedColumn<String>(
    'external_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _barcodeMeta = const VerificationMeta(
    'barcode',
  );
  @override
  late final GeneratedColumn<String> barcode = GeneratedColumn<String>(
    'barcode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _brandMeta = const VerificationMeta('brand');
  @override
  late final GeneratedColumn<String> brand = GeneratedColumn<String>(
    'brand',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kcalPer100gMeta = const VerificationMeta(
    'kcalPer100g',
  );
  @override
  late final GeneratedColumn<double> kcalPer100g = GeneratedColumn<double>(
    'kcal_per100g',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _proteinPer100gMeta = const VerificationMeta(
    'proteinPer100g',
  );
  @override
  late final GeneratedColumn<double> proteinPer100g = GeneratedColumn<double>(
    'protein_per100g',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fatPer100gMeta = const VerificationMeta(
    'fatPer100g',
  );
  @override
  late final GeneratedColumn<double> fatPer100g = GeneratedColumn<double>(
    'fat_per100g',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _carbsPer100gMeta = const VerificationMeta(
    'carbsPer100g',
  );
  @override
  late final GeneratedColumn<double> carbsPer100g = GeneratedColumn<double>(
    'carbs_per100g',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _servingNameMeta = const VerificationMeta(
    'servingName',
  );
  @override
  late final GeneratedColumn<String> servingName = GeneratedColumn<String>(
    'serving_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _servingGramsMeta = const VerificationMeta(
    'servingGrams',
  );
  @override
  late final GeneratedColumn<double> servingGrams = GeneratedColumn<double>(
    'serving_grams',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isFavoriteMeta = const VerificationMeta(
    'isFavorite',
  );
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
    'is_favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastUsedAtMeta = const VerificationMeta(
    'lastUsedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastUsedAt = GeneratedColumn<DateTime>(
    'last_used_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    source,
    externalId,
    barcode,
    name,
    brand,
    kcalPer100g,
    proteinPer100g,
    fatPer100g,
    carbsPer100g,
    servingName,
    servingGrams,
    isFavorite,
    lastUsedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'foods';
  @override
  VerificationContext validateIntegrity(
    Insertable<Food> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('external_id')) {
      context.handle(
        _externalIdMeta,
        externalId.isAcceptableOrUnknown(data['external_id']!, _externalIdMeta),
      );
    }
    if (data.containsKey('barcode')) {
      context.handle(
        _barcodeMeta,
        barcode.isAcceptableOrUnknown(data['barcode']!, _barcodeMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('brand')) {
      context.handle(
        _brandMeta,
        brand.isAcceptableOrUnknown(data['brand']!, _brandMeta),
      );
    }
    if (data.containsKey('kcal_per100g')) {
      context.handle(
        _kcalPer100gMeta,
        kcalPer100g.isAcceptableOrUnknown(
          data['kcal_per100g']!,
          _kcalPer100gMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_kcalPer100gMeta);
    }
    if (data.containsKey('protein_per100g')) {
      context.handle(
        _proteinPer100gMeta,
        proteinPer100g.isAcceptableOrUnknown(
          data['protein_per100g']!,
          _proteinPer100gMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_proteinPer100gMeta);
    }
    if (data.containsKey('fat_per100g')) {
      context.handle(
        _fatPer100gMeta,
        fatPer100g.isAcceptableOrUnknown(data['fat_per100g']!, _fatPer100gMeta),
      );
    } else if (isInserting) {
      context.missing(_fatPer100gMeta);
    }
    if (data.containsKey('carbs_per100g')) {
      context.handle(
        _carbsPer100gMeta,
        carbsPer100g.isAcceptableOrUnknown(
          data['carbs_per100g']!,
          _carbsPer100gMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_carbsPer100gMeta);
    }
    if (data.containsKey('serving_name')) {
      context.handle(
        _servingNameMeta,
        servingName.isAcceptableOrUnknown(
          data['serving_name']!,
          _servingNameMeta,
        ),
      );
    }
    if (data.containsKey('serving_grams')) {
      context.handle(
        _servingGramsMeta,
        servingGrams.isAcceptableOrUnknown(
          data['serving_grams']!,
          _servingGramsMeta,
        ),
      );
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
        _isFavoriteMeta,
        isFavorite.isAcceptableOrUnknown(data['is_favorite']!, _isFavoriteMeta),
      );
    }
    if (data.containsKey('last_used_at')) {
      context.handle(
        _lastUsedAtMeta,
        lastUsedAt.isAcceptableOrUnknown(
          data['last_used_at']!,
          _lastUsedAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {source, externalId},
  ];
  @override
  Food map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Food(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      externalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}external_id'],
      ),
      barcode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}barcode'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      brand: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}brand'],
      ),
      kcalPer100g: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}kcal_per100g'],
      )!,
      proteinPer100g: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}protein_per100g'],
      )!,
      fatPer100g: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fat_per100g'],
      )!,
      carbsPer100g: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}carbs_per100g'],
      )!,
      servingName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}serving_name'],
      ),
      servingGrams: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}serving_grams'],
      ),
      isFavorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_favorite'],
      )!,
      lastUsedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_used_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $FoodsTable createAlias(String alias) {
    return $FoodsTable(attachedDatabase, alias);
  }
}

class Food extends DataClass implements Insertable<Food> {
  final int id;

  /// 'off', 'usda' or 'custom'.
  final String source;

  /// Barcode (off), fdcId (usda), null for custom.
  final String? externalId;

  /// Barcode for custom foods entered from a label (so a later scan finds it).
  final String? barcode;
  final String name;
  final String? brand;
  final double kcalPer100g;
  final double proteinPer100g;
  final double fatPer100g;
  final double carbsPer100g;

  /// Optional default serving, e.g. "1 slice" = 30 g.
  final String? servingName;
  final double? servingGrams;
  final bool isFavorite;
  final DateTime? lastUsedAt;
  final DateTime createdAt;
  const Food({
    required this.id,
    required this.source,
    this.externalId,
    this.barcode,
    required this.name,
    this.brand,
    required this.kcalPer100g,
    required this.proteinPer100g,
    required this.fatPer100g,
    required this.carbsPer100g,
    this.servingName,
    this.servingGrams,
    required this.isFavorite,
    this.lastUsedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || externalId != null) {
      map['external_id'] = Variable<String>(externalId);
    }
    if (!nullToAbsent || barcode != null) {
      map['barcode'] = Variable<String>(barcode);
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || brand != null) {
      map['brand'] = Variable<String>(brand);
    }
    map['kcal_per100g'] = Variable<double>(kcalPer100g);
    map['protein_per100g'] = Variable<double>(proteinPer100g);
    map['fat_per100g'] = Variable<double>(fatPer100g);
    map['carbs_per100g'] = Variable<double>(carbsPer100g);
    if (!nullToAbsent || servingName != null) {
      map['serving_name'] = Variable<String>(servingName);
    }
    if (!nullToAbsent || servingGrams != null) {
      map['serving_grams'] = Variable<double>(servingGrams);
    }
    map['is_favorite'] = Variable<bool>(isFavorite);
    if (!nullToAbsent || lastUsedAt != null) {
      map['last_used_at'] = Variable<DateTime>(lastUsedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  FoodsCompanion toCompanion(bool nullToAbsent) {
    return FoodsCompanion(
      id: Value(id),
      source: Value(source),
      externalId: externalId == null && nullToAbsent
          ? const Value.absent()
          : Value(externalId),
      barcode: barcode == null && nullToAbsent
          ? const Value.absent()
          : Value(barcode),
      name: Value(name),
      brand: brand == null && nullToAbsent
          ? const Value.absent()
          : Value(brand),
      kcalPer100g: Value(kcalPer100g),
      proteinPer100g: Value(proteinPer100g),
      fatPer100g: Value(fatPer100g),
      carbsPer100g: Value(carbsPer100g),
      servingName: servingName == null && nullToAbsent
          ? const Value.absent()
          : Value(servingName),
      servingGrams: servingGrams == null && nullToAbsent
          ? const Value.absent()
          : Value(servingGrams),
      isFavorite: Value(isFavorite),
      lastUsedAt: lastUsedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastUsedAt),
      createdAt: Value(createdAt),
    );
  }

  factory Food.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Food(
      id: serializer.fromJson<int>(json['id']),
      source: serializer.fromJson<String>(json['source']),
      externalId: serializer.fromJson<String?>(json['externalId']),
      barcode: serializer.fromJson<String?>(json['barcode']),
      name: serializer.fromJson<String>(json['name']),
      brand: serializer.fromJson<String?>(json['brand']),
      kcalPer100g: serializer.fromJson<double>(json['kcalPer100g']),
      proteinPer100g: serializer.fromJson<double>(json['proteinPer100g']),
      fatPer100g: serializer.fromJson<double>(json['fatPer100g']),
      carbsPer100g: serializer.fromJson<double>(json['carbsPer100g']),
      servingName: serializer.fromJson<String?>(json['servingName']),
      servingGrams: serializer.fromJson<double?>(json['servingGrams']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      lastUsedAt: serializer.fromJson<DateTime?>(json['lastUsedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'source': serializer.toJson<String>(source),
      'externalId': serializer.toJson<String?>(externalId),
      'barcode': serializer.toJson<String?>(barcode),
      'name': serializer.toJson<String>(name),
      'brand': serializer.toJson<String?>(brand),
      'kcalPer100g': serializer.toJson<double>(kcalPer100g),
      'proteinPer100g': serializer.toJson<double>(proteinPer100g),
      'fatPer100g': serializer.toJson<double>(fatPer100g),
      'carbsPer100g': serializer.toJson<double>(carbsPer100g),
      'servingName': serializer.toJson<String?>(servingName),
      'servingGrams': serializer.toJson<double?>(servingGrams),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'lastUsedAt': serializer.toJson<DateTime?>(lastUsedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Food copyWith({
    int? id,
    String? source,
    Value<String?> externalId = const Value.absent(),
    Value<String?> barcode = const Value.absent(),
    String? name,
    Value<String?> brand = const Value.absent(),
    double? kcalPer100g,
    double? proteinPer100g,
    double? fatPer100g,
    double? carbsPer100g,
    Value<String?> servingName = const Value.absent(),
    Value<double?> servingGrams = const Value.absent(),
    bool? isFavorite,
    Value<DateTime?> lastUsedAt = const Value.absent(),
    DateTime? createdAt,
  }) => Food(
    id: id ?? this.id,
    source: source ?? this.source,
    externalId: externalId.present ? externalId.value : this.externalId,
    barcode: barcode.present ? barcode.value : this.barcode,
    name: name ?? this.name,
    brand: brand.present ? brand.value : this.brand,
    kcalPer100g: kcalPer100g ?? this.kcalPer100g,
    proteinPer100g: proteinPer100g ?? this.proteinPer100g,
    fatPer100g: fatPer100g ?? this.fatPer100g,
    carbsPer100g: carbsPer100g ?? this.carbsPer100g,
    servingName: servingName.present ? servingName.value : this.servingName,
    servingGrams: servingGrams.present ? servingGrams.value : this.servingGrams,
    isFavorite: isFavorite ?? this.isFavorite,
    lastUsedAt: lastUsedAt.present ? lastUsedAt.value : this.lastUsedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  Food copyWithCompanion(FoodsCompanion data) {
    return Food(
      id: data.id.present ? data.id.value : this.id,
      source: data.source.present ? data.source.value : this.source,
      externalId: data.externalId.present
          ? data.externalId.value
          : this.externalId,
      barcode: data.barcode.present ? data.barcode.value : this.barcode,
      name: data.name.present ? data.name.value : this.name,
      brand: data.brand.present ? data.brand.value : this.brand,
      kcalPer100g: data.kcalPer100g.present
          ? data.kcalPer100g.value
          : this.kcalPer100g,
      proteinPer100g: data.proteinPer100g.present
          ? data.proteinPer100g.value
          : this.proteinPer100g,
      fatPer100g: data.fatPer100g.present
          ? data.fatPer100g.value
          : this.fatPer100g,
      carbsPer100g: data.carbsPer100g.present
          ? data.carbsPer100g.value
          : this.carbsPer100g,
      servingName: data.servingName.present
          ? data.servingName.value
          : this.servingName,
      servingGrams: data.servingGrams.present
          ? data.servingGrams.value
          : this.servingGrams,
      isFavorite: data.isFavorite.present
          ? data.isFavorite.value
          : this.isFavorite,
      lastUsedAt: data.lastUsedAt.present
          ? data.lastUsedAt.value
          : this.lastUsedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Food(')
          ..write('id: $id, ')
          ..write('source: $source, ')
          ..write('externalId: $externalId, ')
          ..write('barcode: $barcode, ')
          ..write('name: $name, ')
          ..write('brand: $brand, ')
          ..write('kcalPer100g: $kcalPer100g, ')
          ..write('proteinPer100g: $proteinPer100g, ')
          ..write('fatPer100g: $fatPer100g, ')
          ..write('carbsPer100g: $carbsPer100g, ')
          ..write('servingName: $servingName, ')
          ..write('servingGrams: $servingGrams, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('lastUsedAt: $lastUsedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    source,
    externalId,
    barcode,
    name,
    brand,
    kcalPer100g,
    proteinPer100g,
    fatPer100g,
    carbsPer100g,
    servingName,
    servingGrams,
    isFavorite,
    lastUsedAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Food &&
          other.id == this.id &&
          other.source == this.source &&
          other.externalId == this.externalId &&
          other.barcode == this.barcode &&
          other.name == this.name &&
          other.brand == this.brand &&
          other.kcalPer100g == this.kcalPer100g &&
          other.proteinPer100g == this.proteinPer100g &&
          other.fatPer100g == this.fatPer100g &&
          other.carbsPer100g == this.carbsPer100g &&
          other.servingName == this.servingName &&
          other.servingGrams == this.servingGrams &&
          other.isFavorite == this.isFavorite &&
          other.lastUsedAt == this.lastUsedAt &&
          other.createdAt == this.createdAt);
}

class FoodsCompanion extends UpdateCompanion<Food> {
  final Value<int> id;
  final Value<String> source;
  final Value<String?> externalId;
  final Value<String?> barcode;
  final Value<String> name;
  final Value<String?> brand;
  final Value<double> kcalPer100g;
  final Value<double> proteinPer100g;
  final Value<double> fatPer100g;
  final Value<double> carbsPer100g;
  final Value<String?> servingName;
  final Value<double?> servingGrams;
  final Value<bool> isFavorite;
  final Value<DateTime?> lastUsedAt;
  final Value<DateTime> createdAt;
  const FoodsCompanion({
    this.id = const Value.absent(),
    this.source = const Value.absent(),
    this.externalId = const Value.absent(),
    this.barcode = const Value.absent(),
    this.name = const Value.absent(),
    this.brand = const Value.absent(),
    this.kcalPer100g = const Value.absent(),
    this.proteinPer100g = const Value.absent(),
    this.fatPer100g = const Value.absent(),
    this.carbsPer100g = const Value.absent(),
    this.servingName = const Value.absent(),
    this.servingGrams = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.lastUsedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  FoodsCompanion.insert({
    this.id = const Value.absent(),
    required String source,
    this.externalId = const Value.absent(),
    this.barcode = const Value.absent(),
    required String name,
    this.brand = const Value.absent(),
    required double kcalPer100g,
    required double proteinPer100g,
    required double fatPer100g,
    required double carbsPer100g,
    this.servingName = const Value.absent(),
    this.servingGrams = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.lastUsedAt = const Value.absent(),
    required DateTime createdAt,
  }) : source = Value(source),
       name = Value(name),
       kcalPer100g = Value(kcalPer100g),
       proteinPer100g = Value(proteinPer100g),
       fatPer100g = Value(fatPer100g),
       carbsPer100g = Value(carbsPer100g),
       createdAt = Value(createdAt);
  static Insertable<Food> custom({
    Expression<int>? id,
    Expression<String>? source,
    Expression<String>? externalId,
    Expression<String>? barcode,
    Expression<String>? name,
    Expression<String>? brand,
    Expression<double>? kcalPer100g,
    Expression<double>? proteinPer100g,
    Expression<double>? fatPer100g,
    Expression<double>? carbsPer100g,
    Expression<String>? servingName,
    Expression<double>? servingGrams,
    Expression<bool>? isFavorite,
    Expression<DateTime>? lastUsedAt,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (source != null) 'source': source,
      if (externalId != null) 'external_id': externalId,
      if (barcode != null) 'barcode': barcode,
      if (name != null) 'name': name,
      if (brand != null) 'brand': brand,
      if (kcalPer100g != null) 'kcal_per100g': kcalPer100g,
      if (proteinPer100g != null) 'protein_per100g': proteinPer100g,
      if (fatPer100g != null) 'fat_per100g': fatPer100g,
      if (carbsPer100g != null) 'carbs_per100g': carbsPer100g,
      if (servingName != null) 'serving_name': servingName,
      if (servingGrams != null) 'serving_grams': servingGrams,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (lastUsedAt != null) 'last_used_at': lastUsedAt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  FoodsCompanion copyWith({
    Value<int>? id,
    Value<String>? source,
    Value<String?>? externalId,
    Value<String?>? barcode,
    Value<String>? name,
    Value<String?>? brand,
    Value<double>? kcalPer100g,
    Value<double>? proteinPer100g,
    Value<double>? fatPer100g,
    Value<double>? carbsPer100g,
    Value<String?>? servingName,
    Value<double?>? servingGrams,
    Value<bool>? isFavorite,
    Value<DateTime?>? lastUsedAt,
    Value<DateTime>? createdAt,
  }) {
    return FoodsCompanion(
      id: id ?? this.id,
      source: source ?? this.source,
      externalId: externalId ?? this.externalId,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      kcalPer100g: kcalPer100g ?? this.kcalPer100g,
      proteinPer100g: proteinPer100g ?? this.proteinPer100g,
      fatPer100g: fatPer100g ?? this.fatPer100g,
      carbsPer100g: carbsPer100g ?? this.carbsPer100g,
      servingName: servingName ?? this.servingName,
      servingGrams: servingGrams ?? this.servingGrams,
      isFavorite: isFavorite ?? this.isFavorite,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (externalId.present) {
      map['external_id'] = Variable<String>(externalId.value);
    }
    if (barcode.present) {
      map['barcode'] = Variable<String>(barcode.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (brand.present) {
      map['brand'] = Variable<String>(brand.value);
    }
    if (kcalPer100g.present) {
      map['kcal_per100g'] = Variable<double>(kcalPer100g.value);
    }
    if (proteinPer100g.present) {
      map['protein_per100g'] = Variable<double>(proteinPer100g.value);
    }
    if (fatPer100g.present) {
      map['fat_per100g'] = Variable<double>(fatPer100g.value);
    }
    if (carbsPer100g.present) {
      map['carbs_per100g'] = Variable<double>(carbsPer100g.value);
    }
    if (servingName.present) {
      map['serving_name'] = Variable<String>(servingName.value);
    }
    if (servingGrams.present) {
      map['serving_grams'] = Variable<double>(servingGrams.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (lastUsedAt.present) {
      map['last_used_at'] = Variable<DateTime>(lastUsedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FoodsCompanion(')
          ..write('id: $id, ')
          ..write('source: $source, ')
          ..write('externalId: $externalId, ')
          ..write('barcode: $barcode, ')
          ..write('name: $name, ')
          ..write('brand: $brand, ')
          ..write('kcalPer100g: $kcalPer100g, ')
          ..write('proteinPer100g: $proteinPer100g, ')
          ..write('fatPer100g: $fatPer100g, ')
          ..write('carbsPer100g: $carbsPer100g, ')
          ..write('servingName: $servingName, ')
          ..write('servingGrams: $servingGrams, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('lastUsedAt: $lastUsedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $FoodLogEntriesTable extends FoodLogEntries
    with TableInfo<$FoodLogEntriesTable, FoodLogEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FoodLogEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _dayKeyMeta = const VerificationMeta('dayKey');
  @override
  late final GeneratedColumn<String> dayKey = GeneratedColumn<String>(
    'day_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mealMeta = const VerificationMeta('meal');
  @override
  late final GeneratedColumn<int> meal = GeneratedColumn<int>(
    'meal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _foodIdMeta = const VerificationMeta('foodId');
  @override
  late final GeneratedColumn<int> foodId = GeneratedColumn<int>(
    'food_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES foods (id)',
    ),
  );
  static const VerificationMeta _gramsMeta = const VerificationMeta('grams');
  @override
  late final GeneratedColumn<double> grams = GeneratedColumn<double>(
    'grams',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kcalMeta = const VerificationMeta('kcal');
  @override
  late final GeneratedColumn<double> kcal = GeneratedColumn<double>(
    'kcal',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _proteinGMeta = const VerificationMeta(
    'proteinG',
  );
  @override
  late final GeneratedColumn<double> proteinG = GeneratedColumn<double>(
    'protein_g',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fatGMeta = const VerificationMeta('fatG');
  @override
  late final GeneratedColumn<double> fatG = GeneratedColumn<double>(
    'fat_g',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _carbsGMeta = const VerificationMeta('carbsG');
  @override
  late final GeneratedColumn<double> carbsG = GeneratedColumn<double>(
    'carbs_g',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    dayKey,
    meal,
    foodId,
    grams,
    kcal,
    proteinG,
    fatG,
    carbsG,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'food_log_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<FoodLogEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('day_key')) {
      context.handle(
        _dayKeyMeta,
        dayKey.isAcceptableOrUnknown(data['day_key']!, _dayKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_dayKeyMeta);
    }
    if (data.containsKey('meal')) {
      context.handle(
        _mealMeta,
        meal.isAcceptableOrUnknown(data['meal']!, _mealMeta),
      );
    } else if (isInserting) {
      context.missing(_mealMeta);
    }
    if (data.containsKey('food_id')) {
      context.handle(
        _foodIdMeta,
        foodId.isAcceptableOrUnknown(data['food_id']!, _foodIdMeta),
      );
    } else if (isInserting) {
      context.missing(_foodIdMeta);
    }
    if (data.containsKey('grams')) {
      context.handle(
        _gramsMeta,
        grams.isAcceptableOrUnknown(data['grams']!, _gramsMeta),
      );
    } else if (isInserting) {
      context.missing(_gramsMeta);
    }
    if (data.containsKey('kcal')) {
      context.handle(
        _kcalMeta,
        kcal.isAcceptableOrUnknown(data['kcal']!, _kcalMeta),
      );
    } else if (isInserting) {
      context.missing(_kcalMeta);
    }
    if (data.containsKey('protein_g')) {
      context.handle(
        _proteinGMeta,
        proteinG.isAcceptableOrUnknown(data['protein_g']!, _proteinGMeta),
      );
    } else if (isInserting) {
      context.missing(_proteinGMeta);
    }
    if (data.containsKey('fat_g')) {
      context.handle(
        _fatGMeta,
        fatG.isAcceptableOrUnknown(data['fat_g']!, _fatGMeta),
      );
    } else if (isInserting) {
      context.missing(_fatGMeta);
    }
    if (data.containsKey('carbs_g')) {
      context.handle(
        _carbsGMeta,
        carbsG.isAcceptableOrUnknown(data['carbs_g']!, _carbsGMeta),
      );
    } else if (isInserting) {
      context.missing(_carbsGMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FoodLogEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FoodLogEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      dayKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day_key'],
      )!,
      meal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}meal'],
      )!,
      foodId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}food_id'],
      )!,
      grams: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}grams'],
      )!,
      kcal: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}kcal'],
      )!,
      proteinG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}protein_g'],
      )!,
      fatG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fat_g'],
      )!,
      carbsG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}carbs_g'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $FoodLogEntriesTable createAlias(String alias) {
    return $FoodLogEntriesTable(attachedDatabase, alias);
  }
}

class FoodLogEntry extends DataClass implements Insertable<FoodLogEntry> {
  final int id;
  final String dayKey;
  final int meal;
  final int foodId;
  final double grams;
  final double kcal;
  final double proteinG;
  final double fatG;
  final double carbsG;
  final DateTime createdAt;
  const FoodLogEntry({
    required this.id,
    required this.dayKey,
    required this.meal,
    required this.foodId,
    required this.grams,
    required this.kcal,
    required this.proteinG,
    required this.fatG,
    required this.carbsG,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['day_key'] = Variable<String>(dayKey);
    map['meal'] = Variable<int>(meal);
    map['food_id'] = Variable<int>(foodId);
    map['grams'] = Variable<double>(grams);
    map['kcal'] = Variable<double>(kcal);
    map['protein_g'] = Variable<double>(proteinG);
    map['fat_g'] = Variable<double>(fatG);
    map['carbs_g'] = Variable<double>(carbsG);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  FoodLogEntriesCompanion toCompanion(bool nullToAbsent) {
    return FoodLogEntriesCompanion(
      id: Value(id),
      dayKey: Value(dayKey),
      meal: Value(meal),
      foodId: Value(foodId),
      grams: Value(grams),
      kcal: Value(kcal),
      proteinG: Value(proteinG),
      fatG: Value(fatG),
      carbsG: Value(carbsG),
      createdAt: Value(createdAt),
    );
  }

  factory FoodLogEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FoodLogEntry(
      id: serializer.fromJson<int>(json['id']),
      dayKey: serializer.fromJson<String>(json['dayKey']),
      meal: serializer.fromJson<int>(json['meal']),
      foodId: serializer.fromJson<int>(json['foodId']),
      grams: serializer.fromJson<double>(json['grams']),
      kcal: serializer.fromJson<double>(json['kcal']),
      proteinG: serializer.fromJson<double>(json['proteinG']),
      fatG: serializer.fromJson<double>(json['fatG']),
      carbsG: serializer.fromJson<double>(json['carbsG']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'dayKey': serializer.toJson<String>(dayKey),
      'meal': serializer.toJson<int>(meal),
      'foodId': serializer.toJson<int>(foodId),
      'grams': serializer.toJson<double>(grams),
      'kcal': serializer.toJson<double>(kcal),
      'proteinG': serializer.toJson<double>(proteinG),
      'fatG': serializer.toJson<double>(fatG),
      'carbsG': serializer.toJson<double>(carbsG),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  FoodLogEntry copyWith({
    int? id,
    String? dayKey,
    int? meal,
    int? foodId,
    double? grams,
    double? kcal,
    double? proteinG,
    double? fatG,
    double? carbsG,
    DateTime? createdAt,
  }) => FoodLogEntry(
    id: id ?? this.id,
    dayKey: dayKey ?? this.dayKey,
    meal: meal ?? this.meal,
    foodId: foodId ?? this.foodId,
    grams: grams ?? this.grams,
    kcal: kcal ?? this.kcal,
    proteinG: proteinG ?? this.proteinG,
    fatG: fatG ?? this.fatG,
    carbsG: carbsG ?? this.carbsG,
    createdAt: createdAt ?? this.createdAt,
  );
  FoodLogEntry copyWithCompanion(FoodLogEntriesCompanion data) {
    return FoodLogEntry(
      id: data.id.present ? data.id.value : this.id,
      dayKey: data.dayKey.present ? data.dayKey.value : this.dayKey,
      meal: data.meal.present ? data.meal.value : this.meal,
      foodId: data.foodId.present ? data.foodId.value : this.foodId,
      grams: data.grams.present ? data.grams.value : this.grams,
      kcal: data.kcal.present ? data.kcal.value : this.kcal,
      proteinG: data.proteinG.present ? data.proteinG.value : this.proteinG,
      fatG: data.fatG.present ? data.fatG.value : this.fatG,
      carbsG: data.carbsG.present ? data.carbsG.value : this.carbsG,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FoodLogEntry(')
          ..write('id: $id, ')
          ..write('dayKey: $dayKey, ')
          ..write('meal: $meal, ')
          ..write('foodId: $foodId, ')
          ..write('grams: $grams, ')
          ..write('kcal: $kcal, ')
          ..write('proteinG: $proteinG, ')
          ..write('fatG: $fatG, ')
          ..write('carbsG: $carbsG, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    dayKey,
    meal,
    foodId,
    grams,
    kcal,
    proteinG,
    fatG,
    carbsG,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FoodLogEntry &&
          other.id == this.id &&
          other.dayKey == this.dayKey &&
          other.meal == this.meal &&
          other.foodId == this.foodId &&
          other.grams == this.grams &&
          other.kcal == this.kcal &&
          other.proteinG == this.proteinG &&
          other.fatG == this.fatG &&
          other.carbsG == this.carbsG &&
          other.createdAt == this.createdAt);
}

class FoodLogEntriesCompanion extends UpdateCompanion<FoodLogEntry> {
  final Value<int> id;
  final Value<String> dayKey;
  final Value<int> meal;
  final Value<int> foodId;
  final Value<double> grams;
  final Value<double> kcal;
  final Value<double> proteinG;
  final Value<double> fatG;
  final Value<double> carbsG;
  final Value<DateTime> createdAt;
  const FoodLogEntriesCompanion({
    this.id = const Value.absent(),
    this.dayKey = const Value.absent(),
    this.meal = const Value.absent(),
    this.foodId = const Value.absent(),
    this.grams = const Value.absent(),
    this.kcal = const Value.absent(),
    this.proteinG = const Value.absent(),
    this.fatG = const Value.absent(),
    this.carbsG = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  FoodLogEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String dayKey,
    required int meal,
    required int foodId,
    required double grams,
    required double kcal,
    required double proteinG,
    required double fatG,
    required double carbsG,
    required DateTime createdAt,
  }) : dayKey = Value(dayKey),
       meal = Value(meal),
       foodId = Value(foodId),
       grams = Value(grams),
       kcal = Value(kcal),
       proteinG = Value(proteinG),
       fatG = Value(fatG),
       carbsG = Value(carbsG),
       createdAt = Value(createdAt);
  static Insertable<FoodLogEntry> custom({
    Expression<int>? id,
    Expression<String>? dayKey,
    Expression<int>? meal,
    Expression<int>? foodId,
    Expression<double>? grams,
    Expression<double>? kcal,
    Expression<double>? proteinG,
    Expression<double>? fatG,
    Expression<double>? carbsG,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dayKey != null) 'day_key': dayKey,
      if (meal != null) 'meal': meal,
      if (foodId != null) 'food_id': foodId,
      if (grams != null) 'grams': grams,
      if (kcal != null) 'kcal': kcal,
      if (proteinG != null) 'protein_g': proteinG,
      if (fatG != null) 'fat_g': fatG,
      if (carbsG != null) 'carbs_g': carbsG,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  FoodLogEntriesCompanion copyWith({
    Value<int>? id,
    Value<String>? dayKey,
    Value<int>? meal,
    Value<int>? foodId,
    Value<double>? grams,
    Value<double>? kcal,
    Value<double>? proteinG,
    Value<double>? fatG,
    Value<double>? carbsG,
    Value<DateTime>? createdAt,
  }) {
    return FoodLogEntriesCompanion(
      id: id ?? this.id,
      dayKey: dayKey ?? this.dayKey,
      meal: meal ?? this.meal,
      foodId: foodId ?? this.foodId,
      grams: grams ?? this.grams,
      kcal: kcal ?? this.kcal,
      proteinG: proteinG ?? this.proteinG,
      fatG: fatG ?? this.fatG,
      carbsG: carbsG ?? this.carbsG,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (dayKey.present) {
      map['day_key'] = Variable<String>(dayKey.value);
    }
    if (meal.present) {
      map['meal'] = Variable<int>(meal.value);
    }
    if (foodId.present) {
      map['food_id'] = Variable<int>(foodId.value);
    }
    if (grams.present) {
      map['grams'] = Variable<double>(grams.value);
    }
    if (kcal.present) {
      map['kcal'] = Variable<double>(kcal.value);
    }
    if (proteinG.present) {
      map['protein_g'] = Variable<double>(proteinG.value);
    }
    if (fatG.present) {
      map['fat_g'] = Variable<double>(fatG.value);
    }
    if (carbsG.present) {
      map['carbs_g'] = Variable<double>(carbsG.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FoodLogEntriesCompanion(')
          ..write('id: $id, ')
          ..write('dayKey: $dayKey, ')
          ..write('meal: $meal, ')
          ..write('foodId: $foodId, ')
          ..write('grams: $grams, ')
          ..write('kcal: $kcal, ')
          ..write('proteinG: $proteinG, ')
          ..write('fatG: $fatG, ')
          ..write('carbsG: $carbsG, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $SavedMealsTable extends SavedMeals
    with TableInfo<$SavedMealsTable, SavedMeal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedMealsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_meals';
  @override
  VerificationContext validateIntegrity(
    Insertable<SavedMeal> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SavedMeal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedMeal(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SavedMealsTable createAlias(String alias) {
    return $SavedMealsTable(attachedDatabase, alias);
  }
}

class SavedMeal extends DataClass implements Insertable<SavedMeal> {
  final int id;
  final String name;
  final DateTime createdAt;
  const SavedMeal({
    required this.id,
    required this.name,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SavedMealsCompanion toCompanion(bool nullToAbsent) {
    return SavedMealsCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
    );
  }

  factory SavedMeal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedMeal(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SavedMeal copyWith({int? id, String? name, DateTime? createdAt}) => SavedMeal(
    id: id ?? this.id,
    name: name ?? this.name,
    createdAt: createdAt ?? this.createdAt,
  );
  SavedMeal copyWithCompanion(SavedMealsCompanion data) {
    return SavedMeal(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedMeal(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedMeal &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt);
}

class SavedMealsCompanion extends UpdateCompanion<SavedMeal> {
  final Value<int> id;
  final Value<String> name;
  final Value<DateTime> createdAt;
  const SavedMealsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  SavedMealsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required DateTime createdAt,
  }) : name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<SavedMeal> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  SavedMealsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<DateTime>? createdAt,
  }) {
    return SavedMealsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedMealsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $SavedMealItemsTable extends SavedMealItems
    with TableInfo<$SavedMealItemsTable, SavedMealItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedMealItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _savedMealIdMeta = const VerificationMeta(
    'savedMealId',
  );
  @override
  late final GeneratedColumn<int> savedMealId = GeneratedColumn<int>(
    'saved_meal_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES saved_meals (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _foodIdMeta = const VerificationMeta('foodId');
  @override
  late final GeneratedColumn<int> foodId = GeneratedColumn<int>(
    'food_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES foods (id)',
    ),
  );
  static const VerificationMeta _gramsMeta = const VerificationMeta('grams');
  @override
  late final GeneratedColumn<double> grams = GeneratedColumn<double>(
    'grams',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, savedMealId, foodId, grams];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_meal_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<SavedMealItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('saved_meal_id')) {
      context.handle(
        _savedMealIdMeta,
        savedMealId.isAcceptableOrUnknown(
          data['saved_meal_id']!,
          _savedMealIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_savedMealIdMeta);
    }
    if (data.containsKey('food_id')) {
      context.handle(
        _foodIdMeta,
        foodId.isAcceptableOrUnknown(data['food_id']!, _foodIdMeta),
      );
    } else if (isInserting) {
      context.missing(_foodIdMeta);
    }
    if (data.containsKey('grams')) {
      context.handle(
        _gramsMeta,
        grams.isAcceptableOrUnknown(data['grams']!, _gramsMeta),
      );
    } else if (isInserting) {
      context.missing(_gramsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SavedMealItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedMealItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      savedMealId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}saved_meal_id'],
      )!,
      foodId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}food_id'],
      )!,
      grams: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}grams'],
      )!,
    );
  }

  @override
  $SavedMealItemsTable createAlias(String alias) {
    return $SavedMealItemsTable(attachedDatabase, alias);
  }
}

class SavedMealItem extends DataClass implements Insertable<SavedMealItem> {
  final int id;
  final int savedMealId;
  final int foodId;
  final double grams;
  const SavedMealItem({
    required this.id,
    required this.savedMealId,
    required this.foodId,
    required this.grams,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['saved_meal_id'] = Variable<int>(savedMealId);
    map['food_id'] = Variable<int>(foodId);
    map['grams'] = Variable<double>(grams);
    return map;
  }

  SavedMealItemsCompanion toCompanion(bool nullToAbsent) {
    return SavedMealItemsCompanion(
      id: Value(id),
      savedMealId: Value(savedMealId),
      foodId: Value(foodId),
      grams: Value(grams),
    );
  }

  factory SavedMealItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedMealItem(
      id: serializer.fromJson<int>(json['id']),
      savedMealId: serializer.fromJson<int>(json['savedMealId']),
      foodId: serializer.fromJson<int>(json['foodId']),
      grams: serializer.fromJson<double>(json['grams']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'savedMealId': serializer.toJson<int>(savedMealId),
      'foodId': serializer.toJson<int>(foodId),
      'grams': serializer.toJson<double>(grams),
    };
  }

  SavedMealItem copyWith({
    int? id,
    int? savedMealId,
    int? foodId,
    double? grams,
  }) => SavedMealItem(
    id: id ?? this.id,
    savedMealId: savedMealId ?? this.savedMealId,
    foodId: foodId ?? this.foodId,
    grams: grams ?? this.grams,
  );
  SavedMealItem copyWithCompanion(SavedMealItemsCompanion data) {
    return SavedMealItem(
      id: data.id.present ? data.id.value : this.id,
      savedMealId: data.savedMealId.present
          ? data.savedMealId.value
          : this.savedMealId,
      foodId: data.foodId.present ? data.foodId.value : this.foodId,
      grams: data.grams.present ? data.grams.value : this.grams,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedMealItem(')
          ..write('id: $id, ')
          ..write('savedMealId: $savedMealId, ')
          ..write('foodId: $foodId, ')
          ..write('grams: $grams')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, savedMealId, foodId, grams);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedMealItem &&
          other.id == this.id &&
          other.savedMealId == this.savedMealId &&
          other.foodId == this.foodId &&
          other.grams == this.grams);
}

class SavedMealItemsCompanion extends UpdateCompanion<SavedMealItem> {
  final Value<int> id;
  final Value<int> savedMealId;
  final Value<int> foodId;
  final Value<double> grams;
  const SavedMealItemsCompanion({
    this.id = const Value.absent(),
    this.savedMealId = const Value.absent(),
    this.foodId = const Value.absent(),
    this.grams = const Value.absent(),
  });
  SavedMealItemsCompanion.insert({
    this.id = const Value.absent(),
    required int savedMealId,
    required int foodId,
    required double grams,
  }) : savedMealId = Value(savedMealId),
       foodId = Value(foodId),
       grams = Value(grams);
  static Insertable<SavedMealItem> custom({
    Expression<int>? id,
    Expression<int>? savedMealId,
    Expression<int>? foodId,
    Expression<double>? grams,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (savedMealId != null) 'saved_meal_id': savedMealId,
      if (foodId != null) 'food_id': foodId,
      if (grams != null) 'grams': grams,
    });
  }

  SavedMealItemsCompanion copyWith({
    Value<int>? id,
    Value<int>? savedMealId,
    Value<int>? foodId,
    Value<double>? grams,
  }) {
    return SavedMealItemsCompanion(
      id: id ?? this.id,
      savedMealId: savedMealId ?? this.savedMealId,
      foodId: foodId ?? this.foodId,
      grams: grams ?? this.grams,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (savedMealId.present) {
      map['saved_meal_id'] = Variable<int>(savedMealId.value);
    }
    if (foodId.present) {
      map['food_id'] = Variable<int>(foodId.value);
    }
    if (grams.present) {
      map['grams'] = Variable<double>(grams.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedMealItemsCompanion(')
          ..write('id: $id, ')
          ..write('savedMealId: $savedMealId, ')
          ..write('foodId: $foodId, ')
          ..write('grams: $grams')
          ..write(')'))
        .toString();
  }
}

class $WeighInsTable extends WeighIns with TableInfo<$WeighInsTable, WeighIn> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WeighInsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dayKeyMeta = const VerificationMeta('dayKey');
  @override
  late final GeneratedColumn<String> dayKey = GeneratedColumn<String>(
    'day_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weightKgMeta = const VerificationMeta(
    'weightKg',
  );
  @override
  late final GeneratedColumn<double> weightKg = GeneratedColumn<double>(
    'weight_kg',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [dayKey, weightKg, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'weigh_ins';
  @override
  VerificationContext validateIntegrity(
    Insertable<WeighIn> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('day_key')) {
      context.handle(
        _dayKeyMeta,
        dayKey.isAcceptableOrUnknown(data['day_key']!, _dayKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_dayKeyMeta);
    }
    if (data.containsKey('weight_kg')) {
      context.handle(
        _weightKgMeta,
        weightKg.isAcceptableOrUnknown(data['weight_kg']!, _weightKgMeta),
      );
    } else if (isInserting) {
      context.missing(_weightKgMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {dayKey};
  @override
  WeighIn map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WeighIn(
      dayKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day_key'],
      )!,
      weightKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight_kg'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $WeighInsTable createAlias(String alias) {
    return $WeighInsTable(attachedDatabase, alias);
  }
}

class WeighIn extends DataClass implements Insertable<WeighIn> {
  final String dayKey;
  final double weightKg;
  final DateTime createdAt;
  const WeighIn({
    required this.dayKey,
    required this.weightKg,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['day_key'] = Variable<String>(dayKey);
    map['weight_kg'] = Variable<double>(weightKg);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  WeighInsCompanion toCompanion(bool nullToAbsent) {
    return WeighInsCompanion(
      dayKey: Value(dayKey),
      weightKg: Value(weightKg),
      createdAt: Value(createdAt),
    );
  }

  factory WeighIn.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WeighIn(
      dayKey: serializer.fromJson<String>(json['dayKey']),
      weightKg: serializer.fromJson<double>(json['weightKg']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'dayKey': serializer.toJson<String>(dayKey),
      'weightKg': serializer.toJson<double>(weightKg),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  WeighIn copyWith({String? dayKey, double? weightKg, DateTime? createdAt}) =>
      WeighIn(
        dayKey: dayKey ?? this.dayKey,
        weightKg: weightKg ?? this.weightKg,
        createdAt: createdAt ?? this.createdAt,
      );
  WeighIn copyWithCompanion(WeighInsCompanion data) {
    return WeighIn(
      dayKey: data.dayKey.present ? data.dayKey.value : this.dayKey,
      weightKg: data.weightKg.present ? data.weightKg.value : this.weightKg,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WeighIn(')
          ..write('dayKey: $dayKey, ')
          ..write('weightKg: $weightKg, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(dayKey, weightKg, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WeighIn &&
          other.dayKey == this.dayKey &&
          other.weightKg == this.weightKg &&
          other.createdAt == this.createdAt);
}

class WeighInsCompanion extends UpdateCompanion<WeighIn> {
  final Value<String> dayKey;
  final Value<double> weightKg;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const WeighInsCompanion({
    this.dayKey = const Value.absent(),
    this.weightKg = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WeighInsCompanion.insert({
    required String dayKey,
    required double weightKg,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : dayKey = Value(dayKey),
       weightKg = Value(weightKg),
       createdAt = Value(createdAt);
  static Insertable<WeighIn> custom({
    Expression<String>? dayKey,
    Expression<double>? weightKg,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (dayKey != null) 'day_key': dayKey,
      if (weightKg != null) 'weight_kg': weightKg,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WeighInsCompanion copyWith({
    Value<String>? dayKey,
    Value<double>? weightKg,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return WeighInsCompanion(
      dayKey: dayKey ?? this.dayKey,
      weightKg: weightKg ?? this.weightKg,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (dayKey.present) {
      map['day_key'] = Variable<String>(dayKey.value);
    }
    if (weightKg.present) {
      map['weight_kg'] = Variable<double>(weightKg.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WeighInsCompanion(')
          ..write('dayKey: $dayKey, ')
          ..write('weightKg: $weightKg, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DayStatusesTable extends DayStatuses
    with TableInfo<$DayStatusesTable, DayStatus> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DayStatusesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dayKeyMeta = const VerificationMeta('dayKey');
  @override
  late final GeneratedColumn<String> dayKey = GeneratedColumn<String>(
    'day_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fullyLoggedMeta = const VerificationMeta(
    'fullyLogged',
  );
  @override
  late final GeneratedColumn<bool> fullyLogged = GeneratedColumn<bool>(
    'fully_logged',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("fully_logged" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [dayKey, fullyLogged];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'day_statuses';
  @override
  VerificationContext validateIntegrity(
    Insertable<DayStatus> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('day_key')) {
      context.handle(
        _dayKeyMeta,
        dayKey.isAcceptableOrUnknown(data['day_key']!, _dayKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_dayKeyMeta);
    }
    if (data.containsKey('fully_logged')) {
      context.handle(
        _fullyLoggedMeta,
        fullyLogged.isAcceptableOrUnknown(
          data['fully_logged']!,
          _fullyLoggedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {dayKey};
  @override
  DayStatus map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DayStatus(
      dayKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day_key'],
      )!,
      fullyLogged: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}fully_logged'],
      )!,
    );
  }

  @override
  $DayStatusesTable createAlias(String alias) {
    return $DayStatusesTable(attachedDatabase, alias);
  }
}

class DayStatus extends DataClass implements Insertable<DayStatus> {
  final String dayKey;
  final bool fullyLogged;
  const DayStatus({required this.dayKey, required this.fullyLogged});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['day_key'] = Variable<String>(dayKey);
    map['fully_logged'] = Variable<bool>(fullyLogged);
    return map;
  }

  DayStatusesCompanion toCompanion(bool nullToAbsent) {
    return DayStatusesCompanion(
      dayKey: Value(dayKey),
      fullyLogged: Value(fullyLogged),
    );
  }

  factory DayStatus.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DayStatus(
      dayKey: serializer.fromJson<String>(json['dayKey']),
      fullyLogged: serializer.fromJson<bool>(json['fullyLogged']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'dayKey': serializer.toJson<String>(dayKey),
      'fullyLogged': serializer.toJson<bool>(fullyLogged),
    };
  }

  DayStatus copyWith({String? dayKey, bool? fullyLogged}) => DayStatus(
    dayKey: dayKey ?? this.dayKey,
    fullyLogged: fullyLogged ?? this.fullyLogged,
  );
  DayStatus copyWithCompanion(DayStatusesCompanion data) {
    return DayStatus(
      dayKey: data.dayKey.present ? data.dayKey.value : this.dayKey,
      fullyLogged: data.fullyLogged.present
          ? data.fullyLogged.value
          : this.fullyLogged,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DayStatus(')
          ..write('dayKey: $dayKey, ')
          ..write('fullyLogged: $fullyLogged')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(dayKey, fullyLogged);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DayStatus &&
          other.dayKey == this.dayKey &&
          other.fullyLogged == this.fullyLogged);
}

class DayStatusesCompanion extends UpdateCompanion<DayStatus> {
  final Value<String> dayKey;
  final Value<bool> fullyLogged;
  final Value<int> rowid;
  const DayStatusesCompanion({
    this.dayKey = const Value.absent(),
    this.fullyLogged = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DayStatusesCompanion.insert({
    required String dayKey,
    this.fullyLogged = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : dayKey = Value(dayKey);
  static Insertable<DayStatus> custom({
    Expression<String>? dayKey,
    Expression<bool>? fullyLogged,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (dayKey != null) 'day_key': dayKey,
      if (fullyLogged != null) 'fully_logged': fullyLogged,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DayStatusesCompanion copyWith({
    Value<String>? dayKey,
    Value<bool>? fullyLogged,
    Value<int>? rowid,
  }) {
    return DayStatusesCompanion(
      dayKey: dayKey ?? this.dayKey,
      fullyLogged: fullyLogged ?? this.fullyLogged,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (dayKey.present) {
      map['day_key'] = Variable<String>(dayKey.value);
    }
    if (fullyLogged.present) {
      map['fully_logged'] = Variable<bool>(fullyLogged.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DayStatusesCompanion(')
          ..write('dayKey: $dayKey, ')
          ..write('fullyLogged: $fullyLogged, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DailyStepsTable extends DailySteps
    with TableInfo<$DailyStepsTable, DailyStep> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailyStepsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dayKeyMeta = const VerificationMeta('dayKey');
  @override
  late final GeneratedColumn<String> dayKey = GeneratedColumn<String>(
    'day_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stepsMeta = const VerificationMeta('steps');
  @override
  late final GeneratedColumn<int> steps = GeneratedColumn<int>(
    'steps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [dayKey, steps, syncedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_steps';
  @override
  VerificationContext validateIntegrity(
    Insertable<DailyStep> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('day_key')) {
      context.handle(
        _dayKeyMeta,
        dayKey.isAcceptableOrUnknown(data['day_key']!, _dayKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_dayKeyMeta);
    }
    if (data.containsKey('steps')) {
      context.handle(
        _stepsMeta,
        steps.isAcceptableOrUnknown(data['steps']!, _stepsMeta),
      );
    } else if (isInserting) {
      context.missing(_stepsMeta);
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_syncedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {dayKey};
  @override
  DailyStep map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailyStep(
      dayKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day_key'],
      )!,
      steps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}steps'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      )!,
    );
  }

  @override
  $DailyStepsTable createAlias(String alias) {
    return $DailyStepsTable(attachedDatabase, alias);
  }
}

class DailyStep extends DataClass implements Insertable<DailyStep> {
  final String dayKey;
  final int steps;
  final DateTime syncedAt;
  const DailyStep({
    required this.dayKey,
    required this.steps,
    required this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['day_key'] = Variable<String>(dayKey);
    map['steps'] = Variable<int>(steps);
    map['synced_at'] = Variable<DateTime>(syncedAt);
    return map;
  }

  DailyStepsCompanion toCompanion(bool nullToAbsent) {
    return DailyStepsCompanion(
      dayKey: Value(dayKey),
      steps: Value(steps),
      syncedAt: Value(syncedAt),
    );
  }

  factory DailyStep.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailyStep(
      dayKey: serializer.fromJson<String>(json['dayKey']),
      steps: serializer.fromJson<int>(json['steps']),
      syncedAt: serializer.fromJson<DateTime>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'dayKey': serializer.toJson<String>(dayKey),
      'steps': serializer.toJson<int>(steps),
      'syncedAt': serializer.toJson<DateTime>(syncedAt),
    };
  }

  DailyStep copyWith({String? dayKey, int? steps, DateTime? syncedAt}) =>
      DailyStep(
        dayKey: dayKey ?? this.dayKey,
        steps: steps ?? this.steps,
        syncedAt: syncedAt ?? this.syncedAt,
      );
  DailyStep copyWithCompanion(DailyStepsCompanion data) {
    return DailyStep(
      dayKey: data.dayKey.present ? data.dayKey.value : this.dayKey,
      steps: data.steps.present ? data.steps.value : this.steps,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailyStep(')
          ..write('dayKey: $dayKey, ')
          ..write('steps: $steps, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(dayKey, steps, syncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyStep &&
          other.dayKey == this.dayKey &&
          other.steps == this.steps &&
          other.syncedAt == this.syncedAt);
}

class DailyStepsCompanion extends UpdateCompanion<DailyStep> {
  final Value<String> dayKey;
  final Value<int> steps;
  final Value<DateTime> syncedAt;
  final Value<int> rowid;
  const DailyStepsCompanion({
    this.dayKey = const Value.absent(),
    this.steps = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DailyStepsCompanion.insert({
    required String dayKey,
    required int steps,
    required DateTime syncedAt,
    this.rowid = const Value.absent(),
  }) : dayKey = Value(dayKey),
       steps = Value(steps),
       syncedAt = Value(syncedAt);
  static Insertable<DailyStep> custom({
    Expression<String>? dayKey,
    Expression<int>? steps,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (dayKey != null) 'day_key': dayKey,
      if (steps != null) 'steps': steps,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DailyStepsCompanion copyWith({
    Value<String>? dayKey,
    Value<int>? steps,
    Value<DateTime>? syncedAt,
    Value<int>? rowid,
  }) {
    return DailyStepsCompanion(
      dayKey: dayKey ?? this.dayKey,
      steps: steps ?? this.steps,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (dayKey.present) {
      map['day_key'] = Variable<String>(dayKey.value);
    }
    if (steps.present) {
      map['steps'] = Variable<int>(steps.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailyStepsCompanion(')
          ..write('dayKey: $dayKey, ')
          ..write('steps: $steps, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkoutsTable extends Workouts with TableInfo<$WorkoutsTable, Workout> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dayKeyMeta = const VerificationMeta('dayKey');
  @override
  late final GeneratedColumn<String> dayKey = GeneratedColumn<String>(
    'day_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startTimeMeta = const VerificationMeta(
    'startTime',
  );
  @override
  late final GeneratedColumn<DateTime> startTime = GeneratedColumn<DateTime>(
    'start_time',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endTimeMeta = const VerificationMeta(
    'endTime',
  );
  @override
  late final GeneratedColumn<DateTime> endTime = GeneratedColumn<DateTime>(
    'end_time',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activityTypeMeta = const VerificationMeta(
    'activityType',
  );
  @override
  late final GeneratedColumn<String> activityType = GeneratedColumn<String>(
    'activity_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceAppMeta = const VerificationMeta(
    'sourceApp',
  );
  @override
  late final GeneratedColumn<String> sourceApp = GeneratedColumn<String>(
    'source_app',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kcalMeta = const VerificationMeta('kcal');
  @override
  late final GeneratedColumn<double> kcal = GeneratedColumn<double>(
    'kcal',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    dayKey,
    title,
    startTime,
    endTime,
    activityType,
    sourceApp,
    kcal,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workouts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Workout> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('day_key')) {
      context.handle(
        _dayKeyMeta,
        dayKey.isAcceptableOrUnknown(data['day_key']!, _dayKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_dayKeyMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('start_time')) {
      context.handle(
        _startTimeMeta,
        startTime.isAcceptableOrUnknown(data['start_time']!, _startTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_startTimeMeta);
    }
    if (data.containsKey('end_time')) {
      context.handle(
        _endTimeMeta,
        endTime.isAcceptableOrUnknown(data['end_time']!, _endTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_endTimeMeta);
    }
    if (data.containsKey('activity_type')) {
      context.handle(
        _activityTypeMeta,
        activityType.isAcceptableOrUnknown(
          data['activity_type']!,
          _activityTypeMeta,
        ),
      );
    }
    if (data.containsKey('source_app')) {
      context.handle(
        _sourceAppMeta,
        sourceApp.isAcceptableOrUnknown(data['source_app']!, _sourceAppMeta),
      );
    }
    if (data.containsKey('kcal')) {
      context.handle(
        _kcalMeta,
        kcal.isAcceptableOrUnknown(data['kcal']!, _kcalMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_syncedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Workout map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Workout(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      dayKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day_key'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      startTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_time'],
      )!,
      endTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_time'],
      )!,
      activityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_type'],
      ),
      sourceApp: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_app'],
      ),
      kcal: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}kcal'],
      ),
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      )!,
    );
  }

  @override
  $WorkoutsTable createAlias(String alias) {
    return $WorkoutsTable(attachedDatabase, alias);
  }
}

class Workout extends DataClass implements Insertable<Workout> {
  /// Health Connect record id (stable across syncs).
  final String id;
  final String dayKey;
  final String title;
  final DateTime startTime;
  final DateTime endTime;

  /// Health Connect exercise type name, e.g. 'STRENGTH_TRAINING'.
  final String? activityType;
  final String? sourceApp;
  final double? kcal;
  final DateTime syncedAt;
  const Workout({
    required this.id,
    required this.dayKey,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.activityType,
    this.sourceApp,
    this.kcal,
    required this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['day_key'] = Variable<String>(dayKey);
    map['title'] = Variable<String>(title);
    map['start_time'] = Variable<DateTime>(startTime);
    map['end_time'] = Variable<DateTime>(endTime);
    if (!nullToAbsent || activityType != null) {
      map['activity_type'] = Variable<String>(activityType);
    }
    if (!nullToAbsent || sourceApp != null) {
      map['source_app'] = Variable<String>(sourceApp);
    }
    if (!nullToAbsent || kcal != null) {
      map['kcal'] = Variable<double>(kcal);
    }
    map['synced_at'] = Variable<DateTime>(syncedAt);
    return map;
  }

  WorkoutsCompanion toCompanion(bool nullToAbsent) {
    return WorkoutsCompanion(
      id: Value(id),
      dayKey: Value(dayKey),
      title: Value(title),
      startTime: Value(startTime),
      endTime: Value(endTime),
      activityType: activityType == null && nullToAbsent
          ? const Value.absent()
          : Value(activityType),
      sourceApp: sourceApp == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceApp),
      kcal: kcal == null && nullToAbsent ? const Value.absent() : Value(kcal),
      syncedAt: Value(syncedAt),
    );
  }

  factory Workout.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Workout(
      id: serializer.fromJson<String>(json['id']),
      dayKey: serializer.fromJson<String>(json['dayKey']),
      title: serializer.fromJson<String>(json['title']),
      startTime: serializer.fromJson<DateTime>(json['startTime']),
      endTime: serializer.fromJson<DateTime>(json['endTime']),
      activityType: serializer.fromJson<String?>(json['activityType']),
      sourceApp: serializer.fromJson<String?>(json['sourceApp']),
      kcal: serializer.fromJson<double?>(json['kcal']),
      syncedAt: serializer.fromJson<DateTime>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'dayKey': serializer.toJson<String>(dayKey),
      'title': serializer.toJson<String>(title),
      'startTime': serializer.toJson<DateTime>(startTime),
      'endTime': serializer.toJson<DateTime>(endTime),
      'activityType': serializer.toJson<String?>(activityType),
      'sourceApp': serializer.toJson<String?>(sourceApp),
      'kcal': serializer.toJson<double?>(kcal),
      'syncedAt': serializer.toJson<DateTime>(syncedAt),
    };
  }

  Workout copyWith({
    String? id,
    String? dayKey,
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    Value<String?> activityType = const Value.absent(),
    Value<String?> sourceApp = const Value.absent(),
    Value<double?> kcal = const Value.absent(),
    DateTime? syncedAt,
  }) => Workout(
    id: id ?? this.id,
    dayKey: dayKey ?? this.dayKey,
    title: title ?? this.title,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    activityType: activityType.present ? activityType.value : this.activityType,
    sourceApp: sourceApp.present ? sourceApp.value : this.sourceApp,
    kcal: kcal.present ? kcal.value : this.kcal,
    syncedAt: syncedAt ?? this.syncedAt,
  );
  Workout copyWithCompanion(WorkoutsCompanion data) {
    return Workout(
      id: data.id.present ? data.id.value : this.id,
      dayKey: data.dayKey.present ? data.dayKey.value : this.dayKey,
      title: data.title.present ? data.title.value : this.title,
      startTime: data.startTime.present ? data.startTime.value : this.startTime,
      endTime: data.endTime.present ? data.endTime.value : this.endTime,
      activityType: data.activityType.present
          ? data.activityType.value
          : this.activityType,
      sourceApp: data.sourceApp.present ? data.sourceApp.value : this.sourceApp,
      kcal: data.kcal.present ? data.kcal.value : this.kcal,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Workout(')
          ..write('id: $id, ')
          ..write('dayKey: $dayKey, ')
          ..write('title: $title, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('activityType: $activityType, ')
          ..write('sourceApp: $sourceApp, ')
          ..write('kcal: $kcal, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    dayKey,
    title,
    startTime,
    endTime,
    activityType,
    sourceApp,
    kcal,
    syncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Workout &&
          other.id == this.id &&
          other.dayKey == this.dayKey &&
          other.title == this.title &&
          other.startTime == this.startTime &&
          other.endTime == this.endTime &&
          other.activityType == this.activityType &&
          other.sourceApp == this.sourceApp &&
          other.kcal == this.kcal &&
          other.syncedAt == this.syncedAt);
}

class WorkoutsCompanion extends UpdateCompanion<Workout> {
  final Value<String> id;
  final Value<String> dayKey;
  final Value<String> title;
  final Value<DateTime> startTime;
  final Value<DateTime> endTime;
  final Value<String?> activityType;
  final Value<String?> sourceApp;
  final Value<double?> kcal;
  final Value<DateTime> syncedAt;
  final Value<int> rowid;
  const WorkoutsCompanion({
    this.id = const Value.absent(),
    this.dayKey = const Value.absent(),
    this.title = const Value.absent(),
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.activityType = const Value.absent(),
    this.sourceApp = const Value.absent(),
    this.kcal = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkoutsCompanion.insert({
    required String id,
    required String dayKey,
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    this.activityType = const Value.absent(),
    this.sourceApp = const Value.absent(),
    this.kcal = const Value.absent(),
    required DateTime syncedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       dayKey = Value(dayKey),
       title = Value(title),
       startTime = Value(startTime),
       endTime = Value(endTime),
       syncedAt = Value(syncedAt);
  static Insertable<Workout> custom({
    Expression<String>? id,
    Expression<String>? dayKey,
    Expression<String>? title,
    Expression<DateTime>? startTime,
    Expression<DateTime>? endTime,
    Expression<String>? activityType,
    Expression<String>? sourceApp,
    Expression<double>? kcal,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dayKey != null) 'day_key': dayKey,
      if (title != null) 'title': title,
      if (startTime != null) 'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
      if (activityType != null) 'activity_type': activityType,
      if (sourceApp != null) 'source_app': sourceApp,
      if (kcal != null) 'kcal': kcal,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkoutsCompanion copyWith({
    Value<String>? id,
    Value<String>? dayKey,
    Value<String>? title,
    Value<DateTime>? startTime,
    Value<DateTime>? endTime,
    Value<String?>? activityType,
    Value<String?>? sourceApp,
    Value<double?>? kcal,
    Value<DateTime>? syncedAt,
    Value<int>? rowid,
  }) {
    return WorkoutsCompanion(
      id: id ?? this.id,
      dayKey: dayKey ?? this.dayKey,
      title: title ?? this.title,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      activityType: activityType ?? this.activityType,
      sourceApp: sourceApp ?? this.sourceApp,
      kcal: kcal ?? this.kcal,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (dayKey.present) {
      map['day_key'] = Variable<String>(dayKey.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (startTime.present) {
      map['start_time'] = Variable<DateTime>(startTime.value);
    }
    if (endTime.present) {
      map['end_time'] = Variable<DateTime>(endTime.value);
    }
    if (activityType.present) {
      map['activity_type'] = Variable<String>(activityType.value);
    }
    if (sourceApp.present) {
      map['source_app'] = Variable<String>(sourceApp.value);
    }
    if (kcal.present) {
      map['kcal'] = Variable<double>(kcal.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutsCompanion(')
          ..write('id: $id, ')
          ..write('dayKey: $dayKey, ')
          ..write('title: $title, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('activityType: $activityType, ')
          ..write('sourceApp: $sourceApp, ')
          ..write('kcal: $kcal, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TargetHistoryTable extends TargetHistory
    with TableInfo<$TargetHistoryTable, TargetRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TargetHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _effectiveFromMeta = const VerificationMeta(
    'effectiveFrom',
  );
  @override
  late final GeneratedColumn<String> effectiveFrom = GeneratedColumn<String>(
    'effective_from',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kcalMeta = const VerificationMeta('kcal');
  @override
  late final GeneratedColumn<double> kcal = GeneratedColumn<double>(
    'kcal',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _proteinGMeta = const VerificationMeta(
    'proteinG',
  );
  @override
  late final GeneratedColumn<double> proteinG = GeneratedColumn<double>(
    'protein_g',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fatGMeta = const VerificationMeta('fatG');
  @override
  late final GeneratedColumn<double> fatG = GeneratedColumn<double>(
    'fat_g',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _carbsGMeta = const VerificationMeta('carbsG');
  @override
  late final GeneratedColumn<double> carbsG = GeneratedColumn<double>(
    'carbs_g',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _maintenanceKcalMeta = const VerificationMeta(
    'maintenanceKcal',
  );
  @override
  late final GeneratedColumn<double> maintenanceKcal = GeneratedColumn<double>(
    'maintenance_kcal',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _methodMeta = const VerificationMeta('method');
  @override
  late final GeneratedColumn<int> method = GeneratedColumn<int>(
    'method',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _explanationJsonMeta = const VerificationMeta(
    'explanationJson',
  );
  @override
  late final GeneratedColumn<String> explanationJson = GeneratedColumn<String>(
    'explanation_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    effectiveFrom,
    kcal,
    proteinG,
    fatG,
    carbsG,
    maintenanceKcal,
    method,
    explanationJson,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'target_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<TargetRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('effective_from')) {
      context.handle(
        _effectiveFromMeta,
        effectiveFrom.isAcceptableOrUnknown(
          data['effective_from']!,
          _effectiveFromMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_effectiveFromMeta);
    }
    if (data.containsKey('kcal')) {
      context.handle(
        _kcalMeta,
        kcal.isAcceptableOrUnknown(data['kcal']!, _kcalMeta),
      );
    } else if (isInserting) {
      context.missing(_kcalMeta);
    }
    if (data.containsKey('protein_g')) {
      context.handle(
        _proteinGMeta,
        proteinG.isAcceptableOrUnknown(data['protein_g']!, _proteinGMeta),
      );
    } else if (isInserting) {
      context.missing(_proteinGMeta);
    }
    if (data.containsKey('fat_g')) {
      context.handle(
        _fatGMeta,
        fatG.isAcceptableOrUnknown(data['fat_g']!, _fatGMeta),
      );
    } else if (isInserting) {
      context.missing(_fatGMeta);
    }
    if (data.containsKey('carbs_g')) {
      context.handle(
        _carbsGMeta,
        carbsG.isAcceptableOrUnknown(data['carbs_g']!, _carbsGMeta),
      );
    } else if (isInserting) {
      context.missing(_carbsGMeta);
    }
    if (data.containsKey('maintenance_kcal')) {
      context.handle(
        _maintenanceKcalMeta,
        maintenanceKcal.isAcceptableOrUnknown(
          data['maintenance_kcal']!,
          _maintenanceKcalMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_maintenanceKcalMeta);
    }
    if (data.containsKey('method')) {
      context.handle(
        _methodMeta,
        method.isAcceptableOrUnknown(data['method']!, _methodMeta),
      );
    } else if (isInserting) {
      context.missing(_methodMeta);
    }
    if (data.containsKey('explanation_json')) {
      context.handle(
        _explanationJsonMeta,
        explanationJson.isAcceptableOrUnknown(
          data['explanation_json']!,
          _explanationJsonMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TargetRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TargetRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      effectiveFrom: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}effective_from'],
      )!,
      kcal: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}kcal'],
      )!,
      proteinG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}protein_g'],
      )!,
      fatG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fat_g'],
      )!,
      carbsG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}carbs_g'],
      )!,
      maintenanceKcal: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}maintenance_kcal'],
      )!,
      method: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}method'],
      )!,
      explanationJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}explanation_json'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TargetHistoryTable createAlias(String alias) {
    return $TargetHistoryTable(attachedDatabase, alias);
  }
}

class TargetRecord extends DataClass implements Insertable<TargetRecord> {
  final int id;

  /// Day key from which this target applies; one row per day.
  final String effectiveFrom;
  final double kcal;
  final double proteinG;
  final double fatG;
  final double carbsG;
  final double maintenanceKcal;
  final int method;

  /// JSON with the numbers behind the recommendation (shown on check-in).
  final String? explanationJson;
  final DateTime createdAt;
  const TargetRecord({
    required this.id,
    required this.effectiveFrom,
    required this.kcal,
    required this.proteinG,
    required this.fatG,
    required this.carbsG,
    required this.maintenanceKcal,
    required this.method,
    this.explanationJson,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['effective_from'] = Variable<String>(effectiveFrom);
    map['kcal'] = Variable<double>(kcal);
    map['protein_g'] = Variable<double>(proteinG);
    map['fat_g'] = Variable<double>(fatG);
    map['carbs_g'] = Variable<double>(carbsG);
    map['maintenance_kcal'] = Variable<double>(maintenanceKcal);
    map['method'] = Variable<int>(method);
    if (!nullToAbsent || explanationJson != null) {
      map['explanation_json'] = Variable<String>(explanationJson);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TargetHistoryCompanion toCompanion(bool nullToAbsent) {
    return TargetHistoryCompanion(
      id: Value(id),
      effectiveFrom: Value(effectiveFrom),
      kcal: Value(kcal),
      proteinG: Value(proteinG),
      fatG: Value(fatG),
      carbsG: Value(carbsG),
      maintenanceKcal: Value(maintenanceKcal),
      method: Value(method),
      explanationJson: explanationJson == null && nullToAbsent
          ? const Value.absent()
          : Value(explanationJson),
      createdAt: Value(createdAt),
    );
  }

  factory TargetRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TargetRecord(
      id: serializer.fromJson<int>(json['id']),
      effectiveFrom: serializer.fromJson<String>(json['effectiveFrom']),
      kcal: serializer.fromJson<double>(json['kcal']),
      proteinG: serializer.fromJson<double>(json['proteinG']),
      fatG: serializer.fromJson<double>(json['fatG']),
      carbsG: serializer.fromJson<double>(json['carbsG']),
      maintenanceKcal: serializer.fromJson<double>(json['maintenanceKcal']),
      method: serializer.fromJson<int>(json['method']),
      explanationJson: serializer.fromJson<String?>(json['explanationJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'effectiveFrom': serializer.toJson<String>(effectiveFrom),
      'kcal': serializer.toJson<double>(kcal),
      'proteinG': serializer.toJson<double>(proteinG),
      'fatG': serializer.toJson<double>(fatG),
      'carbsG': serializer.toJson<double>(carbsG),
      'maintenanceKcal': serializer.toJson<double>(maintenanceKcal),
      'method': serializer.toJson<int>(method),
      'explanationJson': serializer.toJson<String?>(explanationJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TargetRecord copyWith({
    int? id,
    String? effectiveFrom,
    double? kcal,
    double? proteinG,
    double? fatG,
    double? carbsG,
    double? maintenanceKcal,
    int? method,
    Value<String?> explanationJson = const Value.absent(),
    DateTime? createdAt,
  }) => TargetRecord(
    id: id ?? this.id,
    effectiveFrom: effectiveFrom ?? this.effectiveFrom,
    kcal: kcal ?? this.kcal,
    proteinG: proteinG ?? this.proteinG,
    fatG: fatG ?? this.fatG,
    carbsG: carbsG ?? this.carbsG,
    maintenanceKcal: maintenanceKcal ?? this.maintenanceKcal,
    method: method ?? this.method,
    explanationJson: explanationJson.present
        ? explanationJson.value
        : this.explanationJson,
    createdAt: createdAt ?? this.createdAt,
  );
  TargetRecord copyWithCompanion(TargetHistoryCompanion data) {
    return TargetRecord(
      id: data.id.present ? data.id.value : this.id,
      effectiveFrom: data.effectiveFrom.present
          ? data.effectiveFrom.value
          : this.effectiveFrom,
      kcal: data.kcal.present ? data.kcal.value : this.kcal,
      proteinG: data.proteinG.present ? data.proteinG.value : this.proteinG,
      fatG: data.fatG.present ? data.fatG.value : this.fatG,
      carbsG: data.carbsG.present ? data.carbsG.value : this.carbsG,
      maintenanceKcal: data.maintenanceKcal.present
          ? data.maintenanceKcal.value
          : this.maintenanceKcal,
      method: data.method.present ? data.method.value : this.method,
      explanationJson: data.explanationJson.present
          ? data.explanationJson.value
          : this.explanationJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TargetRecord(')
          ..write('id: $id, ')
          ..write('effectiveFrom: $effectiveFrom, ')
          ..write('kcal: $kcal, ')
          ..write('proteinG: $proteinG, ')
          ..write('fatG: $fatG, ')
          ..write('carbsG: $carbsG, ')
          ..write('maintenanceKcal: $maintenanceKcal, ')
          ..write('method: $method, ')
          ..write('explanationJson: $explanationJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    effectiveFrom,
    kcal,
    proteinG,
    fatG,
    carbsG,
    maintenanceKcal,
    method,
    explanationJson,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TargetRecord &&
          other.id == this.id &&
          other.effectiveFrom == this.effectiveFrom &&
          other.kcal == this.kcal &&
          other.proteinG == this.proteinG &&
          other.fatG == this.fatG &&
          other.carbsG == this.carbsG &&
          other.maintenanceKcal == this.maintenanceKcal &&
          other.method == this.method &&
          other.explanationJson == this.explanationJson &&
          other.createdAt == this.createdAt);
}

class TargetHistoryCompanion extends UpdateCompanion<TargetRecord> {
  final Value<int> id;
  final Value<String> effectiveFrom;
  final Value<double> kcal;
  final Value<double> proteinG;
  final Value<double> fatG;
  final Value<double> carbsG;
  final Value<double> maintenanceKcal;
  final Value<int> method;
  final Value<String?> explanationJson;
  final Value<DateTime> createdAt;
  const TargetHistoryCompanion({
    this.id = const Value.absent(),
    this.effectiveFrom = const Value.absent(),
    this.kcal = const Value.absent(),
    this.proteinG = const Value.absent(),
    this.fatG = const Value.absent(),
    this.carbsG = const Value.absent(),
    this.maintenanceKcal = const Value.absent(),
    this.method = const Value.absent(),
    this.explanationJson = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  TargetHistoryCompanion.insert({
    this.id = const Value.absent(),
    required String effectiveFrom,
    required double kcal,
    required double proteinG,
    required double fatG,
    required double carbsG,
    required double maintenanceKcal,
    required int method,
    this.explanationJson = const Value.absent(),
    required DateTime createdAt,
  }) : effectiveFrom = Value(effectiveFrom),
       kcal = Value(kcal),
       proteinG = Value(proteinG),
       fatG = Value(fatG),
       carbsG = Value(carbsG),
       maintenanceKcal = Value(maintenanceKcal),
       method = Value(method),
       createdAt = Value(createdAt);
  static Insertable<TargetRecord> custom({
    Expression<int>? id,
    Expression<String>? effectiveFrom,
    Expression<double>? kcal,
    Expression<double>? proteinG,
    Expression<double>? fatG,
    Expression<double>? carbsG,
    Expression<double>? maintenanceKcal,
    Expression<int>? method,
    Expression<String>? explanationJson,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (effectiveFrom != null) 'effective_from': effectiveFrom,
      if (kcal != null) 'kcal': kcal,
      if (proteinG != null) 'protein_g': proteinG,
      if (fatG != null) 'fat_g': fatG,
      if (carbsG != null) 'carbs_g': carbsG,
      if (maintenanceKcal != null) 'maintenance_kcal': maintenanceKcal,
      if (method != null) 'method': method,
      if (explanationJson != null) 'explanation_json': explanationJson,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  TargetHistoryCompanion copyWith({
    Value<int>? id,
    Value<String>? effectiveFrom,
    Value<double>? kcal,
    Value<double>? proteinG,
    Value<double>? fatG,
    Value<double>? carbsG,
    Value<double>? maintenanceKcal,
    Value<int>? method,
    Value<String?>? explanationJson,
    Value<DateTime>? createdAt,
  }) {
    return TargetHistoryCompanion(
      id: id ?? this.id,
      effectiveFrom: effectiveFrom ?? this.effectiveFrom,
      kcal: kcal ?? this.kcal,
      proteinG: proteinG ?? this.proteinG,
      fatG: fatG ?? this.fatG,
      carbsG: carbsG ?? this.carbsG,
      maintenanceKcal: maintenanceKcal ?? this.maintenanceKcal,
      method: method ?? this.method,
      explanationJson: explanationJson ?? this.explanationJson,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (effectiveFrom.present) {
      map['effective_from'] = Variable<String>(effectiveFrom.value);
    }
    if (kcal.present) {
      map['kcal'] = Variable<double>(kcal.value);
    }
    if (proteinG.present) {
      map['protein_g'] = Variable<double>(proteinG.value);
    }
    if (fatG.present) {
      map['fat_g'] = Variable<double>(fatG.value);
    }
    if (carbsG.present) {
      map['carbs_g'] = Variable<double>(carbsG.value);
    }
    if (maintenanceKcal.present) {
      map['maintenance_kcal'] = Variable<double>(maintenanceKcal.value);
    }
    if (method.present) {
      map['method'] = Variable<int>(method.value);
    }
    if (explanationJson.present) {
      map['explanation_json'] = Variable<String>(explanationJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TargetHistoryCompanion(')
          ..write('id: $id, ')
          ..write('effectiveFrom: $effectiveFrom, ')
          ..write('kcal: $kcal, ')
          ..write('proteinG: $proteinG, ')
          ..write('fatG: $fatG, ')
          ..write('carbsG: $carbsG, ')
          ..write('maintenanceKcal: $maintenanceKcal, ')
          ..write('method: $method, ')
          ..write('explanationJson: $explanationJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $KeyValuesTable extends KeyValues
    with TableInfo<$KeyValuesTable, KeyValue> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KeyValuesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'key_values';
  @override
  VerificationContext validateIntegrity(
    Insertable<KeyValue> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  KeyValue map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KeyValue(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $KeyValuesTable createAlias(String alias) {
    return $KeyValuesTable(attachedDatabase, alias);
  }
}

class KeyValue extends DataClass implements Insertable<KeyValue> {
  final String key;
  final String value;
  const KeyValue({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  KeyValuesCompanion toCompanion(bool nullToAbsent) {
    return KeyValuesCompanion(key: Value(key), value: Value(value));
  }

  factory KeyValue.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KeyValue(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  KeyValue copyWith({String? key, String? value}) =>
      KeyValue(key: key ?? this.key, value: value ?? this.value);
  KeyValue copyWithCompanion(KeyValuesCompanion data) {
    return KeyValue(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KeyValue(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KeyValue && other.key == this.key && other.value == this.value);
}

class KeyValuesCompanion extends UpdateCompanion<KeyValue> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const KeyValuesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KeyValuesCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<KeyValue> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KeyValuesCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return KeyValuesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KeyValuesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ProfilesTable profiles = $ProfilesTable(this);
  late final $FoodsTable foods = $FoodsTable(this);
  late final $FoodLogEntriesTable foodLogEntries = $FoodLogEntriesTable(this);
  late final $SavedMealsTable savedMeals = $SavedMealsTable(this);
  late final $SavedMealItemsTable savedMealItems = $SavedMealItemsTable(this);
  late final $WeighInsTable weighIns = $WeighInsTable(this);
  late final $DayStatusesTable dayStatuses = $DayStatusesTable(this);
  late final $DailyStepsTable dailySteps = $DailyStepsTable(this);
  late final $WorkoutsTable workouts = $WorkoutsTable(this);
  late final $TargetHistoryTable targetHistory = $TargetHistoryTable(this);
  late final $KeyValuesTable keyValues = $KeyValuesTable(this);
  late final Index foodLogDayIdx = Index(
    'food_log_day_idx',
    'CREATE INDEX food_log_day_idx ON food_log_entries (day_key)',
  );
  late final Index workoutsDayIdx = Index(
    'workouts_day_idx',
    'CREATE INDEX workouts_day_idx ON workouts (day_key)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    profiles,
    foods,
    foodLogEntries,
    savedMeals,
    savedMealItems,
    weighIns,
    dayStatuses,
    dailySteps,
    workouts,
    targetHistory,
    keyValues,
    foodLogDayIdx,
    workoutsDayIdx,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'saved_meals',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('saved_meal_items', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$ProfilesTableCreateCompanionBuilder = ProfilesCompanion Function({
  Value<int> id,
  required int sex,
  required DateTime birthDate,
  required double heightCm,
  required int activityLevel,
  required double goalWeightKg,
  Value<double> weeklyRatePct,
  Value<double> proteinPerKg,
  Value<int> checkInWeekday,
  required DateTime updatedAt,
});
typedef $$ProfilesTableUpdateCompanionBuilder = ProfilesCompanion Function({
  Value<int> id,
  Value<int> sex,
  Value<DateTime> birthDate,
  Value<double> heightCm,
  Value<int> activityLevel,
  Value<double> goalWeightKg,
  Value<double> weeklyRatePct,
  Value<double> proteinPerKg,
  Value<int> checkInWeekday,
  Value<DateTime> updatedAt,
});

class $$ProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sex => $composableBuilder(
    column: $table.sex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get birthDate => $composableBuilder(
    column: $table.birthDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get heightCm => $composableBuilder(
    column: $table.heightCm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get activityLevel => $composableBuilder(
    column: $table.activityLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get goalWeightKg => $composableBuilder(
    column: $table.goalWeightKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weeklyRatePct => $composableBuilder(
    column: $table.weeklyRatePct,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get proteinPerKg => $composableBuilder(
    column: $table.proteinPerKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get checkInWeekday => $composableBuilder(
    column: $table.checkInWeekday,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sex => $composableBuilder(
    column: $table.sex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get birthDate => $composableBuilder(
    column: $table.birthDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get heightCm => $composableBuilder(
    column: $table.heightCm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get activityLevel => $composableBuilder(
    column: $table.activityLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get goalWeightKg => $composableBuilder(
    column: $table.goalWeightKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weeklyRatePct => $composableBuilder(
    column: $table.weeklyRatePct,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get proteinPerKg => $composableBuilder(
    column: $table.proteinPerKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get checkInWeekday => $composableBuilder(
    column: $table.checkInWeekday,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sex =>
      $composableBuilder(column: $table.sex, builder: (column) => column);

  GeneratedColumn<DateTime> get birthDate =>
      $composableBuilder(column: $table.birthDate, builder: (column) => column);

  GeneratedColumn<double> get heightCm =>
      $composableBuilder(column: $table.heightCm, builder: (column) => column);

  GeneratedColumn<int> get activityLevel => $composableBuilder(
    column: $table.activityLevel,
    builder: (column) => column,
  );

  GeneratedColumn<double> get goalWeightKg => $composableBuilder(
    column: $table.goalWeightKg,
    builder: (column) => column,
  );

  GeneratedColumn<double> get weeklyRatePct => $composableBuilder(
    column: $table.weeklyRatePct,
    builder: (column) => column,
  );

  GeneratedColumn<double> get proteinPerKg => $composableBuilder(
    column: $table.proteinPerKg,
    builder: (column) => column,
  );

  GeneratedColumn<int> get checkInWeekday => $composableBuilder(
    column: $table.checkInWeekday,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProfilesTable,
          Profile,
          $$ProfilesTableFilterComposer,
          $$ProfilesTableOrderingComposer,
          $$ProfilesTableAnnotationComposer,
          $$ProfilesTableCreateCompanionBuilder,
          $$ProfilesTableUpdateCompanionBuilder,
          (Profile, BaseReferences<_$AppDatabase, $ProfilesTable, Profile>),
          Profile,
          PrefetchHooks Function()
        > {
  $$ProfilesTableTableManager(_$AppDatabase db, $ProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> sex = const Value.absent(),
                Value<DateTime> birthDate = const Value.absent(),
                Value<double> heightCm = const Value.absent(),
                Value<int> activityLevel = const Value.absent(),
                Value<double> goalWeightKg = const Value.absent(),
                Value<double> weeklyRatePct = const Value.absent(),
                Value<double> proteinPerKg = const Value.absent(),
                Value<int> checkInWeekday = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ProfilesCompanion(
                id: id,
                sex: sex,
                birthDate: birthDate,
                heightCm: heightCm,
                activityLevel: activityLevel,
                goalWeightKg: goalWeightKg,
                weeklyRatePct: weeklyRatePct,
                proteinPerKg: proteinPerKg,
                checkInWeekday: checkInWeekday,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int sex,
                required DateTime birthDate,
                required double heightCm,
                required int activityLevel,
                required double goalWeightKg,
                Value<double> weeklyRatePct = const Value.absent(),
                Value<double> proteinPerKg = const Value.absent(),
                Value<int> checkInWeekday = const Value.absent(),
                required DateTime updatedAt,
              }) => ProfilesCompanion.insert(
                id: id,
                sex: sex,
                birthDate: birthDate,
                heightCm: heightCm,
                activityLevel: activityLevel,
                goalWeightKg: goalWeightKg,
                weeklyRatePct: weeklyRatePct,
                proteinPerKg: proteinPerKg,
                checkInWeekday: checkInWeekday,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProfilesTable, Profile>(table),
                  BaseReferences<_$AppDatabase, $ProfilesTable, Profile>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProfilesTable,
      Profile,
      $$ProfilesTableFilterComposer,
      $$ProfilesTableOrderingComposer,
      $$ProfilesTableAnnotationComposer,
      $$ProfilesTableCreateCompanionBuilder,
      $$ProfilesTableUpdateCompanionBuilder,
      (Profile, BaseReferences<_$AppDatabase, $ProfilesTable, Profile>),
      Profile,
      PrefetchHooks Function()
    >;
typedef $$FoodsTableCreateCompanionBuilder = FoodsCompanion Function({
  Value<int> id,
  required String source,
  Value<String?> externalId,
  Value<String?> barcode,
  required String name,
  Value<String?> brand,
  required double kcalPer100g,
  required double proteinPer100g,
  required double fatPer100g,
  required double carbsPer100g,
  Value<String?> servingName,
  Value<double?> servingGrams,
  Value<bool> isFavorite,
  Value<DateTime?> lastUsedAt,
  required DateTime createdAt,
});
typedef $$FoodsTableUpdateCompanionBuilder = FoodsCompanion Function({
  Value<int> id,
  Value<String> source,
  Value<String?> externalId,
  Value<String?> barcode,
  Value<String> name,
  Value<String?> brand,
  Value<double> kcalPer100g,
  Value<double> proteinPer100g,
  Value<double> fatPer100g,
  Value<double> carbsPer100g,
  Value<String?> servingName,
  Value<double?> servingGrams,
  Value<bool> isFavorite,
  Value<DateTime?> lastUsedAt,
  Value<DateTime> createdAt,
});

final class $$FoodsTableReferences
    extends BaseReferences<_$AppDatabase, $FoodsTable, Food> {
  $$FoodsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$FoodLogEntriesTable, List<FoodLogEntry>>
  _foodLogEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.foodLogEntries,
    aliasName: 'foods__id__food_log_entries__food_id',
  );

  $$FoodLogEntriesTableProcessedTableManager get foodLogEntriesRefs {
    final manager = $$FoodLogEntriesTableTableManager(
      $_db,
      $_db.foodLogEntries,
    ).filter((f) => f.foodId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_foodLogEntriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SavedMealItemsTable, List<SavedMealItem>>
  _savedMealItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.savedMealItems,
    aliasName: 'foods__id__saved_meal_items__food_id',
  );

  $$SavedMealItemsTableProcessedTableManager get savedMealItemsRefs {
    final manager = $$SavedMealItemsTableTableManager(
      $_db,
      $_db.savedMealItems,
    ).filter((f) => f.foodId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_savedMealItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FoodsTableFilterComposer extends Composer<_$AppDatabase, $FoodsTable> {
  $$FoodsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get barcode => $composableBuilder(
    column: $table.barcode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get brand => $composableBuilder(
    column: $table.brand,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get kcalPer100g => $composableBuilder(
    column: $table.kcalPer100g,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get proteinPer100g => $composableBuilder(
    column: $table.proteinPer100g,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fatPer100g => $composableBuilder(
    column: $table.fatPer100g,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get carbsPer100g => $composableBuilder(
    column: $table.carbsPer100g,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get servingName => $composableBuilder(
    column: $table.servingName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get servingGrams => $composableBuilder(
    column: $table.servingGrams,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> foodLogEntriesRefs(
    Expression<bool> Function($$FoodLogEntriesTableFilterComposer f) f,
  ) {
    final $$FoodLogEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.foodLogEntries,
      getReferencedColumn: (t) => t.foodId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodLogEntriesTableFilterComposer(
            $db: $db,
            $table: $db.foodLogEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> savedMealItemsRefs(
    Expression<bool> Function($$SavedMealItemsTableFilterComposer f) f,
  ) {
    final $$SavedMealItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.savedMealItems,
      getReferencedColumn: (t) => t.foodId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedMealItemsTableFilterComposer(
            $db: $db,
            $table: $db.savedMealItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FoodsTableOrderingComposer
    extends Composer<_$AppDatabase, $FoodsTable> {
  $$FoodsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get barcode => $composableBuilder(
    column: $table.barcode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get brand => $composableBuilder(
    column: $table.brand,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get kcalPer100g => $composableBuilder(
    column: $table.kcalPer100g,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get proteinPer100g => $composableBuilder(
    column: $table.proteinPer100g,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fatPer100g => $composableBuilder(
    column: $table.fatPer100g,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get carbsPer100g => $composableBuilder(
    column: $table.carbsPer100g,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get servingName => $composableBuilder(
    column: $table.servingName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get servingGrams => $composableBuilder(
    column: $table.servingGrams,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FoodsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FoodsTable> {
  $$FoodsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get barcode =>
      $composableBuilder(column: $table.barcode, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get brand =>
      $composableBuilder(column: $table.brand, builder: (column) => column);

  GeneratedColumn<double> get kcalPer100g => $composableBuilder(
    column: $table.kcalPer100g,
    builder: (column) => column,
  );

  GeneratedColumn<double> get proteinPer100g => $composableBuilder(
    column: $table.proteinPer100g,
    builder: (column) => column,
  );

  GeneratedColumn<double> get fatPer100g => $composableBuilder(
    column: $table.fatPer100g,
    builder: (column) => column,
  );

  GeneratedColumn<double> get carbsPer100g => $composableBuilder(
    column: $table.carbsPer100g,
    builder: (column) => column,
  );

  GeneratedColumn<String> get servingName => $composableBuilder(
    column: $table.servingName,
    builder: (column) => column,
  );

  GeneratedColumn<double> get servingGrams => $composableBuilder(
    column: $table.servingGrams,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> foodLogEntriesRefs<T extends Object>(
    Expression<T> Function($$FoodLogEntriesTableAnnotationComposer a) f,
  ) {
    final $$FoodLogEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.foodLogEntries,
      getReferencedColumn: (t) => t.foodId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodLogEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.foodLogEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> savedMealItemsRefs<T extends Object>(
    Expression<T> Function($$SavedMealItemsTableAnnotationComposer a) f,
  ) {
    final $$SavedMealItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.savedMealItems,
      getReferencedColumn: (t) => t.foodId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedMealItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.savedMealItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FoodsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FoodsTable,
          Food,
          $$FoodsTableFilterComposer,
          $$FoodsTableOrderingComposer,
          $$FoodsTableAnnotationComposer,
          $$FoodsTableCreateCompanionBuilder,
          $$FoodsTableUpdateCompanionBuilder,
          (Food, $$FoodsTableReferences),
          Food,
          PrefetchHooks Function({
            bool foodLogEntriesRefs,
            bool savedMealItemsRefs,
          })
        > {
  $$FoodsTableTableManager(_$AppDatabase db, $FoodsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FoodsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FoodsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FoodsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> externalId = const Value.absent(),
                Value<String?> barcode = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> brand = const Value.absent(),
                Value<double> kcalPer100g = const Value.absent(),
                Value<double> proteinPer100g = const Value.absent(),
                Value<double> fatPer100g = const Value.absent(),
                Value<double> carbsPer100g = const Value.absent(),
                Value<String?> servingName = const Value.absent(),
                Value<double?> servingGrams = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<DateTime?> lastUsedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => FoodsCompanion(
                id: id,
                source: source,
                externalId: externalId,
                barcode: barcode,
                name: name,
                brand: brand,
                kcalPer100g: kcalPer100g,
                proteinPer100g: proteinPer100g,
                fatPer100g: fatPer100g,
                carbsPer100g: carbsPer100g,
                servingName: servingName,
                servingGrams: servingGrams,
                isFavorite: isFavorite,
                lastUsedAt: lastUsedAt,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String source,
                Value<String?> externalId = const Value.absent(),
                Value<String?> barcode = const Value.absent(),
                required String name,
                Value<String?> brand = const Value.absent(),
                required double kcalPer100g,
                required double proteinPer100g,
                required double fatPer100g,
                required double carbsPer100g,
                Value<String?> servingName = const Value.absent(),
                Value<double?> servingGrams = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<DateTime?> lastUsedAt = const Value.absent(),
                required DateTime createdAt,
              }) => FoodsCompanion.insert(
                id: id,
                source: source,
                externalId: externalId,
                barcode: barcode,
                name: name,
                brand: brand,
                kcalPer100g: kcalPer100g,
                proteinPer100g: proteinPer100g,
                fatPer100g: fatPer100g,
                carbsPer100g: carbsPer100g,
                servingName: servingName,
                servingGrams: servingGrams,
                isFavorite: isFavorite,
                lastUsedAt: lastUsedAt,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FoodsTable, Food>(table),
                  $$FoodsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({foodLogEntriesRefs = false, savedMealItemsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (foodLogEntriesRefs) db.foodLogEntries,
                    if (savedMealItemsRefs) db.savedMealItems,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (foodLogEntriesRefs)
                        await $_getPrefetchedData<
                          Food,
                          $FoodsTable,
                          FoodLogEntry
                        >(
                          currentTable: table,
                          referencedTable: $$FoodsTableReferences
                              ._foodLogEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FoodsTableReferences(
                                db,
                                table,
                                p0,
                              ).foodLogEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.foodId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (savedMealItemsRefs)
                        await $_getPrefetchedData<
                          Food,
                          $FoodsTable,
                          SavedMealItem
                        >(
                          currentTable: table,
                          referencedTable: $$FoodsTableReferences
                              ._savedMealItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FoodsTableReferences(
                                db,
                                table,
                                p0,
                              ).savedMealItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.foodId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$FoodsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FoodsTable,
      Food,
      $$FoodsTableFilterComposer,
      $$FoodsTableOrderingComposer,
      $$FoodsTableAnnotationComposer,
      $$FoodsTableCreateCompanionBuilder,
      $$FoodsTableUpdateCompanionBuilder,
      (Food, $$FoodsTableReferences),
      Food,
      PrefetchHooks Function({bool foodLogEntriesRefs, bool savedMealItemsRefs})
    >;
typedef $$FoodLogEntriesTableCreateCompanionBuilder =
    FoodLogEntriesCompanion Function({
      Value<int> id,
      required String dayKey,
      required int meal,
      required int foodId,
      required double grams,
      required double kcal,
      required double proteinG,
      required double fatG,
      required double carbsG,
      required DateTime createdAt,
    });
typedef $$FoodLogEntriesTableUpdateCompanionBuilder =
    FoodLogEntriesCompanion Function({
      Value<int> id,
      Value<String> dayKey,
      Value<int> meal,
      Value<int> foodId,
      Value<double> grams,
      Value<double> kcal,
      Value<double> proteinG,
      Value<double> fatG,
      Value<double> carbsG,
      Value<DateTime> createdAt,
    });

final class $$FoodLogEntriesTableReferences
    extends BaseReferences<_$AppDatabase, $FoodLogEntriesTable, FoodLogEntry> {
  $$FoodLogEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $FoodsTable _foodIdTable(_$AppDatabase db) =>
      db.foods.createAlias('food_log_entries__food_id__foods__id');

  $$FoodsTableProcessedTableManager get foodId {
    final $_column = $_itemColumn<int>('food_id')!;

    final manager = $$FoodsTableTableManager(
      $_db,
      $_db.foods,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_foodIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FoodLogEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $FoodLogEntriesTable> {
  $$FoodLogEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dayKey => $composableBuilder(
    column: $table.dayKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get meal => $composableBuilder(
    column: $table.meal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get grams => $composableBuilder(
    column: $table.grams,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get kcal => $composableBuilder(
    column: $table.kcal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get proteinG => $composableBuilder(
    column: $table.proteinG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fatG => $composableBuilder(
    column: $table.fatG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get carbsG => $composableBuilder(
    column: $table.carbsG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$FoodsTableFilterComposer get foodId {
    final $$FoodsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.foodId,
      referencedTable: $db.foods,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodsTableFilterComposer(
            $db: $db,
            $table: $db.foods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FoodLogEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $FoodLogEntriesTable> {
  $$FoodLogEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dayKey => $composableBuilder(
    column: $table.dayKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get meal => $composableBuilder(
    column: $table.meal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get grams => $composableBuilder(
    column: $table.grams,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get kcal => $composableBuilder(
    column: $table.kcal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get proteinG => $composableBuilder(
    column: $table.proteinG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fatG => $composableBuilder(
    column: $table.fatG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get carbsG => $composableBuilder(
    column: $table.carbsG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$FoodsTableOrderingComposer get foodId {
    final $$FoodsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.foodId,
      referencedTable: $db.foods,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodsTableOrderingComposer(
            $db: $db,
            $table: $db.foods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FoodLogEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FoodLogEntriesTable> {
  $$FoodLogEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get dayKey =>
      $composableBuilder(column: $table.dayKey, builder: (column) => column);

  GeneratedColumn<int> get meal =>
      $composableBuilder(column: $table.meal, builder: (column) => column);

  GeneratedColumn<double> get grams =>
      $composableBuilder(column: $table.grams, builder: (column) => column);

  GeneratedColumn<double> get kcal =>
      $composableBuilder(column: $table.kcal, builder: (column) => column);

  GeneratedColumn<double> get proteinG =>
      $composableBuilder(column: $table.proteinG, builder: (column) => column);

  GeneratedColumn<double> get fatG =>
      $composableBuilder(column: $table.fatG, builder: (column) => column);

  GeneratedColumn<double> get carbsG =>
      $composableBuilder(column: $table.carbsG, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$FoodsTableAnnotationComposer get foodId {
    final $$FoodsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.foodId,
      referencedTable: $db.foods,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodsTableAnnotationComposer(
            $db: $db,
            $table: $db.foods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FoodLogEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FoodLogEntriesTable,
          FoodLogEntry,
          $$FoodLogEntriesTableFilterComposer,
          $$FoodLogEntriesTableOrderingComposer,
          $$FoodLogEntriesTableAnnotationComposer,
          $$FoodLogEntriesTableCreateCompanionBuilder,
          $$FoodLogEntriesTableUpdateCompanionBuilder,
          (FoodLogEntry, $$FoodLogEntriesTableReferences),
          FoodLogEntry,
          PrefetchHooks Function({bool foodId})
        > {
  $$FoodLogEntriesTableTableManager(
    _$AppDatabase db,
    $FoodLogEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FoodLogEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FoodLogEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FoodLogEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> dayKey = const Value.absent(),
                Value<int> meal = const Value.absent(),
                Value<int> foodId = const Value.absent(),
                Value<double> grams = const Value.absent(),
                Value<double> kcal = const Value.absent(),
                Value<double> proteinG = const Value.absent(),
                Value<double> fatG = const Value.absent(),
                Value<double> carbsG = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => FoodLogEntriesCompanion(
                id: id,
                dayKey: dayKey,
                meal: meal,
                foodId: foodId,
                grams: grams,
                kcal: kcal,
                proteinG: proteinG,
                fatG: fatG,
                carbsG: carbsG,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String dayKey,
                required int meal,
                required int foodId,
                required double grams,
                required double kcal,
                required double proteinG,
                required double fatG,
                required double carbsG,
                required DateTime createdAt,
              }) => FoodLogEntriesCompanion.insert(
                id: id,
                dayKey: dayKey,
                meal: meal,
                foodId: foodId,
                grams: grams,
                kcal: kcal,
                proteinG: proteinG,
                fatG: fatG,
                carbsG: carbsG,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FoodLogEntriesTable, FoodLogEntry>(table),
                  $$FoodLogEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({foodId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (foodId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.foodId,
                        referencedTable: $$FoodLogEntriesTableReferences
                            ._foodIdTable(db),
                        referencedColumn: $$FoodLogEntriesTableReferences
                            ._foodIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$FoodLogEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FoodLogEntriesTable,
      FoodLogEntry,
      $$FoodLogEntriesTableFilterComposer,
      $$FoodLogEntriesTableOrderingComposer,
      $$FoodLogEntriesTableAnnotationComposer,
      $$FoodLogEntriesTableCreateCompanionBuilder,
      $$FoodLogEntriesTableUpdateCompanionBuilder,
      (FoodLogEntry, $$FoodLogEntriesTableReferences),
      FoodLogEntry,
      PrefetchHooks Function({bool foodId})
    >;
typedef $$SavedMealsTableCreateCompanionBuilder = SavedMealsCompanion Function({
  Value<int> id,
  required String name,
  required DateTime createdAt,
});
typedef $$SavedMealsTableUpdateCompanionBuilder = SavedMealsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<DateTime> createdAt,
});

final class $$SavedMealsTableReferences
    extends BaseReferences<_$AppDatabase, $SavedMealsTable, SavedMeal> {
  $$SavedMealsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SavedMealItemsTable, List<SavedMealItem>>
  _savedMealItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.savedMealItems,
    aliasName: 'saved_meals__id__saved_meal_items__saved_meal_id',
  );

  $$SavedMealItemsTableProcessedTableManager get savedMealItemsRefs {
    final manager = $$SavedMealItemsTableTableManager(
      $_db,
      $_db.savedMealItems,
    ).filter((f) => f.savedMealId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_savedMealItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SavedMealsTableFilterComposer
    extends Composer<_$AppDatabase, $SavedMealsTable> {
  $$SavedMealsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> savedMealItemsRefs(
    Expression<bool> Function($$SavedMealItemsTableFilterComposer f) f,
  ) {
    final $$SavedMealItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.savedMealItems,
      getReferencedColumn: (t) => t.savedMealId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedMealItemsTableFilterComposer(
            $db: $db,
            $table: $db.savedMealItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SavedMealsTableOrderingComposer
    extends Composer<_$AppDatabase, $SavedMealsTable> {
  $$SavedMealsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SavedMealsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SavedMealsTable> {
  $$SavedMealsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> savedMealItemsRefs<T extends Object>(
    Expression<T> Function($$SavedMealItemsTableAnnotationComposer a) f,
  ) {
    final $$SavedMealItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.savedMealItems,
      getReferencedColumn: (t) => t.savedMealId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedMealItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.savedMealItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SavedMealsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SavedMealsTable,
          SavedMeal,
          $$SavedMealsTableFilterComposer,
          $$SavedMealsTableOrderingComposer,
          $$SavedMealsTableAnnotationComposer,
          $$SavedMealsTableCreateCompanionBuilder,
          $$SavedMealsTableUpdateCompanionBuilder,
          (SavedMeal, $$SavedMealsTableReferences),
          SavedMeal,
          PrefetchHooks Function({bool savedMealItemsRefs})
        > {
  $$SavedMealsTableTableManager(_$AppDatabase db, $SavedMealsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavedMealsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SavedMealsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SavedMealsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) => SavedMealsCompanion(id: id, name: name, createdAt: createdAt),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required DateTime createdAt,
              }) => SavedMealsCompanion.insert(
                id: id,
                name: name,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SavedMealsTable, SavedMeal>(table),
                  $$SavedMealsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({savedMealItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (savedMealItemsRefs) db.savedMealItems,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (savedMealItemsRefs)
                    await $_getPrefetchedData<
                      SavedMeal,
                      $SavedMealsTable,
                      SavedMealItem
                    >(
                      currentTable: table,
                      referencedTable: $$SavedMealsTableReferences
                          ._savedMealItemsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$SavedMealsTableReferences(
                            db,
                            table,
                            p0,
                          ).savedMealItemsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.savedMealId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SavedMealsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SavedMealsTable,
      SavedMeal,
      $$SavedMealsTableFilterComposer,
      $$SavedMealsTableOrderingComposer,
      $$SavedMealsTableAnnotationComposer,
      $$SavedMealsTableCreateCompanionBuilder,
      $$SavedMealsTableUpdateCompanionBuilder,
      (SavedMeal, $$SavedMealsTableReferences),
      SavedMeal,
      PrefetchHooks Function({bool savedMealItemsRefs})
    >;
typedef $$SavedMealItemsTableCreateCompanionBuilder =
    SavedMealItemsCompanion Function({
      Value<int> id,
      required int savedMealId,
      required int foodId,
      required double grams,
    });
typedef $$SavedMealItemsTableUpdateCompanionBuilder =
    SavedMealItemsCompanion Function({
      Value<int> id,
      Value<int> savedMealId,
      Value<int> foodId,
      Value<double> grams,
    });

final class $$SavedMealItemsTableReferences
    extends BaseReferences<_$AppDatabase, $SavedMealItemsTable, SavedMealItem> {
  $$SavedMealItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SavedMealsTable _savedMealIdTable(_$AppDatabase db) => db.savedMeals
      .createAlias('saved_meal_items__saved_meal_id__saved_meals__id');

  $$SavedMealsTableProcessedTableManager get savedMealId {
    final $_column = $_itemColumn<int>('saved_meal_id')!;

    final manager = $$SavedMealsTableTableManager(
      $_db,
      $_db.savedMeals,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_savedMealIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $FoodsTable _foodIdTable(_$AppDatabase db) =>
      db.foods.createAlias('saved_meal_items__food_id__foods__id');

  $$FoodsTableProcessedTableManager get foodId {
    final $_column = $_itemColumn<int>('food_id')!;

    final manager = $$FoodsTableTableManager(
      $_db,
      $_db.foods,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_foodIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SavedMealItemsTableFilterComposer
    extends Composer<_$AppDatabase, $SavedMealItemsTable> {
  $$SavedMealItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get grams => $composableBuilder(
    column: $table.grams,
    builder: (column) => ColumnFilters(column),
  );

  $$SavedMealsTableFilterComposer get savedMealId {
    final $$SavedMealsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.savedMealId,
      referencedTable: $db.savedMeals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedMealsTableFilterComposer(
            $db: $db,
            $table: $db.savedMeals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$FoodsTableFilterComposer get foodId {
    final $$FoodsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.foodId,
      referencedTable: $db.foods,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodsTableFilterComposer(
            $db: $db,
            $table: $db.foods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SavedMealItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $SavedMealItemsTable> {
  $$SavedMealItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get grams => $composableBuilder(
    column: $table.grams,
    builder: (column) => ColumnOrderings(column),
  );

  $$SavedMealsTableOrderingComposer get savedMealId {
    final $$SavedMealsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.savedMealId,
      referencedTable: $db.savedMeals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedMealsTableOrderingComposer(
            $db: $db,
            $table: $db.savedMeals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$FoodsTableOrderingComposer get foodId {
    final $$FoodsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.foodId,
      referencedTable: $db.foods,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodsTableOrderingComposer(
            $db: $db,
            $table: $db.foods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SavedMealItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SavedMealItemsTable> {
  $$SavedMealItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get grams =>
      $composableBuilder(column: $table.grams, builder: (column) => column);

  $$SavedMealsTableAnnotationComposer get savedMealId {
    final $$SavedMealsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.savedMealId,
      referencedTable: $db.savedMeals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedMealsTableAnnotationComposer(
            $db: $db,
            $table: $db.savedMeals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$FoodsTableAnnotationComposer get foodId {
    final $$FoodsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.foodId,
      referencedTable: $db.foods,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodsTableAnnotationComposer(
            $db: $db,
            $table: $db.foods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SavedMealItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SavedMealItemsTable,
          SavedMealItem,
          $$SavedMealItemsTableFilterComposer,
          $$SavedMealItemsTableOrderingComposer,
          $$SavedMealItemsTableAnnotationComposer,
          $$SavedMealItemsTableCreateCompanionBuilder,
          $$SavedMealItemsTableUpdateCompanionBuilder,
          (SavedMealItem, $$SavedMealItemsTableReferences),
          SavedMealItem,
          PrefetchHooks Function({bool savedMealId, bool foodId})
        > {
  $$SavedMealItemsTableTableManager(
    _$AppDatabase db,
    $SavedMealItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavedMealItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SavedMealItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SavedMealItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> savedMealId = const Value.absent(),
                Value<int> foodId = const Value.absent(),
                Value<double> grams = const Value.absent(),
              }) => SavedMealItemsCompanion(
                id: id,
                savedMealId: savedMealId,
                foodId: foodId,
                grams: grams,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int savedMealId,
                required int foodId,
                required double grams,
              }) => SavedMealItemsCompanion.insert(
                id: id,
                savedMealId: savedMealId,
                foodId: foodId,
                grams: grams,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SavedMealItemsTable, SavedMealItem>(table),
                  $$SavedMealItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({savedMealId = false, foodId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (savedMealId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.savedMealId,
                        referencedTable: $$SavedMealItemsTableReferences
                            ._savedMealIdTable(db),
                        referencedColumn: $$SavedMealItemsTableReferences
                            ._savedMealIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (foodId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.foodId,
                        referencedTable: $$SavedMealItemsTableReferences
                            ._foodIdTable(db),
                        referencedColumn: $$SavedMealItemsTableReferences
                            ._foodIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SavedMealItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SavedMealItemsTable,
      SavedMealItem,
      $$SavedMealItemsTableFilterComposer,
      $$SavedMealItemsTableOrderingComposer,
      $$SavedMealItemsTableAnnotationComposer,
      $$SavedMealItemsTableCreateCompanionBuilder,
      $$SavedMealItemsTableUpdateCompanionBuilder,
      (SavedMealItem, $$SavedMealItemsTableReferences),
      SavedMealItem,
      PrefetchHooks Function({bool savedMealId, bool foodId})
    >;
typedef $$WeighInsTableCreateCompanionBuilder = WeighInsCompanion Function({
  required String dayKey,
  required double weightKg,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$WeighInsTableUpdateCompanionBuilder = WeighInsCompanion Function({
  Value<String> dayKey,
  Value<double> weightKg,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$WeighInsTableFilterComposer
    extends Composer<_$AppDatabase, $WeighInsTable> {
  $$WeighInsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get dayKey => $composableBuilder(
    column: $table.dayKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weightKg => $composableBuilder(
    column: $table.weightKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WeighInsTableOrderingComposer
    extends Composer<_$AppDatabase, $WeighInsTable> {
  $$WeighInsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get dayKey => $composableBuilder(
    column: $table.dayKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weightKg => $composableBuilder(
    column: $table.weightKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WeighInsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WeighInsTable> {
  $$WeighInsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get dayKey =>
      $composableBuilder(column: $table.dayKey, builder: (column) => column);

  GeneratedColumn<double> get weightKg =>
      $composableBuilder(column: $table.weightKg, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$WeighInsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WeighInsTable,
          WeighIn,
          $$WeighInsTableFilterComposer,
          $$WeighInsTableOrderingComposer,
          $$WeighInsTableAnnotationComposer,
          $$WeighInsTableCreateCompanionBuilder,
          $$WeighInsTableUpdateCompanionBuilder,
          (WeighIn, BaseReferences<_$AppDatabase, $WeighInsTable, WeighIn>),
          WeighIn,
          PrefetchHooks Function()
        > {
  $$WeighInsTableTableManager(_$AppDatabase db, $WeighInsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WeighInsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WeighInsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WeighInsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> dayKey = const Value.absent(),
                Value<double> weightKg = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WeighInsCompanion(
                dayKey: dayKey,
                weightKg: weightKg,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String dayKey,
                required double weightKg,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => WeighInsCompanion.insert(
                dayKey: dayKey,
                weightKg: weightKg,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WeighInsTable, WeighIn>(table),
                  BaseReferences<_$AppDatabase, $WeighInsTable, WeighIn>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WeighInsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WeighInsTable,
      WeighIn,
      $$WeighInsTableFilterComposer,
      $$WeighInsTableOrderingComposer,
      $$WeighInsTableAnnotationComposer,
      $$WeighInsTableCreateCompanionBuilder,
      $$WeighInsTableUpdateCompanionBuilder,
      (WeighIn, BaseReferences<_$AppDatabase, $WeighInsTable, WeighIn>),
      WeighIn,
      PrefetchHooks Function()
    >;
typedef $$DayStatusesTableCreateCompanionBuilder =
    DayStatusesCompanion Function({
      required String dayKey,
      Value<bool> fullyLogged,
      Value<int> rowid,
    });
typedef $$DayStatusesTableUpdateCompanionBuilder =
    DayStatusesCompanion Function({
      Value<String> dayKey,
      Value<bool> fullyLogged,
      Value<int> rowid,
    });

class $$DayStatusesTableFilterComposer
    extends Composer<_$AppDatabase, $DayStatusesTable> {
  $$DayStatusesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get dayKey => $composableBuilder(
    column: $table.dayKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get fullyLogged => $composableBuilder(
    column: $table.fullyLogged,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DayStatusesTableOrderingComposer
    extends Composer<_$AppDatabase, $DayStatusesTable> {
  $$DayStatusesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get dayKey => $composableBuilder(
    column: $table.dayKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get fullyLogged => $composableBuilder(
    column: $table.fullyLogged,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DayStatusesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DayStatusesTable> {
  $$DayStatusesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get dayKey =>
      $composableBuilder(column: $table.dayKey, builder: (column) => column);

  GeneratedColumn<bool> get fullyLogged => $composableBuilder(
    column: $table.fullyLogged,
    builder: (column) => column,
  );
}

class $$DayStatusesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DayStatusesTable,
          DayStatus,
          $$DayStatusesTableFilterComposer,
          $$DayStatusesTableOrderingComposer,
          $$DayStatusesTableAnnotationComposer,
          $$DayStatusesTableCreateCompanionBuilder,
          $$DayStatusesTableUpdateCompanionBuilder,
          (
            DayStatus,
            BaseReferences<_$AppDatabase, $DayStatusesTable, DayStatus>,
          ),
          DayStatus,
          PrefetchHooks Function()
        > {
  $$DayStatusesTableTableManager(_$AppDatabase db, $DayStatusesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DayStatusesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DayStatusesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DayStatusesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> dayKey = const Value.absent(),
                Value<bool> fullyLogged = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DayStatusesCompanion(
                dayKey: dayKey,
                fullyLogged: fullyLogged,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String dayKey,
                Value<bool> fullyLogged = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DayStatusesCompanion.insert(
                dayKey: dayKey,
                fullyLogged: fullyLogged,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DayStatusesTable, DayStatus>(table),
                  BaseReferences<_$AppDatabase, $DayStatusesTable, DayStatus>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DayStatusesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DayStatusesTable,
      DayStatus,
      $$DayStatusesTableFilterComposer,
      $$DayStatusesTableOrderingComposer,
      $$DayStatusesTableAnnotationComposer,
      $$DayStatusesTableCreateCompanionBuilder,
      $$DayStatusesTableUpdateCompanionBuilder,
      (DayStatus, BaseReferences<_$AppDatabase, $DayStatusesTable, DayStatus>),
      DayStatus,
      PrefetchHooks Function()
    >;
typedef $$DailyStepsTableCreateCompanionBuilder = DailyStepsCompanion Function({
  required String dayKey,
  required int steps,
  required DateTime syncedAt,
  Value<int> rowid,
});
typedef $$DailyStepsTableUpdateCompanionBuilder = DailyStepsCompanion Function({
  Value<String> dayKey,
  Value<int> steps,
  Value<DateTime> syncedAt,
  Value<int> rowid,
});

class $$DailyStepsTableFilterComposer
    extends Composer<_$AppDatabase, $DailyStepsTable> {
  $$DailyStepsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get dayKey => $composableBuilder(
    column: $table.dayKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get steps => $composableBuilder(
    column: $table.steps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DailyStepsTableOrderingComposer
    extends Composer<_$AppDatabase, $DailyStepsTable> {
  $$DailyStepsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get dayKey => $composableBuilder(
    column: $table.dayKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get steps => $composableBuilder(
    column: $table.steps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DailyStepsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DailyStepsTable> {
  $$DailyStepsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get dayKey =>
      $composableBuilder(column: $table.dayKey, builder: (column) => column);

  GeneratedColumn<int> get steps =>
      $composableBuilder(column: $table.steps, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$DailyStepsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DailyStepsTable,
          DailyStep,
          $$DailyStepsTableFilterComposer,
          $$DailyStepsTableOrderingComposer,
          $$DailyStepsTableAnnotationComposer,
          $$DailyStepsTableCreateCompanionBuilder,
          $$DailyStepsTableUpdateCompanionBuilder,
          (
            DailyStep,
            BaseReferences<_$AppDatabase, $DailyStepsTable, DailyStep>,
          ),
          DailyStep,
          PrefetchHooks Function()
        > {
  $$DailyStepsTableTableManager(_$AppDatabase db, $DailyStepsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DailyStepsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DailyStepsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DailyStepsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> dayKey = const Value.absent(),
                Value<int> steps = const Value.absent(),
                Value<DateTime> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DailyStepsCompanion(
                dayKey: dayKey,
                steps: steps,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String dayKey,
                required int steps,
                required DateTime syncedAt,
                Value<int> rowid = const Value.absent(),
              }) => DailyStepsCompanion.insert(
                dayKey: dayKey,
                steps: steps,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DailyStepsTable, DailyStep>(table),
                  BaseReferences<_$AppDatabase, $DailyStepsTable, DailyStep>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DailyStepsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DailyStepsTable,
      DailyStep,
      $$DailyStepsTableFilterComposer,
      $$DailyStepsTableOrderingComposer,
      $$DailyStepsTableAnnotationComposer,
      $$DailyStepsTableCreateCompanionBuilder,
      $$DailyStepsTableUpdateCompanionBuilder,
      (DailyStep, BaseReferences<_$AppDatabase, $DailyStepsTable, DailyStep>),
      DailyStep,
      PrefetchHooks Function()
    >;
typedef $$WorkoutsTableCreateCompanionBuilder = WorkoutsCompanion Function({
  required String id,
  required String dayKey,
  required String title,
  required DateTime startTime,
  required DateTime endTime,
  Value<String?> activityType,
  Value<String?> sourceApp,
  Value<double?> kcal,
  required DateTime syncedAt,
  Value<int> rowid,
});
typedef $$WorkoutsTableUpdateCompanionBuilder = WorkoutsCompanion Function({
  Value<String> id,
  Value<String> dayKey,
  Value<String> title,
  Value<DateTime> startTime,
  Value<DateTime> endTime,
  Value<String?> activityType,
  Value<String?> sourceApp,
  Value<double?> kcal,
  Value<DateTime> syncedAt,
  Value<int> rowid,
});

class $$WorkoutsTableFilterComposer
    extends Composer<_$AppDatabase, $WorkoutsTable> {
  $$WorkoutsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dayKey => $composableBuilder(
    column: $table.dayKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activityType => $composableBuilder(
    column: $table.activityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceApp => $composableBuilder(
    column: $table.sourceApp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get kcal => $composableBuilder(
    column: $table.kcal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WorkoutsTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkoutsTable> {
  $$WorkoutsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dayKey => $composableBuilder(
    column: $table.dayKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activityType => $composableBuilder(
    column: $table.activityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceApp => $composableBuilder(
    column: $table.sourceApp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get kcal => $composableBuilder(
    column: $table.kcal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorkoutsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkoutsTable> {
  $$WorkoutsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get dayKey =>
      $composableBuilder(column: $table.dayKey, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<DateTime> get startTime =>
      $composableBuilder(column: $table.startTime, builder: (column) => column);

  GeneratedColumn<DateTime> get endTime =>
      $composableBuilder(column: $table.endTime, builder: (column) => column);

  GeneratedColumn<String> get activityType => $composableBuilder(
    column: $table.activityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceApp =>
      $composableBuilder(column: $table.sourceApp, builder: (column) => column);

  GeneratedColumn<double> get kcal =>
      $composableBuilder(column: $table.kcal, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$WorkoutsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkoutsTable,
          Workout,
          $$WorkoutsTableFilterComposer,
          $$WorkoutsTableOrderingComposer,
          $$WorkoutsTableAnnotationComposer,
          $$WorkoutsTableCreateCompanionBuilder,
          $$WorkoutsTableUpdateCompanionBuilder,
          (Workout, BaseReferences<_$AppDatabase, $WorkoutsTable, Workout>),
          Workout,
          PrefetchHooks Function()
        > {
  $$WorkoutsTableTableManager(_$AppDatabase db, $WorkoutsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkoutsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkoutsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkoutsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> dayKey = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<DateTime> startTime = const Value.absent(),
                Value<DateTime> endTime = const Value.absent(),
                Value<String?> activityType = const Value.absent(),
                Value<String?> sourceApp = const Value.absent(),
                Value<double?> kcal = const Value.absent(),
                Value<DateTime> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkoutsCompanion(
                id: id,
                dayKey: dayKey,
                title: title,
                startTime: startTime,
                endTime: endTime,
                activityType: activityType,
                sourceApp: sourceApp,
                kcal: kcal,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String dayKey,
                required String title,
                required DateTime startTime,
                required DateTime endTime,
                Value<String?> activityType = const Value.absent(),
                Value<String?> sourceApp = const Value.absent(),
                Value<double?> kcal = const Value.absent(),
                required DateTime syncedAt,
                Value<int> rowid = const Value.absent(),
              }) => WorkoutsCompanion.insert(
                id: id,
                dayKey: dayKey,
                title: title,
                startTime: startTime,
                endTime: endTime,
                activityType: activityType,
                sourceApp: sourceApp,
                kcal: kcal,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WorkoutsTable, Workout>(table),
                  BaseReferences<_$AppDatabase, $WorkoutsTable, Workout>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WorkoutsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkoutsTable,
      Workout,
      $$WorkoutsTableFilterComposer,
      $$WorkoutsTableOrderingComposer,
      $$WorkoutsTableAnnotationComposer,
      $$WorkoutsTableCreateCompanionBuilder,
      $$WorkoutsTableUpdateCompanionBuilder,
      (Workout, BaseReferences<_$AppDatabase, $WorkoutsTable, Workout>),
      Workout,
      PrefetchHooks Function()
    >;
typedef $$TargetHistoryTableCreateCompanionBuilder =
    TargetHistoryCompanion Function({
      Value<int> id,
      required String effectiveFrom,
      required double kcal,
      required double proteinG,
      required double fatG,
      required double carbsG,
      required double maintenanceKcal,
      required int method,
      Value<String?> explanationJson,
      required DateTime createdAt,
    });
typedef $$TargetHistoryTableUpdateCompanionBuilder =
    TargetHistoryCompanion Function({
      Value<int> id,
      Value<String> effectiveFrom,
      Value<double> kcal,
      Value<double> proteinG,
      Value<double> fatG,
      Value<double> carbsG,
      Value<double> maintenanceKcal,
      Value<int> method,
      Value<String?> explanationJson,
      Value<DateTime> createdAt,
    });

class $$TargetHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $TargetHistoryTable> {
  $$TargetHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get effectiveFrom => $composableBuilder(
    column: $table.effectiveFrom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get kcal => $composableBuilder(
    column: $table.kcal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get proteinG => $composableBuilder(
    column: $table.proteinG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fatG => $composableBuilder(
    column: $table.fatG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get carbsG => $composableBuilder(
    column: $table.carbsG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get maintenanceKcal => $composableBuilder(
    column: $table.maintenanceKcal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get explanationJson => $composableBuilder(
    column: $table.explanationJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TargetHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $TargetHistoryTable> {
  $$TargetHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get effectiveFrom => $composableBuilder(
    column: $table.effectiveFrom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get kcal => $composableBuilder(
    column: $table.kcal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get proteinG => $composableBuilder(
    column: $table.proteinG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fatG => $composableBuilder(
    column: $table.fatG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get carbsG => $composableBuilder(
    column: $table.carbsG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get maintenanceKcal => $composableBuilder(
    column: $table.maintenanceKcal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get explanationJson => $composableBuilder(
    column: $table.explanationJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TargetHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $TargetHistoryTable> {
  $$TargetHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get effectiveFrom => $composableBuilder(
    column: $table.effectiveFrom,
    builder: (column) => column,
  );

  GeneratedColumn<double> get kcal =>
      $composableBuilder(column: $table.kcal, builder: (column) => column);

  GeneratedColumn<double> get proteinG =>
      $composableBuilder(column: $table.proteinG, builder: (column) => column);

  GeneratedColumn<double> get fatG =>
      $composableBuilder(column: $table.fatG, builder: (column) => column);

  GeneratedColumn<double> get carbsG =>
      $composableBuilder(column: $table.carbsG, builder: (column) => column);

  GeneratedColumn<double> get maintenanceKcal => $composableBuilder(
    column: $table.maintenanceKcal,
    builder: (column) => column,
  );

  GeneratedColumn<int> get method =>
      $composableBuilder(column: $table.method, builder: (column) => column);

  GeneratedColumn<String> get explanationJson => $composableBuilder(
    column: $table.explanationJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$TargetHistoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TargetHistoryTable,
          TargetRecord,
          $$TargetHistoryTableFilterComposer,
          $$TargetHistoryTableOrderingComposer,
          $$TargetHistoryTableAnnotationComposer,
          $$TargetHistoryTableCreateCompanionBuilder,
          $$TargetHistoryTableUpdateCompanionBuilder,
          (
            TargetRecord,
            BaseReferences<_$AppDatabase, $TargetHistoryTable, TargetRecord>,
          ),
          TargetRecord,
          PrefetchHooks Function()
        > {
  $$TargetHistoryTableTableManager(_$AppDatabase db, $TargetHistoryTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TargetHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TargetHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TargetHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> effectiveFrom = const Value.absent(),
                Value<double> kcal = const Value.absent(),
                Value<double> proteinG = const Value.absent(),
                Value<double> fatG = const Value.absent(),
                Value<double> carbsG = const Value.absent(),
                Value<double> maintenanceKcal = const Value.absent(),
                Value<int> method = const Value.absent(),
                Value<String?> explanationJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TargetHistoryCompanion(
                id: id,
                effectiveFrom: effectiveFrom,
                kcal: kcal,
                proteinG: proteinG,
                fatG: fatG,
                carbsG: carbsG,
                maintenanceKcal: maintenanceKcal,
                method: method,
                explanationJson: explanationJson,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String effectiveFrom,
                required double kcal,
                required double proteinG,
                required double fatG,
                required double carbsG,
                required double maintenanceKcal,
                required int method,
                Value<String?> explanationJson = const Value.absent(),
                required DateTime createdAt,
              }) => TargetHistoryCompanion.insert(
                id: id,
                effectiveFrom: effectiveFrom,
                kcal: kcal,
                proteinG: proteinG,
                fatG: fatG,
                carbsG: carbsG,
                maintenanceKcal: maintenanceKcal,
                method: method,
                explanationJson: explanationJson,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TargetHistoryTable, TargetRecord>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $TargetHistoryTable,
                    TargetRecord
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TargetHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TargetHistoryTable,
      TargetRecord,
      $$TargetHistoryTableFilterComposer,
      $$TargetHistoryTableOrderingComposer,
      $$TargetHistoryTableAnnotationComposer,
      $$TargetHistoryTableCreateCompanionBuilder,
      $$TargetHistoryTableUpdateCompanionBuilder,
      (
        TargetRecord,
        BaseReferences<_$AppDatabase, $TargetHistoryTable, TargetRecord>,
      ),
      TargetRecord,
      PrefetchHooks Function()
    >;
typedef $$KeyValuesTableCreateCompanionBuilder = KeyValuesCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$KeyValuesTableUpdateCompanionBuilder = KeyValuesCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$KeyValuesTableFilterComposer
    extends Composer<_$AppDatabase, $KeyValuesTable> {
  $$KeyValuesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$KeyValuesTableOrderingComposer
    extends Composer<_$AppDatabase, $KeyValuesTable> {
  $$KeyValuesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$KeyValuesTableAnnotationComposer
    extends Composer<_$AppDatabase, $KeyValuesTable> {
  $$KeyValuesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$KeyValuesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $KeyValuesTable,
          KeyValue,
          $$KeyValuesTableFilterComposer,
          $$KeyValuesTableOrderingComposer,
          $$KeyValuesTableAnnotationComposer,
          $$KeyValuesTableCreateCompanionBuilder,
          $$KeyValuesTableUpdateCompanionBuilder,
          (KeyValue, BaseReferences<_$AppDatabase, $KeyValuesTable, KeyValue>),
          KeyValue,
          PrefetchHooks Function()
        > {
  $$KeyValuesTableTableManager(_$AppDatabase db, $KeyValuesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KeyValuesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KeyValuesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KeyValuesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => KeyValuesCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => KeyValuesCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$KeyValuesTable, KeyValue>(table),
                  BaseReferences<_$AppDatabase, $KeyValuesTable, KeyValue>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$KeyValuesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $KeyValuesTable,
      KeyValue,
      $$KeyValuesTableFilterComposer,
      $$KeyValuesTableOrderingComposer,
      $$KeyValuesTableAnnotationComposer,
      $$KeyValuesTableCreateCompanionBuilder,
      $$KeyValuesTableUpdateCompanionBuilder,
      (KeyValue, BaseReferences<_$AppDatabase, $KeyValuesTable, KeyValue>),
      KeyValue,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ProfilesTableTableManager get profiles =>
      $$ProfilesTableTableManager(_db, _db.profiles);
  $$FoodsTableTableManager get foods =>
      $$FoodsTableTableManager(_db, _db.foods);
  $$FoodLogEntriesTableTableManager get foodLogEntries =>
      $$FoodLogEntriesTableTableManager(_db, _db.foodLogEntries);
  $$SavedMealsTableTableManager get savedMeals =>
      $$SavedMealsTableTableManager(_db, _db.savedMeals);
  $$SavedMealItemsTableTableManager get savedMealItems =>
      $$SavedMealItemsTableTableManager(_db, _db.savedMealItems);
  $$WeighInsTableTableManager get weighIns =>
      $$WeighInsTableTableManager(_db, _db.weighIns);
  $$DayStatusesTableTableManager get dayStatuses =>
      $$DayStatusesTableTableManager(_db, _db.dayStatuses);
  $$DailyStepsTableTableManager get dailySteps =>
      $$DailyStepsTableTableManager(_db, _db.dailySteps);
  $$WorkoutsTableTableManager get workouts =>
      $$WorkoutsTableTableManager(_db, _db.workouts);
  $$TargetHistoryTableTableManager get targetHistory =>
      $$TargetHistoryTableTableManager(_db, _db.targetHistory);
  $$KeyValuesTableTableManager get keyValues =>
      $$KeyValuesTableTableManager(_db, _db.keyValues);
}
