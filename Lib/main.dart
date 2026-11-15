import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';

const lime = Color(0xFFA8F36B);
const ink = Color(0xFF101D24);
const panel = Color(0xFF1B2B33);
const muted = Color(0xFF9AA8AE);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (supabaseConfigured) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }
  runApp(const VygoApp());
}

SupabaseClient get db => Supabase.instance.client;

class VygoApp extends StatelessWidget {
  const VygoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'VYGO',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: ink,
      colorScheme: ColorScheme.fromSeed(
        seedColor: lime, brightness: Brightness.dark, surface: ink,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: ink, foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: panel,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lime)),
        labelStyle: const TextStyle(color: muted),
      ),
    ),
    home: supabaseConfigured ? const AuthGate() : const SetupPage(),
  );
}

class SetupPage extends StatelessWidget {
  const SetupPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Spacer(),
        const BrandMark(),
        const SizedBox(height: 24),
        const Text('Conecta VYGO con Supabase',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        const Text('Abre lib/config.dart y reemplaza supabaseUrl y '
          'supabaseAnonKey con los datos de tu proyecto. Luego ejecuta '
          'flutter pub get y flutter run.',
          style: TextStyle(color: muted, height: 1.5)),
        const SizedBox(height: 16),
        const Text('La clave debe ser la publishable/anon. Nunca uses '
          'service_role en Flutter ni la publiques en GitHub.',
          style: TextStyle(color: lime)),
        const Spacer(),
      ]),
    )),
  );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
    stream: db.auth.onAuthStateChange,
    builder: (context, snapshot) {
      final user = db.auth.currentUser;
      if (user == null) return const AuthPage();
      return FutureBuilder<Map<String, dynamic>?>(
        future: db.from('profiles').select().eq('id', user.id).maybeSingle(),
        builder: (context, profileSnapshot) {
          if (profileSnapshot.connectionState == ConnectionState.waiting) {
            return const LoadingPage();
          }
          if (profileSnapshot.hasError) {
            return ErrorPage(message: 'No pudimos cargar tu perfil: '
              '${profileSnapshot.error}', onRetry: () {});
          }
          final profile = profileSnapshot.data;
          if (profile == null) {
            return ErrorPage(
              message: 'Tu usuario existe, pero no encontramos su perfil. '
                'Revisa el trigger de creación de perfiles en Supabase.',
              onRetry: () => db.auth.signOut(),
            );
          }
          return HomeRouter(profile: profile);
        },
      );
    },
  );
}

class HomeRouter extends StatelessWidget {
  final Map<String, dynamic> profile;
  const HomeRouter({super.key, required this.profile});
  @override
  Widget build(BuildContext context) {
    final role = profile['role'] as String? ?? 'passenger';
    if (role == 'admin') return AdminHome(profile: profile);
    if (role == 'driver') return DriverHome(profile: profile);
    return PassengerHome(profile: profile);
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  final phone = TextEditingController();
  bool signup = false;
  bool busy = false;
  String role = 'passenger';

  @override
  void dispose() {
    email.dispose(); password.dispose(); name.dispose(); phone.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      if (signup) {
        final result = await db.auth.signUp(
          email: email.text.trim(),
          password: password.text,
          data: {
            'full_name': name.text.trim(),
            'phone': phone.text.trim(),
            'role': role,
          },
        );
        if (!mounted) return;
        if (result.session == null) {
          showMessage(context, 'Cuenta creada. Revisa tu correo para confirmar '
            'el registro y después inicia sesión.');
        } else {
          showMessage(context, '¡Bienvenido a VYGO!');
        }
      } else {
        await db.auth.signInWithPassword(
          email: email.text.trim(), password: password.text,
        );
      }
    } on AuthException catch (e) {
      if (mounted) showMessage(context, e.message);
    } catch (e) {
      if (mounted) showMessage(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const BrandMark(),
          const SizedBox(height: 34),
          Text(signup ? 'Crea tu cuenta' : 'Bienvenido de nuevo',
            style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(signup ? 'Únete a VYGO y muévete a tu manera.'
            : 'Ingresa para continuar con VYGO.',
            style: const TextStyle(color: muted)),
          const SizedBox(height: 24),
          if (signup) ...[
            TextField(controller: name, textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nombre completo')),
            const SizedBox(height: 12),
            TextField(controller: phone, keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Celular')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: role,
              decoration: const InputDecoration(labelText: 'Quiero registrarme como'),
              items: const [
                DropdownMenuItem(value: 'passenger', child: Text('Pasajero')),
                DropdownMenuItem(value: 'driver', child: Text('Conductor')),
              ],
              onChanged: (v) => setState(() => role = v ?? 'passenger'),
            ),
            const SizedBox(height: 12),
          ],
          TextField(controller: email, keyboardType: TextInputType.emailAddress,
            autocorrect: false, decoration: const InputDecoration(labelText: 'Correo electrónico')),
          const SizedBox(height: 12),
          TextField(controller: password, obscureText: true,
            decoration: const InputDecoration(labelText: 'Contraseña')),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: busy ? null : submit,
            style: FilledButton.styleFrom(backgroundColor: lime,
              foregroundColor: ink, padding: const EdgeInsets.all(17)),
            child: busy ? const SizedBox(height: 20, width: 20,
              child: CircularProgressIndicator(strokeWidth: 2))
              : Text(signup ? 'Crear cuenta' : 'Iniciar sesión',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: busy ? null : () => setState(() => signup = !signup),
            child: Text(signup ? 'Ya tengo cuenta · Iniciar sesión'
              : '¿No tienes cuenta? · Crear cuenta',
              style: const TextStyle(color: lime)),
          ),
          const SizedBox(height: 12),
          const Text('Al registrarte como conductor, tu perfil queda pendiente '
            'de aprobación administrativa antes de recibir solicitudes.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 12)),
        ]),
      ),
    ))),
  );
}

