// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $BusinessesTable extends Businesses
    with TableInfo<$BusinessesTable, Business> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BusinessesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _amountModeMeta = const VerificationMeta(
    'amountMode',
  );
  @override
  late final GeneratedColumn<String> amountMode = GeneratedColumn<String>(
    'amount_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (amount_mode IN (\'integer\', \'two_decimals\'))',
  );
  static const VerificationMeta _quantityModeMeta = const VerificationMeta(
    'quantityMode',
  );
  @override
  late final GeneratedColumn<String> quantityMode = GeneratedColumn<String>(
    'quantity_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (quantity_mode IN (\'integer\', \'fractional\'))',
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, DateTime> createdAt =
      GeneratedColumn<DateTime>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($BusinessesTable.$convertercreatedAt);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    amountMode,
    quantityMode,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'businesses';
  @override
  VerificationContext validateIntegrity(
    Insertable<Business> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('amount_mode')) {
      context.handle(
        _amountModeMeta,
        amountMode.isAcceptableOrUnknown(data['amount_mode']!, _amountModeMeta),
      );
    } else if (isInserting) {
      context.missing(_amountModeMeta);
    }
    if (data.containsKey('quantity_mode')) {
      context.handle(
        _quantityModeMeta,
        quantityMode.isAcceptableOrUnknown(
          data['quantity_mode']!,
          _quantityModeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_quantityModeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Business map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Business(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      amountMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}amount_mode'],
      )!,
      quantityMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quantity_mode'],
      )!,
      createdAt: $BusinessesTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime,
          data['${effectivePrefix}created_at'],
        )!,
      ),
    );
  }

  @override
  $BusinessesTable createAlias(String alias) {
    return $BusinessesTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, DateTime> $convertercreatedAt =
      const UtcDateTimeConverter();
}

class Business extends DataClass implements Insertable<Business> {
  final String id;
  final String name;

  /// `integer` o `two_decimals`.
  final String amountMode;

