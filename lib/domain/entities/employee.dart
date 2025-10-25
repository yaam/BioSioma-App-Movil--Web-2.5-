import 'package:objectbox/objectbox.dart';
import 'package:sioma_biometrics/domain/entities/attendance.dart';

@Entity()
class Employee {
  int id;

  String name;
  String? photoPath;

  @Property(type: PropertyType.floatVector)
  List<double>? faceEmbedding;

  @Backlink('employee')
  final attendances = ToMany<Attendance>();

  @Property(
    type: PropertyType.byteVector,
  ) // Para guardar lista de timestamps como bytes
  List<int>? attendanceData;

  Employee({
    this.id = 0,
    required this.name,
    this.photoPath,
    this.faceEmbedding,
    this.attendanceData,
  });
}
