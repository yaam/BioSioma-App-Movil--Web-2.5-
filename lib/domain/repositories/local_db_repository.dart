import 'package:sioma_biometrics/domain/entities/attendance.dart';
import 'package:sioma_biometrics/domain/entities/employee.dart';

abstract class LocalDbRepository {
  Future<void> createEmployee(Employee employee);
  Future<Employee?> getEmployeeById(int id);
  Future<List<Employee>> getAllEmployees();
  Future<List<Attendance>> getAttendancesForEmployeeBetween(
    int employeeId,
    DateTime start,
    DateTime end,
  );
  Future<void> createAttendance(Attendance attendance);

  Future<void> deleteAllEmployees();

  Future<void> deleteDatabase();
}
