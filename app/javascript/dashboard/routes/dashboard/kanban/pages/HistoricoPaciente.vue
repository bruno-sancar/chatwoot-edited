<script setup>
import { ref, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';

import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import FocohNavegacaoPaciente from '../components/FocohNavegacaoPaciente.vue';
import { useFocohFormularios } from '../composables/useFocohFormularios';
import { getFocohSupabaseClient, obterFocohToken } from '../focohSupabaseClient';

/**
 * "a gente conseguir olhar esses vários dados diferentes, de datas
 * diferentes, de envios diferentes, feitos ao longo de semanas" — a
 * linha do tempo que faltava para o histórico não ser decorativo. Lê
 * direto de `respostas_formulario` (RLS: só equipe clínica, mesmo critério
 * de laudos_semanais — recepção não vê conteúdo de formulário clínico).
 */
const { t } = useI18n();

const TIPO_FORMULARIO_LABEL = {
  admissao:         'Admissão e Triagem',
  progressao_fase:  'Progressão de Fase',
  avaliacao_risco:  'Avaliação de Risco',
  evolucao_semanal: 'Laudo Semanal',
  ficha_admissao:   'Ficha de Admissão',
};

const BLOCO_LABEL = {
  clinico:     'Clínico',
  terapeutico: 'Terapêutico',
  disciplinar: 'Disciplinar',
  risco:       'Risco',
  rede_apoio:  'Rede de Apoio',
};
const route = useRoute();
const pacienteId = route.params.pacienteId;

const paciente = ref(null);
const abertos = ref(new Set());

const { historico, isLoadingHistorico, erroHistorico, carregarHistorico } = useFocohFormularios();

const alternarAberto = id => {
  const proximo = new Set(abertos.value);
  if (proximo.has(id)) proximo.delete(id);
  else proximo.add(id);
  abertos.value = proximo;
};

const corResultado = resultado => {
  if (resultado === 'apto' || resultado === 'baixo') return 'bg-n-teal-3 text-n-teal-11';
  if (resultado === 'nao_apto' || resultado === 'alto') return 'bg-n-ruby-3 text-n-ruby-11';
  if (resultado === 'moderado') return 'bg-n-amber-3 text-n-amber-11';
  return 'bg-n-slate-3 text-n-slate-11';
};

onMounted(async () => {
  const supabase = getFocohSupabaseClient();
  if (supabase) {
    await obterFocohToken();
    const { data } = await supabase.from('pacientes').select('id, nome').eq('id', pacienteId).single();
    paciente.value = data;
  }
  await carregarHistorico(pacienteId);
});
</script>

<template>
  <section class="flex flex-col w-full h-full bg-n-surface-1">
    <div class="flex-1 overflow-y-auto p-6 flex flex-col gap-6">
      <header>
        <h1 class="text-heading-1 text-n-slate-12">
          {{ t('FOCOH_KANBAN.HISTORICO.TITULO') }}
        </h1>
        <p v-if="paciente" class="mt-1 text-body-main text-n-slate-11">
          {{ paciente.nome }}
        </p>
      </header>

      <div v-if="isLoadingHistorico" class="flex items-center justify-center flex-1">
        <Spinner :size="24" />
      </div>

      <p v-else-if="erroHistorico" class="text-body-main text-n-ruby-11">
        {{ erroHistorico.message }}
      </p>

      <p v-else-if="!historico.length" class="text-body-main text-n-slate-11">
        {{ t('FOCOH_KANBAN.HISTORICO.VAZIO') }}
      </p>

      <ol v-else class="flex flex-col gap-3">
        <li
          v-for="envio in historico"
          :key="envio.id"
          class="border rounded-xl border-n-weak bg-n-solid-1"
        >
          <button
            type="button"
            class="flex items-center justify-between w-full gap-3 px-4 py-3 text-left"
            @click="alternarAberto(envio.id)"
          >
            <div class="flex items-center gap-2 min-w-0">
              <span class="truncate text-heading-3 text-n-slate-12">
              <span class="truncate text-heading-3 text-n-slate-12">
                {{ TIPO_FORMULARIO_LABEL[envio.formulario_tipo] ?? envio.formulario_tipo }}
                <template v-if="envio.bloco"> &middot; {{ BLOCO_LABEL[envio.bloco] ?? envio.bloco }}</template>
                <template v-if="envio.etapa"> &middot; {{ envio.etapa }}</template>
              </span>
              <span
                v-if="envio.resultado"
                class="rounded-full px-2 py-0.5 text-label-small shrink-0"
                :class="corResultado(envio.resultado)"
              >
                {{ t(`FOCOH_KANBAN.HISTORICO.RESULTADO.${envio.resultado}`) }}
              </span>
            </div>
            <span class="text-label-small text-n-slate-10 shrink-0">
              {{ new Date(envio.enviado_em).toLocaleString() }}
            </span>
          </button>

          <div v-if="abertos.has(envio.id)" class="flex flex-col gap-2 px-4 pb-4">
            <p class="text-label-small text-n-slate-10">
            <p class="text-label-small text-n-slate-10">
              <template v-if="envio.autor_nome">
                <span class="font-medium">{{ envio.autor_nome }}</span>
                <template v-if="envio.autor_papel"> ({{ envio.autor_papel }})</template>
                 &middot; 
              </template>
              {{ t('FOCOH_KANBAN.HISTORICO.DATA_REFERENCIA') }} {{ envio.data_referencia }}
            </p>
            </p>
            <dl class="grid grid-cols-1 gap-1 sm:grid-cols-2">
              <div v-for="campo in envio.campos" :key="campo.campo_chave">
                <dt class="text-label-small text-n-slate-10">{{ campo.rotulo }}</dt>
                <dd class="text-body-main text-n-slate-12">{{ campo.valor ?? '—' }}</dd>
              </div>
            </dl>
          </div>
        </li>
      </ol>
    </div>
    <FocohNavegacaoPaciente />
  </section>
</template>
