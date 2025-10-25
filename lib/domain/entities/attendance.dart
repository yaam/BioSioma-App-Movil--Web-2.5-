import 'package:objectbox/objectbox.dart';
import 'package:sioma_biometrics/domain/entities/employee.dart';

@Entity()
class Attendance {
  int id;

  final employee = ToOne<Employee>();

  @Property(type: PropertyType.date)
  DateTime timestamp;
  bool isEntry; // true = entrada, false = salida

  Attendance({this.id = 0, required this.timestamp, required this.isEntry});
}
