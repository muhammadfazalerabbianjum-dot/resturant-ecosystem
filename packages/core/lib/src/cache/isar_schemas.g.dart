// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'isar_schemas.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetIsarMenuItemCollection on Isar {
  IsarCollection<IsarMenuItem> get isarMenuItems => this.collection();
}

const IsarMenuItemSchema = CollectionSchema(
  name: r'IsarMenuItem',
  id: -4255425866820853603,
  properties: {
    r'cachedAt': PropertySchema(
      id: 0,
      name: r'cachedAt',
      type: IsarType.dateTime,
    ),
    r'category': PropertySchema(
      id: 1,
      name: r'category',
      type: IsarType.string,
    ),
    r'firestoreId': PropertySchema(
      id: 2,
      name: r'firestoreId',
      type: IsarType.string,
    ),
    r'imageUrl': PropertySchema(
      id: 3,
      name: r'imageUrl',
      type: IsarType.string,
    ),
    r'isAvailable': PropertySchema(
      id: 4,
      name: r'isAvailable',
      type: IsarType.bool,
    ),
    r'lastUpdated': PropertySchema(
      id: 5,
      name: r'lastUpdated',
      type: IsarType.dateTime,
    ),
    r'name': PropertySchema(id: 6, name: r'name', type: IsarType.string),
    r'price': PropertySchema(id: 7, name: r'price', type: IsarType.long),
  },

  estimateSize: _isarMenuItemEstimateSize,
  serialize: _isarMenuItemSerialize,
  deserialize: _isarMenuItemDeserialize,
  deserializeProp: _isarMenuItemDeserializeProp,
  idName: r'id',
  indexes: {
    r'firestoreId': IndexSchema(
      id: 1863077355534729001,
      name: r'firestoreId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'firestoreId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'cachedAt': IndexSchema(
      id: -699654806693614168,
      name: r'cachedAt',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'cachedAt',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _isarMenuItemGetId,
  getLinks: _isarMenuItemGetLinks,
  attach: _isarMenuItemAttach,
  version: '3.3.2',
);

int _isarMenuItemEstimateSize(
  IsarMenuItem object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.category.length * 3;
  bytesCount += 3 + object.firestoreId.length * 3;
  {
    final value = object.imageUrl;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.name.length * 3;
  return bytesCount;
}

void _isarMenuItemSerialize(
  IsarMenuItem object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.cachedAt);
  writer.writeString(offsets[1], object.category);
  writer.writeString(offsets[2], object.firestoreId);
  writer.writeString(offsets[3], object.imageUrl);
  writer.writeBool(offsets[4], object.isAvailable);
  writer.writeDateTime(offsets[5], object.lastUpdated);
  writer.writeString(offsets[6], object.name);
  writer.writeLong(offsets[7], object.price);
}

IsarMenuItem _isarMenuItemDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = IsarMenuItem();
  object.cachedAt = reader.readDateTime(offsets[0]);
  object.category = reader.readString(offsets[1]);
  object.firestoreId = reader.readString(offsets[2]);
  object.id = id;
  object.imageUrl = reader.readStringOrNull(offsets[3]);
  object.isAvailable = reader.readBool(offsets[4]);
  object.lastUpdated = reader.readDateTime(offsets[5]);
  object.name = reader.readString(offsets[6]);
  object.price = reader.readLong(offsets[7]);
  return object;
}

P _isarMenuItemDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTime(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readBool(offset)) as P;
    case 5:
      return (reader.readDateTime(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _isarMenuItemGetId(IsarMenuItem object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _isarMenuItemGetLinks(IsarMenuItem object) {
  return [];
}

void _isarMenuItemAttach(
  IsarCollection<dynamic> col,
  Id id,
  IsarMenuItem object,
) {
  object.id = id;
}

extension IsarMenuItemByIndex on IsarCollection<IsarMenuItem> {
  Future<IsarMenuItem?> getByFirestoreId(String firestoreId) {
    return getByIndex(r'firestoreId', [firestoreId]);
  }

  IsarMenuItem? getByFirestoreIdSync(String firestoreId) {
    return getByIndexSync(r'firestoreId', [firestoreId]);
  }

  Future<bool> deleteByFirestoreId(String firestoreId) {
    return deleteByIndex(r'firestoreId', [firestoreId]);
  }

  bool deleteByFirestoreIdSync(String firestoreId) {
    return deleteByIndexSync(r'firestoreId', [firestoreId]);
  }

  Future<List<IsarMenuItem?>> getAllByFirestoreId(
    List<String> firestoreIdValues,
  ) {
    final values = firestoreIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'firestoreId', values);
  }

  List<IsarMenuItem?> getAllByFirestoreIdSync(List<String> firestoreIdValues) {
    final values = firestoreIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'firestoreId', values);
  }

  Future<int> deleteAllByFirestoreId(List<String> firestoreIdValues) {
    final values = firestoreIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'firestoreId', values);
  }

  int deleteAllByFirestoreIdSync(List<String> firestoreIdValues) {
    final values = firestoreIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'firestoreId', values);
  }

  Future<Id> putByFirestoreId(IsarMenuItem object) {
    return putByIndex(r'firestoreId', object);
  }

  Id putByFirestoreIdSync(IsarMenuItem object, {bool saveLinks = true}) {
    return putByIndexSync(r'firestoreId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByFirestoreId(List<IsarMenuItem> objects) {
    return putAllByIndex(r'firestoreId', objects);
  }

  List<Id> putAllByFirestoreIdSync(
    List<IsarMenuItem> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'firestoreId', objects, saveLinks: saveLinks);
  }
}

extension IsarMenuItemQueryWhereSort
    on QueryBuilder<IsarMenuItem, IsarMenuItem, QWhere> {
  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterWhere> anyCachedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'cachedAt'),
      );
    });
  }
}

