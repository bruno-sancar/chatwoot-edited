<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { useFocohFormularios } from '../composables/useFocohFormularios';
import { getFocohSupabaseClient, obterFocohToken } from '../focohSupabaseClient';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();
const pacienteId = route.params.pacienteId;

const paciente = ref(null);
const ultimaAvaliacaoRisco = ref(null);
const laudosSemana = ref([]);
const isLoading = ref(true);
const contatoChatwoot = ref(null);

const { historico, carregarHistorico } = useFocohFormularios();

const FASE_LABEL = {
  admissao_triagem: 'Admissão',
  fase1_autocritica: 'F1',
  fase2_disciplina: 'F2',
  fase3_empatia: 'F3',
  fase4_identidade: 'F4',
  alta_hospitalar: 'Alta Hosp.',
  alta_transicao: 'Transição',
  transicao_amanda: 'AMANDA',
};

const FASE_COR = {
  admissao_triagem: 'bg-n-slate-3 text-n-slate-11',
  fase1_autocritica: 'bg-n-blue-3 text-n-blue-11',
  fase2_disciplina: 'bg-n-teal-3 text-n-teal-11',
  fase3_empatia: 'bg-n-amber-3 text-n-amber-11',
  fase4_identidade: 'bg-n-violet-3 text-n-violet-11',
  alta_hospitalar: 'bg-n-teal-3 text-n-teal-11',
  alta_transicao: 'bg-n-slate-3 text-n-slate-11',
  transicao_amanda: 'bg-n-slate-3 text-n-slate-11',
};

const RISCO_COR = {
  baixo: 'bg-n-teal-3 text-n-teal-11',
  moderado: 'bg-n-amber-3 text-n-amber-11',
  alto: 'bg-n-ruby-3 text-n-ruby-11',
};


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
const getMondayThisWeek = () => {
  const d = new Date();
  const day = d.getDay();
  const diff = d.getDate() - day + (day === 0 ? -6 : 1);
  d.setDate(diff);
  return d.toISOString().slice(0, 10);
};

const diasInternado = computed(() => {
  if (!paciente.value?.data_admissao) return null;
  const diff = Date.now() - new Date(paciente.value.data_admissao).getTime();
  return Math.floor(diff / 86400000);
});

const riscoCor = computed(() => RISCO_COR[ultimaAvaliacaoRisco.value?.resultado] ?? '');

const riscoLabel = computed(() => {
  const r = ultimaAvaliacaoRisco.value?.resultado;
  return r ? t(`FOCOH_KANBAN.HISTORICO.RESULTADO.${r}`) : null;
});

const laudosPorBloco = computed(() => {
  return ['clinico', 'terapeutico', 'disciplinar'].map(bloco => {
    const laudo = laudosSemana.value.find(l => l.tipo === bloco);
    return {
      bloco,
      resultado: laudo ? (laudo.aprovado ? 'apto' : 'nao_apto') : null,
    };
  });
});

const historicoRecente = computed(() => historico.value.slice(0, 6));

const navegar = routeName => {
  router.push({ name: routeName, params: { accountId: route.params.accountId, pacienteId } });
};

const voltarKanban = () => {
  router.push({ name: 'kanban_clinico_index', params: { accountId: route.params.accountId } });
};

const abrirConversa = () => {
  if (!paciente.value?.chatwoot_conversation_id) return;
  router.push({
    name: 'inbox_conversation',
    params: {
      accountId: route.params.accountId,
      conversation_id: paciente.value.chatwoot_conversation_id,
    },
  });
};

const corResultadoHistorico = resultado => {
  if (resultado === 'apto' || resultado === 'baixo') return 'bg-n-teal-3 text-n-teal-11';
  if (resultado === 'nao_apto' || resultado === 'alto') return 'bg-n-ruby-3 text-n-ruby-11';
  return 'bg-n-amber-3 text-n-amber-11';
};

onMounted(async () => {
  const supabase = getFocohSupabaseClient();
  if (!supabase) { isLoading.value = false; return; }

  await obterFocohToken();

  const [{ data: pac }, { data: riscos }, { data: laudos }] = await Promise.all([
    supabase
      .from('pacientes')
      .select('id, nome, fase, programa, data_admissao')
      .eq('id', pacienteId)
      .single(),
    supabase
      .from('respostas_formulario')
      .select('resultado, enviado_em')
      .eq('paciente_id', pacienteId)
      .eq('formulario_tipo', 'avaliacao_risco')
      .order('enviado_em', { ascending: false })
      .limit(1),
    supabase
      .from('laudos_semanais')
      .select('tipo, aprovado')
      .eq('paciente_id', pacienteId)
      .eq('semana_ref', getMondayThisWeek()),
  ]);

  paciente.value = pac;
  ultimaAvaliacaoRisco.value = riscos?.[0] ?? null;
  laudosSemana.value = laudos ?? [];
  isLoading.value = false;

  carregarHistorico(pacienteId);

  if (pac?.chatwoot_conversation_id) {
    try {
      const conversa = await store.dispatch('conversations/show', {
        id: pac.chatwoot_conversation_id,
      });
      if (conversa?.meta?.sender) {
        contatoChatwoot.value = conversa.meta.sender;
      }
    } catch {
      // silent â€” link fica disponÃ­vel mesmo sem metadados do contato
    }
  }
});
</script>

