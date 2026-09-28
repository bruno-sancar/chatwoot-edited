import { ref } from 'vue';
import { getFocohSupabaseClient, obterFocohToken } from '../focohSupabaseClient';

/**
 * Motor de formulários genérico: lê o catálogo (`definicoes_formulario`) e
 * grava envios (`respostas_formulario`). Usado por toda tela clínica
 * (Admissão, Progressão de Fase, Avaliação de Risco, e o que vier depois) —
 * a tela não sabe nada de campo específico, só monta o formulário a partir
 * do que o catálogo devolve.
 *
 * Ver `supabase/migrations/20260925220000_focoh_kanban_motor_formularios.sql`
 * para o desenho de dado: o catálogo é editável em lugar pelo painel de
 * configuração; a resposta guarda uma CÓPIA do que foi perguntado, não uma
 * referência — por isso `enviarResposta` recebe as definições já carregadas
 * e as embute em `campos`, em vez de o banco montar isso sozinho.
 */
export function useFocohFormularios() {
  const definicoes = ref([]);
  const isLoadingDefinicoes = ref(false);
  const erroDefinicoes = ref(null);

  const historico = ref([]);
  const isLoadingHistorico = ref(false);
  const erroHistorico = ref(null);

  const isSubmitting = ref(false);
  const erroEnvio = ref(null);

  /**
   * @param {string} formularioTipo 'admissao' | 'progressao_fase' | 'avaliacao_risco' | ...
   * @param {{programa?: string, etapa?: string}} filtro
   */
  const carregarDefinicoes = async (formularioTipo, filtro = {}) => {
    const supabase = getFocohSupabaseClient();
    if (!supabase) return;

    isLoadingDefinicoes.value = true;
    erroDefinicoes.value = null;

    try {
      await obterFocohToken();

      let query = supabase
        .from('definicoes_formulario')
        .select('*')
        .eq('formulario_tipo', formularioTipo)
        .eq('ativo', true)
        .order('bloco', { ascending: true, nullsFirst: true })
        .order('ordem', { ascending: true });

      // programa/etapa nulos no catálogo significam "vale para qualquer
      // valor" (ex.: Aba A da admissão é comum aos dois quadros) — por isso
      // o filtro é "igual OU nulo", não um match exato.
      if (filtro.programa) {
        query = query.or(`programa.eq.${filtro.programa},programa.is.null`);
      }
      if (filtro.etapa) {
        query = query.or(`etapa.eq.${filtro.etapa},etapa.is.null`);
      }

      const { data, error } = await query;
      if (error) throw error;

      definicoes.value = data ?? [];
    } catch (error) {
      erroDefinicoes.value = error;
    } finally {
      isLoadingDefinicoes.value = false;
    }
  };

  /**
   * Agrupa `definicoes` por bloco, na ordem em que devem aparecer — o
   * formato que `FocohFormularioDinamico.vue` consome diretamente.
   */
  const definicoesPorBloco = () => {
    const grupos = new Map();
    definicoes.value.forEach(def => {
      const chave = def.bloco ?? '__geral__';
      if (!grupos.has(chave)) grupos.set(chave, []);
      grupos.get(chave).push(def);
    });
    return grupos;
  };

  /**
   * @param {object} params
   * @param {string} params.pacienteId
   * @param {string} params.formularioTipo
   * @param {string=} params.etapa
   * @param {string=} params.bloco
   * @param {string} params.dataReferencia 'YYYY-MM-DD' — data clínica, não o
   *   carimbo de envio (esse o banco grava sozinho em `enviado_em`).
   * @param {Array<{definicao: object, valor: unknown}>} params.respostas
   * @param {string=} params.resultado 'apto'|'nao_apto'|'baixo'|'moderado'|'alto'
   * @param {string=} params.autorPapel
   */
  const enviarResposta = async ({
    pacienteId,
    formularioTipo,
    etapa,
    bloco,
    dataReferencia,
    respostas,
    resultado,
    autorPapel,
  }) => {
    const supabase = getFocohSupabaseClient();
    if (!supabase) return { ok: false };

    isSubmitting.value = true;
    erroEnvio.value = null;

    // Congela o que foi perguntado junto do que foi respondido — é o que
    // mantém o envio legível mesmo se o catálogo mudar depois (ver comentário
    // em respostas_formulario.campos, migration do motor de formulários).
    const campos = respostas.map(({ definicao, valor }) => ({
      campo_chave: definicao.campo_chave,
      rotulo: definicao.rotulo,
      tipo_campo: definicao.tipo_campo,
      obrigatorio: definicao.obrigatorio,
      valor,
    }));

    try {
      const { data, error } = await supabase
        .from('respostas_formulario')
        .insert({
          paciente_id: pacienteId,
          formulario_tipo: formularioTipo,
          etapa: etapa ?? null,
          bloco: bloco ?? null,
          data_referencia: dataReferencia,
          autor_papel: autorPapel ?? null,
          campos,
          resultado: resultado ?? null,
        })
        .select()
        .single();

      if (error) throw error;

      return { ok: true, resposta: data };
    } catch (error) {
      erroEnvio.value = error;
      return { ok: false, error };
    } finally {
      isSubmitting.value = false;
    }
  };

  const carregarHistorico = async pacienteId => {
    const supabase = getFocohSupabaseClient();
    if (!supabase) return;

    isLoadingHistorico.value = true;
    erroHistorico.value = null;

    try {
      await obterFocohToken();

      const { data, error } = await supabase
        .from('respostas_formulario')
        .select('*')
        .eq('paciente_id', pacienteId)
        .order('enviado_em', { ascending: false });

      if (error) throw error;

      historico.value = data ?? [];
    } catch (error) {
      erroHistorico.value = error;
    } finally {
      isLoadingHistorico.value = false;
    }
  };

  return {
    definicoes,
    isLoadingDefinicoes,
    erroDefinicoes,
    carregarDefinicoes,
    definicoesPorBloco,

    isSubmitting,
    erroEnvio,
    enviarResposta,

    historico,
    isLoadingHistorico,
    erroHistorico,
    carregarHistorico,
  };
}