extension IsarMenuItemQueryWhere
    on QueryBuilder<IsarMenuItem, IsarMenuItem, QWhereClause> {
  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterWhereClause> idNotEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterWhereClause>
  firestoreIdEqualTo(String firestoreId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'firestoreId',
          value: [firestoreId],
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterWhereClause>
  firestoreIdNotEqualTo(String firestoreId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'firestoreId',
                lower: [],
                upper: [firestoreId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'firestoreId',
                lower: [firestoreId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'firestoreId',
                lower: [firestoreId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'firestoreId',
                lower: [],
                upper: [firestoreId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterWhereClause> cachedAtEqualTo(
    DateTime cachedAt,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'cachedAt', value: [cachedAt]),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterWhereClause>
  cachedAtNotEqualTo(DateTime cachedAt) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cachedAt',
                lower: [],
                upper: [cachedAt],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cachedAt',
                lower: [cachedAt],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cachedAt',
                lower: [cachedAt],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cachedAt',
                lower: [],
                upper: [cachedAt],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterWhereClause>
  cachedAtGreaterThan(DateTime cachedAt, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'cachedAt',
          lower: [cachedAt],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterWhereClause> cachedAtLessThan(
    DateTime cachedAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'cachedAt',
          lower: [],
          upper: [cachedAt],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterWhereClause> cachedAtBetween(
    DateTime lowerCachedAt,
    DateTime upperCachedAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'cachedAt',
          lower: [lowerCachedAt],
          includeLower: includeLower,
          upper: [upperCachedAt],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension IsarMenuItemQueryFilter
    on QueryBuilder<IsarMenuItem, IsarMenuItem, QFilterCondition> {
  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition>
  cachedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'cachedAt', value: value),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition>
  cachedAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'cachedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition>
  cachedAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'cachedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition>
  cachedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'cachedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition>
  categoryEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'category',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition>
  categoryGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'category',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition>
  categoryLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'category',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition>
  categoryBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'category',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition>
  categoryStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'category',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition>
  categoryEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'category',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition>
  categoryContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'category',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition>
  categoryMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'category',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition>
  categoryIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'category', value: ''),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition>
  categoryIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'category', value: ''),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition>
  firestoreIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'firestoreId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition>
  firestoreIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'firestoreId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition>
  firestoreIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'firestoreId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition>
  firestoreIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'firestoreId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition>
  firestoreIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'firestoreId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition>
  firestoreIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'firestoreId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition>
  firestoreIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'firestoreId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition>
  firestoreIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'firestoreId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition>
  firestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'firestoreId', value: ''),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition>
  firestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'firestoreId', value: ''),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition> idEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition>
  imageUrlIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'imageUrl'),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition>
  imageUrlIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'imageUrl'),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition>
  imageUrlEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'imageUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition>
  imageUrlGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'imageUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition>
  imageUrlLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'imageUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition>
  imageUrlBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'imageUrl',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition>
  imageUrlStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'imageUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition>
  imageUrlEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'imageUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition>
  imageUrlContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'imageUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition>
  imageUrlMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'imageUrl',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition>
  imageUrlIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'imageUrl', value: ''),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition>
  imageUrlIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'imageUrl', value: ''),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition>
  isAvailableEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isAvailable', value: value),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition>
  lastUpdatedEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastUpdated', value: value),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition>
  lastUpdatedGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastUpdated',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition>
  lastUpdatedLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastUpdated',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition>
  lastUpdatedBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastUpdated',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition> nameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition>
  nameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition> nameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition> nameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'name',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition>
  nameStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition> nameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition> nameContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition> nameMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'name',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition>
  nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition>
  nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition> priceEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'price', value: value),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition>
  priceGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'price',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition> priceLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'price',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterFilterCondition> priceBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'price',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension IsarMenuItemQueryObject
    on QueryBuilder<IsarMenuItem, IsarMenuItem, QFilterCondition> {}

extension IsarMenuItemQueryLinks
    on QueryBuilder<IsarMenuItem, IsarMenuItem, QFilterCondition> {}

extension IsarMenuItemQuerySortBy
    on QueryBuilder<IsarMenuItem, IsarMenuItem, QSortBy> {
  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterSortBy> sortByCachedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.asc);
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterSortBy> sortByCachedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.desc);
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterSortBy> sortByCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.asc);
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterSortBy> sortByCategoryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.desc);
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterSortBy> sortByFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.asc);
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterSortBy>
  sortByFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.desc);
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterSortBy> sortByImageUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageUrl', Sort.asc);
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterSortBy> sortByImageUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageUrl', Sort.desc);
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterSortBy> sortByIsAvailable() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isAvailable', Sort.asc);
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterSortBy>
  sortByIsAvailableDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isAvailable', Sort.desc);
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterSortBy> sortByLastUpdated() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdated', Sort.asc);
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterSortBy>
  sortByLastUpdatedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdated', Sort.desc);
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterSortBy> sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterSortBy> sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterSortBy> sortByPrice() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'price', Sort.asc);
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterSortBy> sortByPriceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'price', Sort.desc);
    });
  }
}

extension IsarMenuItemQuerySortThenBy
    on QueryBuilder<IsarMenuItem, IsarMenuItem, QSortThenBy> {
  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterSortBy> thenByCachedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.asc);
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterSortBy> thenByCachedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.desc);
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterSortBy> thenByCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.asc);
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterSortBy> thenByCategoryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.desc);
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterSortBy> thenByFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.asc);
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterSortBy>
  thenByFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.desc);
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterSortBy> thenByImageUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageUrl', Sort.asc);
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterSortBy> thenByImageUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imageUrl', Sort.desc);
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterSortBy> thenByIsAvailable() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isAvailable', Sort.asc);
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterSortBy>
  thenByIsAvailableDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isAvailable', Sort.desc);
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterSortBy> thenByLastUpdated() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdated', Sort.asc);
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterSortBy>
  thenByLastUpdatedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdated', Sort.desc);
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterSortBy> thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterSortBy> thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterSortBy> thenByPrice() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'price', Sort.asc);
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QAfterSortBy> thenByPriceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'price', Sort.desc);
    });
  }
}

extension IsarMenuItemQueryWhereDistinct
    on QueryBuilder<IsarMenuItem, IsarMenuItem, QDistinct> {
  QueryBuilder<IsarMenuItem, IsarMenuItem, QDistinct> distinctByCachedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cachedAt');
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QDistinct> distinctByCategory({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'category', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QDistinct> distinctByFirestoreId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'firestoreId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QDistinct> distinctByImageUrl({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'imageUrl', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QDistinct> distinctByIsAvailable() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isAvailable');
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QDistinct> distinctByLastUpdated() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastUpdated');
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QDistinct> distinctByName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IsarMenuItem, IsarMenuItem, QDistinct> distinctByPrice() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'price');
    });
  }
}

