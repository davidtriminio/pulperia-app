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
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {id, businessId},
  ];
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
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'unit\' CHECK (unit IN (\'unit\', \'pound\', \'ounce\', \'kilo\', \'dozen\', \'liter\', \'gallon\', \'box\', \'bag\', \'pack\'))',
    defaultValue: const CustomExpression('\'unit\''),
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
    unit,
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
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
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
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {id, businessId},
  ];
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
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
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

  /// Unidad de venta (RF-86, RF-88): id de la lista compartida, `unit` por
  /// omisión.
  /// La lista del CHECK debe coincidir con `SaleUnit`; un test lo comprueba.
  final String unit;
  final bool archived;
  final int version;
  final String createdBy;
  final DateTime createdAt;
  const Product({
    required this.id,
    required this.businessId,
    required this.name,
    required this.price,
    required this.unit,
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
    map['unit'] = Variable<String>(unit);
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
      unit: Value(unit),
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
      unit: serializer.fromJson<String>(json['unit']),
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
      'unit': serializer.toJson<String>(unit),
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
    String? unit,
    bool? archived,
    int? version,
    String? createdBy,
    DateTime? createdAt,
  }) => Product(
    id: id ?? this.id,
    businessId: businessId ?? this.businessId,
    name: name ?? this.name,
    price: price ?? this.price,
    unit: unit ?? this.unit,
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
      unit: data.unit.present ? data.unit.value : this.unit,
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
          ..write('unit: $unit, ')
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
    unit,
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
          other.unit == this.unit &&
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
  final Value<String> unit;
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
    this.unit = const Value.absent(),
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
    this.unit = const Value.absent(),
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
    Expression<String>? unit,
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
      if (unit != null) 'unit': unit,
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
    Value<String>? unit,
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
      unit: unit ?? this.unit,
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
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
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
          ..write('unit: $unit, ')
          ..write('archived: $archived, ')
          ..write('version: $version, ')
          ..write('createdBy: $createdBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FiadosTable extends Fiados with TableInfo<$FiadosTable, Fiado> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FiadosTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _clientIdMeta = const VerificationMeta(
    'clientId',
  );
  @override
  late final GeneratedColumn<String> clientId = GeneratedColumn<String>(
    'client_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<int> total = GeneratedColumn<int>(
    'total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (total > 0)',
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, DateTime> occurredAt =
      GeneratedColumn<DateTime>(
        'occurred_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($FiadosTable.$converteroccurredAt);
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
  late final GeneratedColumnWithTypeConverter<DateTime?, DateTime> annulledAt =
      GeneratedColumn<DateTime>(
        'annulled_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($FiadosTable.$converterannulledAt);
  static const VerificationMeta _annulledByMeta = const VerificationMeta(
    'annulledBy',
  );
  @override
  late final GeneratedColumn<String> annulledBy = GeneratedColumn<String>(
    'annulled_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serverSeqMeta = const VerificationMeta(
    'serverSeq',
  );
  @override
  late final GeneratedColumn<int> serverSeq = GeneratedColumn<int>(
    'server_seq',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    businessId,
    clientId,
    total,
    occurredAt,
    createdBy,
    annulledAt,
    annulledBy,
    serverSeq,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'fiados';
  @override
  VerificationContext validateIntegrity(
    Insertable<Fiado> instance, {
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
    if (data.containsKey('client_id')) {
      context.handle(
        _clientIdMeta,
        clientId.isAcceptableOrUnknown(data['client_id']!, _clientIdMeta),
      );
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('total')) {
      context.handle(
        _totalMeta,
        total.isAcceptableOrUnknown(data['total']!, _totalMeta),
      );
    } else if (isInserting) {
      context.missing(_totalMeta);
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    } else if (isInserting) {
      context.missing(_createdByMeta);
    }
    if (data.containsKey('annulled_by')) {
      context.handle(
        _annulledByMeta,
        annulledBy.isAcceptableOrUnknown(data['annulled_by']!, _annulledByMeta),
      );
    }
    if (data.containsKey('server_seq')) {
      context.handle(
        _serverSeqMeta,
        serverSeq.isAcceptableOrUnknown(data['server_seq']!, _serverSeqMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {id, businessId},
  ];
  @override
  Fiado map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Fiado(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      )!,
      clientId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_id'],
      )!,
      total: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total'],
      )!,
      occurredAt: $FiadosTable.$converteroccurredAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime,
          data['${effectivePrefix}occurred_at'],
        )!,
      ),
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      )!,
      annulledAt: $FiadosTable.$converterannulledAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime,
          data['${effectivePrefix}annulled_at'],
        ),
      ),
      annulledBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}annulled_by'],
      ),
      serverSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_seq'],
      ),
    );
  }

  @override
  $FiadosTable createAlias(String alias) {
    return $FiadosTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, DateTime> $converteroccurredAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime?, DateTime?> $converterannulledAt =
      NullAwareTypeConverter.wrap(const UtcDateTimeConverter());
}

class Fiado extends DataClass implements Insertable<Fiado> {
  final String id;
  final String businessId;
  final String clientId;

  /// Total en la unidad menor; con ítems es la suma de sus subtotales,
  /// calculada al crear y nunca recalculada (principio 4).
  final int total;

  /// Cuándo ocurrió la venta, según el dispositivo que la registró (D-18).
  final DateTime occurredAt;
  final String createdBy;
  final DateTime? annulledAt;
  final String? annulledBy;

