<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useStore } from 'vuex';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import { getFocohSupabaseClient, obterFocohToken } from '../focohSupabaseClient';

const route = useRoute();
const router = useRouter();
const store = useStore();

const PAPEL_COLUNA = {
  medico_psiquiatra: 'medico_responsavel_chatwoot_id',
  psicologo: 'psicologo_gerente_caso_chatwoot_id',
  coordenacao_tecnica: 'psicologo_gerente_caso_chatwoot_id',
};

const TODOS_TIPOS_LAUDO = ['clinico', 'terapeutico', 'disciplinar'];

// --- Estado ---
const isLoading = ref(true);
const erro = ref(null);
const papeisAtuais = ref([]);
const nomeAtual = ref(null);
const atividades = ref([]);
const filtroStatus = ref('pendente'); // 'pendente' | 'aprovado' | 'todos'
const filtroVisao = ref('meu'); // 'meu' | 'equipe'

const papelAtual = computed(() => papeisAtuais.value[0] ?? null);

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

const tiposLaudo = computed(() =>
  [...new Set(papeisAtuais.value.map(r => PAPEL_LAUDO[r]).filter(Boolean))]
);
const tipoLaudo = computed(() => tiposLaudo.value[0] ?? null);
const laudoLabel = computed(() => {
  const labels = tiposLaudo.value.map(t => LAUDO_LABEL[t]).filter(Boolean);
  return labels.length ? labels.join(', ') : null;
});

const ehCoordenador = computed(() =>
  papeisAtuais.value.some(r => ['coordenacao_tecnica', 'diretor_geral'].includes(r))
);

const semDeAtividades = computed(() =>
  papeisAtuais.value.length > 0 &&
  tiposLaudo.value.length === 0 &&
  papeisAtuais.value.every(r => ['recepcao', 'enfermeiro_rt', 'gerente_familias'].includes(r))
);

const atividadesFiltradas = computed(() => {
  if (filtroStatus.value === 'pendente') {
    return atividades.value.filter(p => p.laudoStatus !== 'aprovado');
  }
  if (filtroStatus.value === 'aprovado') {
    return atividades.value.filter(p => p.laudoStatus === 'aprovado');
  }
  return atividades.value;
});

const totalPendentes = computed(() =>
  atividades.value.filter(p => p.laudoStatus !== 'aprovado').length
);

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
    const roles = payload?.app_metadata?.roles ??
      (payload?.app_metadata?.role ? [payload.app_metadata.role] : []);
    papeisAtuais.value = roles;
    nomeAtual.value = payload?.user_metadata?.name ?? null;

    const modoEquipe = filtroVisao.value === 'equipe';

    // Em modo equipe mostra todos os tipos; senão apenas os tipos do profissional
    const tipos = modoEquipe
      ? TODOS_TIPOS_LAUDO
      : [...new Set(roles.map(r => PAPEL_LAUDO[r]).filter(Boolean))];

    if (!tipos.length && !modoEquipe) { isLoading.value = false; return; }

    const semana = semanaAtualRef();
    const currentAgentId = store.getters['auth/getCurrentUser']?.id ?? null;

    let query = supabase
      .from('pacientes')
      .select('id, nome, fase, programa')
      .eq('arquivado', false)
      .order('nome');

    // Filtra por profissional responsável apenas no modo "meu"
    if (!modoEquipe) {
      const papelComColuna = roles.find(r => PAPEL_COLUNA[r]);
      const colunaFiltro = papelComColuna ? PAPEL_COLUNA[papelComColuna] : null;
      if (colunaFiltro && currentAgentId) {
        query = query.eq(colunaFiltro, currentAgentId);
      }
    }

    const { data: pacientes, error: errPac } = await query;
    if (errPac) throw errPac;

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

    const entreguesMap = {};
    for (const l of laudosEntregues) {
      if (!entreguesMap[l.paciente_id]) entreguesMap[l.paciente_id] = {};
      entreguesMap[l.paciente_id][l.tipo] = l;
    }

    atividades.value = (pacientes ?? []).map(p => {
      const porTipo = entreguesMap[p.id] ?? {};
      const todosAprovados = tipos.every(t => porTipo[t]?.aprovado);
      const algumEntregue  = tipos.some(t => porTipo[t]);
      const pendentesCount = tipos.filter(t => !porTipo[t]?.aprovado).length;
      return {
        ...p,
        laudoStatus: todosAprovados ? 'aprovado' : algumEntregue ? 'pendente' : 'ausente',
        pendentesCount,
        laudosPorTipo: tipos.map(t => ({
          tipo: t,
          label: LAUDO_LABEL[t],
          entregue: !!porTipo[t],
          aprovado: !!porTipo[t]?.aprovado,
        })),
      };
    });
  } catch (e) {
    erro.value = e.message ?? 'Erro ao carregar atividades.';
  } finally {
    isLoading.value = false;
  }
};