extension IsarMenuItemQueryProperty
    on QueryBuilder<IsarMenuItem, IsarMenuItem, QQueryProperty> {
  QueryBuilder<IsarMenuItem, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<IsarMenuItem, DateTime, QQueryOperations> cachedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cachedAt');
    });
  }

  QueryBuilder<IsarMenuItem, String, QQueryOperations> categoryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'category');
    });
  }

  QueryBuilder<IsarMenuItem, String, QQueryOperations> firestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'firestoreId');
    });
  }

  QueryBuilder<IsarMenuItem, String?, QQueryOperations> imageUrlProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'imageUrl');
    });
  }

  QueryBuilder<IsarMenuItem, bool, QQueryOperations> isAvailableProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isAvailable');
    });
  }

  QueryBuilder<IsarMenuItem, DateTime, QQueryOperations> lastUpdatedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastUpdated');
    });
  }

  QueryBuilder<IsarMenuItem, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<IsarMenuItem, int, QQueryOperations> priceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'price');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetIsarCartCollection on Isar {
  IsarCollection<IsarCart> get isarCarts => this.collection();
}

const IsarCartSchema = CollectionSchema(
  name: r'IsarCart',
  id: 5607633097166060554,
  properties: {
    r'cachedAt': PropertySchema(
      id: 0,
      name: r'cachedAt',
      type: IsarType.dateTime,
    ),
    r'firestoreId': PropertySchema(
      id: 1,
      name: r'firestoreId',
      type: IsarType.string,
    ),
    r'lastUpdated': PropertySchema(
      id: 2,
      name: r'lastUpdated',
      type: IsarType.dateTime,
    ),
    r'quantity': PropertySchema(id: 3, name: r'quantity', type: IsarType.long),
    r'selectedOptionsJson': PropertySchema(
      id: 4,
      name: r'selectedOptionsJson',
      type: IsarType.string,
    ),
  },

  estimateSize: _isarCartEstimateSize,
  serialize: _isarCartSerialize,
  deserialize: _isarCartDeserialize,
  deserializeProp: _isarCartDeserializeProp,
  idName: r'id',
  indexes: {
    r'firestoreId': IndexSchema(
      id: 1863077355534729001,
      name: r'firestoreId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'firestoreId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'cachedAt': IndexSchema(
      id: -699654806693614168,
      name: r'cachedAt',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'cachedAt',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _isarCartGetId,
  getLinks: _isarCartGetLinks,
  attach: _isarCartAttach,
  version: '3.3.2',
);

int _isarCartEstimateSize(
  IsarCart object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.firestoreId.length * 3;
  bytesCount += 3 + object.selectedOptionsJson.length * 3;
  return bytesCount;
}

void _isarCartSerialize(
  IsarCart object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.cachedAt);
  writer.writeString(offsets[1], object.firestoreId);
  writer.writeDateTime(offsets[2], object.lastUpdated);
  writer.writeLong(offsets[3], object.quantity);
  writer.writeString(offsets[4], object.selectedOptionsJson);
}

IsarCart _isarCartDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = IsarCart();
  object.cachedAt = reader.readDateTime(offsets[0]);
  object.firestoreId = reader.readString(offsets[1]);
  object.id = id;
  object.lastUpdated = reader.readDateTime(offsets[2]);
  object.quantity = reader.readLong(offsets[3]);
  object.selectedOptionsJson = reader.readString(offsets[4]);
  return object;
}

P _isarCartDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTime(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readDateTime(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _isarCartGetId(IsarCart object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _isarCartGetLinks(IsarCart object) {
  return [];
}

void _isarCartAttach(IsarCollection<dynamic> col, Id id, IsarCart object) {
  object.id = id;
}

extension IsarCartByIndex on IsarCollection<IsarCart> {
  Future<IsarCart?> getByFirestoreId(String firestoreId) {
    return getByIndex(r'firestoreId', [firestoreId]);
  }

  IsarCart? getByFirestoreIdSync(String firestoreId) {
    return getByIndexSync(r'firestoreId', [firestoreId]);
  }

  Future<bool> deleteByFirestoreId(String firestoreId) {
    return deleteByIndex(r'firestoreId', [firestoreId]);
  }

  bool deleteByFirestoreIdSync(String firestoreId) {
    return deleteByIndexSync(r'firestoreId', [firestoreId]);
  }

  Future<List<IsarCart?>> getAllByFirestoreId(List<String> firestoreIdValues) {
    final values = firestoreIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'firestoreId', values);
  }

  List<IsarCart?> getAllByFirestoreIdSync(List<String> firestoreIdValues) {
    final values = firestoreIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'firestoreId', values);
  }

  Future<int> deleteAllByFirestoreId(List<String> firestoreIdValues) {
    final values = firestoreIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'firestoreId', values);
  }

  int deleteAllByFirestoreIdSync(List<String> firestoreIdValues) {
    final values = firestoreIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'firestoreId', values);
  }

  Future<Id> putByFirestoreId(IsarCart object) {
    return putByIndex(r'firestoreId', object);
  }

  Id putByFirestoreIdSync(IsarCart object, {bool saveLinks = true}) {
    return putByIndexSync(r'firestoreId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByFirestoreId(List<IsarCart> objects) {
    return putAllByIndex(r'firestoreId', objects);
  }

  List<Id> putAllByFirestoreIdSync(
    List<IsarCart> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'firestoreId', objects, saveLinks: saveLinks);
  }
}

extension IsarCartQueryWhereSort on QueryBuilder<IsarCart, IsarCart, QWhere> {
  QueryBuilder<IsarCart, IsarCart, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterWhere> anyCachedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'cachedAt'),
      );
    });
  }
}

