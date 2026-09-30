<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';

import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import FocohBlocoFormulario from '../components/FocohBlocoFormulario.vue';
import FocohNavegacaoPaciente from '../components/FocohNavegacaoPaciente.vue';
import { useFocohFormularios } from '../composables/useFocohFormularios';
import { getFocohSupabaseClient, obterFocohToken } from '../focohSupabaseClient';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const pacienteId = route.params.pacienteId;

const BLOCO_TITULO = {
  clinico:     'FOCOH_KANBAN.LAUDO.BLOCO_CLINICO',
  terapeutico: 'FOCOH_KANBAN.LAUDO.BLOCO_TERAPEUTICO',
  disciplinar: 'FOCOH_KANBAN.LAUDO.BLOCO_DISCIPLINAR',
};

const paciente = ref(null);
const isLoadingPaciente = ref(true);
const blocoEnviadoNestaVisita = ref(new Set());

const {
  definicoes,
  isLoadingDefinicoes,
  carregarDefinicoes,
  definicoesPorBloco,
  isSubmitting,
  enviarResposta,
  historico,
  carregarHistorico,
} = useFocohFormularios();

const blocos = computed(() => {
  const grupos = definicoesPorBloco();
  return Array.from(grupos.entries())
    .filter(([bloco]) => bloco !== '__geral__')
    .map(([bloco, defs]) => ({ bloco, defs }));
});

const ultimoEnvioPorBloco = computed(() => {
  const mapa = {};
  historico.value
    .filter(r => r.formulario_tipo === 'evolucao_semanal')
    .forEach(r => {
      if (!mapa[r.bloco]) mapa[r.bloco] = r;
    });
  return mapa;
});

const carregarPaciente = async () => {
  const supabase = getFocohSupabaseClient();
  if (!supabase) return;
  isLoadingPaciente.value = true;
  try {
    await obterFocohToken();
    const { data, error } = await supabase
      .from('pacientes')
      .select('id, nome, programa')
      .eq('id', pacienteId)
      .single();
    if (error) throw error;
    paciente.value = data;
  } finally {
    isLoadingPaciente.value = false;
  }
};

const onEnviarBloco = async (bloco, { respostas, resultado }) => {
  const { ok, error } = await enviarResposta({
    pacienteId,
    formularioTipo: 'evolucao_semanal',
    bloco,
    dataReferencia: new Date().toISOString().slice(0, 10),
    respostas,
    resultado,
  });

  if (ok) {
    useAlert(t('FOCOH_KANBAN.LAUDO.ENVIADO'));
    blocoEnviadoNestaVisita.value = new Set([...blocoEnviadoNestaVisita.value, bloco]);
    await carregarHistorico(pacienteId);
  } else {
    useAlert(error?.message ?? t('FOCOH_KANBAN.BLOCO.ENVIAR'));
  }
};

const voltarKanban = () => {
  router.push({
    name: 'kanban_clinico_index',
    params: { accountId: route.params.accountId },
  });
};

onMounted(async () => {
  await carregarPaciente();
  await carregarDefinicoes('evolucao_semanal', { programa: paciente.value?.programa });
  await carregarHistorico(pacienteId);
});
</script>

<template>
  <section class="flex flex-col w-full h-full bg-n-surface-1">
    <div class="flex-1 overflow-y-auto p-6 flex flex-col gap-6">
      <div v-if="isLoadingPaciente" class="flex items-center justify-center flex-1">
        <Spinner :size="24" />
      </div>

      <template v-else-if="paciente">
        <header class="flex items-start justify-between gap-4">
          <div>
            <h1 class="text-heading-1 text-n-slate-12">
              {{ t('FOCOH_KANBAN.LAUDO.TITULO') }}
            </h1>
            <p class="mt-1 text-body-main text-n-slate-11">
              {{ t('FOCOH_KANBAN.LAUDO.SUBTITULO', { nome: paciente.nome }) }}
            </p>
          </div>
          <Button
            :label="t('FOCOH_KANBAN.LAUDO.VOLTAR_KANBAN')"
            variant="ghost"
            size="sm"
            icon="i-lucide-arrow-left"
            @click="voltarKanban"
          />
        </header>

        <div v-if="isLoadingDefinicoes" class="flex items-center justify-center flex-1">
          <Spinner :size="24" />
        </div>

        <div v-else class="flex flex-col gap-4">
          <FocohBlocoFormulario
            v-for="{ bloco, defs } in blocos"
            :key="bloco"
            :titulo="t(BLOCO_TITULO[bloco] ?? bloco)"
            :definicoes="defs"
            com-decisao
            :is-submitting="isSubmitting"
            :ultimo-envio="ultimoEnvioPorBloco[bloco]"
            :enviado="blocoEnviadoNestaVisita.has(bloco)"
            @enviar="payload => onEnviarBloco(bloco, payload)"
          />
        </div>
      </template>
    </div>
    <FocohNavegacaoPaciente />
  </section>
</template>
