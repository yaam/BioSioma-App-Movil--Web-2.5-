import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sioma_biometrics/infrastructure/datasources/objectbox_datasource.dart';
import 'package:sioma_biometrics/infrastructure/repositories/objectbox_repository.dart';

final localDbRepositoryProvider = Provider((ref) {
  return ObjectBoxRepository(objectBoxImpl: ObjectBoxDatasource());
});