extension IsarCartQueryWhere on QueryBuilder<IsarCart, IsarCart, QWhereClause> {
  QueryBuilder<IsarCart, IsarCart, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterWhereClause> idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterWhereClause> firestoreIdEqualTo(
    String firestoreId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'firestoreId',
          value: [firestoreId],
        ),
      );
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterWhereClause> firestoreIdNotEqualTo(
    String firestoreId,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'firestoreId',
                lower: [],
                upper: [firestoreId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'firestoreId',
                lower: [firestoreId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'firestoreId',
                lower: [firestoreId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'firestoreId',
                lower: [],
                upper: [firestoreId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterWhereClause> cachedAtEqualTo(
    DateTime cachedAt,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'cachedAt', value: [cachedAt]),
      );
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterWhereClause> cachedAtNotEqualTo(
    DateTime cachedAt,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cachedAt',
                lower: [],
                upper: [cachedAt],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cachedAt',
                lower: [cachedAt],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cachedAt',
                lower: [cachedAt],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'cachedAt',
                lower: [],
                upper: [cachedAt],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterWhereClause> cachedAtGreaterThan(
    DateTime cachedAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'cachedAt',
          lower: [cachedAt],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterWhereClause> cachedAtLessThan(
    DateTime cachedAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'cachedAt',
          lower: [],
          upper: [cachedAt],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterWhereClause> cachedAtBetween(
    DateTime lowerCachedAt,
    DateTime upperCachedAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'cachedAt',
          lower: [lowerCachedAt],
          includeLower: includeLower,
          upper: [upperCachedAt],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension IsarCartQueryFilter
    on QueryBuilder<IsarCart, IsarCart, QFilterCondition> {
  QueryBuilder<IsarCart, IsarCart, QAfterFilterCondition> cachedAtEqualTo(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'cachedAt', value: value),
      );
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterFilterCondition> cachedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'cachedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterFilterCondition> cachedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'cachedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterFilterCondition> cachedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'cachedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterFilterCondition> firestoreIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'firestoreId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterFilterCondition>
  firestoreIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'firestoreId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterFilterCondition> firestoreIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'firestoreId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterFilterCondition> firestoreIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'firestoreId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterFilterCondition> firestoreIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'firestoreId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterFilterCondition> firestoreIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'firestoreId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterFilterCondition> firestoreIdContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'firestoreId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterFilterCondition> firestoreIdMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'firestoreId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterFilterCondition> firestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'firestoreId', value: ''),
      );
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterFilterCondition>
  firestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'firestoreId', value: ''),
      );
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterFilterCondition> lastUpdatedEqualTo(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastUpdated', value: value),
      );
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterFilterCondition>
  lastUpdatedGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastUpdated',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterFilterCondition> lastUpdatedLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastUpdated',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterFilterCondition> lastUpdatedBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastUpdated',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterFilterCondition> quantityEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'quantity', value: value),
      );
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterFilterCondition> quantityGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'quantity',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterFilterCondition> quantityLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'quantity',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterFilterCondition> quantityBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'quantity',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterFilterCondition>
  selectedOptionsJsonEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'selectedOptionsJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterFilterCondition>
  selectedOptionsJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'selectedOptionsJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterFilterCondition>
  selectedOptionsJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'selectedOptionsJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterFilterCondition>
  selectedOptionsJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'selectedOptionsJson',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterFilterCondition>
  selectedOptionsJsonStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'selectedOptionsJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterFilterCondition>
  selectedOptionsJsonEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'selectedOptionsJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterFilterCondition>
  selectedOptionsJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'selectedOptionsJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterFilterCondition>
  selectedOptionsJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'selectedOptionsJson',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterFilterCondition>
  selectedOptionsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'selectedOptionsJson', value: ''),
      );
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterFilterCondition>
  selectedOptionsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          property: r'selectedOptionsJson',
          value: '',
        ),
      );
    });
  }
}

extension IsarCartQueryObject
    on QueryBuilder<IsarCart, IsarCart, QFilterCondition> {}

extension IsarCartQueryLinks
    on QueryBuilder<IsarCart, IsarCart, QFilterCondition> {}

extension IsarCartQuerySortBy on QueryBuilder<IsarCart, IsarCart, QSortBy> {
  QueryBuilder<IsarCart, IsarCart, QAfterSortBy> sortByCachedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.asc);
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterSortBy> sortByCachedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.desc);
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterSortBy> sortByFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.asc);
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterSortBy> sortByFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.desc);
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterSortBy> sortByLastUpdated() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdated', Sort.asc);
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterSortBy> sortByLastUpdatedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdated', Sort.desc);
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterSortBy> sortByQuantity() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quantity', Sort.asc);
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterSortBy> sortByQuantityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quantity', Sort.desc);
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterSortBy> sortBySelectedOptionsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'selectedOptionsJson', Sort.asc);
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterSortBy>
  sortBySelectedOptionsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'selectedOptionsJson', Sort.desc);
    });
  }
}

extension IsarCartQuerySortThenBy
    on QueryBuilder<IsarCart, IsarCart, QSortThenBy> {
  QueryBuilder<IsarCart, IsarCart, QAfterSortBy> thenByCachedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.asc);
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterSortBy> thenByCachedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.desc);
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterSortBy> thenByFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.asc);
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterSortBy> thenByFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.desc);
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterSortBy> thenByLastUpdated() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdated', Sort.asc);
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterSortBy> thenByLastUpdatedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdated', Sort.desc);
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterSortBy> thenByQuantity() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quantity', Sort.asc);
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterSortBy> thenByQuantityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quantity', Sort.desc);
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterSortBy> thenBySelectedOptionsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'selectedOptionsJson', Sort.asc);
    });
  }

  QueryBuilder<IsarCart, IsarCart, QAfterSortBy>
  thenBySelectedOptionsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'selectedOptionsJson', Sort.desc);
    });
  }
}

extension IsarCartQueryWhereDistinct
    on QueryBuilder<IsarCart, IsarCart, QDistinct> {
  QueryBuilder<IsarCart, IsarCart, QDistinct> distinctByCachedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cachedAt');
    });
  }

  QueryBuilder<IsarCart, IsarCart, QDistinct> distinctByFirestoreId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'firestoreId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IsarCart, IsarCart, QDistinct> distinctByLastUpdated() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastUpdated');
    });
  }

  QueryBuilder<IsarCart, IsarCart, QDistinct> distinctByQuantity() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'quantity');
    });
  }

  QueryBuilder<IsarCart, IsarCart, QDistinct> distinctBySelectedOptionsJson({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'selectedOptionsJson',
        caseSensitive: caseSensitive,
      );
    });
  }
}

extension IsarCartQueryProperty
    on QueryBuilder<IsarCart, IsarCart, QQueryProperty> {
  QueryBuilder<IsarCart, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<IsarCart, DateTime, QQueryOperations> cachedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cachedAt');
    });
  }

  QueryBuilder<IsarCart, String, QQueryOperations> firestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'firestoreId');
    });
  }

  QueryBuilder<IsarCart, DateTime, QQueryOperations> lastUpdatedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastUpdated');
    });
  }

  QueryBuilder<IsarCart, int, QQueryOperations> quantityProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'quantity');
    });
  }

  QueryBuilder<IsarCart, String, QQueryOperations>
  selectedOptionsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'selectedOptionsJson');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetIsarPendingOperationCollection on Isar {
  IsarCollection<IsarPendingOperation> get isarPendingOperations =>
      this.collection();
}

