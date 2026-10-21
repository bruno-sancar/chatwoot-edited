<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useStore } from 'vuex';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import { getFocohSupabaseClient, obterFocohToken } from '../focohSupabaseClient';

const route = useRoute();
const router = useRouter();
const store = useStore();

// Papel → coluna de atribuição no Supabase
const PAPEL_COLUNA = {
  medico_psiquiatra: 'medico_responsavel_chatwoot_id',
  psicologo: 'psicologo_gerente_caso_chatwoot_id',
  coordenacao_tecnica: 'psicologo_gerente_caso_chatwoot_id',
};

// --- Estado ---
const isLoading = ref(true);
const erro = ref(null);
const papeisAtuais = ref([]);
const nomeAtual = ref(null);
const atividades = ref([]);

// Papel principal (primeiro) — mantido para compatibilidade com template.
const papelAtual = computed(() => papeisAtuais.value[0] ?? null);

// --- Papel → tipo de laudo ---
const PAPEL_LAUDO = {
  medico_psiquiatra:   'clinico',
  psicologo:           'terapeutico',
  coordenacao_tecnica: 'disciplinar',
  diretor_geral:       'disciplinar',
};

const PAPEL_LABEL = {
  medico_psiquiatra:   'Médico Psiquiatra',
  psicologo:           'Psicólogo',
  enfermeiro_rt:       'Enfermeiro RT',
  coordenacao_tecnica: 'Coordenação Técnica',
  diretor_geral:       'Diretor Geral',
  gerente_familias:    'Gerente de Famílias',
  recepcao:            'Recepção',
};

const LAUDO_LABEL = {
  clinico:     'Laudo Clínico',
  terapeutico: 'Laudo Terapêutico',
  disciplinar: 'Laudo Disciplinar',
};

const FASE_LABEL = {
  admissao_triagem:  'Admissão',
  fase1_autocritica: 'F1 – Autocrítica',
  fase2_disciplina:  'F2 – Disciplina',
  fase3_empatia:     'F3 – Empatia',
  fase4_identidade:  'F4 – Identidade',
  alta_hospitalar:   'Alta Hospitalar',
  transicao_amanda:  'Transição AMANDA',
  alta_transicao:    'Alta Pós-Detox',
};

// Tipos de laudo únicos derivados de todos os papéis ativos.
const tiposLaudo = computed(() =>
  [...new Set(papeisAtuais.value.map(r => PAPEL_LAUDO[r]).filter(Boolean))]
);
const tipoLaudo = computed(() => tiposLaudo.value[0] ?? null);
const laudoLabel = computed(() => {
  const labels = tiposLaudo.value.map(t => LAUDO_LABEL[t]).filter(Boolean);
  return labels.length ? labels.join(', ') : null;
});

const semDeAtividades = computed(() =>
  papeisAtuais.value.length > 0 &&
  tiposLaudo.value.length === 0 &&
  papeisAtuais.value.every(r => ['recepcao', 'enfermeiro_rt', 'gerente_familias'].includes(r))
);

// Segunda-feira da semana atual (ISO: seg a dom)
function semanaAtualRef() {
  const hoje = new Date();
  const diaSemana = hoje.getDay() === 0 ? 7 : hoje.getDay();
  const seg = new Date(hoje);
  seg.setDate(hoje.getDate() - diaSemana + 1);
  return seg.toISOString().split('T')[0];
}

function decodeJwtPayload(token) {
  try {
    const base64 = token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
    return JSON.parse(atob(base64));
  } catch {
    return null;
  }
}

