<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useStore } from 'vuex';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import FocohBlocoFormulario from '../components/FocohBlocoFormulario.vue';
import { useFocohFormularios } from '../composables/useFocohFormularios';
import { getFocohSupabaseClient, obterFocohToken } from '../focohSupabaseClient';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();

const contatoParaVincular = route.query.vincularContatoId ?? null;

const { definicoes, isLoadingDefinicoes, carregarDefinicoes } = useFocohFormularios();
const isSubmitting = ref(false);

// Contato Chatwoot selecionado (para pré-preenchimento)
const contatoSelecionado = ref(null);

// Busca de contato (FOCO-71 — quando não vem da sidebar)
const textoBusca = ref('');
const resultadosBusca = ref([]);
const buscando = ref(false);
const mostrarDropdown = ref(false);

// Mapeia contato Chatwoot → campo_chave do formulário (best-effort)
const valoresIniciaisDoContato = computed(() => {
  if (!contatoSelecionado.value) return {};
  const c = contatoSelecionado.value;
  const mapa = {};
  if (c.name) mapa.nome = c.name;
  if (c.phone_number) {
    mapa.telefone = c.phone_number;
    mapa.celular = c.phone_number;
    mapa.telefone_celular = c.phone_number;
  }
  if (c.email) mapa.email = c.email;
  return mapa;
});

// Busca contatos Chatwoot ao digitar (FOCO-71)
let buscaTimer = null;
watch(textoBusca, q => {
  clearTimeout(buscaTimer);
  resultadosBusca.value = [];
  mostrarDropdown.value = false;
  if (q.length < 2) { buscando.value = false; return; }
  buscando.value = true;
  buscaTimer = setTimeout(async () => {
    try {
      await store.dispatch('contacts/search', { searchStr: q, page: 1 });
      const todos = store.getters['contacts/allContacts'] ?? [];
      resultadosBusca.value = todos
        .filter(c => c.name?.toLowerCase().includes(q.toLowerCase()))
        .slice(0, 8);
      mostrarDropdown.value = resultadosBusca.value.length > 0;
    } catch {
      // silent — search is optional
    } finally {
      buscando.value = false;
    }
  }, 350);
});

const selecionarContato = c => {
  contatoSelecionado.value = c;
  textoBusca.value = '';
  resultadosBusca.value = [];
  mostrarDropdown.value = false;
};

const limparContato = () => {
  contatoSelecionado.value = null;
};

// FOCO-70 — pré-carrega contato quando vindo da sidebar com vincularContatoId
const carregarContatoVinculado = async () => {
  if (!contatoParaVincular) return;
  try {
    const contato = await store.dispatch('contacts/show', {
      id: parseInt(contatoParaVincular),
    });
    if (contato) contatoSelecionado.value = contato;
  } catch {
    // silent — form still works without pre-fill
  }
};

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
      .insert({ nome, programa: 'jornada_superacao', dados_cadastrais: dadosCadastrais })
      .select('id')
      .single();
    if (error) throw error;
    const contatoId = contatoParaVincular ?? contatoSelecionado.value?.id;
    if (contatoId) {
      await store.dispatch('contacts/update', {
        id: contatoId,
        customAttributes: { focoh_patient_id: pacienteCriado.id, focoh_patient_nome: nome },
      });
    }
    useAlert(t('FOCOH_KANBAN.ADMISSAO.CRIADO'));
    router.push({ name: 'kanban_clinico_index', params: { accountId: route.params.accountId } });
  } catch (err) {
    useAlert(err?.message ?? t('FOCOH_KANBAN.BLOCO.ENVIAR'));
  } finally {
    isSubmitting.value = false;
  }
};