const IsarPendingOperationSchema = CollectionSchema(
  name: r'IsarPendingOperation',
  id: 3670552476072754002,
  properties: {
    r'collectionName': PropertySchema(
      id: 0,
      name: r'collectionName',
      type: IsarType.string,
    ),
    r'dataString': PropertySchema(
      id: 1,
      name: r'dataString',
      type: IsarType.string,
    ),
    r'operation': PropertySchema(
      id: 2,
      name: r'operation',
      type: IsarType.string,
    ),
    r'retryCount': PropertySchema(
      id: 3,
      name: r'retryCount',
      type: IsarType.long,
    ),
    r'timestamp': PropertySchema(
      id: 4,
      name: r'timestamp',
      type: IsarType.dateTime,
    ),
  },

  estimateSize: _isarPendingOperationEstimateSize,
  serialize: _isarPendingOperationSerialize,
  deserialize: _isarPendingOperationDeserialize,
  deserializeProp: _isarPendingOperationDeserializeProp,
  idName: r'id',
  indexes: {
    r'timestamp': IndexSchema(
      id: 1852253767416892198,
      name: r'timestamp',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'timestamp',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _isarPendingOperationGetId,
  getLinks: _isarPendingOperationGetLinks,
  attach: _isarPendingOperationAttach,
  version: '3.3.2',
);

int _isarPendingOperationEstimateSize(
  IsarPendingOperation object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.collectionName.length * 3;
  bytesCount += 3 + object.dataString.length * 3;
  bytesCount += 3 + object.operation.length * 3;
  return bytesCount;
}

void _isarPendingOperationSerialize(
  IsarPendingOperation object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.collectionName);
  writer.writeString(offsets[1], object.dataString);
  writer.writeString(offsets[2], object.operation);
  writer.writeLong(offsets[3], object.retryCount);
  writer.writeDateTime(offsets[4], object.timestamp);
}

IsarPendingOperation _isarPendingOperationDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = IsarPendingOperation();
  object.collectionName = reader.readString(offsets[0]);
  object.dataString = reader.readString(offsets[1]);
  object.id = id;
  object.operation = reader.readString(offsets[2]);
  object.retryCount = reader.readLong(offsets[3]);
  object.timestamp = reader.readDateTime(offsets[4]);
  return object;
}

P _isarPendingOperationDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    case 4:
      return (reader.readDateTime(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _isarPendingOperationGetId(IsarPendingOperation object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _isarPendingOperationGetLinks(
  IsarPendingOperation object,
) {
  return [];
}

void _isarPendingOperationAttach(
  IsarCollection<dynamic> col,
  Id id,
  IsarPendingOperation object,
) {
  object.id = id;
}

extension IsarPendingOperationQueryWhereSort
    on QueryBuilder<IsarPendingOperation, IsarPendingOperation, QWhere> {
  QueryBuilder<IsarPendingOperation, IsarPendingOperation, QAfterWhere>
  anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<IsarPendingOperation, IsarPendingOperation, QAfterWhere>
  anyTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'timestamp'),
      );
    });
  }
}