const carregarAtividades = async () => {
  const supabase = getFocohSupabaseClient();
  if (!supabase) { isLoading.value = false; return; }

  isLoading.value = true;
  erro.value = null;

  try {
    const token = await obterFocohToken();
    const payload = decodeJwtPayload(token);
    // Lê `roles` (array, FOCO-105) com fallback para `role` (string legado).
    const roles = payload?.app_metadata?.roles ??
      (payload?.app_metadata?.role ? [payload.app_metadata.role] : []);
    papeisAtuais.value = roles;
    nomeAtual.value = payload?.user_metadata?.name ?? null;

    const tipos = [...new Set(roles.map(r => PAPEL_LAUDO[r]).filter(Boolean))];
    if (!tipos.length) { isLoading.value = false; return; }

    const semana = semanaAtualRef();

    // Determina coluna de filtro com base no papel (primeiro papel com coluna mapeada)
    const currentAgentId = store.getters['auth/getCurrentUser']?.id ?? null;
    const papelComColuna = roles.find(r => PAPEL_COLUNA[r]);
    const colunaFiltro = papelComColuna ? PAPEL_COLUNA[papelComColuna] : null;

    // 1. Pacientes não-arquivados, filtrados por profissional responsável quando aplicável
    let query = supabase
      .from('pacientes')
      .select('id, nome, fase, programa')
      .eq('arquivado', false)
      .order('nome');
    if (colunaFiltro && currentAgentId) {
      query = query.eq(colunaFiltro, currentAgentId);
    }
    const { data: pacientes, error: errPac } = await query;
    if (errPac) throw errPac;

    // 2. Laudos já entregues esta semana para todos os tipos do profissional
    const ids = (pacientes ?? []).map(p => p.id);
    let laudosEntregues = [];
    if (ids.length) {
      const { data: laudos, error: errL } = await supabase
        .from('laudos_semanais')
        .select('paciente_id, tipo, aprovado')
        .in('tipo', tipos)
        .eq('semana_ref', semana)
        .in('paciente_id', ids);
      if (errL) throw errL;
      laudosEntregues = laudos ?? [];
    }

    // entreguesMap[paciente_id][tipo] = laudo
    const entreguesMap = {};
    for (const l of laudosEntregues) {
      if (!entreguesMap[l.paciente_id]) entreguesMap[l.paciente_id] = {};
      entreguesMap[l.paciente_id][l.tipo] = l;
    }

    atividades.value = (pacientes ?? [])
      .map(p => {
        const porTipo = entreguesMap[p.id] ?? {};
        const todosAprovados = tipos.every(t => porTipo[t]?.aprovado);
        const algumEntregue  = tipos.some(t => porTipo[t]);
        return {
          ...p,
          laudoStatus: todosAprovados ? 'aprovado'
            : algumEntregue ? 'pendente'
            : 'ausente',
        };
      })
      .filter(p => p.laudoStatus !== 'aprovado');
  } catch (e) {
    erro.value = e.message ?? 'Erro ao carregar atividades.';
  } finally {
    isLoading.value = false;
  }
};

const abrirLaudo = pacienteId => {
  router.push({
    name: 'kanban_clinico_laudo_semanal',
    params: { accountId: route.params.accountId, pacienteId },
  });
};

const voltarKanban = () => {
  router.push({
    name: 'kanban_clinico_index',
    params: { accountId: route.params.accountId },
  });
};

