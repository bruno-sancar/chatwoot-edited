<script setup>
import { computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const ORDER = [
  { name: 'kanban_clinico_progressao_fase', labelKey: 'FOCOH_KANBAN.PROGRESSAO.TITULO_CURTO' },
  { name: 'kanban_clinico_laudo_semanal',   labelKey: 'FOCOH_KANBAN.LAUDO.TITULO' },
  { name: 'kanban_clinico_avaliacao_risco', labelKey: 'FOCOH_KANBAN.RISCO.TITULO_CURTO' },
  { name: 'kanban_clinico_ficha_admissao',  labelKey: 'FOCOH_KANBAN.ADMISSAO.TITULO_CURTO' },
  { name: 'kanban_clinico_historico_paciente', labelKey: 'FOCOH_KANBAN.HISTORICO.TITULO' },
];

const idx = computed(() => ORDER.findIndex(o => o.name === route.name));
const prevItem = computed(() => (idx.value > 0 ? ORDER[idx.value - 1] : null));
const nextItem = computed(() => (idx.value >= 0 && idx.value < ORDER.length - 1 ? ORDER[idx.value + 1] : null));

const navegar = nome => {
  router.push({ name: nome, params: route.params });
};
</script>

<template>
  <div
    v-if="prevItem || nextItem"
    class="flex items-center justify-between gap-3 px-6 py-3 border-t border-n-weak shrink-0"
  >
    <button
      v-if="prevItem"
      type="button"
      class="flex items-center gap-1.5 text-body-sm text-n-slate-11 hover:text-n-slate-12 transition-colors"
      @click="navegar(prevItem.name)"
    >
      <span class="i-lucide-arrow-left w-4 h-4" />
      {{ t(prevItem.labelKey) }}
    </button>
    <div v-else />

    <button
      v-if="nextItem"
      type="button"
      class="flex items-center gap-1.5 text-body-sm text-n-slate-11 hover:text-n-slate-12 transition-colors"
      @click="navegar(nextItem.name)"
    >
      {{ t(nextItem.labelKey) }}
      <span class="i-lucide-arrow-right w-4 h-4" />
    </button>
    <div v-else />
  </div>
</template>