extension IsarPendingOperationQueryWhere
    on QueryBuilder<IsarPendingOperation, IsarPendingOperation, QWhereClause> {
  QueryBuilder<IsarPendingOperation, IsarPendingOperation, QAfterWhereClause>
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<IsarPendingOperation, IsarPendingOperation, QAfterWhereClause>
  idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<IsarPendingOperation, IsarPendingOperation, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<IsarPendingOperation, IsarPendingOperation, QAfterWhereClause>
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<IsarPendingOperation, IsarPendingOperation, QAfterWhereClause>
  idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<IsarPendingOperation, IsarPendingOperation, QAfterWhereClause>
  timestampEqualTo(DateTime timestamp) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'timestamp', value: [timestamp]),
      );
    });
  }

  QueryBuilder<IsarPendingOperation, IsarPendingOperation, QAfterWhereClause>
  timestampNotEqualTo(DateTime timestamp) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'timestamp',
                lower: [],
                upper: [timestamp],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'timestamp',
                lower: [timestamp],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'timestamp',
                lower: [timestamp],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'timestamp',
                lower: [],
                upper: [timestamp],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<IsarPendingOperation, IsarPendingOperation, QAfterWhereClause>
  timestampGreaterThan(DateTime timestamp, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'timestamp',
          lower: [timestamp],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<IsarPendingOperation, IsarPendingOperation, QAfterWhereClause>
  timestampLessThan(DateTime timestamp, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'timestamp',
          lower: [],
          upper: [timestamp],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<IsarPendingOperation, IsarPendingOperation, QAfterWhereClause>
  timestampBetween(
    DateTime lowerTimestamp,
    DateTime upperTimestamp, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'timestamp',
          lower: [lowerTimestamp],
          includeLower: includeLower,
          upper: [upperTimestamp],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension IsarPendingOperationQueryFilter
    on
        QueryBuilder<
          IsarPendingOperation,
          IsarPendingOperation,
          QFilterCondition
        > {
  QueryBuilder<
    IsarPendingOperation,
    IsarPendingOperation,
    QAfterFilterCondition
  >
  collectionNameEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'collectionName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    IsarPendingOperation,
    IsarPendingOperation,
    QAfterFilterCondition
  >
  collectionNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'collectionName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    IsarPendingOperation,
    IsarPendingOperation,
    QAfterFilterCondition
  >
  collectionNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'collectionName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    IsarPendingOperation,
    IsarPendingOperation,
    QAfterFilterCondition
  >
  collectionNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'collectionName',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    IsarPendingOperation,
    IsarPendingOperation,
    QAfterFilterCondition
  >
  collectionNameStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'collectionName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    IsarPendingOperation,
    IsarPendingOperation,
    QAfterFilterCondition
  >
  collectionNameEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'collectionName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    IsarPendingOperation,
    IsarPendingOperation,
    QAfterFilterCondition
  >
  collectionNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'collectionName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    IsarPendingOperation,
    IsarPendingOperation,
    QAfterFilterCondition
  >
  collectionNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'collectionName',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    IsarPendingOperation,
    IsarPendingOperation,
    QAfterFilterCondition
  >
  collectionNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'collectionName', value: ''),
      );
    });
  }

  QueryBuilder<
    IsarPendingOperation,
    IsarPendingOperation,
    QAfterFilterCondition
  >
  collectionNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'collectionName', value: ''),
      );
    });
  }

  QueryBuilder<
    IsarPendingOperation,
    IsarPendingOperation,
    QAfterFilterCondition
  >
  dataStringEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'dataString',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    IsarPendingOperation,
    IsarPendingOperation,
    QAfterFilterCondition
  >
  dataStringGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'dataString',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    IsarPendingOperation,
    IsarPendingOperation,
    QAfterFilterCondition
  >
  dataStringLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'dataString',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    IsarPendingOperation,
    IsarPendingOperation,
    QAfterFilterCondition
  >
  dataStringBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'dataString',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    IsarPendingOperation,
    IsarPendingOperation,
    QAfterFilterCondition
  >
  dataStringStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'dataString',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    IsarPendingOperation,
    IsarPendingOperation,
    QAfterFilterCondition
  >
  dataStringEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'dataString',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    IsarPendingOperation,
    IsarPendingOperation,
    QAfterFilterCondition
  >
  dataStringContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'dataString',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    IsarPendingOperation,
    IsarPendingOperation,
    QAfterFilterCondition
  >
  dataStringMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'dataString',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    IsarPendingOperation,
    IsarPendingOperation,
    QAfterFilterCondition
  >
  dataStringIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'dataString', value: ''),
      );
    });
  }

  QueryBuilder<
    IsarPendingOperation,
    IsarPendingOperation,
    QAfterFilterCondition
  >
  dataStringIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'dataString', value: ''),
      );
    });
  }

  QueryBuilder<
    IsarPendingOperation,
    IsarPendingOperation,
    QAfterFilterCondition
  >
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<
    IsarPendingOperation,
    IsarPendingOperation,
    QAfterFilterCondition
  >
  idGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    IsarPendingOperation,
    IsarPendingOperation,
    QAfterFilterCondition
  >
  idLessThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    IsarPendingOperation,
    IsarPendingOperation,
    QAfterFilterCondition
  >
  idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    IsarPendingOperation,
    IsarPendingOperation,
    QAfterFilterCondition
  >
  operationEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'operation',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    IsarPendingOperation,
    IsarPendingOperation,
    QAfterFilterCondition
  >
  operationGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'operation',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    IsarPendingOperation,
    IsarPendingOperation,
    QAfterFilterCondition
  >
  operationLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'operation',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    IsarPendingOperation,
    IsarPendingOperation,
    QAfterFilterCondition
  >
  operationBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'operation',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    IsarPendingOperation,
    IsarPendingOperation,
    QAfterFilterCondition
  >
  operationStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'operation',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    IsarPendingOperation,
    IsarPendingOperation,
    QAfterFilterCondition
  >
  operationEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'operation',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    IsarPendingOperation,
    IsarPendingOperation,
    QAfterFilterCondition
  >
  operationContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'operation',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    IsarPendingOperation,
    IsarPendingOperation,
    QAfterFilterCondition
  >
  operationMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'operation',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    IsarPendingOperation,
    IsarPendingOperation,
    QAfterFilterCondition
  >
  operationIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'operation', value: ''),
      );
    });
  }

  QueryBuilder<
    IsarPendingOperation,
    IsarPendingOperation,
    QAfterFilterCondition
  >
  operationIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'operation', value: ''),
      );
    });
  }

  QueryBuilder<
    IsarPendingOperation,
    IsarPendingOperation,
    QAfterFilterCondition
  >
  retryCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'retryCount', value: value),
      );
    });
  }

  QueryBuilder<
    IsarPendingOperation,
    IsarPendingOperation,
    QAfterFilterCondition
  >
  retryCountGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'retryCount',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    IsarPendingOperation,
    IsarPendingOperation,
    QAfterFilterCondition
  >
  retryCountLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'retryCount',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    IsarPendingOperation,
    IsarPendingOperation,
    QAfterFilterCondition
  >
  retryCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'retryCount',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    IsarPendingOperation,
    IsarPendingOperation,
    QAfterFilterCondition
  >
  timestampEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'timestamp', value: value),
      );
    });
  }

  QueryBuilder<
    IsarPendingOperation,
    IsarPendingOperation,
    QAfterFilterCondition
  >
  timestampGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'timestamp',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    IsarPendingOperation,
    IsarPendingOperation,
    QAfterFilterCondition
  >
  timestampLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'timestamp',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    IsarPendingOperation,
    IsarPendingOperation,
    QAfterFilterCondition
  >
  timestampBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'timestamp',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension IsarPendingOperationQueryObject
    on
        QueryBuilder<
          IsarPendingOperation,
          IsarPendingOperation,
          QFilterCondition
        > {}

extension IsarPendingOperationQueryLinks
    on
        QueryBuilder<
          IsarPendingOperation,
          IsarPendingOperation,
          QFilterCondition
        > {}

extension IsarPendingOperationQuerySortBy
    on QueryBuilder<IsarPendingOperation, IsarPendingOperation, QSortBy> {
  QueryBuilder<IsarPendingOperation, IsarPendingOperation, QAfterSortBy>
  sortByCollectionName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'collectionName', Sort.asc);
    });
  }

  QueryBuilder<IsarPendingOperation, IsarPendingOperation, QAfterSortBy>
  sortByCollectionNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'collectionName', Sort.desc);
    });
  }

  QueryBuilder<IsarPendingOperation, IsarPendingOperation, QAfterSortBy>
  sortByDataString() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dataString', Sort.asc);
    });
  }

  QueryBuilder<IsarPendingOperation, IsarPendingOperation, QAfterSortBy>
  sortByDataStringDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dataString', Sort.desc);
    });
  }

  QueryBuilder<IsarPendingOperation, IsarPendingOperation, QAfterSortBy>
  sortByOperation() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'operation', Sort.asc);
    });
  }

  QueryBuilder<IsarPendingOperation, IsarPendingOperation, QAfterSortBy>
  sortByOperationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'operation', Sort.desc);
    });
  }

  QueryBuilder<IsarPendingOperation, IsarPendingOperation, QAfterSortBy>
  sortByRetryCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retryCount', Sort.asc);
    });
  }

  QueryBuilder<IsarPendingOperation, IsarPendingOperation, QAfterSortBy>
  sortByRetryCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retryCount', Sort.desc);
    });
  }

  QueryBuilder<IsarPendingOperation, IsarPendingOperation, QAfterSortBy>
  sortByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.asc);
    });
  }

  QueryBuilder<IsarPendingOperation, IsarPendingOperation, QAfterSortBy>
  sortByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.desc);
    });
  }
}

