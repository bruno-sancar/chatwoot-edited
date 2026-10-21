<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import FocohBlocoFormulario from '../components/FocohBlocoFormulario.vue';
import FocohNavegacaoPaciente from '../components/FocohNavegacaoPaciente.vue';
import { useFocohFormularios } from '../composables/useFocohFormularios';
import { getFocohSupabaseClient, obterFocohToken } from '../focohSupabaseClient';

const { t } = useI18n();
const store = useStore();
const currentUserName = () => store.getters['auth/getCurrentUser']?.name ?? '';
const route = useRoute();
const pacienteId = route.params.pacienteId;

const BLOCO_TITULO = {
  historico_clinico: 'FOCOH_KANBAN.ADMISSAO.BLOCO_HISTORICO_CLINICO',
  rede_apoio:        'FOCOH_KANBAN.ADMISSAO.BLOCO_REDE_APOIO',
};

const paciente = ref(null);
const isLoadingPaciente = ref(true);
const blocoEnviadoNestaVisita = ref(new Set());
const salvandoIdentificacao = ref(false);

// Composable para aba_bc (histórico clínico + rede de apoio) — grava em respostas_formulario
const {
  definicoes: definicoesBC,
  isLoadingDefinicoes: isLoadingBC,
  carregarDefinicoes: carregarBC,
  definicoesPorBloco,
  isSubmitting,
  enviarResposta,
  historico,
  carregarHistorico,
} = useFocohFormularios();

// Composable separado para aba_a (identificação) — dados_cadastrais do paciente
const {
  definicoes: definicoesA,
  isLoadingDefinicoes: isLoadingA,
  carregarDefinicoes: carregarA,
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
    .filter(r => r.formulario_tipo === 'admissao' && r.etapa === 'aba_bc')
    .forEach(r => {
      if (!mapa[r.bloco]) mapa[r.bloco] = r;
    });
  return mapa;
});

// Valores da Identificação pré-preenchidos com dados_cadastrais do paciente
const valoresIdentificacao = computed(() => paciente.value?.dados_cadastrais ?? {});

const carregarPaciente = async () => {
  const supabase = getFocohSupabaseClient();
  if (!supabase) return;
  isLoadingPaciente.value = true;
  try {
    await obterFocohToken();
    const { data } = await supabase
      .from('pacientes')
      .select('id, nome, programa, dados_cadastrais')
      .eq('id', pacienteId)
      .single();
    paciente.value = data;
  } finally {
    isLoadingPaciente.value = false;
  }
};

// Salva edições de identificação de volta em pacientes.dados_cadastrais
const onEnviarIdentificacao = async ({ respostas }) => {
  const supabase = getFocohSupabaseClient();
  if (!supabase) return;
  salvandoIdentificacao.value = true;
  try {
    const porChave = Object.fromEntries(
      respostas.map(({ definicao, valor }) => [definicao.campo_chave, valor])
    );
    const { nome, ...dadosCadastrais } = porChave;
    const updateData = { dados_cadastrais: dadosCadastrais };
    if (nome) updateData.nome = nome;
    const { error } = await supabase
      .from('pacientes')
      .update(updateData)
      .eq('id', pacienteId);
    if (error) throw error;
    paciente.value = { ...paciente.value, nome: nome ?? paciente.value.nome, dados_cadastrais: dadosCadastrais };
    useAlert(t('FOCOH_KANBAN.ADMISSAO.BLOCO_ENVIADO'));
  } catch (err) {
    useAlert(err?.message ?? t('FOCOH_KANBAN.BLOCO.ENVIAR'));
  } finally {
    salvandoIdentificacao.value = false;
  }
};

const onEnviarBloco = async (bloco, { respostas }) => {
  const { ok, error } = await enviarResposta({
    pacienteId,
    formularioTipo: 'admissao',
    etapa: 'aba_bc',
    bloco,
    dataReferencia: new Date().toISOString().slice(0, 10),
    respostas,
    autorNome: currentUserName(),
  });

  if (ok) {
    useAlert(t('FOCOH_KANBAN.ADMISSAO.BLOCO_ENVIADO'));
    blocoEnviadoNestaVisita.value = new Set([...blocoEnviadoNestaVisita.value, bloco]);
    await carregarHistorico(pacienteId);
  } else {
    useAlert(error?.message ?? t('FOCOH_KANBAN.BLOCO.ENVIAR'));
  }
};

onMounted(async () => {
  await carregarPaciente();
  await Promise.all([
    carregarA('admissao', { etapa: 'aba_a' }),
    carregarBC('admissao', { programa: paciente.value?.programa, etapa: 'aba_bc' }),
    carregarHistorico(pacienteId),
  ]);
});
</script>

<template>
  <section class="flex flex-col w-full h-full bg-n-surface-1">
    <div class="flex-1 overflow-y-auto p-6 flex flex-col gap-6">
      <div v-if="isLoadingPaciente" class="flex items-center justify-center flex-1">
        <Spinner :size="24" />
      </div>

      <template v-else-if="paciente">
        <header>
          <h1 class="text-heading-1 text-n-slate-12">
            {{ t('FOCOH_KANBAN.ADMISSAO.TITULO_COMPLEMENTAR') }}
          </h1>
          <p class="mt-1 text-body-main text-n-slate-11">
            {{ t('FOCOH_KANBAN.ADMISSAO.SUBTITULO_COMPLEMENTAR', { nome: paciente.nome }) }}
          </p>
        </header>

        <div v-if="isLoadingA || isLoadingBC" class="flex items-center justify-center flex-1">
          <Spinner :size="24" />
        </div>

        <div v-else class="flex flex-col gap-4">
          <!-- Seção A: Identificação — pré-preenchida com dados_cadastrais -->
          <FocohBlocoFormulario
            v-if="definicoesA.length"
            :titulo="t('FOCOH_KANBAN.ADMISSAO.ABA_A')"
            :definicoes="definicoesA"
            :valores-iniciais="valoresIdentificacao"
            :is-submitting="salvandoIdentificacao"
            @enviar="onEnviarIdentificacao"
          />

          <!-- Seções B/C: Histórico Clínico, Rede de Apoio -->
          <FocohBlocoFormulario
            v-for="{ bloco, defs } in blocos"
            :key="bloco"
            :titulo="t(BLOCO_TITULO[bloco] ?? bloco)"
            :definicoes="defs"
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
