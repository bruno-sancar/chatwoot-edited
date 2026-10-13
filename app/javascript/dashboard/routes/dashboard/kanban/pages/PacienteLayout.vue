<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { getFocohSupabaseClient, obterFocohToken } from '../focohSupabaseClient';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();
const pacienteId = route.params.pacienteId;

const paciente = ref(null);
const ultimaAvaliacaoRisco = ref(null);
const isLoading = ref(true);
const contatoChatwoot = ref(null);

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

const rotaAtiva = computed(() => route.name);

const NAV_ITEMS = [
  { routeName: 'kanban_clinico_historico_paciente', icon: 'i-lucide-history',       labelKey: 'FOCOH_KANBAN.HISTORICO.TITULO' },
  { routeName: 'kanban_clinico_progressao_fase',    icon: 'i-lucide-git-branch-plus', labelKey: 'FOCOH_KANBAN.PROGRESSAO.TITULO_CURTO' },
  { routeName: 'kanban_clinico_laudo_semanal',      icon: 'i-lucide-file-text',      labelKey: 'FOCOH_KANBAN.LAUDO.TITULO' },
  { routeName: 'kanban_clinico_avaliacao_risco',    icon: 'i-lucide-shield-alert',   labelKey: 'FOCOH_KANBAN.RISCO.TITULO_CURTO' },
  { routeName: 'kanban_clinico_ficha_admissao',     icon: 'i-lucide-clipboard-list', labelKey: 'FOCOH_KANBAN.ADMISSAO.TITULO_CURTO' },
];

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

onMounted(async () => {
  const supabase = getFocohSupabaseClient();
  if (!supabase) { isLoading.value = false; return; }

  await obterFocohToken();

  const [{ data: pac }, { data: riscos }] = await Promise.all([
    supabase
      .from('pacientes')
      .select('id, nome, fase, programa, data_admissao, chatwoot_conversation_id')
      .eq('id', pacienteId)
      .single(),
    supabase
      .from('respostas_formulario')
      .select('resultado, enviado_em')
      .eq('paciente_id', pacienteId)
      .eq('formulario_tipo', 'avaliacao_risco')
      .order('enviado_em', { ascending: false })
      .limit(1),
  ]);

  paciente.value = pac;
  ultimaAvaliacaoRisco.value = riscos?.[0] ?? null;
  isLoading.value = false;

  if (pac?.chatwoot_conversation_id) {
    try {
      const conversa = await store.dispatch('conversations/show', {
        id: pac.chatwoot_conversation_id,
      });
      if (conversa?.meta?.sender) {
        contatoChatwoot.value = conversa.meta.sender;
      }
    } catch {
      // silent — link fica disponível mesmo sem metadados do contato
    }
  }
});
</script>

<template>
  <div class="flex w-full h-full overflow-hidden">
    <!-- Center: active page via router-view -->
    <main class="flex-1 min-w-0 overflow-hidden">
      <router-view />
    </main>

    <!-- Right panel: patient info + nav + links -->
    <aside
      class="w-64 shrink-0 flex flex-col border-l border-n-weak bg-n-solid-1 overflow-y-auto"
    >
      <div v-if="isLoading" class="flex items-center justify-center flex-1 py-12">
        <Spinner :size="20" />
      </div>

      <template v-else-if="paciente">
        <!-- Patient info -->
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
            v-for="item in NAV_ITEMS"
            :key="item.routeName"
            type="button"
            class="flex items-center gap-2 px-3 py-2 rounded-lg text-body-sm transition-colors text-left w-full"
            :class="rotaAtiva === item.routeName
              ? 'bg-n-surface-2 text-n-slate-12 font-medium'
              : 'text-n-slate-11 hover:bg-n-surface-2'"
            @click="navegar(item.routeName)"
          >
            <span :class="[item.icon, 'w-4 h-4 shrink-0']" />
            {{ t(item.labelKey) }}
          </button>
        </nav>

        <!-- Conversation + contact links -->
        <div class="mt-auto border-t border-n-weak p-4 flex flex-col gap-3">
          <button
            v-if="paciente.chatwoot_conversation_id"
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

          <div v-else class="flex items-center gap-2 px-3 py-2 text-label-small text-n-slate-10">
            <span class="i-lucide-message-circle size-4 shrink-0" />
            {{ t('FOCOH_KANBAN.PAINEL.SEM_CONVERSA') }}
          </div>
        </div>
      </template>
    </aside>
  </div>
</template>