extension IsarPendingOperationQuerySortThenBy
    on QueryBuilder<IsarPendingOperation, IsarPendingOperation, QSortThenBy> {
  QueryBuilder<IsarPendingOperation, IsarPendingOperation, QAfterSortBy>
  thenByCollectionName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'collectionName', Sort.asc);
    });
  }

  QueryBuilder<IsarPendingOperation, IsarPendingOperation, QAfterSortBy>
  thenByCollectionNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'collectionName', Sort.desc);
    });
  }

  QueryBuilder<IsarPendingOperation, IsarPendingOperation, QAfterSortBy>
  thenByDataString() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dataString', Sort.asc);
    });
  }

  QueryBuilder<IsarPendingOperation, IsarPendingOperation, QAfterSortBy>
  thenByDataStringDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dataString', Sort.desc);
    });
  }

  QueryBuilder<IsarPendingOperation, IsarPendingOperation, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<IsarPendingOperation, IsarPendingOperation, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<IsarPendingOperation, IsarPendingOperation, QAfterSortBy>
  thenByOperation() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'operation', Sort.asc);
    });
  }

  QueryBuilder<IsarPendingOperation, IsarPendingOperation, QAfterSortBy>
  thenByOperationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'operation', Sort.desc);
    });
  }

  QueryBuilder<IsarPendingOperation, IsarPendingOperation, QAfterSortBy>
  thenByRetryCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retryCount', Sort.asc);
    });
  }

  QueryBuilder<IsarPendingOperation, IsarPendingOperation, QAfterSortBy>
  thenByRetryCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retryCount', Sort.desc);
    });
  }

  QueryBuilder<IsarPendingOperation, IsarPendingOperation, QAfterSortBy>
  thenByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.asc);
    });
  }

  QueryBuilder<IsarPendingOperation, IsarPendingOperation, QAfterSortBy>
  thenByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.desc);
    });
  }
}

extension IsarPendingOperationQueryWhereDistinct
    on QueryBuilder<IsarPendingOperation, IsarPendingOperation, QDistinct> {
  QueryBuilder<IsarPendingOperation, IsarPendingOperation, QDistinct>
  distinctByCollectionName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'collectionName',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<IsarPendingOperation, IsarPendingOperation, QDistinct>
  distinctByDataString({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'dataString', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IsarPendingOperation, IsarPendingOperation, QDistinct>
  distinctByOperation({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'operation', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IsarPendingOperation, IsarPendingOperation, QDistinct>
  distinctByRetryCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'retryCount');
    });
  }

  QueryBuilder<IsarPendingOperation, IsarPendingOperation, QDistinct>
  distinctByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'timestamp');
    });
  }
}

extension IsarPendingOperationQueryProperty
    on
        QueryBuilder<
          IsarPendingOperation,
          IsarPendingOperation,
          QQueryProperty
        > {
  QueryBuilder<IsarPendingOperation, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<IsarPendingOperation, String, QQueryOperations>
  collectionNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'collectionName');
    });
  }

  QueryBuilder<IsarPendingOperation, String, QQueryOperations>
  dataStringProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'dataString');
    });
  }

  QueryBuilder<IsarPendingOperation, String, QQueryOperations>
  operationProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'operation');
    });
  }

  QueryBuilder<IsarPendingOperation, int, QQueryOperations>
  retryCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'retryCount');
    });
  }

  QueryBuilder<IsarPendingOperation, DateTime, QQueryOperations>
  timestampProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'timestamp');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetIsarDeadLetterCollection on Isar {
  IsarCollection<IsarDeadLetter> get isarDeadLetters => this.collection();
}

const IsarDeadLetterSchema = CollectionSchema(
  name: r'IsarDeadLetter',
  id: -3110417864399876866,
  properties: {
    r'collectionName': PropertySchema(
      id: 0,
      name: r'collectionName',
      type: IsarType.string,
    ),
    r'dataString': PropertySchema(
      id: 1,
      name: r'dataString',
      type: IsarType.string,
    ),
    r'lastError': PropertySchema(
      id: 2,
      name: r'lastError',
      type: IsarType.string,
    ),
    r'operation': PropertySchema(
      id: 3,
      name: r'operation',
      type: IsarType.string,
    ),
    r'retryCount': PropertySchema(
      id: 4,
      name: r'retryCount',
      type: IsarType.long,
    ),
    r'timestamp': PropertySchema(
      id: 5,
      name: r'timestamp',
      type: IsarType.dateTime,
    ),
  },

  estimateSize: _isarDeadLetterEstimateSize,
  serialize: _isarDeadLetterSerialize,
  deserialize: _isarDeadLetterDeserialize,
  deserializeProp: _isarDeadLetterDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},

  getId: _isarDeadLetterGetId,
  getLinks: _isarDeadLetterGetLinks,
  attach: _isarDeadLetterAttach,
  version: '3.3.2',
);

int _isarDeadLetterEstimateSize(
  IsarDeadLetter object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.collectionName.length * 3;
  bytesCount += 3 + object.dataString.length * 3;
  bytesCount += 3 + object.lastError.length * 3;
  bytesCount += 3 + object.operation.length * 3;
  return bytesCount;
}

void _isarDeadLetterSerialize(
  IsarDeadLetter object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.collectionName);
  writer.writeString(offsets[1], object.dataString);
  writer.writeString(offsets[2], object.lastError);
  writer.writeString(offsets[3], object.operation);
  writer.writeLong(offsets[4], object.retryCount);
  writer.writeDateTime(offsets[5], object.timestamp);
}

IsarDeadLetter _isarDeadLetterDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = IsarDeadLetter();
  object.collectionName = reader.readString(offsets[0]);
  object.dataString = reader.readString(offsets[1]);
  object.id = id;
  object.lastError = reader.readString(offsets[2]);
  object.operation = reader.readString(offsets[3]);
  object.retryCount = reader.readLong(offsets[4]);
  object.timestamp = reader.readDateTime(offsets[5]);
  return object;
}