  /// `integer` o `fractional`.
  final String quantityMode;
  final DateTime createdAt;
  const Business({
    required this.id,
    required this.name,
    required this.amountMode,
    required this.quantityMode,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['amount_mode'] = Variable<String>(amountMode);
    map['quantity_mode'] = Variable<String>(quantityMode);
    {
      map['created_at'] = Variable<DateTime>(
        $BusinessesTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    return map;
  }

  BusinessesCompanion toCompanion(bool nullToAbsent) {
    return BusinessesCompanion(
      id: Value(id),
      name: Value(name),
      amountMode: Value(amountMode),
      quantityMode: Value(quantityMode),
      createdAt: Value(createdAt),
    );
  }

  factory Business.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Business(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      amountMode: serializer.fromJson<String>(json['amountMode']),
      quantityMode: serializer.fromJson<String>(json['quantityMode']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'amountMode': serializer.toJson<String>(amountMode),
      'quantityMode': serializer.toJson<String>(quantityMode),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Business copyWith({
    String? id,
    String? name,
    String? amountMode,
    String? quantityMode,
    DateTime? createdAt,
  }) => Business(
    id: id ?? this.id,
    name: name ?? this.name,
    amountMode: amountMode ?? this.amountMode,
    quantityMode: quantityMode ?? this.quantityMode,
    createdAt: createdAt ?? this.createdAt,
  );
  Business copyWithCompanion(BusinessesCompanion data) {
    return Business(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      amountMode: data.amountMode.present
          ? data.amountMode.value
          : this.amountMode,
      quantityMode: data.quantityMode.present
          ? data.quantityMode.value
          : this.quantityMode,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Business(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('amountMode: $amountMode, ')
          ..write('quantityMode: $quantityMode, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, amountMode, quantityMode, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Business &&
          other.id == this.id &&
          other.name == this.name &&
          other.amountMode == this.amountMode &&
          other.quantityMode == this.quantityMode &&
          other.createdAt == this.createdAt);
}

class BusinessesCompanion extends UpdateCompanion<Business> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> amountMode;
  final Value<String> quantityMode;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const BusinessesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.amountMode = const Value.absent(),
    this.quantityMode = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BusinessesCompanion.insert({
    required String id,
    required String name,
    required String amountMode,
    required String quantityMode,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       amountMode = Value(amountMode),
       quantityMode = Value(quantityMode),
       createdAt = Value(createdAt);
  static Insertable<Business> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? amountMode,
    Expression<String>? quantityMode,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (amountMode != null) 'amount_mode': amountMode,
      if (quantityMode != null) 'quantity_mode': quantityMode,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BusinessesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? amountMode,
    Value<String>? quantityMode,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return BusinessesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      amountMode: amountMode ?? this.amountMode,
      quantityMode: quantityMode ?? this.quantityMode,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (amountMode.present) {
      map['amount_mode'] = Variable<String>(amountMode.value);
    }
    if (quantityMode.present) {
      map['quantity_mode'] = Variable<String>(quantityMode.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(
        $BusinessesTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BusinessesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('amountMode: $amountMode, ')
          ..write('quantityMode: $quantityMode, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MembershipsTable extends Memberships
    with TableInfo<$MembershipsTable, Membership> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MembershipsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _businessIdMeta = const VerificationMeta(
    'businessId',
  );
  @override
  late final GeneratedColumn<String> businessId = GeneratedColumn<String>(
    'business_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES businesses (id)',
    ),
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (role IN (\'owner\', \'employee\'))',
  );
  @override
  List<GeneratedColumn> get $columns => [userId, businessId, role];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'memberships';
  @override
  VerificationContext validateIntegrity(
    Insertable<Membership> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('business_id')) {
      context.handle(
        _businessIdMeta,
        businessId.isAcceptableOrUnknown(data['business_id']!, _businessIdMeta),
      );
    } else if (isInserting) {
      context.missing(_businessIdMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, businessId};
  @override
  Membership map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Membership(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
    );
  }

  @override
  $MembershipsTable createAlias(String alias) {
    return $MembershipsTable(attachedDatabase, alias);
  }
}

class Membership extends DataClass implements Insertable<Membership> {
  final String userId;
  final String businessId;

  /// `owner` o `employee`.
  final String role;
  const Membership({
    required this.userId,
    required this.businessId,
    required this.role,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['business_id'] = Variable<String>(businessId);
    map['role'] = Variable<String>(role);
    return map;
  }

  MembershipsCompanion toCompanion(bool nullToAbsent) {
    return MembershipsCompanion(
      userId: Value(userId),
      businessId: Value(businessId),
      role: Value(role),
    );
  }

  factory Membership.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Membership(
      userId: serializer.fromJson<String>(json['userId']),
      businessId: serializer.fromJson<String>(json['businessId']),
      role: serializer.fromJson<String>(json['role']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'businessId': serializer.toJson<String>(businessId),
      'role': serializer.toJson<String>(role),
    };
  }

  Membership copyWith({String? userId, String? businessId, String? role}) =>
      Membership(
        userId: userId ?? this.userId,
        businessId: businessId ?? this.businessId,
        role: role ?? this.role,
      );
  Membership copyWithCompanion(MembershipsCompanion data) {
    return Membership(
      userId: data.userId.present ? data.userId.value : this.userId,
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      role: data.role.present ? data.role.value : this.role,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Membership(')
          ..write('userId: $userId, ')
          ..write('businessId: $businessId, ')
          ..write('role: $role')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(userId, businessId, role);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Membership &&
          other.userId == this.userId &&
          other.businessId == this.businessId &&
          other.role == this.role);
}

class MembershipsCompanion extends UpdateCompanion<Membership> {
  final Value<String> userId;
  final Value<String> businessId;
  final Value<String> role;
  final Value<int> rowid;
  const MembershipsCompanion({
    this.userId = const Value.absent(),
    this.businessId = const Value.absent(),
    this.role = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MembershipsCompanion.insert({
    required String userId,
    required String businessId,
    required String role,
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       businessId = Value(businessId),
       role = Value(role);
  static Insertable<Membership> custom({
    Expression<String>? userId,
    Expression<String>? businessId,
    Expression<String>? role,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (businessId != null) 'business_id': businessId,
      if (role != null) 'role': role,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MembershipsCompanion copyWith({
    Value<String>? userId,
    Value<String>? businessId,
    Value<String>? role,
    Value<int>? rowid,
  }) {
    return MembershipsCompanion(
      userId: userId ?? this.userId,
      businessId: businessId ?? this.businessId,
      role: role ?? this.role,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (businessId.present) {
      map['business_id'] = Variable<String>(businessId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MembershipsCompanion(')
          ..write('userId: $userId, ')
          ..write('businessId: $businessId, ')
          ..write('role: $role, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ClientsTable extends Clients with TableInfo<$ClientsTable, Client> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClientsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _businessIdMeta = const VerificationMeta(
    'businessId',
  );
  @override
  late final GeneratedColumn<String> businessId = GeneratedColumn<String>(
    'business_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES businesses (id)',
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
  static const VerificationMeta _characterIdMeta = const VerificationMeta(
    'characterId',
  );
  @override
  late final GeneratedColumn<String> characterId = GeneratedColumn<String>(
    'character_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _skinIdMeta = const VerificationMeta('skinId');
  @override
  late final GeneratedColumn<String> skinId = GeneratedColumn<String>(
    'skin_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _backgroundIdMeta = const VerificationMeta(
    'backgroundId',
  );
  @override
  late final GeneratedColumn<String> backgroundId = GeneratedColumn<String>(
    'background_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, DateTime> createdAt =
      GeneratedColumn<DateTime>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($ClientsTable.$convertercreatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, DateTime> updatedAt =
      GeneratedColumn<DateTime>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($ClientsTable.$converterupdatedAt);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    businessId,
    name,
    characterId,
    skinId,
    backgroundId,
    phone,
    address,
    note,
    archived,
    version,
    createdBy,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'clients';
  @override
  VerificationContext validateIntegrity(
    Insertable<Client> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('business_id')) {
      context.handle(
        _businessIdMeta,
        businessId.isAcceptableOrUnknown(data['business_id']!, _businessIdMeta),
      );
    } else if (isInserting) {
      context.missing(_businessIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('character_id')) {
      context.handle(
        _characterIdMeta,
        characterId.isAcceptableOrUnknown(
          data['character_id']!,
          _characterIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_characterIdMeta);
    }
    if (data.containsKey('skin_id')) {
      context.handle(
        _skinIdMeta,
        skinId.isAcceptableOrUnknown(data['skin_id']!, _skinIdMeta),
      );
    } else if (isInserting) {
      context.missing(_skinIdMeta);
    }
    if (data.containsKey('background_id')) {
      context.handle(
        _backgroundIdMeta,
        backgroundId.isAcceptableOrUnknown(
          data['background_id']!,
          _backgroundIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_backgroundIdMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    } else if (isInserting) {
      context.missing(_createdByMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Client map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Client(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      characterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}character_id'],
      )!,
      skinId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}skin_id'],
      )!,
      backgroundId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}background_id'],
      )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      )!,
      createdAt: $ClientsTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime,
          data['${effectivePrefix}created_at'],
        )!,
      ),
      updatedAt: $ClientsTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
    );
  }

  @override
  $ClientsTable createAlias(String alias) {
    return $ClientsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, DateTime> $convertercreatedAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime, DateTime> $converterupdatedAt =
      const UtcDateTimeConverter();
}

class Client extends DataClass implements Insertable<Client> {
  final String id;
  final String businessId;
  final String name;
  final String characterId;
  final String skinId;
  final String backgroundId;
  final String? phone;
  final String? address;
  final String? note;
  final bool archived;

  /// Para detectar conflictos al sincronizar ediciones (D-8).
  final int version;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Client({
    required this.id,
    required this.businessId,
    required this.name,
    required this.characterId,
    required this.skinId,
    required this.backgroundId,
    this.phone,
    this.address,
    this.note,
    required this.archived,
    required this.version,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['business_id'] = Variable<String>(businessId);
    map['name'] = Variable<String>(name);
    map['character_id'] = Variable<String>(characterId);
    map['skin_id'] = Variable<String>(skinId);
    map['background_id'] = Variable<String>(backgroundId);
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || address != null) {
      map['address'] = Variable<String>(address);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['archived'] = Variable<bool>(archived);
    map['version'] = Variable<int>(version);
    map['created_by'] = Variable<String>(createdBy);
    {
      map['created_at'] = Variable<DateTime>(
        $ClientsTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    {
      map['updated_at'] = Variable<DateTime>(
        $ClientsTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    return map;
  }

  ClientsCompanion toCompanion(bool nullToAbsent) {
    return ClientsCompanion(
      id: Value(id),
      businessId: Value(businessId),
      name: Value(name),
      characterId: Value(characterId),
      skinId: Value(skinId),
      backgroundId: Value(backgroundId),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      archived: Value(archived),
      version: Value(version),
      createdBy: Value(createdBy),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Client.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Client(
      id: serializer.fromJson<String>(json['id']),
      businessId: serializer.fromJson<String>(json['businessId']),
      name: serializer.fromJson<String>(json['name']),
      characterId: serializer.fromJson<String>(json['characterId']),
      skinId: serializer.fromJson<String>(json['skinId']),
      backgroundId: serializer.fromJson<String>(json['backgroundId']),
      phone: serializer.fromJson<String?>(json['phone']),
      address: serializer.fromJson<String?>(json['address']),
      note: serializer.fromJson<String?>(json['note']),
      archived: serializer.fromJson<bool>(json['archived']),
      version: serializer.fromJson<int>(json['version']),
      createdBy: serializer.fromJson<String>(json['createdBy']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'businessId': serializer.toJson<String>(businessId),
      'name': serializer.toJson<String>(name),
      'characterId': serializer.toJson<String>(characterId),
      'skinId': serializer.toJson<String>(skinId),
      'backgroundId': serializer.toJson<String>(backgroundId),
      'phone': serializer.toJson<String?>(phone),
      'address': serializer.toJson<String?>(address),
      'note': serializer.toJson<String?>(note),
      'archived': serializer.toJson<bool>(archived),
      'version': serializer.toJson<int>(version),
      'createdBy': serializer.toJson<String>(createdBy),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Client copyWith({
    String? id,
    String? businessId,
    String? name,
    String? characterId,
    String? skinId,
    String? backgroundId,
    Value<String?> phone = const Value.absent(),
    Value<String?> address = const Value.absent(),
    Value<String?> note = const Value.absent(),
    bool? archived,
    int? version,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Client(
    id: id ?? this.id,
    businessId: businessId ?? this.businessId,
    name: name ?? this.name,
    characterId: characterId ?? this.characterId,
    skinId: skinId ?? this.skinId,
    backgroundId: backgroundId ?? this.backgroundId,
    phone: phone.present ? phone.value : this.phone,
    address: address.present ? address.value : this.address,
    note: note.present ? note.value : this.note,
    archived: archived ?? this.archived,
    version: version ?? this.version,
    createdBy: createdBy ?? this.createdBy,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Client copyWithCompanion(ClientsCompanion data) {
    return Client(
      id: data.id.present ? data.id.value : this.id,
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      name: data.name.present ? data.name.value : this.name,
      characterId: data.characterId.present
          ? data.characterId.value
          : this.characterId,
      skinId: data.skinId.present ? data.skinId.value : this.skinId,
      backgroundId: data.backgroundId.present
          ? data.backgroundId.value
          : this.backgroundId,
      phone: data.phone.present ? data.phone.value : this.phone,
      address: data.address.present ? data.address.value : this.address,
      note: data.note.present ? data.note.value : this.note,
      archived: data.archived.present ? data.archived.value : this.archived,
      version: data.version.present ? data.version.value : this.version,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Client(')
          ..write('id: $id, ')
          ..write('businessId: $businessId, ')
          ..write('name: $name, ')
          ..write('characterId: $characterId, ')
          ..write('skinId: $skinId, ')
          ..write('backgroundId: $backgroundId, ')
          ..write('phone: $phone, ')
          ..write('address: $address, ')
          ..write('note: $note, ')
          ..write('archived: $archived, ')
          ..write('version: $version, ')
          ..write('createdBy: $createdBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    businessId,
    name,
    characterId,
    skinId,
    backgroundId,
    phone,
    address,
    note,
    archived,
    version,
    createdBy,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Client &&
          other.id == this.id &&
          other.businessId == this.businessId &&
          other.name == this.name &&
          other.characterId == this.characterId &&
          other.skinId == this.skinId &&
          other.backgroundId == this.backgroundId &&
          other.phone == this.phone &&
          other.address == this.address &&
          other.note == this.note &&
          other.archived == this.archived &&
          other.version == this.version &&
          other.createdBy == this.createdBy &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ClientsCompanion extends UpdateCompanion<Client> {
  final Value<String> id;
  final Value<String> businessId;
  final Value<String> name;
  final Value<String> characterId;
  final Value<String> skinId;
  final Value<String> backgroundId;
  final Value<String?> phone;
  final Value<String?> address;
  final Value<String?> note;
  final Value<bool> archived;
  final Value<int> version;
  final Value<String> createdBy;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ClientsCompanion({
    this.id = const Value.absent(),
    this.businessId = const Value.absent(),
    this.name = const Value.absent(),
    this.characterId = const Value.absent(),
    this.skinId = const Value.absent(),
    this.backgroundId = const Value.absent(),
    this.phone = const Value.absent(),
    this.address = const Value.absent(),
    this.note = const Value.absent(),
    this.archived = const Value.absent(),
    this.version = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ClientsCompanion.insert({
    required String id,
    required String businessId,
    required String name,
    required String characterId,
    required String skinId,
    required String backgroundId,
    this.phone = const Value.absent(),
    this.address = const Value.absent(),
    this.note = const Value.absent(),
    this.archived = const Value.absent(),
    this.version = const Value.absent(),
    required String createdBy,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       businessId = Value(businessId),
       name = Value(name),
       characterId = Value(characterId),
       skinId = Value(skinId),
       backgroundId = Value(backgroundId),
       createdBy = Value(createdBy),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Client> custom({
    Expression<String>? id,
    Expression<String>? businessId,
    Expression<String>? name,
    Expression<String>? characterId,
    Expression<String>? skinId,
    Expression<String>? backgroundId,
    Expression<String>? phone,
    Expression<String>? address,
    Expression<String>? note,
    Expression<bool>? archived,
    Expression<int>? version,
    Expression<String>? createdBy,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (businessId != null) 'business_id': businessId,
      if (name != null) 'name': name,
      if (characterId != null) 'character_id': characterId,
      if (skinId != null) 'skin_id': skinId,
      if (backgroundId != null) 'background_id': backgroundId,
      if (phone != null) 'phone': phone,
      if (address != null) 'address': address,
      if (note != null) 'note': note,
      if (archived != null) 'archived': archived,
      if (version != null) 'version': version,
      if (createdBy != null) 'created_by': createdBy,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ClientsCompanion copyWith({
    Value<String>? id,
    Value<String>? businessId,
    Value<String>? name,
    Value<String>? characterId,
    Value<String>? skinId,
    Value<String>? backgroundId,
    Value<String?>? phone,
    Value<String?>? address,
    Value<String?>? note,
    Value<bool>? archived,
    Value<int>? version,
    Value<String>? createdBy,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ClientsCompanion(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      name: name ?? this.name,
      characterId: characterId ?? this.characterId,
      skinId: skinId ?? this.skinId,
      backgroundId: backgroundId ?? this.backgroundId,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      note: note ?? this.note,
      archived: archived ?? this.archived,
      version: version ?? this.version,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (businessId.present) {
      map['business_id'] = Variable<String>(businessId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (characterId.present) {
      map['character_id'] = Variable<String>(characterId.value);
    }
    if (skinId.present) {
      map['skin_id'] = Variable<String>(skinId.value);
    }
    if (backgroundId.present) {
      map['background_id'] = Variable<String>(backgroundId.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(
        $ClientsTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(
        $ClientsTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClientsCompanion(')
          ..write('id: $id, ')
          ..write('businessId: $businessId, ')
          ..write('name: $name, ')
          ..write('characterId: $characterId, ')
          ..write('skinId: $skinId, ')
          ..write('backgroundId: $backgroundId, ')
          ..write('phone: $phone, ')
          ..write('address: $address, ')
          ..write('note: $note, ')
          ..write('archived: $archived, ')
          ..write('version: $version, ')
          ..write('createdBy: $createdBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProductsTable extends Products with TableInfo<$ProductsTable, Product> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProductsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _businessIdMeta = const VerificationMeta(
    'businessId',
  );
  @override
  late final GeneratedColumn<String> businessId = GeneratedColumn<String>(
    'business_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES businesses (id)',
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
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<int> price = GeneratedColumn<int>(
    'price',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (price > 0)',
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, DateTime> createdAt =
      GeneratedColumn<DateTime>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($ProductsTable.$convertercreatedAt);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    businessId,
    name,
    price,
    archived,
    version,
    createdBy,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'products';
  @override
  VerificationContext validateIntegrity(
    Insertable<Product> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('business_id')) {
      context.handle(
        _businessIdMeta,
        businessId.isAcceptableOrUnknown(data['business_id']!, _businessIdMeta),
      );
    } else if (isInserting) {
      context.missing(_businessIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('price')) {
      context.handle(
        _priceMeta,
        price.isAcceptableOrUnknown(data['price']!, _priceMeta),
      );
    } else if (isInserting) {
      context.missing(_priceMeta);
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    } else if (isInserting) {
      context.missing(_createdByMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Product map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Product(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      price: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}price'],
      )!,
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      )!,
      createdAt: $ProductsTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime,
          data['${effectivePrefix}created_at'],
        )!,
      ),
    );
  }

  @override
  $ProductsTable createAlias(String alias) {
    return $ProductsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, DateTime> $convertercreatedAt =
      const UtcDateTimeConverter();
}

class Product extends DataClass implements Insertable<Product> {
  final String id;
  final String businessId;
  final String name;

  /// Precio en la unidad menor (centavos de lempira); siempre positivo.
  final int price;
  final bool archived;
  final int version;
  final String createdBy;
  final DateTime createdAt;
  const Product({
    required this.id,
    required this.businessId,
    required this.name,
    required this.price,
    required this.archived,
    required this.version,
    required this.createdBy,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['business_id'] = Variable<String>(businessId);
    map['name'] = Variable<String>(name);
    map['price'] = Variable<int>(price);
    map['archived'] = Variable<bool>(archived);
    map['version'] = Variable<int>(version);
    map['created_by'] = Variable<String>(createdBy);
    {
      map['created_at'] = Variable<DateTime>(
        $ProductsTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    return map;
  }

  ProductsCompanion toCompanion(bool nullToAbsent) {
    return ProductsCompanion(
      id: Value(id),
      businessId: Value(businessId),
      name: Value(name),
      price: Value(price),
      archived: Value(archived),
      version: Value(version),
      createdBy: Value(createdBy),
      createdAt: Value(createdAt),
    );
  }

  factory Product.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Product(
      id: serializer.fromJson<String>(json['id']),
      businessId: serializer.fromJson<String>(json['businessId']),
      name: serializer.fromJson<String>(json['name']),
      price: serializer.fromJson<int>(json['price']),
      archived: serializer.fromJson<bool>(json['archived']),
      version: serializer.fromJson<int>(json['version']),
      createdBy: serializer.fromJson<String>(json['createdBy']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'businessId': serializer.toJson<String>(businessId),
      'name': serializer.toJson<String>(name),
      'price': serializer.toJson<int>(price),
      'archived': serializer.toJson<bool>(archived),
      'version': serializer.toJson<int>(version),
      'createdBy': serializer.toJson<String>(createdBy),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Product copyWith({
    String? id,
    String? businessId,
    String? name,
    int? price,
    bool? archived,
    int? version,
    String? createdBy,
    DateTime? createdAt,
  }) => Product(
    id: id ?? this.id,
    businessId: businessId ?? this.businessId,
    name: name ?? this.name,
    price: price ?? this.price,
    archived: archived ?? this.archived,
    version: version ?? this.version,
    createdBy: createdBy ?? this.createdBy,
    createdAt: createdAt ?? this.createdAt,
  );
  Product copyWithCompanion(ProductsCompanion data) {
    return Product(
      id: data.id.present ? data.id.value : this.id,
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      name: data.name.present ? data.name.value : this.name,
      price: data.price.present ? data.price.value : this.price,
      archived: data.archived.present ? data.archived.value : this.archived,
      version: data.version.present ? data.version.value : this.version,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Product(')
          ..write('id: $id, ')
          ..write('businessId: $businessId, ')
          ..write('name: $name, ')
          ..write('price: $price, ')
          ..write('archived: $archived, ')
          ..write('version: $version, ')
          ..write('createdBy: $createdBy, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    businessId,
    name,
    price,
    archived,
    version,
    createdBy,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Product &&
          other.id == this.id &&
          other.businessId == this.businessId &&
          other.name == this.name &&
          other.price == this.price &&
          other.archived == this.archived &&
          other.version == this.version &&
          other.createdBy == this.createdBy &&
          other.createdAt == this.createdAt);
}

class ProductsCompanion extends UpdateCompanion<Product> {
  final Value<String> id;
  final Value<String> businessId;
  final Value<String> name;
  final Value<int> price;
  final Value<bool> archived;
  final Value<int> version;
  final Value<String> createdBy;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ProductsCompanion({
    this.id = const Value.absent(),
    this.businessId = const Value.absent(),
    this.name = const Value.absent(),
    this.price = const Value.absent(),
    this.archived = const Value.absent(),
    this.version = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProductsCompanion.insert({
    required String id,
    required String businessId,
    required String name,
    required int price,
    this.archived = const Value.absent(),
    this.version = const Value.absent(),
    required String createdBy,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       businessId = Value(businessId),
       name = Value(name),
       price = Value(price),
       createdBy = Value(createdBy),
       createdAt = Value(createdAt);
  static Insertable<Product> custom({
    Expression<String>? id,
    Expression<String>? businessId,
    Expression<String>? name,
    Expression<int>? price,
    Expression<bool>? archived,
    Expression<int>? version,
    Expression<String>? createdBy,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (businessId != null) 'business_id': businessId,
      if (name != null) 'name': name,
      if (price != null) 'price': price,
      if (archived != null) 'archived': archived,
      if (version != null) 'version': version,
      if (createdBy != null) 'created_by': createdBy,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProductsCompanion copyWith({
    Value<String>? id,
    Value<String>? businessId,
    Value<String>? name,
    Value<int>? price,
    Value<bool>? archived,
    Value<int>? version,
    Value<String>? createdBy,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ProductsCompanion(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      name: name ?? this.name,
      price: price ?? this.price,
      archived: archived ?? this.archived,
      version: version ?? this.version,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (businessId.present) {
      map['business_id'] = Variable<String>(businessId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (price.present) {
      map['price'] = Variable<int>(price.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(
        $ProductsTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProductsCompanion(')
          ..write('id: $id, ')
          ..write('businessId: $businessId, ')
          ..write('name: $name, ')
          ..write('price: $price, ')
          ..write('archived: $archived, ')
          ..write('version: $version, ')
          ..write('createdBy: $createdBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $BusinessesTable businesses = $BusinessesTable(this);
  late final $MembershipsTable memberships = $MembershipsTable(this);
  late final $ClientsTable clients = $ClientsTable(this);
  late final $ProductsTable products = $ProductsTable(this);
  late final Index clientsBusiness = Index(
    'clients_business',
    'CREATE INDEX clients_business ON clients (business_id)',
  );
  late final Index productsBusiness = Index(
    'products_business',
    'CREATE INDEX products_business ON products (business_id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    businesses,
    memberships,
    clients,
    products,
    clientsBusiness,
    productsBusiness,
  ];
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$BusinessesTableCreateCompanionBuilder = BusinessesCompanion Function({
  required String id,
  required String name,
  required String amountMode,
  required String quantityMode,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$BusinessesTableUpdateCompanionBuilder = BusinessesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> amountMode,
  Value<String> quantityMode,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$BusinessesTableReferences
    extends BaseReferences<_$AppDatabase, $BusinessesTable, Business> {
  $$BusinessesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MembershipsTable, List<Membership>>
  _membershipsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.memberships,
    aliasName: 'businesses__id__memberships__business_id',
  );

  $$MembershipsTableProcessedTableManager get membershipsRefs {
    final manager = $$MembershipsTableTableManager(
      $_db,
      $_db.memberships,
    ).filter((f) => f.businessId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_membershipsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ClientsTable, List<Client>> _clientsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.clients,
    aliasName: 'businesses__id__clients__business_id',
  );

  $$ClientsTableProcessedTableManager get clientsRefs {
    final manager = $$ClientsTableTableManager(
      $_db,
      $_db.clients,
    ).filter((f) => f.businessId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_clientsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ProductsTable, List<Product>> _productsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.products,
    aliasName: 'businesses__id__products__business_id',
  );

  $$ProductsTableProcessedTableManager get productsRefs {
    final manager = $$ProductsTableTableManager(
      $_db,
      $_db.products,
    ).filter((f) => f.businessId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_productsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$BusinessesTableFilterComposer
    extends Composer<_$AppDatabase, $BusinessesTable> {
  $$BusinessesTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get amountMode => $composableBuilder(
    column: $table.amountMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get quantityMode => $composableBuilder(
    column: $table.quantityMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, DateTime> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  Expression<bool> membershipsRefs(
    Expression<bool> Function($$MembershipsTableFilterComposer f) f,
  ) {
    final $$MembershipsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.memberships,
      getReferencedColumn: (t) => t.businessId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MembershipsTableFilterComposer(
            $db: $db,
            $table: $db.memberships,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> clientsRefs(
    Expression<bool> Function($$ClientsTableFilterComposer f) f,
  ) {
    final $$ClientsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.clients,
      getReferencedColumn: (t) => t.businessId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClientsTableFilterComposer(
            $db: $db,
            $table: $db.clients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> productsRefs(
    Expression<bool> Function($$ProductsTableFilterComposer f) f,
  ) {
    final $$ProductsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.businessId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableFilterComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BusinessesTableOrderingComposer
    extends Composer<_$AppDatabase, $BusinessesTable> {
  $$BusinessesTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get amountMode => $composableBuilder(
    column: $table.amountMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quantityMode => $composableBuilder(
    column: $table.quantityMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BusinessesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BusinessesTable> {
  $$BusinessesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get amountMode => $composableBuilder(
    column: $table.amountMode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get quantityMode => $composableBuilder(
    column: $table.quantityMode,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime, DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> membershipsRefs<T extends Object>(
    Expression<T> Function($$MembershipsTableAnnotationComposer a) f,
  ) {
    final $$MembershipsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.memberships,
      getReferencedColumn: (t) => t.businessId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MembershipsTableAnnotationComposer(
            $db: $db,
            $table: $db.memberships,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> clientsRefs<T extends Object>(
    Expression<T> Function($$ClientsTableAnnotationComposer a) f,
  ) {
    final $$ClientsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.clients,
      getReferencedColumn: (t) => t.businessId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClientsTableAnnotationComposer(
            $db: $db,
            $table: $db.clients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> productsRefs<T extends Object>(
    Expression<T> Function($$ProductsTableAnnotationComposer a) f,
  ) {
    final $$ProductsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.businessId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableAnnotationComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BusinessesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BusinessesTable,
          Business,
          $$BusinessesTableFilterComposer,
          $$BusinessesTableOrderingComposer,
          $$BusinessesTableAnnotationComposer,
          $$BusinessesTableCreateCompanionBuilder,
          $$BusinessesTableUpdateCompanionBuilder,
          (Business, $$BusinessesTableReferences),
          Business,
          PrefetchHooks Function({
            bool membershipsRefs,
            bool clientsRefs,
            bool productsRefs,
          })
        > {
  $$BusinessesTableTableManager(_$AppDatabase db, $BusinessesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BusinessesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BusinessesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BusinessesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> amountMode = const Value.absent(),
                Value<String> quantityMode = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BusinessesCompanion(
                id: id,
                name: name,
                amountMode: amountMode,
                quantityMode: quantityMode,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String amountMode,
                required String quantityMode,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => BusinessesCompanion.insert(
                id: id,
                name: name,
                amountMode: amountMode,
                quantityMode: quantityMode,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BusinessesTable, Business>(table),
                  $$BusinessesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                membershipsRefs = false,
                clientsRefs = false,
                productsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (membershipsRefs) db.memberships,
                    if (clientsRefs) db.clients,
                    if (productsRefs) db.products,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (membershipsRefs)
                        await $_getPrefetchedData<
                          Business,
                          $BusinessesTable,
                          Membership
                        >(
                          currentTable: table,
                          referencedTable: $$BusinessesTableReferences
                              ._membershipsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BusinessesTableReferences(
                                db,
                                table,
                                p0,
                              ).membershipsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.businessId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (clientsRefs)
                        await $_getPrefetchedData<
                          Business,
                          $BusinessesTable,
                          Client
                        >(
                          currentTable: table,
                          referencedTable: $$BusinessesTableReferences
                              ._clientsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BusinessesTableReferences(
                                db,
                                table,
                                p0,
                              ).clientsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.businessId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (productsRefs)
                        await $_getPrefetchedData<
                          Business,
                          $BusinessesTable,
                          Product
                        >(
                          currentTable: table,
                          referencedTable: $$BusinessesTableReferences
                              ._productsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BusinessesTableReferences(
                                db,
                                table,
                                p0,
                              ).productsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.businessId == item.id,
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

typedef $$BusinessesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BusinessesTable,
      Business,
      $$BusinessesTableFilterComposer,
      $$BusinessesTableOrderingComposer,
      $$BusinessesTableAnnotationComposer,
      $$BusinessesTableCreateCompanionBuilder,
      $$BusinessesTableUpdateCompanionBuilder,
      (Business, $$BusinessesTableReferences),
      Business,
      PrefetchHooks Function({
        bool membershipsRefs,
        bool clientsRefs,
        bool productsRefs,
      })
    >;
typedef $$MembershipsTableCreateCompanionBuilder =
    MembershipsCompanion Function({
      required String userId,
      required String businessId,
      required String role,
      Value<int> rowid,
    });
typedef $$MembershipsTableUpdateCompanionBuilder =
    MembershipsCompanion Function({
      Value<String> userId,
      Value<String> businessId,
      Value<String> role,
      Value<int> rowid,
    });

final class $$MembershipsTableReferences
    extends BaseReferences<_$AppDatabase, $MembershipsTable, Membership> {
  $$MembershipsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BusinessesTable _businessIdTable(_$AppDatabase db) =>
      db.businesses.createAlias('memberships__business_id__businesses__id');

  $$BusinessesTableProcessedTableManager get businessId {
    final $_column = $_itemColumn<String>('business_id')!;

    final manager = $$BusinessesTableTableManager(
      $_db,
      $_db.businesses,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_businessIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MembershipsTableFilterComposer
    extends Composer<_$AppDatabase, $MembershipsTable> {
  $$MembershipsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  $$BusinessesTableFilterComposer get businessId {
    final $$BusinessesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.businessId,
      referencedTable: $db.businesses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BusinessesTableFilterComposer(
            $db: $db,
            $table: $db.businesses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MembershipsTableOrderingComposer
    extends Composer<_$AppDatabase, $MembershipsTable> {
  $$MembershipsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  $$BusinessesTableOrderingComposer get businessId {
    final $$BusinessesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.businessId,
      referencedTable: $db.businesses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BusinessesTableOrderingComposer(
            $db: $db,
            $table: $db.businesses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MembershipsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MembershipsTable> {
  $$MembershipsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  $$BusinessesTableAnnotationComposer get businessId {
    final $$BusinessesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.businessId,
      referencedTable: $db.businesses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BusinessesTableAnnotationComposer(
            $db: $db,
            $table: $db.businesses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MembershipsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MembershipsTable,
          Membership,
          $$MembershipsTableFilterComposer,
          $$MembershipsTableOrderingComposer,
          $$MembershipsTableAnnotationComposer,
          $$MembershipsTableCreateCompanionBuilder,
          $$MembershipsTableUpdateCompanionBuilder,
          (Membership, $$MembershipsTableReferences),
          Membership,
          PrefetchHooks Function({bool businessId})
        > {
  $$MembershipsTableTableManager(_$AppDatabase db, $MembershipsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MembershipsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MembershipsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MembershipsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> userId = const Value.absent(),
                Value<String> businessId = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MembershipsCompanion(
                userId: userId,
                businessId: businessId,
                role: role,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userId,
                required String businessId,
                required String role,
                Value<int> rowid = const Value.absent(),
              }) => MembershipsCompanion.insert(
                userId: userId,
                businessId: businessId,
                role: role,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MembershipsTable, Membership>(table),
                  $$MembershipsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({businessId = false}) {
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
                    if (businessId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.businessId,
                        referencedTable: $$MembershipsTableReferences
                            ._businessIdTable(db),
                        referencedColumn: $$MembershipsTableReferences
                            ._businessIdTable(db)
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

typedef $$MembershipsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MembershipsTable,
      Membership,
      $$MembershipsTableFilterComposer,
      $$MembershipsTableOrderingComposer,
      $$MembershipsTableAnnotationComposer,
      $$MembershipsTableCreateCompanionBuilder,
      $$MembershipsTableUpdateCompanionBuilder,
      (Membership, $$MembershipsTableReferences),
      Membership,
      PrefetchHooks Function({bool businessId})
    >;
typedef $$ClientsTableCreateCompanionBuilder = ClientsCompanion Function({
  required String id,
  required String businessId,
  required String name,
  required String characterId,
  required String skinId,
  required String backgroundId,
  Value<String?> phone,
  Value<String?> address,
  Value<String?> note,
  Value<bool> archived,
  Value<int> version,
  required String createdBy,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$ClientsTableUpdateCompanionBuilder = ClientsCompanion Function({
  Value<String> id,
  Value<String> businessId,
  Value<String> name,
  Value<String> characterId,
  Value<String> skinId,
  Value<String> backgroundId,
  Value<String?> phone,
  Value<String?> address,
  Value<String?> note,
  Value<bool> archived,
  Value<int> version,
  Value<String> createdBy,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$ClientsTableReferences
    extends BaseReferences<_$AppDatabase, $ClientsTable, Client> {
  $$ClientsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BusinessesTable _businessIdTable(_$AppDatabase db) =>
      db.businesses.createAlias('clients__business_id__businesses__id');

  $$BusinessesTableProcessedTableManager get businessId {
    final $_column = $_itemColumn<String>('business_id')!;

    final manager = $$BusinessesTableTableManager(
      $_db,
      $_db.businesses,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_businessIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ClientsTableFilterComposer
    extends Composer<_$AppDatabase, $ClientsTable> {
  $$ClientsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get characterId => $composableBuilder(
    column: $table.characterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get skinId => $composableBuilder(
    column: $table.skinId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get backgroundId => $composableBuilder(
    column: $table.backgroundId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, DateTime> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime, DateTime, DateTime> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$BusinessesTableFilterComposer get businessId {
    final $$BusinessesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.businessId,
      referencedTable: $db.businesses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BusinessesTableFilterComposer(
            $db: $db,
            $table: $db.businesses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ClientsTableOrderingComposer
    extends Composer<_$AppDatabase, $ClientsTable> {
  $$ClientsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get characterId => $composableBuilder(
    column: $table.characterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get skinId => $composableBuilder(
    column: $table.skinId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backgroundId => $composableBuilder(
    column: $table.backgroundId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$BusinessesTableOrderingComposer get businessId {
    final $$BusinessesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.businessId,
      referencedTable: $db.businesses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BusinessesTableOrderingComposer(
            $db: $db,
            $table: $db.businesses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ClientsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ClientsTable> {
  $$ClientsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get characterId => $composableBuilder(
    column: $table.characterId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get skinId =>
      $composableBuilder(column: $table.skinId, builder: (column) => column);

  GeneratedColumn<String> get backgroundId => $composableBuilder(
    column: $table.backgroundId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$BusinessesTableAnnotationComposer get businessId {
    final $$BusinessesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.businessId,
      referencedTable: $db.businesses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BusinessesTableAnnotationComposer(
            $db: $db,
            $table: $db.businesses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ClientsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ClientsTable,
          Client,
          $$ClientsTableFilterComposer,
          $$ClientsTableOrderingComposer,
          $$ClientsTableAnnotationComposer,
          $$ClientsTableCreateCompanionBuilder,
          $$ClientsTableUpdateCompanionBuilder,
          (Client, $$ClientsTableReferences),
          Client,
          PrefetchHooks Function({bool businessId})
        > {
  $$ClientsTableTableManager(_$AppDatabase db, $ClientsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClientsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClientsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ClientsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> businessId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> characterId = const Value.absent(),
                Value<String> skinId = const Value.absent(),
                Value<String> backgroundId = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> createdBy = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ClientsCompanion(
                id: id,
                businessId: businessId,
                name: name,
                characterId: characterId,
                skinId: skinId,
                backgroundId: backgroundId,
                phone: phone,
                address: address,
                note: note,
                archived: archived,
                version: version,
                createdBy: createdBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String businessId,
                required String name,
                required String characterId,
                required String skinId,
                required String backgroundId,
                Value<String?> phone = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int> version = const Value.absent(),
                required String createdBy,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ClientsCompanion.insert(
                id: id,
                businessId: businessId,
                name: name,
                characterId: characterId,
                skinId: skinId,
                backgroundId: backgroundId,
                phone: phone,
                address: address,
                note: note,
                archived: archived,
                version: version,
                createdBy: createdBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ClientsTable, Client>(table),
                  $$ClientsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({businessId = false}) {
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
                    if (businessId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.businessId,
                        referencedTable: $$ClientsTableReferences
                            ._businessIdTable(db),
                        referencedColumn: $$ClientsTableReferences
                            ._businessIdTable(db)
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

typedef $$ClientsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ClientsTable,
      Client,
      $$ClientsTableFilterComposer,
      $$ClientsTableOrderingComposer,
      $$ClientsTableAnnotationComposer,
      $$ClientsTableCreateCompanionBuilder,
      $$ClientsTableUpdateCompanionBuilder,
      (Client, $$ClientsTableReferences),
      Client,
      PrefetchHooks Function({bool businessId})
    >;
typedef $$ProductsTableCreateCompanionBuilder = ProductsCompanion Function({
  required String id,
  required String businessId,
  required String name,
  required int price,
  Value<bool> archived,
  Value<int> version,
  required String createdBy,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$ProductsTableUpdateCompanionBuilder = ProductsCompanion Function({
  Value<String> id,
  Value<String> businessId,
  Value<String> name,
  Value<int> price,
  Value<bool> archived,
  Value<int> version,
  Value<String> createdBy,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$ProductsTableReferences
    extends BaseReferences<_$AppDatabase, $ProductsTable, Product> {
  $$ProductsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BusinessesTable _businessIdTable(_$AppDatabase db) =>
      db.businesses.createAlias('products__business_id__businesses__id');

  $$BusinessesTableProcessedTableManager get businessId {
    final $_column = $_itemColumn<String>('business_id')!;

    final manager = $$BusinessesTableTableManager(
      $_db,
      $_db.businesses,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_businessIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ProductsTableFilterComposer
    extends Composer<_$AppDatabase, $ProductsTable> {
  $$ProductsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, DateTime> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$BusinessesTableFilterComposer get businessId {
    final $$BusinessesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.businessId,
      referencedTable: $db.businesses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BusinessesTableFilterComposer(
            $db: $db,
            $table: $db.businesses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProductsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProductsTable> {
  $$ProductsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$BusinessesTableOrderingComposer get businessId {
    final $$BusinessesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.businessId,
      referencedTable: $db.businesses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BusinessesTableOrderingComposer(
            $db: $db,
            $table: $db.businesses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProductsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProductsTable> {
  $$ProductsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get price =>
      $composableBuilder(column: $table.price, builder: (column) => column);

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$BusinessesTableAnnotationComposer get businessId {
    final $$BusinessesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.businessId,
      referencedTable: $db.businesses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BusinessesTableAnnotationComposer(
            $db: $db,
            $table: $db.businesses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProductsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProductsTable,
          Product,
          $$ProductsTableFilterComposer,
          $$ProductsTableOrderingComposer,
          $$ProductsTableAnnotationComposer,
          $$ProductsTableCreateCompanionBuilder,
          $$ProductsTableUpdateCompanionBuilder,
          (Product, $$ProductsTableReferences),
          Product,
          PrefetchHooks Function({bool businessId})
        > {
  $$ProductsTableTableManager(_$AppDatabase db, $ProductsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProductsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProductsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProductsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> businessId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> price = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> createdBy = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProductsCompanion(
                id: id,
                businessId: businessId,
                name: name,
                price: price,
                archived: archived,
                version: version,
                createdBy: createdBy,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String businessId,
                required String name,
                required int price,
                Value<bool> archived = const Value.absent(),
                Value<int> version = const Value.absent(),
                required String createdBy,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ProductsCompanion.insert(
                id: id,
                businessId: businessId,
                name: name,
                price: price,
                archived: archived,
                version: version,
                createdBy: createdBy,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProductsTable, Product>(table),
                  $$ProductsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({businessId = false}) {
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
                    if (businessId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.businessId,
                        referencedTable: $$ProductsTableReferences
                            ._businessIdTable(db),
                        referencedColumn: $$ProductsTableReferences
                            ._businessIdTable(db)
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

typedef $$ProductsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProductsTable,
      Product,
      $$ProductsTableFilterComposer,
      $$ProductsTableOrderingComposer,
      $$ProductsTableAnnotationComposer,
      $$ProductsTableCreateCompanionBuilder,
      $$ProductsTableUpdateCompanionBuilder,
      (Product, $$ProductsTableReferences),
      Product,
      PrefetchHooks Function({bool businessId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$BusinessesTableTableManager get businesses =>
      $$BusinessesTableTableManager(_db, _db.businesses);
  $$MembershipsTableTableManager get memberships =>
      $$MembershipsTableTableManager(_db, _db.memberships);
  $$ClientsTableTableManager get clients =>
      $$ClientsTableTableManager(_db, _db.clients);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db, _db.products);
}