<template>
  <div class="flex w-full h-full overflow-hidden">
    <!-- Left sidebar: patient info + nav -->
    <aside
      class="w-52 shrink-0 flex flex-col border-r border-n-weak bg-n-solid-1 overflow-y-auto"
    >
      <div v-if="isLoading" class="flex items-center justify-center flex-1">
        <Spinner :size="20" />
      </div>

      <template v-else-if="paciente">
        <!-- Patient card -->
        <div class="p-4 flex flex-col gap-3 border-b border-n-weak">
          <button
            type="button"
            class="flex items-center gap-1.5 text-label-small text-n-slate-10 hover:text-n-slate-12 transition-colors self-start"
            @click="voltarKanban"
          >
            <span class="i-lucide-arrow-left w-3 h-3" />
            {{ t('FOCOH_KANBAN.PAINEL.VOLTAR_KANBAN') }}
          </button>

          <div>
            <p class="text-heading-3 text-n-slate-12 leading-snug break-words">
              {{ paciente.nome }}
            </p>
          </div>

          <div class="flex flex-wrap gap-1">
            <span
              class="rounded-full px-2 py-0.5 text-label-small font-medium"
              :class="FASE_COR[paciente.fase] ?? 'bg-n-slate-3 text-n-slate-11'"
            >
              {{ FASE_LABEL[paciente.fase] ?? paciente.fase }}
            </span>
            <span
              v-if="riscoLabel"
              class="rounded-full px-2 py-0.5 text-label-small font-medium"
              :class="riscoCor"
            >
              {{ riscoLabel }}
            </span>
          </div>

          <p v-if="diasInternado !== null" class="text-label-small text-n-slate-10">
            {{ t('KANBAN.CARD.DIAS_INTERNADO', diasInternado, { n: diasInternado }) }}
          </p>
        </div>

        <!-- Navigation -->
        <nav class="flex flex-col gap-0.5 p-2">
          <button
            type="button"
            class="flex items-center gap-2 px-3 py-2 rounded-lg text-body-sm text-n-slate-11 hover:bg-n-surface-2 transition-colors text-left w-full"
            @click="navegar('kanban_clinico_progressao_fase')"
          >
            <span class="i-lucide-git-branch-plus w-4 h-4 shrink-0" />
            {{ t('FOCOH_KANBAN.PROGRESSAO.TITULO_CURTO') }}
          </button>
          <button
            type="button"
            class="flex items-center gap-2 px-3 py-2 rounded-lg text-body-sm text-n-slate-11 hover:bg-n-surface-2 transition-colors text-left w-full"
            @click="navegar('kanban_clinico_laudo_semanal')"
          >
            <span class="i-lucide-file-text w-4 h-4 shrink-0" />
            {{ t('FOCOH_KANBAN.LAUDO.TITULO') }}
          </button>
          <button
            type="button"
            class="flex items-center gap-2 px-3 py-2 rounded-lg text-body-sm text-n-slate-11 hover:bg-n-surface-2 transition-colors text-left w-full"
            @click="navegar('kanban_clinico_avaliacao_risco')"
          >
            <span class="i-lucide-shield-alert w-4 h-4 shrink-0" />
            {{ t('FOCOH_KANBAN.RISCO.TITULO_CURTO') }}
          </button>
          <button
            type="button"
            class="flex items-center gap-2 px-3 py-2 rounded-lg text-body-sm text-n-slate-11 hover:bg-n-surface-2 transition-colors text-left w-full"
            @click="navegar('kanban_clinico_ficha_admissao')"
          >
            <span class="i-lucide-clipboard-list w-4 h-4 shrink-0" />
            {{ t('FOCOH_KANBAN.ADMISSAO.TITULO_CURTO') }}
          </button>
          <button
            type="button"
            class="flex items-center gap-2 px-3 py-2 rounded-lg text-body-sm text-n-slate-11 hover:bg-n-surface-2 transition-colors text-left w-full"
            @click="navegar('kanban_clinico_historico_paciente')"
          >
            <span class="i-lucide-history w-4 h-4 shrink-0" />
            {{ t('FOCOH_KANBAN.HISTORICO.TITULO') }}
          </button>
        </nav>
      </template>
    </aside>

    <!-- Center: active page via router-view; children manage their own scroll -->
    <main class="flex-1 min-w-0 overflow-hidden">
      <router-view />
    </main>

    <!-- Right sidebar: contato Chatwoot + laudos da semana + histÃ³rico recente -->
    <aside
      class="w-72 shrink-0 flex flex-col border-l border-n-weak bg-n-solid-1 overflow-y-auto"
    >
      <!-- Contato Chatwoot vinculado -->
      <div
        v-if="paciente?.chatwoot_conversation_id"
        class="p-4 border-b border-n-weak"
      >
        <p class="text-label-small font-medium text-n-slate-10 uppercase tracking-wide mb-2">
          {{ t('FOCOH_KANBAN.PAINEL.CONTATO_CHATWOOT') }}
        </p>
        <button
          type="button"
          class="w-full flex items-center justify-between gap-2 px-3 py-2 rounded-lg border border-n-weak hover:bg-n-surface-2 transition-colors text-left"
          @click="abrirConversa"
        >
          <div class="flex items-center gap-2 min-w-0">
            <span class="i-lucide-message-circle size-4 text-n-slate-11 shrink-0" />
            <div class="min-w-0">
              <p class="text-body-sm font-medium text-n-slate-12 truncate">
                {{ contatoChatwoot?.name || t('FOCOH_KANBAN.PAINEL.VER_CONVERSA') }}
              </p>
              <p v-if="contatoChatwoot?.phone_number" class="text-label-small text-n-slate-10 truncate">
                {{ contatoChatwoot.phone_number }}
              </p>
            </div>
          </div>
          <span class="i-lucide-arrow-up-right size-4 text-n-slate-10 shrink-0" />
        </button>
      </div>

      <!-- Laudos semanais status -->
      <div class="p-4 border-b border-n-weak">
        <p class="text-label-small font-medium text-n-slate-10 uppercase tracking-wide mb-3">
          {{ t('FOCOH_KANBAN.PAINEL.LAUDOS_SEMANA') }}
        </p>
        <div class="flex flex-col gap-2">
          <div
            v-for="{ bloco, resultado } in laudosPorBloco"
            :key="bloco"
            class="flex items-center justify-between gap-2"
          >
            <span class="text-body-sm text-n-slate-11">
              {{ t(`FOCOH_KANBAN.PAINEL.BLOCO_${bloco.toUpperCase()}`) }}
            </span>
            <span
              class="rounded-full px-2 py-0.5 text-label-small shrink-0"
              :class="
                resultado === 'apto'
                  ? 'bg-n-teal-3 text-n-teal-11'
                  : resultado === 'nao_apto'
                    ? 'bg-n-ruby-3 text-n-ruby-11'
                    : 'bg-n-slate-3 text-n-slate-10'
              "
            >
              {{
                resultado
                  ? t(`FOCOH_KANBAN.HISTORICO.RESULTADO.${resultado}`)
                  : t('FOCOH_KANBAN.PAINEL.PENDENTE')
              }}
            </span>
          </div>
        </div>
      </div>

      <!-- HistÃ³rico recente -->
      <div class="p-4 flex flex-col gap-3">
        <p class="text-label-small font-medium text-n-slate-10 uppercase tracking-wide">
          {{ t('FOCOH_KANBAN.PAINEL.HISTORICO_RECENTE') }}
        </p>

        <p v-if="!historicoRecente.length" class="text-body-sm text-n-slate-10">
          {{ t('FOCOH_KANBAN.HISTORICO.VAZIO') }}
        </p>

        <ol v-else class="flex flex-col gap-3">
          <li
            v-for="envio in historicoRecente"
            :key="envio.id"
            class="flex items-start gap-2"
          >
            <div class="mt-1.5 w-1.5 h-1.5 rounded-full bg-n-slate-7 shrink-0" />
            <div class="min-w-0 flex-1">
              <p class="text-body-sm text-n-slate-12 leading-snug">
                {{ TIPO_FORMULARIO_LABEL[envio.formulario_tipo] ?? envio.formulario_tipo }}
                <template v-if="envio.bloco"> &middot; {{ BLOCO_LABEL[envio.bloco] ?? envio.bloco }}</template>
              </p>
              <div class="flex items-center gap-1.5 mt-0.5 flex-wrap">
                <span v-if="envio.autor_nome" class="text-label-small text-n-slate-10">
                  {{ envio.autor_nome }} ·
                </span>
                <span class="text-label-small text-n-slate-10">
                  {{ new Date(envio.enviado_em).toLocaleDateString('pt-BR') }}
                </span>
                <span
                  v-if="envio.resultado"
                  class="rounded-full px-1.5 py-0.5 text-label-small"
                  :class="corResultadoHistorico(envio.resultado)"
                >
                  {{ t(`FOCOH_KANBAN.HISTORICO.RESULTADO.${envio.resultado}`) }}
                </span>
              </div>
            </div>
          </li>
        </ol>

        <button
          v-if="historico.length > 6"
          type="button"
          class="text-label-small text-n-blue-11 hover:underline text-left"
          @click="navegar('kanban_clinico_historico_paciente')"
        >
          {{ t('FOCOH_KANBAN.PAINEL.VER_HISTORICO_COMPLETO') }}
        </button>
      </div>
    </aside>
  </div>
</template>