class PassengerHome extends StatefulWidget {
  final Map<String, dynamic> profile;
  const PassengerHome({super.key, required this.profile});
  @override
  State<PassengerHome> createState() => _PassengerHomeState();
}

class _PassengerHomeState extends State<PassengerHome> {
  final pickup = TextEditingController();
  final destination = TextEditingController();
  final fare = TextEditingController();
  final note = TextEditingController();
  bool busy = false;
  List<Map<String, dynamic>> trips = [];

  @override
  void initState() { super.initState(); loadTrips(); }
  @override
  void dispose() {
    pickup.dispose(); destination.dispose(); fare.dispose(); note.dispose();
    super.dispose();
  }

  Future<void> loadTrips() async {
    try {
      final rows = await db.from('trips').select('*, trip_offers(*)')
        .eq('passenger_id', db.auth.currentUser!.id)
        .order('created_at', ascending: false).limit(20);
      if (mounted) setState(() => trips = List<Map<String, dynamic>>.from(rows));
    } catch (e) { if (mounted) showMessage(context, 'No se pudieron cargar viajes: $e'); }
  }

  Future<void> createTrip() async {
    final amount = num.tryParse(fare.text.replaceAll('.', '').replaceAll(',', '.'));
    if (pickup.text.trim().isEmpty || destination.text.trim().isEmpty || amount == null || amount <= 0) {
      showMessage(context, 'Completa origen, destino y una tarifa válida.');
      return;
    }
    setState(() => busy = true);
    try {
      await db.from('trips').insert({
        'passenger_id': db.auth.currentUser!.id,
        'pickup_address': pickup.text.trim(),
        'destination_address': destination.text.trim(),
        'requested_fare': amount,
        'passenger_note': note.text.trim().isEmpty ? null : note.text.trim(),
        'status': 'requested',
      });
      pickup.clear(); destination.clear(); fare.clear(); note.clear();
      await loadTrips();
      if (mounted) showMessage(context, '¡Solicitud enviada a VYGO!');
    } catch (e) {
      if (mounted) showMessage(context, 'No se pudo crear el viaje: $e');
    } finally { if (mounted) setState(() => busy = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: vygoAppBar('VYGO Pasajeros'),
    body: RefreshIndicator(
      onRefresh: loadTrips,
      child: ListView(padding: const EdgeInsets.all(20), children: [
        PageHeading('¿A dónde vamos?',
          'Propón tu tarifa. Los conductores podrán enviarte ofertas.'),
        const SizedBox(height: 20),
        TextField(controller: pickup, decoration: const InputDecoration(
          labelText: 'Punto de recogida', prefixIcon: Icon(Icons.my_location, color: lime))),
        const SizedBox(height: 12),
        TextField(controller: destination, decoration: const InputDecoration(
          labelText: 'Destino', prefixIcon: Icon(Icons.location_on_outlined, color: lime))),
        const SizedBox(height: 12),
        TextField(controller: fare, keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Tu tarifa propuesta (COP)',
            prefixIcon: Icon(Icons.payments_outlined, color: lime))),
        const SizedBox(height: 12),
        TextField(controller: note, maxLines: 2,
          decoration: const InputDecoration(labelText: 'Nota para el conductor (opcional)')),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: busy ? null : createTrip,
          icon: const Icon(Icons.search),
          label: Text(busy ? 'Enviando...' : 'Buscar conductores'),
          style: FilledButton.styleFrom(backgroundColor: lime, foregroundColor: ink,
            padding: const EdgeInsets.all(16)),
        ),
        const SizedBox(height: 28),
        const Text('MIS SOLICITUDES', style: TextStyle(
          color: lime, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 10),
        if (trips.isEmpty) const EmptyState(
          text: 'Todavía no tienes solicitudes. Crea tu primer viaje.'),
        ...trips.map((t) => TripCard(trip: t, showFare: true)),
      ]),
    ),
  );
}

class DriverHome extends StatefulWidget {
  final Map<String, dynamic> profile;
  const DriverHome({super.key, required this.profile});
  @override
  State<DriverHome> createState() => _DriverHomeState();
}

class _DriverHomeState extends State<DriverHome> {
  List<Map<String, dynamic>> trips = [];
  bool busy = true;
  bool approved = false;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      final driver = await db.from('driver_profiles').select('verification_status')
        .eq('user_id', db.auth.currentUser!.id).maybeSingle();
      approved = driver?['verification_status'] == 'approved';
      if (approved) {
        final rows = await db.from('trips').select()
          .inFilter('status', ['requested', 'negotiating'])
          .filter('driver_id', 'is', null)
          .order('created_at', ascending: false).limit(50);
        trips = List<Map<String, dynamic>>.from(rows);
      }
    } catch (e) {
      if (mounted) showMessage(context, 'No se pudieron cargar solicitudes: $e');
    } finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> offer(Map<String, dynamic> trip) async {
    final controller = TextEditingController(
      text: (trip['requested_fare'] ?? '').toString());
    final amount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: panel,
        title: const Text('Enviar oferta'),
        content: TextField(controller: controller, autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Tu tarifa en COP')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
          FilledButton(onPressed: () {
            final n = double.tryParse(controller.text.replaceAll('.', '').replaceAll(',', '.'));
            if (n != null && n > 0) Navigator.pop(context, n);
          }, child: const Text('Enviar')),
        ],
      ),
    );
    controller.dispose();
    if (amount == null) return;
    try {
      await db.from('trip_offers').insert({
        'trip_id': trip['id'],
        'driver_id': db.auth.currentUser!.id,
        'fare': amount,
      });
      // La oferta queda registrada; el pasajero podrá verla y decidir.
      if (mounted) showMessage(context, 'Oferta enviada correctamente.');
      await load();
    } catch (e) {
      if (mounted) showMessage(context, 'No se pudo enviar la oferta: $e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: vygoAppBar('VYGO Conductores'),
    body: RefreshIndicator(
      onRefresh: load,
      child: ListView(padding: const EdgeInsets.all(20), children: [
        const PageHeading('Solicitudes disponibles',
          'Consulta viajes y presenta tu propia tarifa.'),
        const SizedBox(height: 16),
        if (!busy && !approved) const InfoPanel(
          text: 'Tu cuenta de conductor está pendiente de aprobación. '
            'El administrador debe verificar tu perfil antes de que puedas '
            'consultar y ofertar en viajes.'),
        if (busy) const Center(child: Padding(
          padding: EdgeInsets.all(30), child: CircularProgressIndicator(color: lime))),
        if (!busy && approved && trips.isEmpty)
          const EmptyState(text: 'No hay solicitudes disponibles por ahora. Desliza hacia abajo para actualizar.'),
        if (approved) ...trips.map((t) => Column(children: [
          TripCard(trip: t, showFare: true),
          Align(alignment: Alignment.centerRight, child: FilledButton(
            onPressed: () => offer(t),
            style: FilledButton.styleFrom(backgroundColor: lime, foregroundColor: ink),
            child: const Text('Enviar mi oferta'),
          )),
          const SizedBox(height: 12),
        ])),
      ]),
    ),
  );
}