onMounted(() => {
  carregarDefinicoes('admissao', { etapa: 'aba_a' });
  carregarContatoVinculado();
});
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-hidden bg-n-surface-1">
    <header class="px-6 pt-6 pb-4 shrink-0 border-b border-n-strong">
      <h1 class="text-heading-1 text-n-slate-12">
        {{ t('FOCOH_KANBAN.ADMISSAO.TITULO') }}
      </h1>
      <p class="mt-1 text-body-main text-n-slate-11">
        {{ t('FOCOH_KANBAN.ADMISSAO.SUBTITULO') }}
      </p>
    </header>

    <div
      v-if="isLoadingDefinicoes"
      class="flex items-center justify-center flex-1"
    >
      <Spinner :size="24" />
    </div>

    <div v-else class="flex-1 overflow-y-auto px-6 py-5">
      <div class="max-w-2xl mx-auto flex flex-col gap-6">

        <!-- Seleção/pré-preenchimento de contato Chatwoot -->
        <div class="flex flex-col gap-3 p-4 rounded-xl border border-n-strong bg-n-surface-2">
          <h2 class="text-heading-3 text-n-slate-12">
            {{ t('FOCOH_KANBAN.ADMISSAO.TITULO_CURTO') }}
          </h2>

          <!-- Contato já selecionado (ou vindo da sidebar) -->
          <div
            v-if="contatoSelecionado"
            class="flex items-center justify-between gap-3 px-3 py-2 rounded-lg border border-n-strong bg-n-surface-1"
          >
            <div class="flex items-center gap-2 min-w-0">
              <span class="i-lucide-user size-4 text-n-slate-11 shrink-0" />
              <div class="min-w-0">
                <p class="text-body-sm font-medium text-n-slate-12 truncate">
                  {{ contatoSelecionado.name }}
                </p>
                <p v-if="contatoSelecionado.phone_number" class="text-label-small text-n-slate-11 truncate">
                  {{ contatoSelecionado.phone_number }}
                </p>
              </div>
            </div>
            <button
              v-if="!contatoParaVincular"
              type="button"
              class="shrink-0 p-1 rounded text-n-slate-10 hover:text-n-slate-12 transition-colors"
              @click="limparContato"
            >
              <span class="i-lucide-x size-4" />
            </button>
          </div>

          <!-- Campo de busca (quando não vem da sidebar) -->
          <div v-else-if="!contatoParaVincular" class="relative">
            <Input
              v-model="textoBusca"
              :placeholder="t('FOCOH_KANBAN.VINCULO.BUSCAR_PLACEHOLDER')"
              class="w-full"
            >
              <template #suffix>
                <span
                  v-if="buscando"
                  class="i-lucide-loader-circle size-4 text-n-slate-10 animate-spin"
                />
                <span v-else class="i-lucide-search size-4 text-n-slate-10" />
              </template>
            </Input>
            <ul
              v-if="mostrarDropdown"
              class="absolute z-10 left-0 right-0 top-full mt-1 rounded-lg border border-n-strong bg-n-surface-1 shadow-lg overflow-hidden"
            >
              <li
                v-for="c in resultadosBusca"
                :key="c.id"
                class="flex flex-col px-3 py-2 cursor-pointer hover:bg-n-surface-2 transition-colors"
                @click="selecionarContato(c)"
              >
                <span class="text-body-sm font-medium text-n-slate-12">{{ c.name }}</span>
                <span v-if="c.phone_number" class="text-label-small text-n-slate-11">{{ c.phone_number }}</span>
              </li>
            </ul>
          </div>

          <p class="text-label-small text-n-slate-10">
            {{ t('FOCOH_KANBAN.ADMISSAO.ABA_A') }}
          </p>
        </div>

        <!-- Bloco do formulário de admissão -->
        <FocohBlocoFormulario
          v-if="definicoes.length"
          :titulo="t('FOCOH_KANBAN.ADMISSAO.TITULO_CURTO')"
          :definicoes="definicoes"
          :valores-iniciais="valoresIniciaisDoContato"
          :is-submitting="isSubmitting"
          @enviar="onEnviar"
        />
      </div>
    </div>
  </section>
</template>
