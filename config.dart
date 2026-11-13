// Configuración pública del cliente Flutter.
// Pega aquí la Project URL y la publishable/anon key de Supabase.
// NUNCA pongas la service_role key en una aplicación móvil.
const String supabaseUrl = 'https://jlpxiphqpwfpzsqiutfh.supabase.co';
const String supabaseAnonKey = 'TU_PUBLISHABLE_O_ANON_KEY';

bool get supabaseConfigured =>
    supabaseUrl.startsWith('https://') &&
    !supabaseUrl.contains('TU-PROYECTO') &&
    supabaseAnonKey.length > 30 &&
    !supabaseAnonKey.contains('TU_PUBLISHABLE');