class AdminHome extends StatefulWidget {
  final Map<String, dynamic> profile;
  const AdminHome({super.key, required this.profile});
  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  bool busy = true;
  List<Map<String, dynamic>> drivers = [];
  List<Map<String, dynamic>> trips = [];
  int users = 0;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      final p = await db.from('profiles').select('id, role');
      users = p.length;
      final d = await db.from('driver_profiles').select(
        'user_id, verification_status, is_available');
      drivers = List<Map<String, dynamic>>.from(d);
      final t = await db.from('trips').select()
        .order('created_at', ascending: false).limit(30);
      trips = List<Map<String, dynamic>>.from(t);
    } catch (e) {
      if (mounted) showMessage(context, 'Error cargando administración: $e');
    } finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> approve(String id, bool value) async {
    try {
      await db.from('driver_profiles').update({
        'verification_status': value ? 'approved' : 'rejected',
      }).eq('user_id', id);
      await load();
      if (mounted) showMessage(context, value ? 'Conductor aprobado.' : 'Conductor rechazado.');
    } catch (e) { if (mounted) showMessage(context, 'No se pudo actualizar: $e'); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: vygoAppBar('VYGO Administración'),
    body: RefreshIndicator(
      onRefresh: load,
      child: ListView(padding: const EdgeInsets.all(20), children: [
        const PageHeading('Centro de control', 'Administración de la plataforma.'),
        const SizedBox(height: 18),
        if (busy) const LinearProgressIndicator(color: lime),
        if (!busy) Wrap(spacing: 10, runSpacing: 10, children: [
          MetricCard(label: 'Usuarios', value: '$users'),
          MetricCard(label: 'Conductores', value: '${drivers.length}'),
          MetricCard(label: 'Viajes', value: '${trips.length}'),
          MetricCard(label: 'En curso', value: '${trips.where((x) => x['status'] == 'in_progress').length}'),
        ]),
        const SizedBox(height: 26),
        const Text('VERIFICACIÓN DE CONDUCTORES',
          style: TextStyle(color: lime, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        if (!busy && drivers.isEmpty) const EmptyState(text: 'Aún no hay conductores registrados.'),
        ...drivers.where((d) => d['verification_status'] == 'pending').map((d) =>
          Card(color: panel, child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Conductor ${shortId(d['user_id'].toString())}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => approve(d['user_id'], false),
                  child: const Text('Rechazar'))),
                const SizedBox(width: 8),
                Expanded(child: FilledButton(
                  onPressed: () => approve(d['user_id'], true),
                  style: FilledButton.styleFrom(backgroundColor: lime, foregroundColor: ink),
                  child: const Text('Aprobar'))),
              ]),
            ]),
          )),
        ),
        const SizedBox(height: 24),
        const Text('ÚLTIMOS VIAJES',
          style: TextStyle(color: lime, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        if (!busy && trips.isEmpty) const EmptyState(text: 'Todavía no hay viajes.'),
        ...trips.map((t) => TripCard(trip: t, showFare: true)),
        const SizedBox(height: 20),
        const InfoPanel(text: 'El panel usa el rol admin validado en Supabase. '
          'La aprobación de conductores está conectada; otras operaciones '
          'administrativas avanzadas se añadirán en próximas versiones.'),
      ]),
    ),
  );
}

