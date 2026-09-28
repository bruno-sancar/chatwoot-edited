<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';

import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import { useFocohConfiguracao } from 'dashboard/routes/dashboard/kanban/composables/useFocohConfiguracao';

import Propriedades from './Propriedades.vue';
import Usuarios from './Usuarios.vue';
import ImportarExportar from './ImportarExportar.vue';

/**
 * "podemos ter somente a possibilidade de definir usuários como editores,
 * para configurar propriedades, propriedades por etapa que são
 * obrigatório... para coisas mais complexas, o cliente deverá nos acionar" —
 * por isso só 3 abas, rasas de propósito. Nada de form-builder genérico.
 */
const { t } = useI18n();

const abas = [
  { label: t('FOCOH_KANBAN.CONFIGURACOES.ABA_PROPRIEDADES') },
  { label: t('FOCOH_KANBAN.CONFIGURACOES.ABA_USUARIOS') },
  { label: t('FOCOH_KANBAN.CONFIGURACOES.ABA_IMPORTAR_EXPORTAR') },
];
const abaAtiva = ref(0);

const { souEditor, verificarSouEditor } = useFocohConfiguracao();

onMounted(verificarSouEditor);
</script>

<template>
  <SettingsLayout :is-loading="false">
    <template #header>
      <BaseSettingsHeader
        :title="t('FOCOH_KANBAN.CONFIGURACOES.TITULO')"
        :description="t('FOCOH_KANBAN.CONFIGURACOES.DESCRICAO')"
      >
        <template #tabs>
          <TabBar :tabs="abas" :initial-active-tab="abaAtiva" @tab-changed="i => (abaAtiva = i)" />
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <p v-if="!souEditor" class="max-w-xl mt-4 text-body-main text-n-amber-11">
        {{ t('FOCOH_KANBAN.CONFIGURACOES.SEM_PERMISSAO_EDICAO') }}
      </p>

      <Propriedades v-if="abaAtiva === 0" :pode-editar="souEditor" class="mt-6" />
      <Usuarios v-else-if="abaAtiva === 1" :pode-editar="souEditor" class="mt-6" />
      <ImportarExportar v-else class="mt-6" />
    </template>
  </SettingsLayout>
</template>
