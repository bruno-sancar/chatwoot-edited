<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';

import { BaseTable, BaseTableRow, BaseTableCell } from 'dashboard/components-next/table';
import Select from 'dashboard/components-next/select/Select.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import { useFocohConfiguracao } from 'dashboard/routes/dashboard/kanban/composables/useFocohConfiguracao';

/**
 * "definir usuários como editores" — allowlist rasa por cima do RBAC
 * clínico já existente (coordenação/direção já editam por papel; isto
 * estende a quem mais precisar, sem criar hierarquia nova).
 */
const props = defineProps({
  podeEditar: { type: Boolean, default: false },
});

const { t } = useI18n();
const store = useStore();

const {
  editores,
  isLoadingEditores,
  carregarEditores,
  concederEditor,
  revogarEditor,
} = useFocohConfiguracao();

const agentes = computed(() => store.getters['agents/getAgents'] ?? []);
const agenteSelecionadoId = ref('');

const opcoesAgentes = computed(() =>
  agentes.value
    .filter(agente => !editores.value.some(e => e.chatwoot_user_id === agente.id))
    .map(agente => ({ value: String(agente.id), label: `${agente.name} (${agente.email})` }))
);

const headers = computed(() => [
  t('FOCOH_KANBAN.CONFIGURACOES.USUARIOS.COLUNA_NOME'),
  t('FOCOH_KANBAN.CONFIGURACOES.USUARIOS.COLUNA_CONCEDIDO_EM'),
  '',
]);

const onConceder = async () => {
  if (!agenteSelecionadoId.value) return;

  const agente = agentes.value.find(a => String(a.id) === agenteSelecionadoId.value);
  const { ok, error } = await concederEditor(agente.id, agente.name);

  if (ok) {
    agenteSelecionadoId.value = '';
  } else {
    useAlert(error?.message ?? t('FOCOH_KANBAN.CONFIGURACOES.ERRO_SALVAR'));
  }
};

const onRevogar = async editor => {
  if (!editor.chatwoot_user_id) return;
  const { ok, error } = await revogarEditor(editor.chatwoot_user_id);
  if (!ok) useAlert(error?.message ?? t('FOCOH_KANBAN.CONFIGURACOES.ERRO_SALVAR'));
};

onMounted(carregarEditores);
</script>

<template>
  <div class="flex flex-col gap-4">
    <div v-if="podeEditar" class="flex items-end gap-2 p-4 border rounded-xl border-n-weak">
      <Select
        v-model="agenteSelecionadoId"
        :options="opcoesAgentes"
        :placeholder="t('FOCOH_KANBAN.CONFIGURACOES.USUARIOS.SELECIONE_AGENTE')"
      />
      <Button
        :label="t('FOCOH_KANBAN.CONFIGURACOES.USUARIOS.CONCEDER')"
        size="sm"
        :disabled="!agenteSelecionadoId"
        @click="onConceder"
      />
    </div>

    <BaseTable
      :headers="headers"
      :items="editores"
      :loading="isLoadingEditores"
      :no-data-message="t('FOCOH_KANBAN.CONFIGURACOES.USUARIOS.VAZIO')"
    >
      <template #row="{ items }">
        <BaseTableRow v-for="editor in items" :key="editor.user_sub">
          <BaseTableCell>{{ editor.nome_exibicao || editor.user_sub }}</BaseTableCell>
          <BaseTableCell>{{ new Date(editor.concedido_em).toLocaleDateString() }}</BaseTableCell>
          <BaseTableCell align="end">
            <Button
              v-if="podeEditar"
              icon="i-lucide-trash-2"
              size="xs"
              slate
              ghost
              @click="onRevogar(editor)"
            />
          </BaseTableCell>
        </BaseTableRow>
      </template>
    </BaseTable>
  </div>
</template>
