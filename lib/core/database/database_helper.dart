import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Singleton que gestiona la conexión y el esquema de la base de datos SQLite.
///
/// Uso básico:
/// ```dart
/// final db = await DatabaseHelper.instance.database;
/// await db.insert('clients', client.toMap());
/// final rows = await db.query('clients');
/// ```
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _db;

  DatabaseHelper._internal();

  /// Devuelve la instancia activa de la DB, inicializándola si es necesario.
  Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'pdm_rutine.db');

    return openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: _onOpen,
    );
  }

  /// Migración incremental del esquema cuando se actualiza la versión de la BD.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // v1 → v2: añadir recurrencia_activa y es_guardia a appointments
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE appointments ADD COLUMN recurrencia_activa INTEGER NOT NULL DEFAULT 1',
      );
      await db.execute(
        'ALTER TABLE appointments ADD COLUMN es_guardia INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  /// Activa las claves foráneas cada vez que se abre la base de datos.
  /// SQLite las desactiva por defecto en cada nueva conexión.
  Future<void> _onOpen(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Crea todas las tablas al instalar la app por primera vez.
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('PRAGMA foreign_keys = ON');

    // ── Clientes ──────────────────────────────────────────────────────────────
    // Entidad raíz. Todos los appointments y fichas se vinculan a un cliente.
    await db.execute('''
      CREATE TABLE clients (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre       TEXT    NOT NULL,
        nif_cif      TEXT,
        direccion    TEXT    NOT NULL,
        ciudad_cp    TEXT    NOT NULL,
        coordenadas  TEXT
      )
    ''');

    // ── Citas / Avisos ─────────────────────────────────────────────────────────
    // Representa una visita de mantenimiento programada para un cliente.
    // fecha_hora: almacenada en UTC ISO 8601 como TEXT.
    // estado: "Pendiente" | "Completada" | "Cancelada"
    // recurrencia_activa: 1 = proyectar futuras ocurrencias, 0 = detener serie.
    // es_guardia: 1 = servicio fuera de horario / guardia.
    await db.execute('''
      CREATE TABLE appointments (
        id                  INTEGER PRIMARY KEY AUTOINCREMENT,
        cliente_id          INTEGER NOT NULL,
        fecha_hora          TEXT    NOT NULL,
        identificacion      TEXT    NOT NULL,
        periodicidad        TEXT    NOT NULL,
        estado              TEXT    NOT NULL DEFAULT 'Pendiente',
        recurrencia_activa  INTEGER NOT NULL DEFAULT 1,
        es_guardia          INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (cliente_id) REFERENCES clients (id) ON DELETE CASCADE
      )
    ''');

    // ── Fichas de Mantenimiento ───────────────────────────────────────────────
    // Resultado de ejecutar una cita. Una cita puede tener una o varias fichas
    // (por ejemplo, si se intervienen varias puertas en la misma visita).
    //
    // datos_inspeccion: JSON Text que almacena un Map<String,dynamic> con el
    //   checklist dinámico de la inspección (campos variables por tipo de puerta).
    // firma_operario: ruta local de la imagen de firma (no Base64).
    // estado_instalacion: "Correcto" | "Deficiente" | "Peligroso"
    await db.execute('''
      CREATE TABLE maintenance_records (
        id                   INTEGER PRIMARY KEY AUTOINCREMENT,
        cita_id              INTEGER NOT NULL,
        tipo_puerta          TEXT    NOT NULL,
        marca_motor          TEXT,
        modelo_motor         TEXT,
        datos_inspeccion     TEXT    NOT NULL DEFAULT '{}',
        observaciones        TEXT,
        acciones_correctivas TEXT,
        incidencias          TEXT,
        estado_instalacion   TEXT    NOT NULL,
        firma_operario       TEXT,
        FOREIGN KEY (cita_id) REFERENCES appointments (id) ON DELETE CASCADE
      )
    ''');

    // ── Plantillas ─────────────────────────────────────────────────────────────
    // Pre-rellenos de fichas que el usuario puede reutilizar.
    // datos_template: mismo formato JSON que datos_inspeccion en maintenance_records.
    await db.execute('''
      CREATE TABLE templates (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre          TEXT    NOT NULL,
        tipo_puerta     TEXT,
        marca_motor     TEXT,
        datos_template  TEXT    NOT NULL DEFAULT '{}',
        observaciones   TEXT,
        created_at      TEXT    NOT NULL
      )
    ''');

    // ── Índices para consultas frecuentes ─────────────────────────────────────
    // Acelera filtrar citas por cliente y por fecha (calendario mensual).
    await db.execute(
      'CREATE INDEX idx_appointments_cliente ON appointments (cliente_id)',
    );
    await db.execute(
      'CREATE INDEX idx_appointments_fecha ON appointments (fecha_hora)',
    );
    // Acelera obtener las fichas de una cita concreta.
    await db.execute(
      'CREATE INDEX idx_records_cita ON maintenance_records (cita_id)',
    );
  }

  // ── Helpers de mantenimiento de BD ──────────────────────────────────────────

  /// Cierra la conexión activa. Útil en tests para resetear el estado.
  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
