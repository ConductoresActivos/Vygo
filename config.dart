// Configuración pública del cliente Flutter.
// Pega aquí la Project URL y la publishable/anon key de Supabase.
// NUNCA pongas la service_role key en una aplicación móvil.
const String supabaseUrl = 'https://jlpxiphqpwfpzsqiutfh.supabase.co';
const String supabaseAnonKey = 'sb_publishable_Zt21icIj1xkxZr1OuA-Iow_JrHnBi_l';

bool get supabaseConfigured =>
    supabaseUrl.startsWith('https://') &&
    !supabaseUrl.contains('TU-PROYECTO') &&
    supabaseAnonKey.length > 30 &&
    !supabaseAnonKey.contains('TU_PUBLISHABLE');
