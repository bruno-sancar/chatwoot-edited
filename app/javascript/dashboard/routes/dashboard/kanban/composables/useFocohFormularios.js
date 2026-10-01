import { ref } from 'vue';
import { getFocohSupabaseClient, obterFocohToken } from '../focohSupabaseClient';

/**
 * Motor de formulÃ¡rios genÃ©rico: lÃª o catÃ¡logo (`definicoes_formulario`) e
 * grava envios (`respostas_formulario`). Usado por toda tela clÃ­nica
 * (AdmissÃ£o, ProgressÃ£o de Fase, AvaliaÃ§Ã£o de Risco, e o que vier depois) â€”
 * a tela nÃ£o sabe nada de campo especÃ­fico, sÃ³ monta o formulÃ¡rio a partir
 * do que o catÃ¡logo devolve.
 *
 * Ver `supabase/migrations/20260925220000_focoh_kanban_motor_formularios.sql`
 * para o desenho de dado: o catÃ¡logo Ã© editÃ¡vel em lugar pelo painel de
 * configuraÃ§Ã£o; a resposta guarda uma CÃ“PIA do que foi perguntado, nÃ£o uma
 * referÃªncia â€” por isso `enviarResposta` recebe as definiÃ§Ãµes jÃ¡ carregadas
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

      // programa/etapa nulos no catÃ¡logo significam "vale para qualquer
      // valor" (ex.: Aba A da admissÃ£o Ã© comum aos dois quadros) â€” por isso
      // o filtro Ã© "igual OU nulo", nÃ£o um match exato.
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
   * Agrupa `definicoes` por bloco, na ordem em que devem aparecer â€” o
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
   * @param {string} params.dataReferencia 'YYYY-MM-DD' â€” data clÃ­nica, nÃ£o o
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
    autorNome,
  }) => {
    const supabase = getFocohSupabaseClient();
    if (!supabase) return { ok: false };

    isSubmitting.value = true;
    erroEnvio.value = null;

    // Congela o que foi perguntado junto do que foi respondido â€” Ã© o que
    // mantÃ©m o envio legÃ­vel mesmo se o catÃ¡logo mudar depois (ver comentÃ¡rio
    // em respostas_formulario.campos, migration do motor de formulÃ¡rios).
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
          autor_nome: autorNome ?? null,
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

