<script setup>
import { ref, watch, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import { getFocohSupabaseClient, isFocohConfigurado, obterFocohToken } from '../focohSupabaseClient';

const { t } = useI18n();

const FORMULARIOS = [
  { id: 'admissao',          label: 'Admissão e Triagem' },
  { id: 'progressao_fase',   label: 'Progressão de Fase' },
  { id: 'avaliacao_risco',   label: 'Avaliação de Risco' },
  { id: 'evolucao_semanal',  label: 'Laudo Semanal' },
  { id: 'ficha_admissao',    label: 'Ficha de Admissão' },
];

const ABAS = [
  { id: 'propriedades', label: 'Propriedades por etapa' },
  { id: 'usuarios',     label: 'Usuários' },
  { id: 'importexport', label: 'Import/Export' },
];

const abaSelecionada     = ref('propriedades');
const formularioAtual    = ref(FORMULARIOS[0]);
const campos             = ref([]);
const isLoading          = ref(false);
const isSaving           = ref(false);
const erro               = ref(null);
const sucessoMsg         = ref(null);

// Aba Usuários
const usuarios           = ref([]);
const isLoadingUsuarios  = ref(false);

const isConfigurado = isFocohConfigurado();

const carregarCampos = async () => {
  if (!isConfigurado) return;
  const supabase = getFocohSupabaseClient();
  if (!supabase) return;

  isLoading.value = true;
  erro.value = null;

  try {
    await obterFocohToken();
    const { data, error: err } = await supabase
      .from('definicoes_formulario')
      .select('id, campo_chave, rotulo, tipo_campo, ativo, ordem, obrigatorio')
      .eq('formulario_tipo', formularioAtual.value.id)
      .order('ordem');

    if (err) throw err;
    campos.value = data ?? [];
  } catch (e) {
    erro.value = e.message ?? 'Erro ao carregar campos.';
  } finally {
    isLoading.value = false;
  }
};

const carregarUsuarios = async () => {
  if (!isConfigurado) return;
  const supabase = getFocohSupabaseClient();
  if (!supabase) return;

  isLoadingUsuarios.value = true;
  try {
    await obterFocohToken();
    const { data, error: err } = await supabase
      .from('papeis_focoh')
      .select('user_sub, papel, nome_exibicao, concedido_em')
      .order('concedido_em');
    if (err) throw err;
    usuarios.value = data ?? [];
  } catch (e) {
    // silencioso — pode não ter permissão
    usuarios.value = [];
  } finally {
    isLoadingUsuarios.value = false;
  }
};

watch(abaSelecionada, aba => {
  if (aba === 'usuarios') carregarUsuarios();
});

const PAPEL_LABEL = {
  diretor_geral:       'Diretor Geral',
  coordenacao_tecnica: 'Coordenação Técnica',
  clinico:             'Clínico',
  terapeuta:           'Terapeuta',
  disciplinar:         'Disciplinar',
  recepcao:            'Recepção',
};

const mover = (index, delta) => {
  const arr = [...campos.value];
  const alvo = index + delta;
  if (alvo < 0 || alvo >= arr.length) return;
  [arr[index], arr[alvo]] = [arr[alvo], arr[index]];
  campos.value = arr;
};

const salvar = async () => {
  const supabase = getFocohSupabaseClient();
  if (!supabase) return;

  isSaving.value = true;
  erro.value = null;
  sucessoMsg.value = null;

  try {
    const updates = campos.value.map((c, i) => ({
      id: c.id,
      ativo: c.ativo,
      ordem: i + 1,
    }));

    const { error: err } = await supabase
      .from('definicoes_formulario')
      .upsert(updates, { onConflict: 'id' });

    if (err) throw err;

    sucessoMsg.value = 'Configurações salvas.';
    setTimeout(() => { sucessoMsg.value = null; }, 3000);
  } catch (e) {
    erro.value = e.message ?? 'Erro ao salvar.';
  } finally {
    isSaving.value = false;
  }
};

const exportarDados = async () => {
  const supabase = getFocohSupabaseClient();
  if (!supabase) return;
  try {
    await obterFocohToken();
    const [{ data: pacientes }, { data: respostas }] = await Promise.all([
      supabase.from('pacientes').select('*'),
      supabase.from('respostas_formulario').select('*'),
    ]);
    const exportado = { exportado_em: new Date().toISOString(), pacientes, respostas };
    const blob = new Blob([JSON.stringify(exportado, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `focoh-export-${new Date().toISOString().slice(0, 10)}.json`;
    a.click();
    URL.revokeObjectURL(url);
  } catch (e) {
    erro.value = e.message ?? 'Erro ao exportar.';
  }
};

watch(formularioAtual, carregarCampos);
onMounted(carregarCampos);
</script>

<template>
  <div class="flex flex-col h-full overflow-hidden bg-n-background">
    <!-- Header -->
    <div class="flex items-center gap-3 px-6 py-4 border-b border-n-weak">
      <i class="i-lucide-settings text-xl text-n-slate-11" />
      <h1 class="text-title-h2 font-semibold text-n-slate-12">
        Configurações do Kanban
      </h1>
    </div>

    <!-- Abas principais -->
    <div class="flex gap-0 border-b border-n-weak px-6">
      <button
        v-for="aba in ABAS"
        :key="aba.id"
        class="px-4 py-3 text-sm font-medium border-b-2 transition-colors"
        :class="abaSelecionada === aba.id
          ? 'border-n-brand text-n-brand'
          : 'border-transparent text-n-slate-11 hover:text-n-slate-12'"
        @click="abaSelecionada = aba.id"
      >
        {{ aba.label }}
      </button>
    </div>

    <!-- Conteúdo -->
    <div class="flex-1 overflow-y-auto p-6">

      <!-- Aba: Propriedades por etapa -->
      <template v-if="abaSelecionada === 'propriedades'">
        <div v-if="!isConfigurado" class="text-sm text-n-slate-11 p-4 bg-n-amber-2 rounded-lg border border-n-amber-6">
          Supabase não configurado. Adicione FOCOH_SUPABASE_URL e FOCOH_SUPABASE_ANON_KEY nas variáveis de ambiente.
        </div>

        <template v-else>
          <!-- Seletor de formulário -->
          <div class="mb-6">
            <label class="block text-sm font-medium text-n-slate-12 mb-2">Formulário / Etapa</label>
            <div class="flex flex-wrap gap-2">
              <button
                v-for="f in FORMULARIOS"
                :key="f.id"
                class="px-3 py-1.5 text-sm rounded-full border transition-colors"
                :class="formularioAtual.id === f.id
                  ? 'bg-n-brand text-white border-n-brand'
                  : 'border-n-weak text-n-slate-11 hover:border-n-slate-9'"
                @click="formularioAtual = f"
              >
                {{ f.label }}
              </button>
            </div>
          </div>

          <!-- Estado de carregamento -->
          <div v-if="isLoading" class="flex justify-center py-12">
            <Spinner />
          </div>

          <div v-else-if="erro" class="text-sm text-n-red-11 p-4 bg-n-red-2 rounded-lg border border-n-red-6">
            {{ erro }}
          </div>

          <template v-else>
            <!-- Lista de campos -->
            <div class="rounded-xl border border-n-weak overflow-hidden mb-4">
              <div class="grid grid-cols-[1fr_auto_auto] text-xs font-medium text-n-slate-11 uppercase tracking-wide px-4 py-2 bg-n-weak border-b border-n-weak">
                <span>Campo</span>
                <span class="text-center pr-8">Visível</span>
                <span class="text-center">Ordem</span>
              </div>

              <div v-if="campos.length === 0" class="px-4 py-6 text-sm text-n-slate-11 text-center">
                Nenhum campo configurado para esta etapa.
              </div>

              <div
                v-for="(campo, i) in campos"
                :key="campo.id"
                class="grid grid-cols-[1fr_auto_auto] items-center px-4 py-3 border-b border-n-weak last:border-b-0 hover:bg-n-weak/40 transition-colors"
              >
                <!-- Info do campo -->
                <div class="flex flex-col gap-0.5">
                  <span class="text-sm font-medium text-n-slate-12">
                    {{ campo.rotulo }}
                    <span v-if="campo.obrigatorio" class="ml-1 text-xs text-n-red-9">*</span>
                  </span>
                  <span class="text-xs text-n-slate-10">{{ campo.campo_chave }} · {{ campo.tipo_campo }}</span>
                </div>

                <!-- Toggle ativo -->
                <div class="flex justify-center pr-8">
                  <button
                    class="relative w-9 h-5 rounded-full transition-colors focus:outline-none"
                    :class="campo.ativo ? 'bg-n-brand' : 'bg-n-slate-6'"
                    :disabled="campo.obrigatorio"
                    :title="campo.obrigatorio ? 'Campo obrigatório — não pode ser desativado' : ''"
                    @click="!campo.obrigatorio && (campo.ativo = !campo.ativo)"
                  >
                    <span
                      class="absolute top-0.5 left-0.5 w-4 h-4 bg-white rounded-full shadow transition-transform"
                      :class="campo.ativo ? 'translate-x-4' : 'translate-x-0'"
                    />
                  </button>
                </div>

                <!-- Botões de ordem -->
                <div class="flex flex-col gap-0.5">
                  <button
                    class="p-0.5 rounded hover:bg-n-weak text-n-slate-10 hover:text-n-slate-12 transition-colors disabled:opacity-30"
                    :disabled="i === 0"
                    @click="mover(i, -1)"
                  >
                    <i class="i-lucide-chevron-up text-sm" />
                  </button>
                  <button
                    class="p-0.5 rounded hover:bg-n-weak text-n-slate-10 hover:text-n-slate-12 transition-colors disabled:opacity-30"
                    :disabled="i === campos.length - 1"
                    @click="mover(i, 1)"
                  >
                    <i class="i-lucide-chevron-down text-sm" />
                  </button>
                </div>
              </div>
            </div>

            <!-- Feedback e botão salvar -->
            <div class="flex items-center justify-between">
              <span v-if="sucessoMsg" class="text-sm text-n-teal-11 flex items-center gap-1">
                <i class="i-lucide-check-circle text-base" />
                {{ sucessoMsg }}
              </span>
              <span v-else-if="erro" class="text-sm text-n-red-11">{{ erro }}</span>
              <span v-else />

              <Button
                :label="isSaving ? 'Salvando…' : 'Salvar configurações'"
                variant="solid"
                color-scheme="primary"
                :disabled="isSaving || campos.length === 0"
                @click="salvar"
              />
            </div>
          </template>
        </template>
      </template>

      <!-- Aba: Usuários -->
      <template v-else-if="abaSelecionada === 'usuarios'">
        <div class="mb-4 flex items-center justify-between">
          <p class="text-sm text-n-slate-11">
            Equipe com acesso ao Kanban Clínico e seus papéis.
          </p>
        </div>

        <div v-if="isLoadingUsuarios" class="flex justify-center py-12">
          <Spinner />
        </div>

        <div v-else-if="usuarios.length === 0" class="flex flex-col items-center justify-center py-20 gap-3 text-n-slate-10">
          <i class="i-lucide-users text-4xl" />
          <p class="text-sm">Nenhum usuário configurado.</p>
          <p class="text-xs text-center max-w-xs">
            Os papéis são atribuídos via SQL diretamente na tabela <code>papeis_focoh</code>.
          </p>
        </div>

        <div v-else class="rounded-xl border border-n-weak overflow-hidden">
          <div class="grid grid-cols-[1fr_auto_auto] text-xs font-medium text-n-slate-11 uppercase tracking-wide px-4 py-2 bg-n-weak border-b border-n-weak">
            <span>Nome</span>
            <span class="pr-4">Papel</span>
            <span>Desde</span>
          </div>
          <div
            v-for="u in usuarios"
            :key="u.user_sub"
            class="grid grid-cols-[1fr_auto_auto] items-center px-4 py-3 border-b border-n-weak last:border-b-0"
          >
            <span class="text-sm text-n-slate-12">{{ u.nome_exibicao || u.user_sub }}</span>
            <span class="text-sm text-n-slate-11 pr-4">
              {{ PAPEL_LABEL[u.papel] ?? u.papel }}
            </span>
            <span class="text-xs text-n-slate-10">
              {{ new Date(u.concedido_em).toLocaleDateString('pt-BR') }}
            </span>
          </div>
        </div>
      </template>

      <!-- Aba: Import/Export -->
      <template v-else-if="abaSelecionada === 'importexport'">
        <div class="flex flex-col gap-6 max-w-md">
          <div>
            <h2 class="text-sm font-semibold text-n-slate-12 mb-1">Exportar dados</h2>
            <p class="text-sm text-n-slate-11 mb-3">
              Exporta todos os pacientes e histórico de formulários em formato JSON.
            </p>
            <Button
              label="Baixar exportação JSON"
              icon="i-lucide-download"
              variant="outline"
              color-scheme="secondary"
              @click="exportarDados"
            />
          </div>

          <div class="border-t border-n-weak pt-6">
            <h2 class="text-sm font-semibold text-n-slate-12 mb-1">Importar dados</h2>
            <p class="text-sm text-n-slate-11 mb-3">
              Importação de dados via arquivo JSON gerado por esta exportação.
            </p>
            <div class="flex flex-col items-center justify-center py-8 gap-2 rounded-xl border-2 border-dashed border-n-weak text-n-slate-10">
              <i class="i-lucide-upload-cloud text-3xl" />
              <p class="text-sm">Em breve — disponível na próxima versão.</p>
            </div>
          </div>
        </div>
      </template>

    </div>
  </div>
</template>
