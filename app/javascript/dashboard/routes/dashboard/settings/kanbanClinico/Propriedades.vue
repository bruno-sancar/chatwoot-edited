<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';

import { BaseTable, BaseTableRow, BaseTableCell } from 'dashboard/components-next/table';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import { useFocohConfiguracao } from 'dashboard/routes/dashboard/kanban/composables/useFocohConfiguracao';

/**
 * "Propriedades por etapa" — a aba mais citada no Mapa Objetivo. Edição
 * rasa: rótulo, obrigatório, ativo. Tipo de campo e chave não mudam depois
 * de criados (ver comentário em useFocohConfiguracao.atualizarPropriedade).
 */
const props = defineProps({
  podeEditar: { type: Boolean, default: false },
});

const { t } = useI18n();
const {
  propriedades,
  isLoadingPropriedades,
  carregarPropriedades,
  criarPropriedade,
  atualizarPropriedade,
} = useFocohConfiguracao();

const mostrarFormularioNovo = ref(false);
const novaPropriedade = ref({
  formulario_tipo: 'progressao_fase',
  etapa: '',
  bloco: '',
  campo_chave: '',
  rotulo: '',
  tipo_campo: 'checkbox',
  natureza: 'historico',
  obrigatorio: false,
});

const TIPOS_FORMULARIO = [
  { value: 'admissao', label: 'Admissão' },
  { value: 'progressao_fase', label: 'Progressão de Fase' },
  { value: 'avaliacao_risco', label: 'Avaliação de Risco' },
];
const TIPOS_CAMPO = [
  { value: 'texto', label: 'Texto' },
  { value: 'texto_longo', label: 'Texto longo' },
  { value: 'numero', label: 'Número' },
  { value: 'data', label: 'Data' },
  { value: 'selecao', label: 'Seleção' },
  { value: 'multipla', label: 'Múltipla escolha' },
  { value: 'checkbox', label: 'Checkbox' },
];

const headers = computed(() => [
  t('FOCOH_KANBAN.CONFIGURACOES.PROPRIEDADES.COLUNA_ROTULO'),
  t('FOCOH_KANBAN.CONFIGURACOES.PROPRIEDADES.COLUNA_FORMULARIO'),
  t('FOCOH_KANBAN.CONFIGURACOES.PROPRIEDADES.COLUNA_BLOCO'),
  t('FOCOH_KANBAN.CONFIGURACOES.PROPRIEDADES.COLUNA_TIPO'),
  t('FOCOH_KANBAN.CONFIGURACOES.PROPRIEDADES.COLUNA_OBRIGATORIO'),
  t('FOCOH_KANBAN.CONFIGURACOES.PROPRIEDADES.COLUNA_ATIVO'),
]);

const onToggleObrigatorio = async (propriedade, valor) => {
  const { ok, error } = await atualizarPropriedade(propriedade.id, { obrigatorio: valor });
  if (!ok) useAlert(error?.message ?? t('FOCOH_KANBAN.CONFIGURACOES.ERRO_SALVAR'));
};

const onToggleAtivo = async (propriedade, valor) => {
  const { ok, error } = await atualizarPropriedade(propriedade.id, { ativo: valor });
  if (!ok) useAlert(error?.message ?? t('FOCOH_KANBAN.CONFIGURACOES.ERRO_SALVAR'));
};

const onCriar = async () => {
  const payload = {
    ...novaPropriedade.value,
    etapa: novaPropriedade.value.etapa || null,
    bloco: novaPropriedade.value.bloco || null,
    programa: novaPropriedade.value.programa || null,
  };

  const { ok, error } = await criarPropriedade(payload);
  if (ok) {
    mostrarFormularioNovo.value = false;
    novaPropriedade.value = { ...novaPropriedade.value, campo_chave: '', rotulo: '', etapa: '', bloco: '' };
  } else {
    useAlert(error?.message ?? t('FOCOH_KANBAN.CONFIGURACOES.ERRO_SALVAR'));
  }
};

onMounted(() => carregarPropriedades());
</script>

<template>
  <div class="flex flex-col gap-4">
    <div class="flex justify-end">
      <Button
        v-if="podeEditar"
        :label="t('FOCOH_KANBAN.CONFIGURACOES.PROPRIEDADES.NOVA')"
        icon="i-lucide-plus"
        size="sm"
        variant="outline"
        @click="mostrarFormularioNovo = !mostrarFormularioNovo"
      />
    </div>

    <div v-if="mostrarFormularioNovo" class="grid grid-cols-2 gap-3 p-4 border rounded-xl border-n-weak sm:grid-cols-3">
      <Select v-model="novaPropriedade.formulario_tipo" :options="TIPOS_FORMULARIO" />
      <Input v-model="novaPropriedade.etapa" :placeholder="t('FOCOH_KANBAN.CONFIGURACOES.PROPRIEDADES.PLACEHOLDER_ETAPA')" />
      <Input v-model="novaPropriedade.bloco" :placeholder="t('FOCOH_KANBAN.CONFIGURACOES.PROPRIEDADES.PLACEHOLDER_BLOCO')" />
      <Input v-model="novaPropriedade.campo_chave" :placeholder="t('FOCOH_KANBAN.CONFIGURACOES.PROPRIEDADES.PLACEHOLDER_CHAVE')" />
      <Input v-model="novaPropriedade.rotulo" :placeholder="t('FOCOH_KANBAN.CONFIGURACOES.PROPRIEDADES.PLACEHOLDER_ROTULO')" />
      <Select v-model="novaPropriedade.tipo_campo" :options="TIPOS_CAMPO" />
      <Button :label="t('FOCOH_KANBAN.CONFIGURACOES.PROPRIEDADES.SALVAR')" size="sm" @click="onCriar" />
    </div>

    <BaseTable
      :headers="headers"
      :items="propriedades"
      :loading="isLoadingPropriedades"
      :no-data-message="t('FOCOH_KANBAN.CONFIGURACOES.PROPRIEDADES.VAZIO')"
    >
      <template #row="{ items }">
        <BaseTableRow v-for="propriedade in items" :key="propriedade.id">
          <BaseTableCell>{{ propriedade.rotulo }}</BaseTableCell>
          <BaseTableCell>{{ propriedade.formulario_tipo }}</BaseTableCell>
          <BaseTableCell>{{ propriedade.bloco || '—' }}</BaseTableCell>
          <BaseTableCell>{{ propriedade.tipo_campo }}</BaseTableCell>
          <BaseTableCell>
            <Switch
              :model-value="propriedade.obrigatorio"
              :disabled="!podeEditar"
              @change="valor => onToggleObrigatorio(propriedade, valor)"
            />
          </BaseTableCell>
          <BaseTableCell>
            <Switch
              :model-value="propriedade.ativo"
              :disabled="!podeEditar"
              @change="valor => onToggleAtivo(propriedade, valor)"
            />
          </BaseTableCell>
        </BaseTableRow>
      </template>
    </BaseTable>
  </div>
</template>