onMounted(carregarAtividades);
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-hidden bg-n-surface-1">
    <!-- Header -->
    <header class="px-6 py-5 border-b border-n-weak shrink-0">
      <button
        type="button"
        class="flex items-center gap-1.5 text-label-small text-n-slate-10 hover:text-n-slate-12 transition-colors mb-3"
        @click="voltarKanban"
      >
        <span class="i-lucide-arrow-left w-3 h-3" />
        Voltar ao Kanban
      </button>
      <div class="flex items-center justify-between gap-4">
        <div>
          <h1 class="text-heading-1 text-n-slate-12">Suas Atividades</h1>
          <p v-if="papeisAtuais.length" class="mt-1 text-body-main text-n-slate-11">
            {{ papeisAtuais.map(r => PAPEL_LABEL[r] ?? r).join(', ') }}
            <span v-if="nomeAtual"> · {{ nomeAtual }}</span>
          </p>
        </div>
        <button
          type="button"
          class="p-2 rounded-lg hover:bg-n-surface-2 text-n-slate-10 hover:text-n-slate-12 transition-colors"
          title="Atualizar"
          @click="carregarAtividades"
        >
          <span class="i-lucide-refresh-cw w-4 h-4" />
        </button>
      </div>
    </header>

    <!-- Body -->
    <div class="flex-1 overflow-y-auto p-6">

      <!-- Loading -->
      <div v-if="isLoading" class="flex items-center justify-center py-20">
        <Spinner :size="28" />
      </div>

      <!-- Erro -->
      <div v-else-if="erro" class="p-4 rounded-xl bg-n-ruby-2 border border-n-ruby-6 text-body-main text-n-ruby-11">
        {{ erro }}
      </div>

      <!-- Papel sem laudos (recepção, enfermeiro, gerente) -->
      <div v-else-if="semDeAtividades" class="flex flex-col items-center justify-center py-20 gap-3 text-n-slate-10">
        <span class="i-lucide-check-circle text-4xl text-n-teal-9" />
        <p class="text-body-main">Nenhuma atividade pendente para o seu papel.</p>
      </div>

      <!-- Papel sem atribuição (token sem papel) -->
      <div v-else-if="!papeisAtuais.length" class="p-4 rounded-xl bg-n-amber-2 border border-n-amber-6 text-body-main text-n-amber-11">
        Papel clínico não identificado. Verifique se o atributo <code>focoh_clinical_role</code> está configurado para o seu usuário.
      </div>

      <!-- Tudo em dia -->
      <div v-else-if="!atividades.length" class="flex flex-col items-center justify-center py-20 gap-3 text-n-slate-10">
        <span class="i-lucide-check-circle text-4xl text-n-teal-9" />
        <p class="text-body-main font-medium text-n-teal-11">Tudo em dia!</p>
        <p class="text-label-small text-center max-w-xs">
          Todos os {{ laudoLabel }}s desta semana já foram entregues.
        </p>
      </div>

      <!-- Lista de atividades -->
      <template v-else>
        <!-- Contexto da semana -->
        <div class="mb-4 flex items-center justify-between">
          <p class="text-body-sm text-n-slate-11">
            <span class="font-medium">{{ laudoLabel }}</span>
            — semana de
            <span class="font-medium">{{ new Date(semanaAtualRef() + 'T12:00:00').toLocaleDateString('pt-BR', { day: '2-digit', month: 'short' }) }}</span>
          </p>
          <span class="text-label-small text-n-slate-10 bg-n-amber-2 border border-n-amber-6 rounded-full px-2.5 py-0.5 text-n-amber-11 font-medium">
            {{ atividades.length }} pendente{{ atividades.length > 1 ? 's' : '' }}
          </span>
        </div>

        <!-- Nota sobre atribuição -->
        <div class="mb-5 p-3 rounded-lg bg-n-surface-2 border border-n-weak text-label-small text-n-slate-11 flex gap-2">
          <span class="i-lucide-info w-4 h-4 shrink-0 mt-0.5 text-n-slate-10" />
          <span>Exibindo pacientes sob sua responsabilidade sem laudo entregue esta semana.</span>
        </div>

        <ul class="flex flex-col gap-2">
          <li
            v-for="pac in atividades"
            :key="pac.id"
            class="flex items-center justify-between gap-3 px-4 py-3 rounded-xl border border-n-weak bg-n-solid-1 hover:bg-n-surface-2 transition-colors"
          >
            <div class="flex flex-col gap-0.5 min-w-0">
              <span class="text-body-sm font-medium text-n-slate-12 truncate">{{ pac.nome }}</span>
              <span class="text-label-small text-n-slate-10">
                {{ FASE_LABEL[pac.fase] ?? pac.fase }}
                <span
                  v-if="pac.laudoStatus === 'pendente'"
                  class="ml-2 text-n-amber-11 font-medium"
                >Entregue mas não aprovado</span>
              </span>
            </div>
            <Button
              label="Preencher"
              icon="i-lucide-edit-3"
              size="sm"
              variant="outline"
              color-scheme="secondary"
              @click="abrirLaudo(pac.id)"
            />
          </li>
        </ul>
      </template>

    </div>
  </section>
</template>