PreferredSizeWidget vygoAppBar(String title) => AppBar(
  title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
  actions: [
    IconButton(tooltip: 'Cerrar sesión', onPressed: () => db.auth.signOut(),
      icon: const Icon(Icons.logout, color: lime)),
  ],
);

class BrandMark extends StatelessWidget {
  const BrandMark({super.key});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 58, height: 58,
      decoration: BoxDecoration(color: lime, borderRadius: BorderRadius.circular(17)),
      child: const Icon(Icons.route_rounded, color: ink, size: 36)),
    const SizedBox(width: 14),
    const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('VYGO', style: TextStyle(color: Colors.white, fontSize: 34,
        fontWeight: FontWeight.w900, letterSpacing: 2)),
      Text('MUÉVETE A TU MANERA.',
        style: TextStyle(color: lime, fontWeight: FontWeight.bold,
          letterSpacing: 1.1, fontSize: 11)),
    ]),
  ]);
}

class PageHeading extends StatelessWidget {
  final String title, subtitle;
  const PageHeading(this.title, this.subtitle, {super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 25,
        fontWeight: FontWeight.w800, color: Colors.white)),
      const SizedBox(height: 6),
      Text(subtitle, style: const TextStyle(color: muted, height: 1.4)),
    ]);
}

class TripCard extends StatelessWidget {
  final Map<String, dynamic> trip;
  final bool showFare;
  const TripCard({super.key, required this.trip, required this.showFare});
  @override
  Widget build(BuildContext context) {
    final fare = trip['requested_fare'];
    final status = (trip['status'] ?? 'requested').toString();
    return Card(
      color: panel, margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.trip_origin, color: lime, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(trip['pickup_address'] ?? 'Origen',
              style: const TextStyle(fontWeight: FontWeight.bold))),
          ]),
          const Padding(padding: EdgeInsets.only(left: 8), child: SizedBox(
            height: 15, child: VerticalDivider(color: muted, thickness: 1))),
          Row(children: [
            const Icon(Icons.location_on, color: lime, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(trip['destination_address'] ?? 'Destino',
              style: const TextStyle(fontWeight: FontWeight.bold))),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 6, children: [
            if (showFare && fare != null) Chip(
              label: Text('Propuesta: ${cop(fare)}'),
              backgroundColor: lime.withOpacity(.12),
              labelStyle: const TextStyle(color: lime)),
            Chip(label: Text(statusLabel(status))),
          ]),
          if ((trip['passenger_note'] ?? '').toString().isNotEmpty)
            Text('Nota: ${trip['passenger_note']}',
              style: const TextStyle(color: muted, fontSize: 12)),
          if (trip['trip_offers'] is List && (trip['trip_offers'] as List).isNotEmpty) ...[
            const Divider(color: Colors.white12, height: 22),
            const Text('OFERTAS RECIBIDAS',
              style: TextStyle(color: lime, fontSize: 11,
                fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 6),
            ...(trip['trip_offers'] as List).map((offer) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(children: [
                Expanded(child: Text(cop(offer['fare']),
                  style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold))),
                Text(statusLabel(offer['status'] == 'pending'
                  ? 'negotiating' : offer['status']),
                  style: const TextStyle(color: muted, fontSize: 11)),
              ]),
            )),
          ],
        ],
      )),
    );
  }
}

