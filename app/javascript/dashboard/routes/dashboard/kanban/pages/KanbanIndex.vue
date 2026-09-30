<script setup>
import { ref, computed, watch, onMounted, useTemplateRef } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import KanbanCard from '../components/KanbanCard.vue';
import KanbanColumn from '../components/KanbanColumn.vue';
import { useFocohKanban } from '../useFocohKanban';
import { PROGRAMAS, CODIGOS_TRAVA } from '../constants';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const {
  isConfigured,
  cards,
  isLoading,
  erroCarregamento,
  erroAutenticacao,
  carregarCards,
  moverPaciente,
} = useFocohKanban();

const MOTIVOS_AUTENTICACAO = {
  clinical_role_missing: 'KANBAN.ESTADO.SEM_PAPEL_CLINICO',
  clinical_role_invalid: 'KANBAN.ESTADO.PAPEL_CLINICO_INVALIDO',
};

const mensagemAutenticacao = computed(() =>
  t(MOTIVOS_AUTENTICACAO[erroAutenticacao.value] ?? 'KANBAN.ESTADO.SEM_TOKEN')
);

const dialogBloqueio = useTemplateRef('dialogBloqueio');
const mensagemBloqueio = ref('');

// Programa selecionado — começa com Jornada de Superação
const programaSelecionado = ref(PROGRAMAS[0]);

const fasesAtivas = computed(() => programaSelecionado.value.fases);

// Filtra cards pelo programa selecionado
const cardsFiltrados = computed(() =>
  cards.value.filter(c => c.programa === programaSelecionado.value.id)
);

const cardsPorFaseAtual = computed(() =>
  cardsFiltrados.value.reduce((acc, card) => {
    acc[card.fase] = acc[card.fase] || [];
    acc[card.fase].push(card);
    return acc;
  }, {})
);

const quadro = ref({});

const sincronizarQuadro = () => {
  quadro.value = Object.fromEntries(
    fasesAtivas.value.map(fase => [fase.id, [...(cardsPorFaseAtual.value[fase.id] ?? [])]])
  );
};

watch([cards, programaSelecionado], sincronizarQuadro, { immediate: true });

const selecionarPrograma = programa => {
  programaSelecionado.value = programa;
};

const onMove = async (card, faseDestino) => {
  const { ok, error } = await moverPaciente(card.id, faseDestino);

  if (!ok) {
    const mensagem = error?.message || t('KANBAN.BLOQUEIO.FALLBACK');

    if (error?.code === CODIGOS_TRAVA.AVANCO_BLOQUEADO) {
      mensagemBloqueio.value = mensagem;
      dialogBloqueio.value.open();
    } else {
      useAlert(mensagem);
    }
  }

  await carregarCards();
};

const abrirAdmissao = () => {
  router.push({
    name: 'kanban_clinico_admissao',
    params: { accountId: route.params.accountId },
  });
};

onMounted(carregarCards);
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-hidden bg-n-surface-1">
    <header class="flex items-start justify-between gap-4 px-6 pt-6 shrink-0">
      <div class="flex flex-col gap-3">
        <div>
          <h1 class="text-heading-1 text-n-slate-12">
            {{ t('KANBAN.HEADER') }}
          </h1>
          <p class="mt-1 text-body-main text-n-slate-11">
            {{ t('KANBAN.SUBTITULO') }}
          </p>
        </div>

        <!-- Seletor de programa -->
        <div v-if="isConfigured" class="flex gap-1 p-1 rounded-lg bg-n-surface-2 w-fit">
          <button
            v-for="programa in PROGRAMAS"
            :key="programa.id"
            type="button"
            class="px-3 py-1.5 rounded-md text-body-sm font-medium transition-colors"
            :class="
              programaSelecionado.id === programa.id
                ? 'bg-n-solid-2 text-n-slate-12 shadow-sm'
                : 'text-n-slate-11 hover:text-n-slate-12'
            "
            @click="selecionarPrograma(programa)"
          >
            {{ t(`KANBAN.${programa.labelKey}`) }}
          </button>
        </div>
      </div>

      <Button
        v-if="isConfigured"
        :label="t('FOCOH_KANBAN.ADMISSAO.CRIAR_PACIENTE')"
        icon="i-lucide-plus"
        size="sm"
        @click="abrirAdmissao"
      />
    </header>

    <div
      v-if="!isConfigured"
      class="flex items-center justify-center flex-1 px-6"
    >
      <p class="max-w-md text-center text-body-main text-n-slate-11">
        {{ t('KANBAN.ESTADO.SEM_CONFIGURACAO') }}
      </p>
    </div>

    <div
      v-else-if="isLoading && !cards.length"
      class="flex items-center justify-center flex-1"
    >
      <Spinner :size="24" />
    </div>

    <div
      v-else-if="erroAutenticacao"
      class="flex items-center justify-center flex-1 px-6"
    >
      <p class="max-w-md text-center text-body-main text-n-slate-11">
        {{ mensagemAutenticacao }}
      </p>
    </div>

    <div
      v-else-if="erroCarregamento"
      class="flex items-center justify-center flex-1 px-6"
    >
      <p class="max-w-md text-center text-body-main text-n-ruby-11">
        {{ erroCarregamento.message }}
      </p>
    </div>

    <template v-else>
      <main class="flex-1 hidden px-6 py-4 overflow-x-auto md:block">
        <div class="grid grid-flow-col auto-cols-[minmax(17rem,1fr)] gap-4 h-full">
          <KanbanColumn
            v-for="fase in fasesAtivas"
            :key="fase.id + programaSelecionado.id"
            :fase="fase"
            :cards="quadro[fase.id] ?? []"
            @move="card => onMove(card, fase.id)"
          />
        </div>
      </main>

      <main class="flex-1 px-4 py-4 overflow-y-auto md:hidden">
        <div
          v-for="fase in fasesAtivas"
          :key="fase.id + programaSelecionado.id"
          class="flex flex-col gap-2 mb-6"
        >
          <div class="flex items-center gap-2">
            <span class="rounded-full size-2 shrink-0" :class="fase.dotClass" />
            <h2 class="text-heading-3 text-n-slate-12">
              {{ t(`KANBAN.FASES.${fase.labelKey}.NOME`) }}
            </h2>
            <span class="text-label-small text-n-slate-11">
              {{ (quadro[fase.id] ?? []).length }}
            </span>
          </div>
          <p
            v-if="!(quadro[fase.id] ?? []).length"
            class="text-label-small text-n-slate-10"
          >
            {{ t('KANBAN.COLUNA_VAZIA') }}
          </p>
          <KanbanCard
            v-for="card in quadro[fase.id] ?? []"
            :key="card.id"
            :card="card"
          />
        </div>
      </main>
    </template>

    <Dialog
      ref="dialogBloqueio"
      type="alert"
      width="md"
      :title="t('KANBAN.BLOQUEIO.TITULO')"
      :description="mensagemBloqueio"
      :show-cancel-button="false"
      :confirm-button-label="t('KANBAN.BLOQUEIO.ENTENDI')"
      @confirm="dialogBloqueio.close()"
    />
  </section>
</template>
