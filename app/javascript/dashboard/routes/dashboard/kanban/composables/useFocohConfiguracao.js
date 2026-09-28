import { ref } from 'vue';
import { getFocohSupabaseClient, obterFocohToken } from '../focohSupabaseClient';

/**
 * Tela Configurações: CRUD do catálogo (`definicoes_formulario`) e da
 * allowlist de editores (`editores_configuracao`). A permissão de escrita
 * é decidida pela RLS/pelas RPCs no banco (papel governança ou flag de
 * editor) — esta composable não decide nada, só chama.
 */
export function useFocohConfiguracao() {
  const propriedades = ref([]);
  const isLoadingPropriedades = ref(false);
  const erroPropriedades = ref(null);

  const editores = ref([]);
  const isLoadingEditores = ref(false);
  const erroEditores = ref(null);

  const souEditor = ref(false);

  const verificarSouEditor = async () => {
    const supabase = getFocohSupabaseClient();
    if (!supabase) return;

    try {
      await obterFocohToken();
      const { data, error } = await supabase.rpc('sou_editor_configuracao');
      if (error) throw error;
      souEditor.value = Boolean(data);
    } catch {
      souEditor.value = false;
    }
  };

  const carregarPropriedades = async formularioTipo => {
    const supabase = getFocohSupabaseClient();
    if (!supabase) return;

    isLoadingPropriedades.value = true;
    erroPropriedades.value = null;

    try {
      await obterFocohToken();
      let query = supabase.from('definicoes_formulario').select('*').order('formulario_tipo').order('bloco').order('ordem');
      if (formularioTipo) query = query.eq('formulario_tipo', formularioTipo);

      const { data, error } = await query;
      if (error) throw error;

      propriedades.value = data ?? [];
    } catch (error) {
      erroPropriedades.value = error;
    } finally {
      isLoadingPropriedades.value = false;
    }
  };

  const criarPropriedade = async propriedade => {
    const supabase = getFocohSupabaseClient();
    if (!supabase) return { ok: false };

    try {
      const { data, error } = await supabase
        .from('definicoes_formulario')
        .insert(propriedade)
        .select()
        .single();

      if (error) throw error;
      propriedades.value = [...propriedades.value, data];
      return { ok: true, propriedade: data };
    } catch (error) {
      return { ok: false, error };
    }
  };

  // Edição rasa de propósito (ver plano): só o que o dia a dia da clínica
  // precisa mexer — rótulo, obrigatoriedade, ativo. Tipo de campo e chave não
  // mudam depois de criados (mudar o tipo quebraria respostas já congeladas
  // em respostas_formulario.campos, que guardam o tipo do momento do envio).
  const atualizarPropriedade = async (id, mudancas) => {
    const supabase = getFocohSupabaseClient();
    if (!supabase) return { ok: false };

    try {
      const { data, error } = await supabase
        .from('definicoes_formulario')
        .update(mudancas)
        .eq('id', id)
        .select()
        .single();

      if (error) throw error;
      propriedades.value = propriedades.value.map(p => (p.id === id ? data : p));
      return { ok: true };
    } catch (error) {
      return { ok: false, error };
    }
  };

  const carregarEditores = async () => {
    const supabase = getFocohSupabaseClient();
    if (!supabase) return;

    isLoadingEditores.value = true;
    erroEditores.value = null;

    try {
      await obterFocohToken();
      const { data, error } = await supabase
        .from('editores_configuracao')
        .select('*')
        .order('concedido_em', { ascending: false });

      if (error) throw error;
      editores.value = data ?? [];
    } catch (error) {
      erroEditores.value = error;
    } finally {
      isLoadingEditores.value = false;
    }
  };

  const concederEditor = async (chatwootUserId, nomeExibicao) => {
    const supabase = getFocohSupabaseClient();
    if (!supabase) return { ok: false };

    try {
      const { error } = await supabase.rpc('conceder_editor_configuracao', {
        p_chatwoot_user_id: chatwootUserId,
        p_nome_exibicao: nomeExibicao ?? null,
      });
      if (error) throw error;

      await carregarEditores();
      return { ok: true };
    } catch (error) {
      return { ok: false, error };
    }
  };

  const revogarEditor = async chatwootUserId => {
    const supabase = getFocohSupabaseClient();
    if (!supabase) return { ok: false };

    try {
      const { error } = await supabase.rpc('revogar_editor_configuracao', {
        p_chatwoot_user_id: chatwootUserId,
      });
      if (error) throw error;

      await carregarEditores();
      return { ok: true };
    } catch (error) {
      return { ok: false, error };
    }
  };

  return {
    propriedades,
    isLoadingPropriedades,
    erroPropriedades,
    carregarPropriedades,
    criarPropriedade,
    atualizarPropriedade,

    editores,
    isLoadingEditores,
    erroEditores,
    carregarEditores,
    concederEditor,
    revogarEditor,

    souEditor,
    verificarSouEditor,
  };
}
