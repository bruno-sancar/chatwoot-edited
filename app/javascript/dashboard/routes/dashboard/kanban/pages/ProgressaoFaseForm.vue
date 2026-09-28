<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';

import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import FocohBlocoFormulario from '../components/FocohBlocoFormulario.vue';
import { useFocohFormularios } from '../composables/useFocohFormularios';
import { getFocohSupabaseClient, obterFocohToken } from '../focohSupabaseClient';

/**
 * Tela B do Mapa Objetivo: o formulário que governa a Jornada de Superação.
 * Estrutura fixa (blocos), conteúdo variável por transição — os blocos são
 * lidos do catálogo (`definicoes_formulario`), nunca hardcoded aqui.
 *
 * Cada bloco submete de forma independente (ver FocohBlocoFormulario) e o
 * trigger `respostas_formulario_10_sincronizar` grava em `laudos_semanais`
 * — a trava "Anexo Fases" já existente reage sozinha, sem este componente
 * saber nada sobre ela.
 */
const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const pacienteId = route.params.pacienteId;

const abrirAvaliacaoRisco = () => {
  router.push({
    name: 'kanban_clinico_avaliacao_risco',
    params: { accountId: route.params.accountId, pacienteId },
  });
};

const abrirHistorico = () => {
  router.push({
    name: 'kanban_clinico_historico_paciente',
    params: { accountId: route.params.accountId, pacienteId },
  });
};

// fase_jornada -> transição avaliada para SAIR da fase atual. Não há
// transição para quem já está em admissão (a saída dali é 72h + triagem,
// não um Formulário de Progressão) nem para alta_transicao (já saiu).
const TRANSICAO_POR_FASE = {
  fase1_autocritica: 'f1_f2',
  fase2_disciplina: 'f2_f3',
  fase3_empatia: 'f3_f4',
  fase4_identidade: 'f4_alta',
};

const BLOCO_TITULO = {
  clinico: 'FOCOH_KANBAN.PROGRESSAO.BLOCO_CLINICO',
  terapeutico: 'FOCOH_KANBAN.PROGRESSAO.BLOCO_TERAPEUTICO',
  disciplinar: 'FOCOH_KANBAN.PROGRESSAO.BLOCO_DISCIPLINAR',
  risco_sustentabilidade: 'FOCOH_KANBAN.PROGRESSAO.BLOCO_RISCO',
  rede_apoio_continuidade: 'FOCOH_KANBAN.PROGRESSAO.BLOCO_REDE_APOIO',
};

// Só os 3 primeiros blocos têm decisão Apto/Não apto — a sincronização com
// laudos_semanais (migration de sincronização) só lê esses. Risco e Rede de
// Apoio ficam registrados no histórico, sem virar um segundo portão de
// trava (ver comentário PENDENTE DE VALIDAÇÃO CLÍNICA na migration).
const BLOCOS_COM_DECISAO = new Set(['clinico', 'terapeutico', 'disciplinar']);

const paciente = ref(null);
const isLoadingPaciente = ref(true);
const erroPaciente = ref(null);

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

const transicao = computed(() => TRANSICAO_POR_FASE[paciente.value?.fase] ?? null);

const blocos = computed(() => {
  const grupos = definicoesPorBloco();
  return Array.from(grupos.entries())
    .filter(([bloco]) => bloco !== '__geral__')
    .map(([bloco, defs]) => ({ bloco, defs }));
});

const ultimoEnvioPorBloco = computed(() => {
  const mapa = {};
  historico.value
    .filter(r => r.formulario_tipo === 'progressao_fase' && r.etapa === transicao.value)
    .forEach(r => {
      // histórico já vem ordenado enviado_em desc — a primeira ocorrência de
      // cada bloco é a mais recente.
      if (!mapa[r.bloco]) mapa[r.bloco] = r;
    });
  return mapa;
});

const carregarPaciente = async () => {
  const supabase = getFocohSupabaseClient();
  if (!supabase) return;

  isLoadingPaciente.value = true;
  erroPaciente.value = null;

  try {
    await obterFocohToken();
    const { data, error } = await supabase
      .from('pacientes')
      .select('id, nome, fase, programa')
      .eq('id', pacienteId)
      .single();

    if (error) throw error;
    paciente.value = data;
  } catch (error) {
    erroPaciente.value = error;
  } finally {
    isLoadingPaciente.value = false;
  }
};

const onEnviarBloco = async (bloco, { respostas, resultado }) => {
  const { ok, error } = await enviarResposta({
    pacienteId,
    formularioTipo: 'progressao_fase',
    etapa: transicao.value,
    bloco,
    dataReferencia: new Date().toISOString().slice(0, 10),
    respostas,
    resultado: BLOCOS_COM_DECISAO.has(bloco) ? resultado : (resultado ?? null),
  });

  if (ok) {
    useAlert(t('FOCOH_KANBAN.PROGRESSAO.ENVIADO'));
    await carregarHistorico(pacienteId);
  } else {
    useAlert(error?.message ?? t('FOCOH_KANBAN.BLOCO.ENVIAR'));
  }
};

onMounted(async () => {
  await carregarPaciente();
  if (transicao.value) {
    await carregarDefinicoes('progressao_fase', {
      programa: paciente.value.programa,
      etapa: transicao.value,
    });
  }
  await carregarHistorico(pacienteId);
});
</script>

<template>
  <section class="flex flex-col w-full h-full gap-6 p-6 overflow-y-auto bg-n-surface-1">
    <div v-if="isLoadingPaciente" class="flex items-center justify-center flex-1">
      <Spinner :size="24" />
    </div>

    <template v-else-if="paciente">
      <header class="flex items-start justify-between gap-4">
        <div>
          <h1 class="text-heading-1 text-n-slate-12">
            {{ t('FOCOH_KANBAN.PROGRESSAO.TITULO') }}
          </h1>
          <p class="mt-1 text-body-main text-n-slate-11">
            {{ t('FOCOH_KANBAN.PROGRESSAO.SUBTITULO', { nome: paciente.nome, transicao }) }}
          </p>
        </div>
        <div class="flex items-center gap-2 shrink-0">
          <Button
            :label="t('FOCOH_KANBAN.HISTORICO.TITULO')"
            variant="ghost"
            size="sm"
            icon="i-lucide-history"
            @click="abrirHistorico"
          />
          <Button
            :label="t('FOCOH_KANBAN.RISCO.TITULO')"
            variant="outline"
            size="sm"
            icon="i-lucide-shield-alert"
            @click="abrirAvaliacaoRisco"
          />
        </div>
      </header>

      <p v-if="!transicao" class="text-body-main text-n-slate-11">
        {{ t('FOCOH_KANBAN.PROGRESSAO.SEM_TRANSICAO') }}
      </p>

      <div v-else-if="isLoadingDefinicoes" class="flex items-center justify-center flex-1">
        <Spinner :size="24" />
      </div>

      <div v-else class="flex flex-col gap-4">
        <FocohBlocoFormulario
          v-for="{ bloco, defs } in blocos"
          :key="bloco"
          :titulo="t(BLOCO_TITULO[bloco] ?? bloco)"
          :definicoes="defs"
          :com-decisao="BLOCOS_COM_DECISAO.has(bloco)"
          :is-submitting="isSubmitting"
          :ultimo-envio="ultimoEnvioPorBloco[bloco]"
          @enviar="payload => onEnviarBloco(bloco, payload)"
        />
      </div>
    </template>
  </section>
</template>