// Recarrega quando muda visão (precisa de nova query); status é só filtro local
watch(filtroVisao, carregarAtividades);

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

      <!-- Filtros -->
      <div v-if="papeisAtuais.length && !semDeAtividades" class="mt-4 flex flex-wrap items-center gap-3">
        <!-- Visão: Minhas / Equipe — apenas para coordenadores -->
        <div v-if="ehCoordenador" class="flex items-center gap-1 p-1 rounded-lg bg-n-surface-2 border border-n-weak">
          <button
            type="button"
            class="px-3 py-1.5 rounded-md text-label-small font-medium transition-colors"
            :class="filtroVisao === 'meu'
              ? 'bg-n-solid-1 text-n-slate-12 shadow-sm'
              : 'text-n-slate-10 hover:text-n-slate-12'"
            @click="filtroVisao = 'meu'"
          >
            <span class="i-lucide-user w-3.5 h-3.5 mr-1 inline-block align-middle" />
            Minhas
          </button>
          <button
            type="button"
            class="px-3 py-1.5 rounded-md text-label-small font-medium transition-colors"
            :class="filtroVisao === 'equipe'
              ? 'bg-n-solid-1 text-n-slate-12 shadow-sm'
              : 'text-n-slate-10 hover:text-n-slate-12'"
            @click="filtroVisao = 'equipe'"
          >
            <span class="i-lucide-users w-3.5 h-3.5 mr-1 inline-block align-middle" />
            Equipe
          </button>
        </div>

        <!-- Status filter -->
        <div class="flex items-center gap-1 p-1 rounded-lg bg-n-surface-2 border border-n-weak">
          <button
            type="button"
            class="px-3 py-1.5 rounded-md text-label-small font-medium transition-colors"
            :class="filtroStatus === 'pendente'
              ? 'bg-n-solid-1 text-n-slate-12 shadow-sm'
              : 'text-n-slate-10 hover:text-n-slate-12'"
            @click="filtroStatus = 'pendente'"
          >
            Pendentes
          </button>
          <button
            type="button"
            class="px-3 py-1.5 rounded-md text-label-small font-medium transition-colors"
            :class="filtroStatus === 'aprovado'
              ? 'bg-n-solid-1 text-n-slate-12 shadow-sm'
              : 'text-n-slate-10 hover:text-n-slate-12'"
            @click="filtroStatus = 'aprovado'"
          >
            Em dia
          </button>
          <button
            type="button"
            class="px-3 py-1.5 rounded-md text-label-small font-medium transition-colors"
            :class="filtroStatus === 'todos'
              ? 'bg-n-solid-1 text-n-slate-12 shadow-sm'
              : 'text-n-slate-10 hover:text-n-slate-12'"
            @click="filtroStatus = 'todos'"
          >
            Todos
          </button>
        </div>
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

      <!-- Nenhum resultado para o filtro selecionado -->
      <div v-else-if="!atividadesFiltradas.length" class="flex flex-col items-center justify-center py-20 gap-3 text-n-slate-10">
        <span class="i-lucide-check-circle text-4xl text-n-teal-9" />
        <p class="text-body-main font-medium text-n-teal-11">
          <template v-if="filtroStatus === 'pendente'">Tudo em dia!</template>
          <template v-else-if="filtroStatus === 'aprovado'">Nenhum laudo aprovado esta semana.</template>
          <template v-else>Nenhum paciente encontrado.</template>
        </p>
        <p v-if="filtroStatus === 'pendente'" class="text-label-small text-center max-w-xs">
          Todos os laudos desta semana já foram entregues.
        </p>
      </div>

      <!-- Lista de atividades -->
      <template v-else>
        <!-- Contexto da semana -->
        <div class="mb-4 flex items-center justify-between">
          <p class="text-body-sm text-n-slate-11">
            <span v-if="filtroVisao === 'equipe'" class="font-medium">Toda a equipe</span>
            <span v-else class="font-medium">{{ laudoLabel }}</span>
            — semana de
            <span class="font-medium">{{ new Date(semanaAtualRef() + 'T12:00:00').toLocaleDateString('pt-BR', { day: '2-digit', month: 'short' }) }}</span>
          </p>
          <span
            v-if="filtroStatus !== 'aprovado' && totalPendentes > 0"
            class="text-label-small text-n-amber-11 bg-n-amber-2 border border-n-amber-6 rounded-full px-2.5 py-0.5 font-medium"
          >
            {{ totalPendentes }} pendente{{ totalPendentes > 1 ? 's' : '' }}
          </span>
          <span
            v-else-if="filtroStatus === 'aprovado'"
            class="text-label-small text-n-teal-11 bg-n-teal-2 border border-n-teal-6 rounded-full px-2.5 py-0.5 font-medium"
          >
            {{ atividadesFiltradas.length }} em dia
          </span>
        </div>

        <!-- Nota contextual -->
        <div class="mb-5 p-3 rounded-lg bg-n-surface-2 border border-n-weak text-label-small text-n-slate-11 flex gap-2">
          <span class="i-lucide-info w-4 h-4 shrink-0 mt-0.5 text-n-slate-10" />
          <span v-if="filtroVisao === 'equipe'">
            Exibindo todos os pacientes internados. Tipos de laudo: Clínico, Terapêutico e Disciplinar.
          </span>
          <span v-else>
            Exibindo pacientes sob sua responsabilidade sem laudo entregue esta semana.
          </span>
        </div>

        <ul class="flex flex-col gap-2">
          <li
            v-for="pac in atividadesFiltradas"
            :key="pac.id"
            class="flex items-center justify-between gap-3 px-4 py-3 rounded-xl border border-n-weak bg-n-solid-1 hover:bg-n-surface-2 transition-colors"
          >
            <div class="flex flex-col gap-1 min-w-0">
              <div class="flex items-center gap-2">
                <span class="text-body-sm font-medium text-n-slate-12 truncate">{{ pac.nome }}</span>
                <span
                  v-if="pac.laudoStatus === 'aprovado'"
                  class="shrink-0 text-label-small text-n-teal-11 font-medium"
                >Em dia</span>
                <span
                  v-else-if="pac.laudoStatus === 'pendente'"
                  class="shrink-0 text-label-small text-n-amber-11 font-medium"
                >Parcial</span>
              </div>
              <span class="text-label-small text-n-slate-10">
                {{ FASE_LABEL[pac.fase] ?? pac.fase }}
              </span>
              <!-- Badges de tipos de laudo (modo equipe) -->
              <div v-if="filtroVisao === 'equipe'" class="flex flex-wrap gap-1 mt-0.5">
                <span
                  v-for="l in pac.laudosPorTipo"
                  :key="l.tipo"
                  class="text-label-small px-2 py-0.5 rounded-full border font-medium"
                  :class="l.aprovado
                    ? 'bg-n-teal-2 border-n-teal-6 text-n-teal-11'
                    : l.entregue
                      ? 'bg-n-amber-2 border-n-amber-6 text-n-amber-11'
                      : 'bg-n-surface-2 border-n-weak text-n-slate-10'"
                >
                  {{ l.label.replace('Laudo ', '') }}
                  <span v-if="l.aprovado"> ✓</span>
                  <span v-else-if="l.entregue"> ⏳</span>
                </span>
              </div>
              <!-- Status simples (modo meu) -->
              <span
                v-else-if="pac.laudoStatus === 'pendente'"
                class="text-label-small text-n-amber-11"
              >Entregue mas não aprovado</span>
            </div>
            <Button
              v-if="pac.laudoStatus !== 'aprovado'"
              label="Preencher"
              icon="i-lucide-edit-3"
              size="sm"
              variant="outline"
              color-scheme="secondary"
              @click="abrirLaudo(pac.id)"
            />
            <span
              v-else
              class="i-lucide-check-circle w-5 h-5 text-n-teal-9 shrink-0"
            />
          </li>
        </ul>
      </template>

    </div>
  </section>
</template>
