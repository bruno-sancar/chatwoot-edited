import { createClient } from '@supabase/supabase-js';
import { useConfig } from 'dashboard/composables/useConfig';
import FocohSupabaseTokenAPI from 'dashboard/api/focohSupabaseToken';

/**
 * Cliente Supabase único do módulo Focoh, compartilhado por todas as
 * composables (quadro, admissão, progressão, risco, configuração). Extraído
 * de `useFocohKanban.js` porque cada composable que criasse seu próprio
 * cliente duplicaria a emissão de token — o board sozinho já dispara vários
 * requests em paralelo (ver comentário original em `emitirToken`).
 *
 * Autenticação: o Rails assina um JWT curto para o usuário logado, com o
 * papel clínico em `app_metadata.role` (Focoh::SupabaseTokenService). O
 * segredo de assinatura fica no servidor; aqui só circulam a anon key e o
 * token emitido.
 */

const MARGEM_RENOVACAO_MS = 60 * 1000;

let client = null;
let tokenCache = { token: null, expiraEmMs: 0 };
let emissaoPendente = null;

const emitirToken = async () => {
  const { data } = await FocohSupabaseTokenAPI.issue();
  tokenCache = {
    token: data.access_token,
    expiraEmMs: data.expires_at * 1000,
  };
  return tokenCache.token;
};

export const obterFocohToken = async () => {
  if (tokenCache.token && Date.now() < tokenCache.expiraEmMs - MARGEM_RENOVACAO_MS) {
    return tokenCache.token;
  }

  emissaoPendente = emissaoPendente || emitirToken();
  try {
    return await emissaoPendente;
  } finally {
    emissaoPendente = null;
  }
};

// Lido a cada chamada, e não uma vez no carregamento do módulo: `window` só
// existe depois que a página renderizou, e ler cedo devolveria undefined.
export const getFocohSupabaseClient = () => {
  const { focohSupabaseUrl, focohSupabaseAnonKey } = useConfig();
  if (!focohSupabaseUrl || !focohSupabaseAnonKey) return null;

  if (!client) {
    // `accessToken` é o contrato do supabase-js para JWT de provedor externo:
    // ele usa este token em todo request e não tenta gerir sessão própria.
    client = createClient(focohSupabaseUrl, focohSupabaseAnonKey, {
      accessToken: obterFocohToken,
    });
  }
  return client;
};

export const isFocohConfigurado = () => {
  const { focohSupabaseUrl, focohSupabaseAnonKey } = useConfig();
  return Boolean(focohSupabaseUrl && focohSupabaseAnonKey);
};
