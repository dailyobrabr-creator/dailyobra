/// Mesmo projeto Supabase do app web ("dailyobra", sa-east-1): uma conta só, e as obras
/// cadastradas em um aparecem no outro.
///
/// A chave publicável é feita para ir dentro do app; quem vê e altera cada obra é decidido
/// no banco pelas políticas RLS. Nunca coloque aqui a chave secreta (service_role / sb_secret_...).
class SupabaseConfig {
  SupabaseConfig._();
  static const url = 'https://wlqtwaiqtwxmmndlunvh.supabase.co';
  static const publishableKey =
      'sb_publishable_MhBkxHBPSukvO6-d3zxiBw_w7isbqmV';
}