class MetricCard extends StatelessWidget {
  final String label, value;
  const MetricCard({super.key, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => SizedBox(width: 145,
    child: Container(padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(15)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(color: lime, fontSize: 28,
          fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(color: muted)),
      ])));
}

class EmptyState extends StatelessWidget {
  final String text;
  const EmptyState({super.key, required this.text});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(14)),
    child: Text(text, style: const TextStyle(color: muted)));
}

class InfoPanel extends StatelessWidget {
  final String text;
  const InfoPanel({super.key, required this.text});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: lime.withOpacity(.09),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: lime.withOpacity(.35))),
    child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13)));
}

class LoadingPage extends StatelessWidget {
  const LoadingPage({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: CircularProgressIndicator(color: lime)));
}

class ErrorPage extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorPage({super.key, required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: Padding(padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, color: lime, size: 42),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton(onPressed: onRetry, child: const Text('Cerrar sesión')),
      ]))));
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
}

String cop(dynamic value) {
  final n = (value as num).round();
  final s = n.toString();
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    out.write(s[i]);
    final remaining = s.length - i - 1;
    if (remaining > 0 && remaining % 3 == 0) out.write('.');
  }
  return '\$${out.toString()} COP';
}

String statusLabel(String status) {
  const labels = {
    'requested': 'Solicitado', 'negotiating': 'Negociando',
    'accepted': 'Aceptado', 'driver_arriving': 'Conductor en camino',
    'in_progress': 'En curso', 'completed': 'Completado',
    'cancelled': 'Cancelado',
  };
  return labels[status] ?? status;
}

String shortId(String id) => id.length > 8 ? id.substring(0, 8) : id;
