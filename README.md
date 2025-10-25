# Sioma Biometrics

Aplicación Flutter para reconocimiento biométrico facial.

## 📋 Requisitos Previos

- Flutter SDK (versión 3.9.2 o superior)
- Dart SDK (incluido con Flutter)
- Android Studio / Xcode (según tu sistema operativo)
- Dispositivo físico Android/iOS o emulador

## 🛠 Instalación

### 1. Instalar Flutter

1. Descarga Flutter SDK desde [aquí](https://docs.flutter.dev/get-started/install)
2. Extrae el archivo descargado en una ubicación de tu preferencia
3. Agrega Flutter a tu PATH de sistema

### 2. Configurar el Entorno de Desarrollo

#### Android Studio / VS Code

Instala las siguientes extensiones:
- Flutter
- Dart
- Flutter Widget Snippets

### 3. Clonar el Repositorio

```bash
git clone [URL_DEL_REPOSITORIO]
cd sioma_biometrics
```

### 4. Instalar Dependencias

Ejecuta el siguiente comando en la raíz del proyecto:

```bash
flutter pub get
```

### 5. Configurar Base de Datos Local (ObjectBox)

El proyecto utiliza ObjectBox como base de datos local. Para generar los archivos necesarios, ejecuta:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## 📱 Ejecutar la Aplicación

### En Dispositivo Físico (Recomendado)

1. **Habilitar Modo Desarrollador**
   - **Android**: Ve a Ajustes > Acerca del teléfono > Toca "Número de compilación" 7 veces
   - **iOS**: Necesitarás una cuenta de desarrollador de Apple

2. **Habilitar Depuración USB**
   - **Android**: Ajustes > Opciones de desarrollador > Depuración USB (activar)
   - **iOS**: Conecta tu dispositivo y confía en el certificado de desarrollador

3. **Conectar el Dispositivo**
   - Conecta tu dispositivo vía USB
   - Asegúrate de que está reconocido por Flutter:
     ```bash
     flutter devices
     ```

4. **Ejecutar la Aplicación**
   ```bash
   flutter run
   ```

### En Emulador

1. **Configurar Emulador**
   - Abre Android Studio > AVD Manager
   - Crea un nuevo dispositivo virtual si es necesario
   - Asegúrate de que el emulador tenga cámara configurada

2. **Iniciar el Emulador**
   - Inicia el emulador desde Android Studio o ejecuta:
     ```bash
     emulator -avd [NOMBRE_DEL_EMULADOR]
     ```

3. **Ejecutar la Aplicación**
   ```bash
   flutter run
   ```

## 🔧 Dependencias Principales

- `camera`: Para el acceso a la cámara del dispositivo
- `google_mlkit_face_detection`: Para detección facial
- `objectbox`: Base de datos local
- `permission_handler`: Manejo de permisos
- `flutter_riverpod`: Gestión de estado

## 📝 Notas Importantes

1. **Permisos**: La aplicación requiere permisos de cámara
2. **Versión de Flutter**: Asegúrate de usar la versión 3.9.2 o superior
3. **Problemas Comunes**:
   - Si encuentras errores de ObjectBox, intenta:
     ```bash
     flutter clean
     flutter pub get
     flutter pub run build_runner build --delete-conflicting-outputs
     ```

## 🤝 Contribuir

1. Haz un fork del proyecto
2. Crea una rama para tu feature (`git checkout -b feature/nueva-funcionalidad`)
3. Haz commit de tus cambios (`git commit -m 'Añadir nueva funcionalidad'`)
4. Haz push a la rama (`git push origin feature/nueva-funcionalidad`)
5. Abre un Pull Request

## 📄 Licencia

Este proyecto está bajo la Licencia MIT - ver el archivo [LICENSE](LICENSE) para más detalles.
