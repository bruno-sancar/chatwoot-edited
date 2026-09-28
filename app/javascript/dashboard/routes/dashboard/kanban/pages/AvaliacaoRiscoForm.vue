<script setup>
import { ref, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';

import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import FocohBlocoFormulario from '../components/FocohBlocoFormulario.vue';
import { useFocohFormularios } from '../composables/useFocohFormularios';
import { getFocohSupabaseClient, obterFocohToken } from '../focohSupabaseClient';

/**
 * Escala de Avaliação de Risco de Suicídio (Aba C da Ficha de Admissão, e
 * recorrente depois — diária/3x/2x por semana conforme a última
 * classificação). Formulário único, sem etapa: os 5 critérios são fixos do
 * instrumento oficial da clínica, não mudam por fase.
 *
 * A sincronização (migration de sincronização) soma os 5 critérios, valida
 * o intervalo 5-20 e grava em `avaliacoes_risco` — o `nivel` (Baixo/
 * Moderado/Alto) é derivado pelo trigger que já existe
 * (`tg_avaliacoes_risco_derivar_nivel`), com a escala invertida corrigida.
 * Este componente não calcula nada, só coleta os 5 números.
 */
const { t } = useI18n();
const route = useRoute();
const pacienteId = route.params.pacienteId;

const paciente = ref(null);
const isLoadingPaciente = ref(true);

const {
  definicoes,
  isLoadingDefinicoes,
  carregarDefinicoes,
  isSubmitting,
  enviarResposta,
} = useFocohFormularios();

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

const onEnviar = async ({ respostas }) => {
  const { ok, error } = await enviarResposta({
    pacienteId,
    formularioTipo: 'avaliacao_risco',
    dataReferencia: new Date().toISOString().slice(0, 10),
    respostas,
  });

  if (ok) {
    useAlert(t('FOCOH_KANBAN.RISCO.ENVIADO'));
  } else {
    // O erro de intervalo (escore fora de 5-20) levantado pela sincronização
    // chega aqui como error.message — não precisa de tradução própria,
    // porque é validação de dado incompleto, não regra de negócio.
    useAlert(error?.message ?? t('FOCOH_KANBAN.BLOCO.ENVIAR'));
  }
};

onMounted(async () => {
  await carregarPaciente();
  await carregarDefinicoes('avaliacao_risco', { programa: paciente.value?.programa });
});
</script>

<template>
  <section class="flex flex-col w-full h-full gap-6 p-6 overflow-y-auto bg-n-surface-1">
    <div v-if="isLoadingPaciente || isLoadingDefinicoes" class="flex items-center justify-center flex-1">
      <Spinner :size="24" />
    </div>

    <template v-else-if="paciente">
      <header>
        <h1 class="text-heading-1 text-n-slate-12">
          {{ t('FOCOH_KANBAN.RISCO.TITULO') }}
        </h1>
        <p class="mt-1 text-body-main text-n-slate-11">
          {{ t('FOCOH_KANBAN.RISCO.SUBTITULO', { nome: paciente.nome }) }}
        </p>
      </header>

      <FocohBlocoFormulario
        :titulo="t('FOCOH_KANBAN.RISCO.TITULO')"
        :definicoes="definicoes"
        :is-submitting="isSubmitting"
        @enviar="onEnviar"
      />
    </template>
  </section>
</template>
