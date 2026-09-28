<script setup>
import { ref, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';

import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import FocohBlocoFormulario from '../components/FocohBlocoFormulario.vue';
import { useFocohFormularios } from '../composables/useFocohFormularios';
import { getFocohSupabaseClient, obterFocohToken } from '../focohSupabaseClient';

/**
 * Ficha de Admissão — Aba A (Identificação + Rede de Apoio). "O card do
 * Kanban É o registro do paciente. Não existe uma tela separada de 'criar
 * registro'" (Mapa Objetivo) — é este formulário que faz o paciente/card
 * nascer, na coluna 1 (a trava `tg_pacientes_admissao_na_coluna_1` recusa
 * qualquer outra fase no INSERT, então nem precisamos declarar `fase` aqui).
 *
 * Diferente da Progressão/Risco, os campos aqui são `natureza=cadastral`:
 * não viram respostas_formulario, viram `pacientes.nome` (coluna própria,
 * porque a trava e cards_do_quadro() já dependem dela) e
 * `pacientes.dados_cadastrais` (o resto do catálogo).
 */
const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();

// Chegando do botão "Criar registro" no painel da conversa (ver
// FocohRegistroVinculado.vue) — o vínculo é gravado de volta na conversa
// assim que o paciente é criado, sem o operador repetir o passo.
const contatoParaVincular = route.query.vincularContatoId ?? null;

const {
  definicoes,
  isLoadingDefinicoes,
  carregarDefinicoes,
} = useFocohFormularios();

const isSubmitting = ref(false);

const onEnviar = async ({ respostas }) => {
  const supabase = getFocohSupabaseClient();
  if (!supabase) return;

  const porChave = Object.fromEntries(
    respostas.map(({ definicao, valor }) => [definicao.campo_chave, valor])
  );
  const { nome, ...dadosCadastrais } = porChave;

  isSubmitting.value = true;
  try {
    await obterFocohToken();

    const { data: pacienteCriado, error } = await supabase
      .from('pacientes')
      // `programa` fixo em jornada_superacao: a matriz de 11 eixos que
      // decide Detox vs. Jornada (Manual Técnico 2026) é triagem de
      // coordenação, fora do escopo desta fatia — só a Jornada tem quadro
      // hoje. Trocar depois é `update pacientes set programa = ...`.
      .insert({ nome, programa: 'jornada_superacao', dados_cadastrais: dadosCadastrais })
      .select('id')
      .single();

    if (error) throw error;

    if (contatoParaVincular) {
      await store.dispatch('contacts/update', {
        id: contatoParaVincular,
        customAttributes: { focoh_patient_id: pacienteCriado.id, focoh_patient_nome: nome },
      });
    }

    useAlert(t('FOCOH_KANBAN.ADMISSAO.CRIADO'));
    router.push({
      name: 'kanban_clinico_index',
      params: { accountId: route.params.accountId },
    });
  } catch (error) {
    useAlert(error?.message ?? t('FOCOH_KANBAN.BLOCO.ENVIAR'));
  } finally {
    isSubmitting.value = false;
  }
};

onMounted(() => {
  carregarDefinicoes('admissao', { etapa: 'aba_a' });
});
</script>

<template>
  <section class="flex flex-col w-full h-full gap-6 p-6 overflow-y-auto bg-n-surface-1">
    <header>
      <h1 class="text-heading-1 text-n-slate-12">
        {{ t('FOCOH_KANBAN.ADMISSAO.TITULO') }}
      </h1>
      <p class="mt-1 text-body-main text-n-slate-11">
        {{ t('FOCOH_KANBAN.ADMISSAO.SUBTITULO') }}
      </p>
    </header>

    <div v-if="isLoadingDefinicoes" class="flex items-center justify-center flex-1">
      <Spinner :size="24" />
    </div>

    <FocohBlocoFormulario
      v-else
      :titulo="t('FOCOH_KANBAN.ADMISSAO.ABA_A')"
      :definicoes="definicoes"
      :is-submitting="isSubmitting"
      @enviar="onEnviar"
    />
  </section>
</template>
