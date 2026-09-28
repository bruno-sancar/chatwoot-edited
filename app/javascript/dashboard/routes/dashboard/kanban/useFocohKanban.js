import { ref, computed } from 'vue';
import {
  getFocohSupabaseClient,
  obterFocohToken,
  isFocohConfigurado,
} from './focohSupabaseClient';

/**
 * Ponte entre o board Vue e o Supabase, que é o sistema-fonte dos dados
 * clínicos. Nada de clínico é replicado no Postgres do Chatwoot.
 *
 * O cliente/token (autenticação via JWT curto emitido por
 * Focoh::SupabaseTokenService) mora em `focohSupabaseClient.js`,
 * compartilhado com as demais composables do módulo — ver esse arquivo para
 * o porquê da autenticação e do dedupe de emissão de token.
 *
 * O board lê exclusivamente a função `cards_do_quadro()`: ela devolve flags
 * derivados e nunca o escore de risco. Ler `avaliacoes_risco` daqui não é uma
 * questão de disciplina — a RLS não devolveria linha alguma para recepção.
 */
const getClient = getFocohSupabaseClient;
const obterToken = obterFocohToken;

export function useFocohKanban() {
  // Ausência das variáveis é erro de deploy, não estado de operação: o board
  // mostra isso na cara do operador em vez de aparecer vazio, que pareceria
  // "nenhum paciente internado".
  const isConfigured = isFocohConfigurado();

  const cards = ref([]);
  const isLoading = ref(false);
  const erroCarregamento = ref(null);
  const erroAutenticacao = ref(null);

  const cardsPorFase = computed(() =>
    cards.value.reduce((acc, card) => {
      acc[card.fase] = acc[card.fase] || [];
      acc[card.fase].push(card);
      return acc;
    }, {})
  );

  const carregarCards = async () => {
    const supabase = getClient();
    if (!supabase) return;

    isLoading.value = true;
    erroCarregamento.value = null;
    erroAutenticacao.value = null;

    try {
      // Emitido aqui, e não só dentro do callback do supabase-js, para que a
      // falta de papel clínico chegue à tela como motivo e não como erro opaco
      // de request. Sem papel, a RLS devolveria zero linhas — indistinguível
      // de "clínica sem pacientes internados".
      await obterToken();
    } catch (error) {
      erroAutenticacao.value = error.response?.data?.error ?? 'token_indisponivel';
      isLoading.value = false;
      return;
    }

    try {
      const { data, error } = await supabase.rpc('cards_do_quadro');
      if (error) throw error;

      cards.value = data ?? [];
    } catch (error) {
      erroCarregamento.value = error;
    } finally {
      isLoading.value = false;
    }
  };

  /**
   * Pede ao banco a progressão de fase. A decisão é do trigger `Anexo Fases`;
   * aqui só se transporta o veredito.
   *
   * @returns {Promise<{ok: boolean, error?: object}>} `error` traz o SQLSTATE
   *   em `code` e o texto oficial de bloqueio em `message`.
   */
  const moverPaciente = async (pacienteId, faseDestino) => {
    const supabase = getClient();
    if (!supabase) return { ok: false };

    const { error } = await supabase
      .from('pacientes')
      .update({ fase: faseDestino })
      .eq('id', pacienteId);

    return error ? { ok: false, error } : { ok: true };
  };

  return {
    isConfigured,
    cards,
    cardsPorFase,
    isLoading,
    erroCarregamento,
    erroAutenticacao,
    carregarCards,
    moverPaciente,
  };
}