  /// Orden de llegada al servidor; null mientras no se ha sincronizado.
  final int? serverSeq;
  const Fiado({
    required this.id,
    required this.businessId,
    required this.clientId,
    required this.total,
    required this.occurredAt,
    required this.createdBy,
    this.annulledAt,
    this.annulledBy,
    this.serverSeq,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['business_id'] = Variable<String>(businessId);
    map['client_id'] = Variable<String>(clientId);
    map['total'] = Variable<int>(total);
    {
      map['occurred_at'] = Variable<DateTime>(
        $FiadosTable.$converteroccurredAt.toSql(occurredAt),
      );
    }
    map['created_by'] = Variable<String>(createdBy);
    if (!nullToAbsent || annulledAt != null) {
      map['annulled_at'] = Variable<DateTime>(
        $FiadosTable.$converterannulledAt.toSql(annulledAt),
      );
    }
    if (!nullToAbsent || annulledBy != null) {
      map['annulled_by'] = Variable<String>(annulledBy);
    }
    if (!nullToAbsent || serverSeq != null) {
      map['server_seq'] = Variable<int>(serverSeq);
    }
    return map;
  }

  FiadosCompanion toCompanion(bool nullToAbsent) {
    return FiadosCompanion(
      id: Value(id),
      businessId: Value(businessId),
      clientId: Value(clientId),
      total: Value(total),
      occurredAt: Value(occurredAt),
      createdBy: Value(createdBy),
      annulledAt: annulledAt == null && nullToAbsent
          ? const Value.absent()
          : Value(annulledAt),
      annulledBy: annulledBy == null && nullToAbsent
          ? const Value.absent()
          : Value(annulledBy),
      serverSeq: serverSeq == null && nullToAbsent
          ? const Value.absent()
          : Value(serverSeq),
    );
  }

  factory Fiado.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Fiado(
      id: serializer.fromJson<String>(json['id']),
      businessId: serializer.fromJson<String>(json['businessId']),
      clientId: serializer.fromJson<String>(json['clientId']),
      total: serializer.fromJson<int>(json['total']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      createdBy: serializer.fromJson<String>(json['createdBy']),
      annulledAt: serializer.fromJson<DateTime?>(json['annulledAt']),
      annulledBy: serializer.fromJson<String?>(json['annulledBy']),
      serverSeq: serializer.fromJson<int?>(json['serverSeq']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'businessId': serializer.toJson<String>(businessId),
      'clientId': serializer.toJson<String>(clientId),
      'total': serializer.toJson<int>(total),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'createdBy': serializer.toJson<String>(createdBy),
      'annulledAt': serializer.toJson<DateTime?>(annulledAt),
      'annulledBy': serializer.toJson<String?>(annulledBy),
      'serverSeq': serializer.toJson<int?>(serverSeq),
    };
  }

  Fiado copyWith({
    String? id,
    String? businessId,
    String? clientId,
    int? total,
    DateTime? occurredAt,
    String? createdBy,
    Value<DateTime?> annulledAt = const Value.absent(),
    Value<String?> annulledBy = const Value.absent(),
    Value<int?> serverSeq = const Value.absent(),
  }) => Fiado(
    id: id ?? this.id,
    businessId: businessId ?? this.businessId,
    clientId: clientId ?? this.clientId,
    total: total ?? this.total,
    occurredAt: occurredAt ?? this.occurredAt,
    createdBy: createdBy ?? this.createdBy,
    annulledAt: annulledAt.present ? annulledAt.value : this.annulledAt,
    annulledBy: annulledBy.present ? annulledBy.value : this.annulledBy,
    serverSeq: serverSeq.present ? serverSeq.value : this.serverSeq,
  );
  Fiado copyWithCompanion(FiadosCompanion data) {
    return Fiado(
      id: data.id.present ? data.id.value : this.id,
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      clientId: data.clientId.present ? data.clientId.value : this.clientId,
      total: data.total.present ? data.total.value : this.total,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      annulledAt: data.annulledAt.present
          ? data.annulledAt.value
          : this.annulledAt,
      annulledBy: data.annulledBy.present
          ? data.annulledBy.value
          : this.annulledBy,
      serverSeq: data.serverSeq.present ? data.serverSeq.value : this.serverSeq,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Fiado(')
          ..write('id: $id, ')
          ..write('businessId: $businessId, ')
          ..write('clientId: $clientId, ')
          ..write('total: $total, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('createdBy: $createdBy, ')
          ..write('annulledAt: $annulledAt, ')
          ..write('annulledBy: $annulledBy, ')
          ..write('serverSeq: $serverSeq')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    businessId,
    clientId,
    total,
    occurredAt,
    createdBy,
    annulledAt,
    annulledBy,
    serverSeq,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Fiado &&
          other.id == this.id &&
          other.businessId == this.businessId &&
          other.clientId == this.clientId &&
          other.total == this.total &&
          other.occurredAt == this.occurredAt &&
          other.createdBy == this.createdBy &&
          other.annulledAt == this.annulledAt &&
          other.annulledBy == this.annulledBy &&
          other.serverSeq == this.serverSeq);
}

class FiadosCompanion extends UpdateCompanion<Fiado> {
  final Value<String> id;
  final Value<String> businessId;
  final Value<String> clientId;
  final Value<int> total;
  final Value<DateTime> occurredAt;
  final Value<String> createdBy;
  final Value<DateTime?> annulledAt;
  final Value<String?> annulledBy;
  final Value<int?> serverSeq;
  final Value<int> rowid;
  const FiadosCompanion({
    this.id = const Value.absent(),
    this.businessId = const Value.absent(),
    this.clientId = const Value.absent(),
    this.total = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.annulledAt = const Value.absent(),
    this.annulledBy = const Value.absent(),
    this.serverSeq = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FiadosCompanion.insert({
    required String id,
    required String businessId,
    required String clientId,
    required int total,
    required DateTime occurredAt,
    required String createdBy,
    this.annulledAt = const Value.absent(),
    this.annulledBy = const Value.absent(),
    this.serverSeq = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       businessId = Value(businessId),
       clientId = Value(clientId),
       total = Value(total),
       occurredAt = Value(occurredAt),
       createdBy = Value(createdBy);
  static Insertable<Fiado> custom({
    Expression<String>? id,
    Expression<String>? businessId,
    Expression<String>? clientId,
    Expression<int>? total,
    Expression<DateTime>? occurredAt,
    Expression<String>? createdBy,
    Expression<DateTime>? annulledAt,
    Expression<String>? annulledBy,
    Expression<int>? serverSeq,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (businessId != null) 'business_id': businessId,
      if (clientId != null) 'client_id': clientId,
      if (total != null) 'total': total,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (createdBy != null) 'created_by': createdBy,
      if (annulledAt != null) 'annulled_at': annulledAt,
      if (annulledBy != null) 'annulled_by': annulledBy,
      if (serverSeq != null) 'server_seq': serverSeq,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FiadosCompanion copyWith({
    Value<String>? id,
    Value<String>? businessId,
    Value<String>? clientId,
    Value<int>? total,
    Value<DateTime>? occurredAt,
    Value<String>? createdBy,
    Value<DateTime?>? annulledAt,
    Value<String?>? annulledBy,
    Value<int?>? serverSeq,
    Value<int>? rowid,
  }) {
    return FiadosCompanion(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      clientId: clientId ?? this.clientId,
      total: total ?? this.total,
      occurredAt: occurredAt ?? this.occurredAt,
      createdBy: createdBy ?? this.createdBy,
      annulledAt: annulledAt ?? this.annulledAt,
      annulledBy: annulledBy ?? this.annulledBy,
      serverSeq: serverSeq ?? this.serverSeq,
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
    if (clientId.present) {
      map['client_id'] = Variable<String>(clientId.value);
    }
    if (total.present) {
      map['total'] = Variable<int>(total.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(
        $FiadosTable.$converteroccurredAt.toSql(occurredAt.value),
      );
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (annulledAt.present) {
      map['annulled_at'] = Variable<DateTime>(
        $FiadosTable.$converterannulledAt.toSql(annulledAt.value),
      );
    }
    if (annulledBy.present) {
      map['annulled_by'] = Variable<String>(annulledBy.value);
    }
    if (serverSeq.present) {
      map['server_seq'] = Variable<int>(serverSeq.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FiadosCompanion(')
          ..write('id: $id, ')
          ..write('businessId: $businessId, ')
          ..write('clientId: $clientId, ')
          ..write('total: $total, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('createdBy: $createdBy, ')
          ..write('annulledAt: $annulledAt, ')
          ..write('annulledBy: $annulledBy, ')
          ..write('serverSeq: $serverSeq, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FiadoItemsTable extends FiadoItems
    with TableInfo<$FiadoItemsTable, FiadoItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FiadoItemsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _fiadoIdMeta = const VerificationMeta(
    'fiadoId',
  );
  @override
  late final GeneratedColumn<String> fiadoId = GeneratedColumn<String>(
    'fiado_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (quantity > 0)',
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'unit\' CHECK (unit IN (\'unit\', \'pound\', \'ounce\', \'kilo\', \'dozen\', \'liter\', \'gallon\', \'box\', \'bag\', \'pack\'))',
    defaultValue: const CustomExpression('\'unit\''),
  );
  static const VerificationMeta _unitPriceMeta = const VerificationMeta(
    'unitPrice',
  );
  @override
  late final GeneratedColumn<int> unitPrice = GeneratedColumn<int>(
    'unit_price',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (unit_price > 0)',
  );
  static const VerificationMeta _subtotalMeta = const VerificationMeta(
    'subtotal',
  );
  @override
  late final GeneratedColumn<int> subtotal = GeneratedColumn<int>(
    'subtotal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (subtotal > 0)',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    businessId,
    fiadoId,
    productId,
    description,
    quantity,
    unit,
    unitPrice,
    subtotal,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'fiado_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<FiadoItem> instance, {
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
    if (data.containsKey('fiado_id')) {
      context.handle(
        _fiadoIdMeta,
        fiadoId.isAcceptableOrUnknown(data['fiado_id']!, _fiadoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_fiadoIdMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    }
    if (data.containsKey('unit_price')) {
      context.handle(
        _unitPriceMeta,
        unitPrice.isAcceptableOrUnknown(data['unit_price']!, _unitPriceMeta),
      );
    } else if (isInserting) {
      context.missing(_unitPriceMeta);
    }
    if (data.containsKey('subtotal')) {
      context.handle(
        _subtotalMeta,
        subtotal.isAcceptableOrUnknown(data['subtotal']!, _subtotalMeta),
      );
    } else if (isInserting) {
      context.missing(_subtotalMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FiadoItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FiadoItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      )!,
      fiadoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fiado_id'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quantity'],
      )!,
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      )!,
      unitPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unit_price'],
      )!,
      subtotal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subtotal'],
      )!,
    );
  }

  @override
  $FiadoItemsTable createAlias(String alias) {
    return $FiadoItemsTable(attachedDatabase, alias);
  }
}

class FiadoItem extends DataClass implements Insertable<FiadoItem> {
  final String id;
  final String businessId;
  final String fiadoId;

  /// Producto del catálogo del que se copió; null en un ítem libre (RF-31).
  final String? productId;
  final String description;

  /// Cantidad en milésimas.
  final int quantity;

  /// Unidad de venta (RF-86, RF-88): id de la lista compartida, `unit` por
  /// omisión.
  /// La lista del CHECK debe coincidir con `SaleUnit`; un test lo comprueba.
  final String unit;

  /// Precio unitario en la unidad menor.
  final int unitPrice;

  /// Subtotal ya redondeado según el modo del negocio, en la unidad menor.
  final int subtotal;
  const FiadoItem({
    required this.id,
    required this.businessId,
    required this.fiadoId,
    this.productId,
    required this.description,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.subtotal,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['business_id'] = Variable<String>(businessId);
    map['fiado_id'] = Variable<String>(fiadoId);
    if (!nullToAbsent || productId != null) {
      map['product_id'] = Variable<String>(productId);
    }
    map['description'] = Variable<String>(description);
    map['quantity'] = Variable<int>(quantity);
    map['unit'] = Variable<String>(unit);
    map['unit_price'] = Variable<int>(unitPrice);
    map['subtotal'] = Variable<int>(subtotal);
    return map;
  }

  FiadoItemsCompanion toCompanion(bool nullToAbsent) {
    return FiadoItemsCompanion(
      id: Value(id),
      businessId: Value(businessId),
      fiadoId: Value(fiadoId),
      productId: productId == null && nullToAbsent
          ? const Value.absent()
          : Value(productId),
      description: Value(description),
      quantity: Value(quantity),
      unit: Value(unit),
      unitPrice: Value(unitPrice),
      subtotal: Value(subtotal),
    );
  }

  factory FiadoItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FiadoItem(
      id: serializer.fromJson<String>(json['id']),
      businessId: serializer.fromJson<String>(json['businessId']),
      fiadoId: serializer.fromJson<String>(json['fiadoId']),
      productId: serializer.fromJson<String?>(json['productId']),
      description: serializer.fromJson<String>(json['description']),
      quantity: serializer.fromJson<int>(json['quantity']),
      unit: serializer.fromJson<String>(json['unit']),
      unitPrice: serializer.fromJson<int>(json['unitPrice']),
      subtotal: serializer.fromJson<int>(json['subtotal']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'businessId': serializer.toJson<String>(businessId),
      'fiadoId': serializer.toJson<String>(fiadoId),
      'productId': serializer.toJson<String?>(productId),
      'description': serializer.toJson<String>(description),
      'quantity': serializer.toJson<int>(quantity),
      'unit': serializer.toJson<String>(unit),
      'unitPrice': serializer.toJson<int>(unitPrice),
      'subtotal': serializer.toJson<int>(subtotal),
    };
  }

  FiadoItem copyWith({
    String? id,
    String? businessId,
    String? fiadoId,
    Value<String?> productId = const Value.absent(),
    String? description,
    int? quantity,
    String? unit,
    int? unitPrice,
    int? subtotal,
  }) => FiadoItem(
    id: id ?? this.id,
    businessId: businessId ?? this.businessId,
    fiadoId: fiadoId ?? this.fiadoId,
    productId: productId.present ? productId.value : this.productId,
    description: description ?? this.description,
    quantity: quantity ?? this.quantity,
    unit: unit ?? this.unit,
    unitPrice: unitPrice ?? this.unitPrice,
    subtotal: subtotal ?? this.subtotal,
  );
  FiadoItem copyWithCompanion(FiadoItemsCompanion data) {
    return FiadoItem(
      id: data.id.present ? data.id.value : this.id,
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      fiadoId: data.fiadoId.present ? data.fiadoId.value : this.fiadoId,
      productId: data.productId.present ? data.productId.value : this.productId,
      description: data.description.present
          ? data.description.value
          : this.description,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      unit: data.unit.present ? data.unit.value : this.unit,
      unitPrice: data.unitPrice.present ? data.unitPrice.value : this.unitPrice,
      subtotal: data.subtotal.present ? data.subtotal.value : this.subtotal,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FiadoItem(')
          ..write('id: $id, ')
          ..write('businessId: $businessId, ')
          ..write('fiadoId: $fiadoId, ')
          ..write('productId: $productId, ')
          ..write('description: $description, ')
          ..write('quantity: $quantity, ')
          ..write('unit: $unit, ')
          ..write('unitPrice: $unitPrice, ')
          ..write('subtotal: $subtotal')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    businessId,
    fiadoId,
    productId,
    description,
    quantity,
    unit,
    unitPrice,
    subtotal,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FiadoItem &&
          other.id == this.id &&
          other.businessId == this.businessId &&
          other.fiadoId == this.fiadoId &&
          other.productId == this.productId &&
          other.description == this.description &&
          other.quantity == this.quantity &&
          other.unit == this.unit &&
          other.unitPrice == this.unitPrice &&
          other.subtotal == this.subtotal);
}

class FiadoItemsCompanion extends UpdateCompanion<FiadoItem> {
  final Value<String> id;
  final Value<String> businessId;
  final Value<String> fiadoId;
  final Value<String?> productId;
  final Value<String> description;
  final Value<int> quantity;
  final Value<String> unit;
  final Value<int> unitPrice;
  final Value<int> subtotal;
  final Value<int> rowid;
  const FiadoItemsCompanion({
    this.id = const Value.absent(),
    this.businessId = const Value.absent(),
    this.fiadoId = const Value.absent(),
    this.productId = const Value.absent(),
    this.description = const Value.absent(),
    this.quantity = const Value.absent(),
    this.unit = const Value.absent(),
    this.unitPrice = const Value.absent(),
    this.subtotal = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FiadoItemsCompanion.insert({
    required String id,
    required String businessId,
    required String fiadoId,
    this.productId = const Value.absent(),
    required String description,
    required int quantity,
    this.unit = const Value.absent(),
    required int unitPrice,
    required int subtotal,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       businessId = Value(businessId),
       fiadoId = Value(fiadoId),
       description = Value(description),
       quantity = Value(quantity),
       unitPrice = Value(unitPrice),
       subtotal = Value(subtotal);
  static Insertable<FiadoItem> custom({
    Expression<String>? id,
    Expression<String>? businessId,
    Expression<String>? fiadoId,
    Expression<String>? productId,
    Expression<String>? description,
    Expression<int>? quantity,
    Expression<String>? unit,
    Expression<int>? unitPrice,
    Expression<int>? subtotal,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (businessId != null) 'business_id': businessId,
      if (fiadoId != null) 'fiado_id': fiadoId,
      if (productId != null) 'product_id': productId,
      if (description != null) 'description': description,
      if (quantity != null) 'quantity': quantity,
      if (unit != null) 'unit': unit,
      if (unitPrice != null) 'unit_price': unitPrice,
      if (subtotal != null) 'subtotal': subtotal,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FiadoItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? businessId,
    Value<String>? fiadoId,
    Value<String?>? productId,
    Value<String>? description,
    Value<int>? quantity,
    Value<String>? unit,
    Value<int>? unitPrice,
    Value<int>? subtotal,
    Value<int>? rowid,
  }) {
    return FiadoItemsCompanion(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      fiadoId: fiadoId ?? this.fiadoId,
      productId: productId ?? this.productId,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      subtotal: subtotal ?? this.subtotal,
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
    if (fiadoId.present) {
      map['fiado_id'] = Variable<String>(fiadoId.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (unitPrice.present) {
      map['unit_price'] = Variable<int>(unitPrice.value);
    }
    if (subtotal.present) {
      map['subtotal'] = Variable<int>(subtotal.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FiadoItemsCompanion(')
          ..write('id: $id, ')
          ..write('businessId: $businessId, ')
          ..write('fiadoId: $fiadoId, ')
          ..write('productId: $productId, ')
          ..write('description: $description, ')
          ..write('quantity: $quantity, ')
          ..write('unit: $unit, ')
          ..write('unitPrice: $unitPrice, ')
          ..write('subtotal: $subtotal, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PaymentsTable extends Payments with TableInfo<$PaymentsTable, Payment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PaymentsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _clientIdMeta = const VerificationMeta(
    'clientId',
  );
  @override
  late final GeneratedColumn<String> clientId = GeneratedColumn<String>(
    'client_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (amount > 0)',
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, DateTime> occurredAt =
      GeneratedColumn<DateTime>(
        'occurred_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($PaymentsTable.$converteroccurredAt);
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
  late final GeneratedColumnWithTypeConverter<DateTime?, DateTime> annulledAt =
      GeneratedColumn<DateTime>(
        'annulled_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($PaymentsTable.$converterannulledAt);
  static const VerificationMeta _annulledByMeta = const VerificationMeta(
    'annulledBy',
  );
  @override
  late final GeneratedColumn<String> annulledBy = GeneratedColumn<String>(
    'annulled_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serverSeqMeta = const VerificationMeta(
    'serverSeq',
  );
  @override
  late final GeneratedColumn<int> serverSeq = GeneratedColumn<int>(
    'server_seq',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    businessId,
    clientId,
    amount,
    occurredAt,
    createdBy,
    annulledAt,
    annulledBy,
    serverSeq,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'payments';
  @override
  VerificationContext validateIntegrity(
    Insertable<Payment> instance, {
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
    if (data.containsKey('client_id')) {
      context.handle(
        _clientIdMeta,
        clientId.isAcceptableOrUnknown(data['client_id']!, _clientIdMeta),
      );
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    } else if (isInserting) {
      context.missing(_createdByMeta);
    }
    if (data.containsKey('annulled_by')) {
      context.handle(
        _annulledByMeta,
        annulledBy.isAcceptableOrUnknown(data['annulled_by']!, _annulledByMeta),
      );
    }
    if (data.containsKey('server_seq')) {
      context.handle(
        _serverSeqMeta,
        serverSeq.isAcceptableOrUnknown(data['server_seq']!, _serverSeqMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Payment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Payment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      )!,
      clientId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_id'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      )!,
      occurredAt: $PaymentsTable.$converteroccurredAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime,
          data['${effectivePrefix}occurred_at'],
        )!,
      ),
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      )!,
      annulledAt: $PaymentsTable.$converterannulledAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime,
          data['${effectivePrefix}annulled_at'],
        ),
      ),
      annulledBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}annulled_by'],
      ),
      serverSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_seq'],
      ),
    );
  }

  @override
  $PaymentsTable createAlias(String alias) {
    return $PaymentsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, DateTime> $converteroccurredAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime?, DateTime?> $converterannulledAt =
      NullAwareTypeConverter.wrap(const UtcDateTimeConverter());
}

class Payment extends DataClass implements Insertable<Payment> {
  final String id;
  final String businessId;
  final String clientId;
  final int amount;
  final DateTime occurredAt;
  final String createdBy;
  final DateTime? annulledAt;
  final String? annulledBy;
  final int? serverSeq;
  const Payment({
    required this.id,
    required this.businessId,
    required this.clientId,
    required this.amount,
    required this.occurredAt,
    required this.createdBy,
    this.annulledAt,
    this.annulledBy,
    this.serverSeq,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['business_id'] = Variable<String>(businessId);
    map['client_id'] = Variable<String>(clientId);
    map['amount'] = Variable<int>(amount);
    {
      map['occurred_at'] = Variable<DateTime>(
        $PaymentsTable.$converteroccurredAt.toSql(occurredAt),
      );
    }
    map['created_by'] = Variable<String>(createdBy);
    if (!nullToAbsent || annulledAt != null) {
      map['annulled_at'] = Variable<DateTime>(
        $PaymentsTable.$converterannulledAt.toSql(annulledAt),
      );
    }
    if (!nullToAbsent || annulledBy != null) {
      map['annulled_by'] = Variable<String>(annulledBy);
    }
    if (!nullToAbsent || serverSeq != null) {
      map['server_seq'] = Variable<int>(serverSeq);
    }
    return map;
  }

  PaymentsCompanion toCompanion(bool nullToAbsent) {
    return PaymentsCompanion(
      id: Value(id),
      businessId: Value(businessId),
      clientId: Value(clientId),
      amount: Value(amount),
      occurredAt: Value(occurredAt),
      createdBy: Value(createdBy),
      annulledAt: annulledAt == null && nullToAbsent
          ? const Value.absent()
          : Value(annulledAt),
      annulledBy: annulledBy == null && nullToAbsent
          ? const Value.absent()
          : Value(annulledBy),
      serverSeq: serverSeq == null && nullToAbsent
          ? const Value.absent()
          : Value(serverSeq),
    );
  }

  factory Payment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Payment(
      id: serializer.fromJson<String>(json['id']),
      businessId: serializer.fromJson<String>(json['businessId']),
      clientId: serializer.fromJson<String>(json['clientId']),
      amount: serializer.fromJson<int>(json['amount']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      createdBy: serializer.fromJson<String>(json['createdBy']),
      annulledAt: serializer.fromJson<DateTime?>(json['annulledAt']),
      annulledBy: serializer.fromJson<String?>(json['annulledBy']),
      serverSeq: serializer.fromJson<int?>(json['serverSeq']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'businessId': serializer.toJson<String>(businessId),
      'clientId': serializer.toJson<String>(clientId),
      'amount': serializer.toJson<int>(amount),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'createdBy': serializer.toJson<String>(createdBy),
      'annulledAt': serializer.toJson<DateTime?>(annulledAt),
      'annulledBy': serializer.toJson<String?>(annulledBy),
      'serverSeq': serializer.toJson<int?>(serverSeq),
    };
  }

  Payment copyWith({
    String? id,
    String? businessId,
    String? clientId,
    int? amount,
    DateTime? occurredAt,
    String? createdBy,
    Value<DateTime?> annulledAt = const Value.absent(),
    Value<String?> annulledBy = const Value.absent(),
    Value<int?> serverSeq = const Value.absent(),
  }) => Payment(
    id: id ?? this.id,
    businessId: businessId ?? this.businessId,
    clientId: clientId ?? this.clientId,
    amount: amount ?? this.amount,
    occurredAt: occurredAt ?? this.occurredAt,
    createdBy: createdBy ?? this.createdBy,
    annulledAt: annulledAt.present ? annulledAt.value : this.annulledAt,
    annulledBy: annulledBy.present ? annulledBy.value : this.annulledBy,
    serverSeq: serverSeq.present ? serverSeq.value : this.serverSeq,
  );
  Payment copyWithCompanion(PaymentsCompanion data) {
    return Payment(
      id: data.id.present ? data.id.value : this.id,
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      clientId: data.clientId.present ? data.clientId.value : this.clientId,
      amount: data.amount.present ? data.amount.value : this.amount,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      annulledAt: data.annulledAt.present
          ? data.annulledAt.value
          : this.annulledAt,
      annulledBy: data.annulledBy.present
          ? data.annulledBy.value
          : this.annulledBy,
      serverSeq: data.serverSeq.present ? data.serverSeq.value : this.serverSeq,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Payment(')
          ..write('id: $id, ')
          ..write('businessId: $businessId, ')
          ..write('clientId: $clientId, ')
          ..write('amount: $amount, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('createdBy: $createdBy, ')
          ..write('annulledAt: $annulledAt, ')
          ..write('annulledBy: $annulledBy, ')
          ..write('serverSeq: $serverSeq')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    businessId,
    clientId,
    amount,
    occurredAt,
    createdBy,
    annulledAt,
    annulledBy,
    serverSeq,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Payment &&
          other.id == this.id &&
          other.businessId == this.businessId &&
          other.clientId == this.clientId &&
          other.amount == this.amount &&
          other.occurredAt == this.occurredAt &&
          other.createdBy == this.createdBy &&
          other.annulledAt == this.annulledAt &&
          other.annulledBy == this.annulledBy &&
          other.serverSeq == this.serverSeq);
}

class PaymentsCompanion extends UpdateCompanion<Payment> {
  final Value<String> id;
  final Value<String> businessId;
  final Value<String> clientId;
  final Value<int> amount;
  final Value<DateTime> occurredAt;
  final Value<String> createdBy;
  final Value<DateTime?> annulledAt;
  final Value<String?> annulledBy;
  final Value<int?> serverSeq;
  final Value<int> rowid;
  const PaymentsCompanion({
    this.id = const Value.absent(),
    this.businessId = const Value.absent(),
    this.clientId = const Value.absent(),
    this.amount = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.annulledAt = const Value.absent(),
    this.annulledBy = const Value.absent(),
    this.serverSeq = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PaymentsCompanion.insert({
    required String id,
    required String businessId,
    required String clientId,
    required int amount,
    required DateTime occurredAt,
    required String createdBy,
    this.annulledAt = const Value.absent(),
    this.annulledBy = const Value.absent(),
    this.serverSeq = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       businessId = Value(businessId),
       clientId = Value(clientId),
       amount = Value(amount),
       occurredAt = Value(occurredAt),
       createdBy = Value(createdBy);
  static Insertable<Payment> custom({
    Expression<String>? id,
    Expression<String>? businessId,
    Expression<String>? clientId,
    Expression<int>? amount,
    Expression<DateTime>? occurredAt,
    Expression<String>? createdBy,
    Expression<DateTime>? annulledAt,
    Expression<String>? annulledBy,
    Expression<int>? serverSeq,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (businessId != null) 'business_id': businessId,
      if (clientId != null) 'client_id': clientId,
      if (amount != null) 'amount': amount,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (createdBy != null) 'created_by': createdBy,
      if (annulledAt != null) 'annulled_at': annulledAt,
      if (annulledBy != null) 'annulled_by': annulledBy,
      if (serverSeq != null) 'server_seq': serverSeq,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PaymentsCompanion copyWith({
    Value<String>? id,
    Value<String>? businessId,
    Value<String>? clientId,
    Value<int>? amount,
    Value<DateTime>? occurredAt,
    Value<String>? createdBy,
    Value<DateTime?>? annulledAt,
    Value<String?>? annulledBy,
    Value<int?>? serverSeq,
    Value<int>? rowid,
  }) {
    return PaymentsCompanion(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      clientId: clientId ?? this.clientId,
      amount: amount ?? this.amount,
      occurredAt: occurredAt ?? this.occurredAt,
      createdBy: createdBy ?? this.createdBy,
      annulledAt: annulledAt ?? this.annulledAt,
      annulledBy: annulledBy ?? this.annulledBy,
      serverSeq: serverSeq ?? this.serverSeq,
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
    if (clientId.present) {
      map['client_id'] = Variable<String>(clientId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(
        $PaymentsTable.$converteroccurredAt.toSql(occurredAt.value),
      );
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (annulledAt.present) {
      map['annulled_at'] = Variable<DateTime>(
        $PaymentsTable.$converterannulledAt.toSql(annulledAt.value),
      );
    }
    if (annulledBy.present) {
      map['annulled_by'] = Variable<String>(annulledBy.value);
    }
    if (serverSeq.present) {
      map['server_seq'] = Variable<int>(serverSeq.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PaymentsCompanion(')
          ..write('id: $id, ')
          ..write('businessId: $businessId, ')
          ..write('clientId: $clientId, ')
          ..write('amount: $amount, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('createdBy: $createdBy, ')
          ..write('annulledAt: $annulledAt, ')
          ..write('annulledBy: $annulledBy, ')
          ..write('serverSeq: $serverSeq, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxOpsTable extends OutboxOps
    with TableInfo<$OutboxOpsTable, OutboxOp> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxOpsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _localSeqMeta = const VerificationMeta(
    'localSeq',
  );
  @override
  late final GeneratedColumn<int> localSeq = GeneratedColumn<int>(
    'local_seq',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _opIdMeta = const VerificationMeta('opId');
  @override
  late final GeneratedColumn<String> opId = GeneratedColumn<String>(
    'op_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
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
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseVersionMeta = const VerificationMeta(
    'baseVersion',
  );
  @override
  late final GeneratedColumn<int> baseVersion = GeneratedColumn<int>(
    'base_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _errorCodeMeta = const VerificationMeta(
    'errorCode',
  );
  @override
  late final GeneratedColumn<String> errorCode = GeneratedColumn<String>(
    'error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, DateTime> createdAt =
      GeneratedColumn<DateTime>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($OutboxOpsTable.$convertercreatedAt);
  @override
  List<GeneratedColumn> get $columns => [
    localSeq,
    opId,
    businessId,
    type,
    entityId,
    payload,
    baseVersion,
    status,
    errorCode,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox_ops';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxOp> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('local_seq')) {
      context.handle(
        _localSeqMeta,
        localSeq.isAcceptableOrUnknown(data['local_seq']!, _localSeqMeta),
      );
    }
    if (data.containsKey('op_id')) {
      context.handle(
        _opIdMeta,
        opId.isAcceptableOrUnknown(data['op_id']!, _opIdMeta),
      );
    } else if (isInserting) {
      context.missing(_opIdMeta);
    }
    if (data.containsKey('business_id')) {
      context.handle(
        _businessIdMeta,
        businessId.isAcceptableOrUnknown(data['business_id']!, _businessIdMeta),
      );
    } else if (isInserting) {
      context.missing(_businessIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('base_version')) {
      context.handle(
        _baseVersionMeta,
        baseVersion.isAcceptableOrUnknown(
          data['base_version']!,
          _baseVersionMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('error_code')) {
      context.handle(
        _errorCodeMeta,
        errorCode.isAcceptableOrUnknown(data['error_code']!, _errorCodeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {localSeq};
  @override
  OutboxOp map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxOp(
      localSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_seq'],
      )!,
      opId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}op_id'],
      )!,
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      baseVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}base_version'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      errorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_code'],
      ),
      createdAt: $OutboxOpsTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime,
          data['${effectivePrefix}created_at'],
        )!,
      ),
    );
  }

  @override
  $OutboxOpsTable createAlias(String alias) {
    return $OutboxOpsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, DateTime> $convertercreatedAt =
      const UtcDateTimeConverter();
}

class OutboxOp extends DataClass implements Insertable<OutboxOp> {
  /// Orden local de creación: el envío respeta este orden aunque dos
  /// operaciones tengan la misma fecha. Con AUTOINCREMENT nunca se reutiliza.
  final int localSeq;

  /// Identificador de la operación (GUID): reenviarla no duplica nada en el
  /// servidor (RF-53).
  final String opId;
  final String businessId;
  final String type;

  /// Id del cliente, producto, fiado o abono sobre el que actúa.
  final String entityId;

  /// Contenido de la operación, en JSON.
  final String payload;

  /// Versión de la entidad sobre la que se hizo una edición, para detectar
  /// conflictos (D-8).
  final int? baseVersion;

  /// `pending`, `sent` o `rejected`.
  final String status;

  /// Motivo del rechazo; solo cuando el estado es `rejected`.
  final String? errorCode;
  final DateTime createdAt;
  const OutboxOp({
    required this.localSeq,
    required this.opId,
    required this.businessId,
    required this.type,
    required this.entityId,
    required this.payload,
    this.baseVersion,
    required this.status,
    this.errorCode,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_seq'] = Variable<int>(localSeq);
    map['op_id'] = Variable<String>(opId);
    map['business_id'] = Variable<String>(businessId);
    map['type'] = Variable<String>(type);
    map['entity_id'] = Variable<String>(entityId);
    map['payload'] = Variable<String>(payload);
    if (!nullToAbsent || baseVersion != null) {
      map['base_version'] = Variable<int>(baseVersion);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || errorCode != null) {
      map['error_code'] = Variable<String>(errorCode);
    }
    {
      map['created_at'] = Variable<DateTime>(
        $OutboxOpsTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    return map;
  }

  OutboxOpsCompanion toCompanion(bool nullToAbsent) {
    return OutboxOpsCompanion(
      localSeq: Value(localSeq),
      opId: Value(opId),
      businessId: Value(businessId),
      type: Value(type),
      entityId: Value(entityId),
      payload: Value(payload),
      baseVersion: baseVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(baseVersion),
      status: Value(status),
      errorCode: errorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(errorCode),
      createdAt: Value(createdAt),
    );
  }

  factory OutboxOp.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxOp(
      localSeq: serializer.fromJson<int>(json['localSeq']),
      opId: serializer.fromJson<String>(json['opId']),
      businessId: serializer.fromJson<String>(json['businessId']),
      type: serializer.fromJson<String>(json['type']),
      entityId: serializer.fromJson<String>(json['entityId']),
      payload: serializer.fromJson<String>(json['payload']),
      baseVersion: serializer.fromJson<int?>(json['baseVersion']),
      status: serializer.fromJson<String>(json['status']),
      errorCode: serializer.fromJson<String?>(json['errorCode']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localSeq': serializer.toJson<int>(localSeq),
      'opId': serializer.toJson<String>(opId),
      'businessId': serializer.toJson<String>(businessId),
      'type': serializer.toJson<String>(type),
      'entityId': serializer.toJson<String>(entityId),
      'payload': serializer.toJson<String>(payload),
      'baseVersion': serializer.toJson<int?>(baseVersion),
      'status': serializer.toJson<String>(status),
      'errorCode': serializer.toJson<String?>(errorCode),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  OutboxOp copyWith({
    int? localSeq,
    String? opId,
    String? businessId,
    String? type,
    String? entityId,
    String? payload,
    Value<int?> baseVersion = const Value.absent(),
    String? status,
    Value<String?> errorCode = const Value.absent(),
    DateTime? createdAt,
  }) => OutboxOp(
    localSeq: localSeq ?? this.localSeq,
    opId: opId ?? this.opId,
    businessId: businessId ?? this.businessId,
    type: type ?? this.type,
    entityId: entityId ?? this.entityId,
    payload: payload ?? this.payload,
    baseVersion: baseVersion.present ? baseVersion.value : this.baseVersion,
    status: status ?? this.status,
    errorCode: errorCode.present ? errorCode.value : this.errorCode,
    createdAt: createdAt ?? this.createdAt,
  );
  OutboxOp copyWithCompanion(OutboxOpsCompanion data) {
    return OutboxOp(
      localSeq: data.localSeq.present ? data.localSeq.value : this.localSeq,
      opId: data.opId.present ? data.opId.value : this.opId,
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      type: data.type.present ? data.type.value : this.type,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      payload: data.payload.present ? data.payload.value : this.payload,
      baseVersion: data.baseVersion.present
          ? data.baseVersion.value
          : this.baseVersion,
      status: data.status.present ? data.status.value : this.status,
      errorCode: data.errorCode.present ? data.errorCode.value : this.errorCode,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxOp(')
          ..write('localSeq: $localSeq, ')
          ..write('opId: $opId, ')
          ..write('businessId: $businessId, ')
          ..write('type: $type, ')
          ..write('entityId: $entityId, ')
          ..write('payload: $payload, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('status: $status, ')
          ..write('errorCode: $errorCode, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    localSeq,
    opId,
    businessId,
    type,
    entityId,
    payload,
    baseVersion,
    status,
    errorCode,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxOp &&
          other.localSeq == this.localSeq &&
          other.opId == this.opId &&
          other.businessId == this.businessId &&
          other.type == this.type &&
          other.entityId == this.entityId &&
          other.payload == this.payload &&
          other.baseVersion == this.baseVersion &&
          other.status == this.status &&
          other.errorCode == this.errorCode &&
          other.createdAt == this.createdAt);
}

class OutboxOpsCompanion extends UpdateCompanion<OutboxOp> {
  final Value<int> localSeq;
  final Value<String> opId;
  final Value<String> businessId;
  final Value<String> type;
  final Value<String> entityId;
  final Value<String> payload;
  final Value<int?> baseVersion;
  final Value<String> status;
  final Value<String?> errorCode;
  final Value<DateTime> createdAt;
  const OutboxOpsCompanion({
    this.localSeq = const Value.absent(),
    this.opId = const Value.absent(),
    this.businessId = const Value.absent(),
    this.type = const Value.absent(),
    this.entityId = const Value.absent(),
    this.payload = const Value.absent(),
    this.baseVersion = const Value.absent(),
    this.status = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  OutboxOpsCompanion.insert({
    this.localSeq = const Value.absent(),
    required String opId,
    required String businessId,
    required String type,
    required String entityId,
    required String payload,
    this.baseVersion = const Value.absent(),
    this.status = const Value.absent(),
    this.errorCode = const Value.absent(),
    required DateTime createdAt,
  }) : opId = Value(opId),
       businessId = Value(businessId),
       type = Value(type),
       entityId = Value(entityId),
       payload = Value(payload),
       createdAt = Value(createdAt);
  static Insertable<OutboxOp> custom({
    Expression<int>? localSeq,
    Expression<String>? opId,
    Expression<String>? businessId,
    Expression<String>? type,
    Expression<String>? entityId,
    Expression<String>? payload,
    Expression<int>? baseVersion,
    Expression<String>? status,
    Expression<String>? errorCode,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (localSeq != null) 'local_seq': localSeq,
      if (opId != null) 'op_id': opId,
      if (businessId != null) 'business_id': businessId,
      if (type != null) 'type': type,
      if (entityId != null) 'entity_id': entityId,
      if (payload != null) 'payload': payload,
      if (baseVersion != null) 'base_version': baseVersion,
      if (status != null) 'status': status,
      if (errorCode != null) 'error_code': errorCode,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  OutboxOpsCompanion copyWith({
    Value<int>? localSeq,
    Value<String>? opId,
    Value<String>? businessId,
    Value<String>? type,
    Value<String>? entityId,
    Value<String>? payload,
    Value<int?>? baseVersion,
    Value<String>? status,
    Value<String?>? errorCode,
    Value<DateTime>? createdAt,
  }) {
    return OutboxOpsCompanion(
      localSeq: localSeq ?? this.localSeq,
      opId: opId ?? this.opId,
      businessId: businessId ?? this.businessId,
      type: type ?? this.type,
      entityId: entityId ?? this.entityId,
      payload: payload ?? this.payload,
      baseVersion: baseVersion ?? this.baseVersion,
      status: status ?? this.status,
      errorCode: errorCode ?? this.errorCode,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (localSeq.present) {
      map['local_seq'] = Variable<int>(localSeq.value);
    }
    if (opId.present) {
      map['op_id'] = Variable<String>(opId.value);
    }
    if (businessId.present) {
      map['business_id'] = Variable<String>(businessId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (baseVersion.present) {
      map['base_version'] = Variable<int>(baseVersion.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (errorCode.present) {
      map['error_code'] = Variable<String>(errorCode.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(
        $OutboxOpsTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxOpsCompanion(')
          ..write('localSeq: $localSeq, ')
          ..write('opId: $opId, ')
          ..write('businessId: $businessId, ')
          ..write('type: $type, ')
          ..write('entityId: $entityId, ')
          ..write('payload: $payload, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('status: $status, ')
          ..write('errorCode: $errorCode, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $SyncStatesTable extends SyncStates
    with TableInfo<$SyncStatesTable, SyncState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStatesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _cursorMeta = const VerificationMeta('cursor');
  @override
  late final GeneratedColumn<int> cursor = GeneratedColumn<int>(
    'cursor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [businessId, cursor];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncState> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('business_id')) {
      context.handle(
        _businessIdMeta,
        businessId.isAcceptableOrUnknown(data['business_id']!, _businessIdMeta),
      );
    } else if (isInserting) {
      context.missing(_businessIdMeta);
    }
    if (data.containsKey('cursor')) {
      context.handle(
        _cursorMeta,
        cursor.isAcceptableOrUnknown(data['cursor']!, _cursorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {businessId};
  @override
  SyncState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncState(
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      )!,
      cursor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cursor'],
      )!,
    );
  }

  @override
  $SyncStatesTable createAlias(String alias) {
    return $SyncStatesTable(attachedDatabase, alias);
  }
}

class SyncState extends DataClass implements Insertable<SyncState> {
  final String businessId;
  final int cursor;
  const SyncState({required this.businessId, required this.cursor});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['business_id'] = Variable<String>(businessId);
    map['cursor'] = Variable<int>(cursor);
    return map;
  }

  SyncStatesCompanion toCompanion(bool nullToAbsent) {
    return SyncStatesCompanion(
      businessId: Value(businessId),
      cursor: Value(cursor),
    );
  }

  factory SyncState.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncState(
      businessId: serializer.fromJson<String>(json['businessId']),
      cursor: serializer.fromJson<int>(json['cursor']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'businessId': serializer.toJson<String>(businessId),
      'cursor': serializer.toJson<int>(cursor),
    };
  }

  SyncState copyWith({String? businessId, int? cursor}) => SyncState(
    businessId: businessId ?? this.businessId,
    cursor: cursor ?? this.cursor,
  );
  SyncState copyWithCompanion(SyncStatesCompanion data) {
    return SyncState(
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      cursor: data.cursor.present ? data.cursor.value : this.cursor,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncState(')
          ..write('businessId: $businessId, ')
          ..write('cursor: $cursor')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(businessId, cursor);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncState &&
          other.businessId == this.businessId &&
          other.cursor == this.cursor);
}

class SyncStatesCompanion extends UpdateCompanion<SyncState> {
  final Value<String> businessId;
  final Value<int> cursor;
  final Value<int> rowid;
  const SyncStatesCompanion({
    this.businessId = const Value.absent(),
    this.cursor = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStatesCompanion.insert({
    required String businessId,
    this.cursor = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : businessId = Value(businessId);
  static Insertable<SyncState> custom({
    Expression<String>? businessId,
    Expression<int>? cursor,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (businessId != null) 'business_id': businessId,
      if (cursor != null) 'cursor': cursor,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStatesCompanion copyWith({
    Value<String>? businessId,
    Value<int>? cursor,
    Value<int>? rowid,
  }) {
    return SyncStatesCompanion(
      businessId: businessId ?? this.businessId,
      cursor: cursor ?? this.cursor,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (businessId.present) {
      map['business_id'] = Variable<String>(businessId.value);
    }
    if (cursor.present) {
      map['cursor'] = Variable<int>(cursor.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStatesCompanion(')
          ..write('businessId: $businessId, ')
          ..write('cursor: $cursor, ')
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
  late final $FiadosTable fiados = $FiadosTable(this);
  late final $FiadoItemsTable fiadoItems = $FiadoItemsTable(this);
  late final $PaymentsTable payments = $PaymentsTable(this);
  late final $OutboxOpsTable outboxOps = $OutboxOpsTable(this);
  late final $SyncStatesTable syncStates = $SyncStatesTable(this);
  late final Index clientsBusiness = Index(
    'clients_business',
    'CREATE INDEX clients_business ON clients (business_id)',
  );
  late final Index productsBusiness = Index(
    'products_business',
    'CREATE INDEX products_business ON products (business_id)',
  );
  late final Index fiadosBusiness = Index(
    'fiados_business',
    'CREATE INDEX fiados_business ON fiados (business_id)',
  );
  late final Index fiadosClient = Index(
    'fiados_client',
    'CREATE INDEX fiados_client ON fiados (client_id)',
  );
  late final Index fiadoItemsFiado = Index(
    'fiado_items_fiado',
    'CREATE INDEX fiado_items_fiado ON fiado_items (fiado_id)',
  );
  late final Index paymentsBusiness = Index(
    'payments_business',
    'CREATE INDEX payments_business ON payments (business_id)',
  );
  late final Index paymentsClient = Index(
    'payments_client',
    'CREATE INDEX payments_client ON payments (client_id)',
  );
  late final Index outboxOpsBusinessStatus = Index(
    'outbox_ops_business_status',
    'CREATE INDEX outbox_ops_business_status ON outbox_ops (business_id, status)',
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
    fiados,
    fiadoItems,
    payments,
    outboxOps,
    syncStates,
    clientsBusiness,
    productsBusiness,
    fiadosBusiness,
    fiadosClient,
    fiadoItemsFiado,
    paymentsBusiness,
    paymentsClient,
    outboxOpsBusinessStatus,
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

  static MultiTypedResultKey<$FiadosTable, List<Fiado>> _fiadosRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.fiados,
    aliasName: 'businesses__id__fiados__business_id',
  );

  $$FiadosTableProcessedTableManager get fiadosRefs {
    final manager = $$FiadosTableTableManager(
      $_db,
      $_db.fiados,
    ).filter((f) => f.businessId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_fiadosRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$FiadoItemsTable, List<FiadoItem>>
  _fiadoItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.fiadoItems,
    aliasName: 'businesses__id__fiado_items__business_id',
  );

  $$FiadoItemsTableProcessedTableManager get fiadoItemsRefs {
    final manager = $$FiadoItemsTableTableManager(
      $_db,
      $_db.fiadoItems,
    ).filter((f) => f.businessId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_fiadoItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PaymentsTable, List<Payment>> _paymentsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.payments,
    aliasName: 'businesses__id__payments__business_id',
  );

  $$PaymentsTableProcessedTableManager get paymentsRefs {
    final manager = $$PaymentsTableTableManager(
      $_db,
      $_db.payments,
    ).filter((f) => f.businessId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_paymentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$OutboxOpsTable, List<OutboxOp>>
  _outboxOpsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.outboxOps,
    aliasName: 'businesses__id__outbox_ops__business_id',
  );

  $$OutboxOpsTableProcessedTableManager get outboxOpsRefs {
    final manager = $$OutboxOpsTableTableManager(
      $_db,
      $_db.outboxOps,
    ).filter((f) => f.businessId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_outboxOpsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SyncStatesTable, List<SyncState>>
  _syncStatesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.syncStates,
    aliasName: 'businesses__id__sync_states__business_id',
  );

  $$SyncStatesTableProcessedTableManager get syncStatesRefs {
    final manager = $$SyncStatesTableTableManager(
      $_db,
      $_db.syncStates,
    ).filter((f) => f.businessId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_syncStatesRefsTable($_db));
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

  Expression<bool> fiadosRefs(
    Expression<bool> Function($$FiadosTableFilterComposer f) f,
  ) {
    final $$FiadosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.fiados,
      getReferencedColumn: (t) => t.businessId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FiadosTableFilterComposer(
            $db: $db,
            $table: $db.fiados,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> fiadoItemsRefs(
    Expression<bool> Function($$FiadoItemsTableFilterComposer f) f,
  ) {
    final $$FiadoItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.fiadoItems,
      getReferencedColumn: (t) => t.businessId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FiadoItemsTableFilterComposer(
            $db: $db,
            $table: $db.fiadoItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> paymentsRefs(
    Expression<bool> Function($$PaymentsTableFilterComposer f) f,
  ) {
    final $$PaymentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.payments,
      getReferencedColumn: (t) => t.businessId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PaymentsTableFilterComposer(
            $db: $db,
            $table: $db.payments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> outboxOpsRefs(
    Expression<bool> Function($$OutboxOpsTableFilterComposer f) f,
  ) {
    final $$OutboxOpsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.outboxOps,
      getReferencedColumn: (t) => t.businessId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OutboxOpsTableFilterComposer(
            $db: $db,
            $table: $db.outboxOps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> syncStatesRefs(
    Expression<bool> Function($$SyncStatesTableFilterComposer f) f,
  ) {
    final $$SyncStatesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.syncStates,
      getReferencedColumn: (t) => t.businessId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyncStatesTableFilterComposer(
            $db: $db,
            $table: $db.syncStates,
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

  Expression<T> fiadosRefs<T extends Object>(
    Expression<T> Function($$FiadosTableAnnotationComposer a) f,
  ) {
    final $$FiadosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.fiados,
      getReferencedColumn: (t) => t.businessId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FiadosTableAnnotationComposer(
            $db: $db,
            $table: $db.fiados,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> fiadoItemsRefs<T extends Object>(
    Expression<T> Function($$FiadoItemsTableAnnotationComposer a) f,
  ) {
    final $$FiadoItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.fiadoItems,
      getReferencedColumn: (t) => t.businessId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FiadoItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.fiadoItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> paymentsRefs<T extends Object>(
    Expression<T> Function($$PaymentsTableAnnotationComposer a) f,
  ) {
    final $$PaymentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.payments,
      getReferencedColumn: (t) => t.businessId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PaymentsTableAnnotationComposer(
            $db: $db,
            $table: $db.payments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> outboxOpsRefs<T extends Object>(
    Expression<T> Function($$OutboxOpsTableAnnotationComposer a) f,
  ) {
    final $$OutboxOpsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.outboxOps,
      getReferencedColumn: (t) => t.businessId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OutboxOpsTableAnnotationComposer(
            $db: $db,
            $table: $db.outboxOps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> syncStatesRefs<T extends Object>(
    Expression<T> Function($$SyncStatesTableAnnotationComposer a) f,
  ) {
    final $$SyncStatesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.syncStates,
      getReferencedColumn: (t) => t.businessId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyncStatesTableAnnotationComposer(
            $db: $db,
            $table: $db.syncStates,
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
            bool fiadosRefs,
            bool fiadoItemsRefs,
            bool paymentsRefs,
            bool outboxOpsRefs,
            bool syncStatesRefs,
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
                fiadosRefs = false,
                fiadoItemsRefs = false,
                paymentsRefs = false,
                outboxOpsRefs = false,
                syncStatesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (membershipsRefs) db.memberships,
                    if (clientsRefs) db.clients,
                    if (productsRefs) db.products,
                    if (fiadosRefs) db.fiados,
                    if (fiadoItemsRefs) db.fiadoItems,
                    if (paymentsRefs) db.payments,
                    if (outboxOpsRefs) db.outboxOps,
                    if (syncStatesRefs) db.syncStates,
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
                      if (fiadosRefs)
                        await $_getPrefetchedData<
                          Business,
                          $BusinessesTable,
                          Fiado
                        >(
                          currentTable: table,
                          referencedTable: $$BusinessesTableReferences
                              ._fiadosRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BusinessesTableReferences(
                                db,
                                table,
                                p0,
                              ).fiadosRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.businessId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (fiadoItemsRefs)
                        await $_getPrefetchedData<
                          Business,
                          $BusinessesTable,
                          FiadoItem
                        >(
                          currentTable: table,
                          referencedTable: $$BusinessesTableReferences
                              ._fiadoItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BusinessesTableReferences(
                                db,
                                table,
                                p0,
                              ).fiadoItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.businessId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (paymentsRefs)
                        await $_getPrefetchedData<
                          Business,
                          $BusinessesTable,
                          Payment
                        >(
                          currentTable: table,
                          referencedTable: $$BusinessesTableReferences
                              ._paymentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BusinessesTableReferences(
                                db,
                                table,
                                p0,
                              ).paymentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.businessId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (outboxOpsRefs)
                        await $_getPrefetchedData<
                          Business,
                          $BusinessesTable,
                          OutboxOp
                        >(
                          currentTable: table,
                          referencedTable: $$BusinessesTableReferences
                              ._outboxOpsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BusinessesTableReferences(
                                db,
                                table,
                                p0,
                              ).outboxOpsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.businessId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (syncStatesRefs)
                        await $_getPrefetchedData<
                          Business,
                          $BusinessesTable,
                          SyncState
                        >(
                          currentTable: table,
                          referencedTable: $$BusinessesTableReferences
                              ._syncStatesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BusinessesTableReferences(
                                db,
                                table,
                                p0,
                              ).syncStatesRefs,
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
        bool fiadosRefs,
        bool fiadoItemsRefs,
        bool paymentsRefs,
        bool outboxOpsRefs,
        bool syncStatesRefs,
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
  Value<String> unit,
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
  Value<String> unit,
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

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
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

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
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

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

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
                Value<String> unit = const Value.absent(),
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
                unit: unit,
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
                Value<String> unit = const Value.absent(),
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
                unit: unit,
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
typedef $$FiadosTableCreateCompanionBuilder = FiadosCompanion Function({
  required String id,
  required String businessId,
  required String clientId,
  required int total,
  required DateTime occurredAt,
  required String createdBy,
  Value<DateTime?> annulledAt,
  Value<String?> annulledBy,
  Value<int?> serverSeq,
  Value<int> rowid,
});
typedef $$FiadosTableUpdateCompanionBuilder = FiadosCompanion Function({
  Value<String> id,
  Value<String> businessId,
  Value<String> clientId,
  Value<int> total,
  Value<DateTime> occurredAt,
  Value<String> createdBy,
  Value<DateTime?> annulledAt,
  Value<String?> annulledBy,
  Value<int?> serverSeq,
  Value<int> rowid,
});

final class $$FiadosTableReferences
    extends BaseReferences<_$AppDatabase, $FiadosTable, Fiado> {
  $$FiadosTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BusinessesTable _businessIdTable(_$AppDatabase db) =>
      db.businesses.createAlias('fiados__business_id__businesses__id');

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

class $$FiadosTableFilterComposer
    extends Composer<_$AppDatabase, $FiadosTable> {
  $$FiadosTableFilterComposer({
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

  ColumnFilters<String> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, DateTime> get occurredAt =>
      $composableBuilder(
        column: $table.occurredAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, DateTime>
  get annulledAt => $composableBuilder(
    column: $table.annulledAt,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get annulledBy => $composableBuilder(
    column: $table.annulledBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverSeq => $composableBuilder(
    column: $table.serverSeq,
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

class $$FiadosTableOrderingComposer
    extends Composer<_$AppDatabase, $FiadosTable> {
  $$FiadosTableOrderingComposer({
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

  ColumnOrderings<String> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get annulledAt => $composableBuilder(
    column: $table.annulledAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get annulledBy => $composableBuilder(
    column: $table.annulledBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverSeq => $composableBuilder(
    column: $table.serverSeq,
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

class $$FiadosTableAnnotationComposer
    extends Composer<_$AppDatabase, $FiadosTable> {
  $$FiadosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get clientId =>
      $composableBuilder(column: $table.clientId, builder: (column) => column);

  GeneratedColumn<int> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, DateTime> get occurredAt =>
      $composableBuilder(
        column: $table.occurredAt,
        builder: (column) => column,
      );

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, DateTime> get annulledAt =>
      $composableBuilder(
        column: $table.annulledAt,
        builder: (column) => column,
      );

  GeneratedColumn<String> get annulledBy => $composableBuilder(
    column: $table.annulledBy,
    builder: (column) => column,
  );

  GeneratedColumn<int> get serverSeq =>
      $composableBuilder(column: $table.serverSeq, builder: (column) => column);

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

class $$FiadosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FiadosTable,
          Fiado,
          $$FiadosTableFilterComposer,
          $$FiadosTableOrderingComposer,
          $$FiadosTableAnnotationComposer,
          $$FiadosTableCreateCompanionBuilder,
          $$FiadosTableUpdateCompanionBuilder,
          (Fiado, $$FiadosTableReferences),
          Fiado,
          PrefetchHooks Function({bool businessId})
        > {
  $$FiadosTableTableManager(_$AppDatabase db, $FiadosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FiadosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FiadosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FiadosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> businessId = const Value.absent(),
                Value<String> clientId = const Value.absent(),
                Value<int> total = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<String> createdBy = const Value.absent(),
                Value<DateTime?> annulledAt = const Value.absent(),
                Value<String?> annulledBy = const Value.absent(),
                Value<int?> serverSeq = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FiadosCompanion(
                id: id,
                businessId: businessId,
                clientId: clientId,
                total: total,
                occurredAt: occurredAt,
                createdBy: createdBy,
                annulledAt: annulledAt,
                annulledBy: annulledBy,
                serverSeq: serverSeq,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String businessId,
                required String clientId,
                required int total,
                required DateTime occurredAt,
                required String createdBy,
                Value<DateTime?> annulledAt = const Value.absent(),
                Value<String?> annulledBy = const Value.absent(),
                Value<int?> serverSeq = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FiadosCompanion.insert(
                id: id,
                businessId: businessId,
                clientId: clientId,
                total: total,
                occurredAt: occurredAt,
                createdBy: createdBy,
                annulledAt: annulledAt,
                annulledBy: annulledBy,
                serverSeq: serverSeq,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FiadosTable, Fiado>(table),
                  $$FiadosTableReferences(db, table, e),
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
                        referencedTable: $$FiadosTableReferences
                            ._businessIdTable(db),
                        referencedColumn: $$FiadosTableReferences
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

typedef $$FiadosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FiadosTable,
      Fiado,
      $$FiadosTableFilterComposer,
      $$FiadosTableOrderingComposer,
      $$FiadosTableAnnotationComposer,
      $$FiadosTableCreateCompanionBuilder,
      $$FiadosTableUpdateCompanionBuilder,
      (Fiado, $$FiadosTableReferences),
      Fiado,
      PrefetchHooks Function({bool businessId})
    >;
typedef $$FiadoItemsTableCreateCompanionBuilder = FiadoItemsCompanion Function({
  required String id,
  required String businessId,
  required String fiadoId,
  Value<String?> productId,
  required String description,
  required int quantity,
  Value<String> unit,
  required int unitPrice,
  required int subtotal,
  Value<int> rowid,
});
typedef $$FiadoItemsTableUpdateCompanionBuilder = FiadoItemsCompanion Function({
  Value<String> id,
  Value<String> businessId,
  Value<String> fiadoId,
  Value<String?> productId,
  Value<String> description,
  Value<int> quantity,
  Value<String> unit,
  Value<int> unitPrice,
  Value<int> subtotal,
  Value<int> rowid,
});

final class $$FiadoItemsTableReferences
    extends BaseReferences<_$AppDatabase, $FiadoItemsTable, FiadoItem> {
  $$FiadoItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BusinessesTable _businessIdTable(_$AppDatabase db) =>
      db.businesses.createAlias('fiado_items__business_id__businesses__id');

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

class $$FiadoItemsTableFilterComposer
    extends Composer<_$AppDatabase, $FiadoItemsTable> {
  $$FiadoItemsTableFilterComposer({
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

  ColumnFilters<String> get fiadoId => $composableBuilder(
    column: $table.fiadoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unitPrice => $composableBuilder(
    column: $table.unitPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get subtotal => $composableBuilder(
    column: $table.subtotal,
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

class $$FiadoItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $FiadoItemsTable> {
  $$FiadoItemsTableOrderingComposer({
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

  ColumnOrderings<String> get fiadoId => $composableBuilder(
    column: $table.fiadoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unitPrice => $composableBuilder(
    column: $table.unitPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get subtotal => $composableBuilder(
    column: $table.subtotal,
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

class $$FiadoItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FiadoItemsTable> {
  $$FiadoItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fiadoId =>
      $composableBuilder(column: $table.fiadoId, builder: (column) => column);

  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<int> get unitPrice =>
      $composableBuilder(column: $table.unitPrice, builder: (column) => column);

  GeneratedColumn<int> get subtotal =>
      $composableBuilder(column: $table.subtotal, builder: (column) => column);

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

class $$FiadoItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FiadoItemsTable,
          FiadoItem,
          $$FiadoItemsTableFilterComposer,
          $$FiadoItemsTableOrderingComposer,
          $$FiadoItemsTableAnnotationComposer,
          $$FiadoItemsTableCreateCompanionBuilder,
          $$FiadoItemsTableUpdateCompanionBuilder,
          (FiadoItem, $$FiadoItemsTableReferences),
          FiadoItem,
          PrefetchHooks Function({bool businessId})
        > {
  $$FiadoItemsTableTableManager(_$AppDatabase db, $FiadoItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FiadoItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FiadoItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FiadoItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> businessId = const Value.absent(),
                Value<String> fiadoId = const Value.absent(),
                Value<String?> productId = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<int> quantity = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<int> unitPrice = const Value.absent(),
                Value<int> subtotal = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FiadoItemsCompanion(
                id: id,
                businessId: businessId,
                fiadoId: fiadoId,
                productId: productId,
                description: description,
                quantity: quantity,
                unit: unit,
                unitPrice: unitPrice,
                subtotal: subtotal,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String businessId,
                required String fiadoId,
                Value<String?> productId = const Value.absent(),
                required String description,
                required int quantity,
                Value<String> unit = const Value.absent(),
                required int unitPrice,
                required int subtotal,
                Value<int> rowid = const Value.absent(),
              }) => FiadoItemsCompanion.insert(
                id: id,
                businessId: businessId,
                fiadoId: fiadoId,
                productId: productId,
                description: description,
                quantity: quantity,
                unit: unit,
                unitPrice: unitPrice,
                subtotal: subtotal,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FiadoItemsTable, FiadoItem>(table),
                  $$FiadoItemsTableReferences(db, table, e),
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
                        referencedTable: $$FiadoItemsTableReferences
                            ._businessIdTable(db),
                        referencedColumn: $$FiadoItemsTableReferences
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

typedef $$FiadoItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FiadoItemsTable,
      FiadoItem,
      $$FiadoItemsTableFilterComposer,
      $$FiadoItemsTableOrderingComposer,
      $$FiadoItemsTableAnnotationComposer,
      $$FiadoItemsTableCreateCompanionBuilder,
      $$FiadoItemsTableUpdateCompanionBuilder,
      (FiadoItem, $$FiadoItemsTableReferences),
      FiadoItem,
      PrefetchHooks Function({bool businessId})
    >;
typedef $$PaymentsTableCreateCompanionBuilder = PaymentsCompanion Function({
  required String id,
  required String businessId,
  required String clientId,
  required int amount,
  required DateTime occurredAt,
  required String createdBy,
  Value<DateTime?> annulledAt,
  Value<String?> annulledBy,
  Value<int?> serverSeq,
  Value<int> rowid,
});
typedef $$PaymentsTableUpdateCompanionBuilder = PaymentsCompanion Function({
  Value<String> id,
  Value<String> businessId,
  Value<String> clientId,
  Value<int> amount,
  Value<DateTime> occurredAt,
  Value<String> createdBy,
  Value<DateTime?> annulledAt,
  Value<String?> annulledBy,
  Value<int?> serverSeq,
  Value<int> rowid,
});

final class $$PaymentsTableReferences
    extends BaseReferences<_$AppDatabase, $PaymentsTable, Payment> {
  $$PaymentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BusinessesTable _businessIdTable(_$AppDatabase db) =>
      db.businesses.createAlias('payments__business_id__businesses__id');

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

class $$PaymentsTableFilterComposer
    extends Composer<_$AppDatabase, $PaymentsTable> {
  $$PaymentsTableFilterComposer({
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

  ColumnFilters<String> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, DateTime> get occurredAt =>
      $composableBuilder(
        column: $table.occurredAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, DateTime>
  get annulledAt => $composableBuilder(
    column: $table.annulledAt,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get annulledBy => $composableBuilder(
    column: $table.annulledBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverSeq => $composableBuilder(
    column: $table.serverSeq,
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

class $$PaymentsTableOrderingComposer
    extends Composer<_$AppDatabase, $PaymentsTable> {
  $$PaymentsTableOrderingComposer({
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

  ColumnOrderings<String> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get annulledAt => $composableBuilder(
    column: $table.annulledAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get annulledBy => $composableBuilder(
    column: $table.annulledBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverSeq => $composableBuilder(
    column: $table.serverSeq,
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

class $$PaymentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PaymentsTable> {
  $$PaymentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get clientId =>
      $composableBuilder(column: $table.clientId, builder: (column) => column);

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, DateTime> get occurredAt =>
      $composableBuilder(
        column: $table.occurredAt,
        builder: (column) => column,
      );

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, DateTime> get annulledAt =>
      $composableBuilder(
        column: $table.annulledAt,
        builder: (column) => column,
      );

  GeneratedColumn<String> get annulledBy => $composableBuilder(
    column: $table.annulledBy,
    builder: (column) => column,
  );

  GeneratedColumn<int> get serverSeq =>
      $composableBuilder(column: $table.serverSeq, builder: (column) => column);

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

class $$PaymentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PaymentsTable,
          Payment,
          $$PaymentsTableFilterComposer,
          $$PaymentsTableOrderingComposer,
          $$PaymentsTableAnnotationComposer,
          $$PaymentsTableCreateCompanionBuilder,
          $$PaymentsTableUpdateCompanionBuilder,
          (Payment, $$PaymentsTableReferences),
          Payment,
          PrefetchHooks Function({bool businessId})
        > {
  $$PaymentsTableTableManager(_$AppDatabase db, $PaymentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PaymentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PaymentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PaymentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> businessId = const Value.absent(),
                Value<String> clientId = const Value.absent(),
                Value<int> amount = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<String> createdBy = const Value.absent(),
                Value<DateTime?> annulledAt = const Value.absent(),
                Value<String?> annulledBy = const Value.absent(),
                Value<int?> serverSeq = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PaymentsCompanion(
                id: id,
                businessId: businessId,
                clientId: clientId,
                amount: amount,
                occurredAt: occurredAt,
                createdBy: createdBy,
                annulledAt: annulledAt,
                annulledBy: annulledBy,
                serverSeq: serverSeq,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String businessId,
                required String clientId,
                required int amount,
                required DateTime occurredAt,
                required String createdBy,
                Value<DateTime?> annulledAt = const Value.absent(),
                Value<String?> annulledBy = const Value.absent(),
                Value<int?> serverSeq = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PaymentsCompanion.insert(
                id: id,
                businessId: businessId,
                clientId: clientId,
                amount: amount,
                occurredAt: occurredAt,
                createdBy: createdBy,
                annulledAt: annulledAt,
                annulledBy: annulledBy,
                serverSeq: serverSeq,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PaymentsTable, Payment>(table),
                  $$PaymentsTableReferences(db, table, e),
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
                        referencedTable: $$PaymentsTableReferences
                            ._businessIdTable(db),
                        referencedColumn: $$PaymentsTableReferences
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

typedef $$PaymentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PaymentsTable,
      Payment,
      $$PaymentsTableFilterComposer,
      $$PaymentsTableOrderingComposer,
      $$PaymentsTableAnnotationComposer,
      $$PaymentsTableCreateCompanionBuilder,
      $$PaymentsTableUpdateCompanionBuilder,
      (Payment, $$PaymentsTableReferences),
      Payment,
      PrefetchHooks Function({bool businessId})
    >;
typedef $$OutboxOpsTableCreateCompanionBuilder = OutboxOpsCompanion Function({
  Value<int> localSeq,
  required String opId,
  required String businessId,
  required String type,
  required String entityId,
  required String payload,
  Value<int?> baseVersion,
  Value<String> status,
  Value<String?> errorCode,
  required DateTime createdAt,
});
typedef $$OutboxOpsTableUpdateCompanionBuilder = OutboxOpsCompanion Function({
  Value<int> localSeq,
  Value<String> opId,
  Value<String> businessId,
  Value<String> type,
  Value<String> entityId,
  Value<String> payload,
  Value<int?> baseVersion,
  Value<String> status,
  Value<String?> errorCode,
  Value<DateTime> createdAt,
});

final class $$OutboxOpsTableReferences
    extends BaseReferences<_$AppDatabase, $OutboxOpsTable, OutboxOp> {
  $$OutboxOpsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BusinessesTable _businessIdTable(_$AppDatabase db) =>
      db.businesses.createAlias('outbox_ops__business_id__businesses__id');

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

class $$OutboxOpsTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxOpsTable> {
  $$OutboxOpsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get localSeq => $composableBuilder(
    column: $table.localSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get opId => $composableBuilder(
    column: $table.opId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
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

class $$OutboxOpsTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxOpsTable> {
  $$OutboxOpsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get localSeq => $composableBuilder(
    column: $table.localSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get opId => $composableBuilder(
    column: $table.opId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
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

class $$OutboxOpsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxOpsTable> {
  $$OutboxOpsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get localSeq =>
      $composableBuilder(column: $table.localSeq, builder: (column) => column);

  GeneratedColumn<String> get opId =>
      $composableBuilder(column: $table.opId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get errorCode =>
      $composableBuilder(column: $table.errorCode, builder: (column) => column);

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

class $$OutboxOpsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxOpsTable,
          OutboxOp,
          $$OutboxOpsTableFilterComposer,
          $$OutboxOpsTableOrderingComposer,
          $$OutboxOpsTableAnnotationComposer,
          $$OutboxOpsTableCreateCompanionBuilder,
          $$OutboxOpsTableUpdateCompanionBuilder,
          (OutboxOp, $$OutboxOpsTableReferences),
          OutboxOp,
          PrefetchHooks Function({bool businessId})
        > {
  $$OutboxOpsTableTableManager(_$AppDatabase db, $OutboxOpsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxOpsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxOpsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxOpsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> localSeq = const Value.absent(),
                Value<String> opId = const Value.absent(),
                Value<String> businessId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int?> baseVersion = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => OutboxOpsCompanion(
                localSeq: localSeq,
                opId: opId,
                businessId: businessId,
                type: type,
                entityId: entityId,
                payload: payload,
                baseVersion: baseVersion,
                status: status,
                errorCode: errorCode,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> localSeq = const Value.absent(),
                required String opId,
                required String businessId,
                required String type,
                required String entityId,
                required String payload,
                Value<int?> baseVersion = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                required DateTime createdAt,
              }) => OutboxOpsCompanion.insert(
                localSeq: localSeq,
                opId: opId,
                businessId: businessId,
                type: type,
                entityId: entityId,
                payload: payload,
                baseVersion: baseVersion,
                status: status,
                errorCode: errorCode,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OutboxOpsTable, OutboxOp>(table),
                  $$OutboxOpsTableReferences(db, table, e),
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
                        referencedTable: $$OutboxOpsTableReferences
                            ._businessIdTable(db),
                        referencedColumn: $$OutboxOpsTableReferences
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

typedef $$OutboxOpsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxOpsTable,
      OutboxOp,
      $$OutboxOpsTableFilterComposer,
      $$OutboxOpsTableOrderingComposer,
      $$OutboxOpsTableAnnotationComposer,
      $$OutboxOpsTableCreateCompanionBuilder,
      $$OutboxOpsTableUpdateCompanionBuilder,
      (OutboxOp, $$OutboxOpsTableReferences),
      OutboxOp,
      PrefetchHooks Function({bool businessId})
    >;
typedef $$SyncStatesTableCreateCompanionBuilder = SyncStatesCompanion Function({
  required String businessId,
  Value<int> cursor,
  Value<int> rowid,
});
typedef $$SyncStatesTableUpdateCompanionBuilder = SyncStatesCompanion Function({
  Value<String> businessId,
  Value<int> cursor,
  Value<int> rowid,
});

final class $$SyncStatesTableReferences
    extends BaseReferences<_$AppDatabase, $SyncStatesTable, SyncState> {
  $$SyncStatesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BusinessesTable _businessIdTable(_$AppDatabase db) =>
      db.businesses.createAlias('sync_states__business_id__businesses__id');

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

class $$SyncStatesTableFilterComposer
    extends Composer<_$AppDatabase, $SyncStatesTable> {
  $$SyncStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get cursor => $composableBuilder(
    column: $table.cursor,
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

class $$SyncStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncStatesTable> {
  $$SyncStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get cursor => $composableBuilder(
    column: $table.cursor,
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

class $$SyncStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncStatesTable> {
  $$SyncStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get cursor =>
      $composableBuilder(column: $table.cursor, builder: (column) => column);

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

class $$SyncStatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncStatesTable,
          SyncState,
          $$SyncStatesTableFilterComposer,
          $$SyncStatesTableOrderingComposer,
          $$SyncStatesTableAnnotationComposer,
          $$SyncStatesTableCreateCompanionBuilder,
          $$SyncStatesTableUpdateCompanionBuilder,
          (SyncState, $$SyncStatesTableReferences),
          SyncState,
          PrefetchHooks Function({bool businessId})
        > {
  $$SyncStatesTableTableManager(_$AppDatabase db, $SyncStatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> businessId = const Value.absent(),
                Value<int> cursor = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStatesCompanion(
                businessId: businessId,
                cursor: cursor,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String businessId,
                Value<int> cursor = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStatesCompanion.insert(
                businessId: businessId,
                cursor: cursor,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncStatesTable, SyncState>(table),
                  $$SyncStatesTableReferences(db, table, e),
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
                        referencedTable: $$SyncStatesTableReferences
                            ._businessIdTable(db),
                        referencedColumn: $$SyncStatesTableReferences
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

typedef $$SyncStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncStatesTable,
      SyncState,
      $$SyncStatesTableFilterComposer,
      $$SyncStatesTableOrderingComposer,
      $$SyncStatesTableAnnotationComposer,
      $$SyncStatesTableCreateCompanionBuilder,
      $$SyncStatesTableUpdateCompanionBuilder,
      (SyncState, $$SyncStatesTableReferences),
      SyncState,
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
  $$FiadosTableTableManager get fiados =>
      $$FiadosTableTableManager(_db, _db.fiados);
  $$FiadoItemsTableTableManager get fiadoItems =>
      $$FiadoItemsTableTableManager(_db, _db.fiadoItems);
  $$PaymentsTableTableManager get payments =>
      $$PaymentsTableTableManager(_db, _db.payments);
  $$OutboxOpsTableTableManager get outboxOps =>
      $$OutboxOpsTableTableManager(_db, _db.outboxOps);
  $$SyncStatesTableTableManager get syncStates =>
      $$SyncStatesTableTableManager(_db, _db.syncStates);
}