P _isarDeadLetterDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readLong(offset)) as P;
    case 5:
      return (reader.readDateTime(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _isarDeadLetterGetId(IsarDeadLetter object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _isarDeadLetterGetLinks(IsarDeadLetter object) {
  return [];
}

void _isarDeadLetterAttach(
  IsarCollection<dynamic> col,
  Id id,
  IsarDeadLetter object,
) {
  object.id = id;
}

extension IsarDeadLetterQueryWhereSort
    on QueryBuilder<IsarDeadLetter, IsarDeadLetter, QWhere> {
  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension IsarDeadLetterQueryWhere
    on QueryBuilder<IsarDeadLetter, IsarDeadLetter, QWhereClause> {
  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterWhereClause> idEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterWhereClause> idNotEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension IsarDeadLetterQueryFilter
    on QueryBuilder<IsarDeadLetter, IsarDeadLetter, QFilterCondition> {
  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  collectionNameEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'collectionName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  collectionNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'collectionName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  collectionNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'collectionName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  collectionNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'collectionName',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  collectionNameStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'collectionName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  collectionNameEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'collectionName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  collectionNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'collectionName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  collectionNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'collectionName',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  collectionNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'collectionName', value: ''),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  collectionNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'collectionName', value: ''),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  dataStringEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'dataString',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  dataStringGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'dataString',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  dataStringLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'dataString',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  dataStringBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'dataString',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  dataStringStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'dataString',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  dataStringEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'dataString',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  dataStringContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'dataString',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  dataStringMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'dataString',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  dataStringIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'dataString', value: ''),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  dataStringIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'dataString', value: ''),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition> idEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  idGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  idLessThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  lastErrorEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'lastError',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  lastErrorGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastError',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  lastErrorLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastError',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  lastErrorBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastError',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  lastErrorStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'lastError',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  lastErrorEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'lastError',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  lastErrorContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'lastError',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  lastErrorMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'lastError',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  lastErrorIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastError', value: ''),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  lastErrorIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'lastError', value: ''),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  operationEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'operation',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  operationGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'operation',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  operationLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'operation',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  operationBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'operation',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  operationStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'operation',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  operationEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'operation',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  operationContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'operation',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  operationMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'operation',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  operationIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'operation', value: ''),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  operationIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'operation', value: ''),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  retryCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'retryCount', value: value),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  retryCountGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'retryCount',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  retryCountLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'retryCount',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  retryCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'retryCount',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  timestampEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'timestamp', value: value),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  timestampGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'timestamp',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  timestampLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'timestamp',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterFilterCondition>
  timestampBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'timestamp',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension IsarDeadLetterQueryObject
    on QueryBuilder<IsarDeadLetter, IsarDeadLetter, QFilterCondition> {}

extension IsarDeadLetterQueryLinks
    on QueryBuilder<IsarDeadLetter, IsarDeadLetter, QFilterCondition> {}

extension IsarDeadLetterQuerySortBy
    on QueryBuilder<IsarDeadLetter, IsarDeadLetter, QSortBy> {
  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterSortBy>
  sortByCollectionName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'collectionName', Sort.asc);
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterSortBy>
  sortByCollectionNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'collectionName', Sort.desc);
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterSortBy>
  sortByDataString() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dataString', Sort.asc);
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterSortBy>
  sortByDataStringDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dataString', Sort.desc);
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterSortBy> sortByLastError() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastError', Sort.asc);
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterSortBy>
  sortByLastErrorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastError', Sort.desc);
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterSortBy> sortByOperation() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'operation', Sort.asc);
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterSortBy>
  sortByOperationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'operation', Sort.desc);
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterSortBy>
  sortByRetryCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retryCount', Sort.asc);
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterSortBy>
  sortByRetryCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retryCount', Sort.desc);
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterSortBy> sortByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.asc);
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterSortBy>
  sortByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.desc);
    });
  }
}

extension IsarDeadLetterQuerySortThenBy
    on QueryBuilder<IsarDeadLetter, IsarDeadLetter, QSortThenBy> {
  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterSortBy>
  thenByCollectionName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'collectionName', Sort.asc);
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterSortBy>
  thenByCollectionNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'collectionName', Sort.desc);
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterSortBy>
  thenByDataString() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dataString', Sort.asc);
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterSortBy>
  thenByDataStringDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dataString', Sort.desc);
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterSortBy> thenByLastError() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastError', Sort.asc);
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterSortBy>
  thenByLastErrorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastError', Sort.desc);
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterSortBy> thenByOperation() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'operation', Sort.asc);
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterSortBy>
  thenByOperationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'operation', Sort.desc);
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterSortBy>
  thenByRetryCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retryCount', Sort.asc);
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterSortBy>
  thenByRetryCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retryCount', Sort.desc);
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterSortBy> thenByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.asc);
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QAfterSortBy>
  thenByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.desc);
    });
  }
}

extension IsarDeadLetterQueryWhereDistinct
    on QueryBuilder<IsarDeadLetter, IsarDeadLetter, QDistinct> {
  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QDistinct>
  distinctByCollectionName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'collectionName',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QDistinct> distinctByDataString({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'dataString', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QDistinct> distinctByLastError({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastError', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QDistinct> distinctByOperation({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'operation', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QDistinct>
  distinctByRetryCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'retryCount');
    });
  }

  QueryBuilder<IsarDeadLetter, IsarDeadLetter, QDistinct>
  distinctByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'timestamp');
    });
  }
}

extension IsarDeadLetterQueryProperty
    on QueryBuilder<IsarDeadLetter, IsarDeadLetter, QQueryProperty> {
  QueryBuilder<IsarDeadLetter, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<IsarDeadLetter, String, QQueryOperations>
  collectionNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'collectionName');
    });
  }

  QueryBuilder<IsarDeadLetter, String, QQueryOperations> dataStringProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'dataString');
    });
  }

  QueryBuilder<IsarDeadLetter, String, QQueryOperations> lastErrorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastError');
    });
  }

  QueryBuilder<IsarDeadLetter, String, QQueryOperations> operationProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'operation');
    });
  }

  QueryBuilder<IsarDeadLetter, int, QQueryOperations> retryCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'retryCount');
    });
  }

  QueryBuilder<IsarDeadLetter, DateTime, QQueryOperations> timestampProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'timestamp');
    });
  }
}
