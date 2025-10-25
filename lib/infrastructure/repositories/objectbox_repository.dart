import 'package:sioma_biometrics/domain/entities/attendance.dart';
import 'package:sioma_biometrics/domain/entities/employee.dart';
import 'package:sioma_biometrics/domain/repositories/local_db_repository.dart';
import 'package:sioma_biometrics/infrastructure/datasources/objectbox_datasource.dart';

class ObjectBoxRepository implements LocalDbRepository {
  final ObjectBoxDatasource objectBoxImpl;

  ObjectBoxRepository({required this.objectBoxImpl});

  @override
  Future<void> createEmployee(Employee employee) async {
    await objectBoxImpl.createEmployee(employee);
  }

  @override
  Future<Employee?> getEmployeeById(int id) async {
    return objectBoxImpl.getEmployeeById(id);
  }

  @override
  Future<List<Employee>> getAllEmployees() async {
    return objectBoxImpl.getAllEmployees();
  }

  @override
  Future<List<Attendance>> getAttendancesForEmployeeBetween(
    int employeeId,
    DateTime start,
    DateTime end,
  ) async {
    return objectBoxImpl.getAttendancesForEmployeeBetween(
      employeeId,
      start,
      end,
    );
  }

  @override
  Future<void> createAttendance(Attendance attendance) async {
    await objectBoxImpl.createAttendance(attendance);
  }

  @override
  Future<void> deleteAllEmployees() async {
    await objectBoxImpl.deleteAllEmployees();
  }

  @override
  Future<void> deleteDatabase() async {
    await objectBoxImpl.deleteDatabase();
  }
}
