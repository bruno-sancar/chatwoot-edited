<script setup>
import { onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';

import Button from 'dashboard/components-next/button/Button.vue';
import { useFocohConfiguracao } from 'dashboard/routes/dashboard/kanban/composables/useFocohConfiguracao';

/**
 * V1 exporta/importa só o CATÁLOGO de propriedades — dado de paciente é
 * sensível e fica fora daqui de propósito (ver plano: "export/import de
 * dados de paciente... merece revisão à parte de formato/consentimento").
 */
const { t } = useI18n();
const { propriedades, carregarPropriedades } = useFocohConfiguracao();

const exportar = () => {
  const conteudo = JSON.stringify(propriedades.value, null, 2);
  const blob = new Blob([conteudo], { type: 'application/json' });
  const url = URL.createObjectURL(blob);

  const link = document.createElement('a');
  link.href = url;
  link.download = `kanban-clinico-propriedades-${new Date().toISOString().slice(0, 10)}.json`;
  link.click();

  URL.revokeObjectURL(url);
};

const onSelecionarArquivo = event => {
  const arquivo = event.target.files?.[0];
  if (!arquivo) return;

  const leitor = new FileReader();
  leitor.onload = () => {
    try {
      const dados = JSON.parse(leitor.result);
      // eslint-disable-next-line no-console
      console.info('Catálogo lido, pronto para revisão manual antes de importar:', dados);
      useAlert(t('FOCOH_KANBAN.CONFIGURACOES.IMPORTAR_EXPORTAR.ARQUIVO_LIDO', { n: dados.length }));
    } catch {
      useAlert(t('FOCOH_KANBAN.CONFIGURACOES.IMPORTAR_EXPORTAR.ARQUIVO_INVALIDO'));
    }
  };
  leitor.readAsText(arquivo);
};

onMounted(() => carregarPropriedades());
</script>

<template>
  <div class="flex flex-col max-w-xl gap-6">
    <section class="flex flex-col gap-2">
      <h3 class="text-heading-3 text-n-slate-12">
        {{ t('FOCOH_KANBAN.CONFIGURACOES.IMPORTAR_EXPORTAR.EXPORTAR_TITULO') }}
      </h3>
      <p class="text-body-main text-n-slate-11">
        {{ t('FOCOH_KANBAN.CONFIGURACOES.IMPORTAR_EXPORTAR.EXPORTAR_DESCRICAO') }}
      </p>
      <Button
        :label="t('FOCOH_KANBAN.CONFIGURACOES.IMPORTAR_EXPORTAR.EXPORTAR_BOTAO')"
        icon="i-lucide-download"
        variant="outline"
        size="sm"
        class="self-start"
        @click="exportar"
      />
    </section>

    <section class="flex flex-col gap-2">
      <h3 class="text-heading-3 text-n-slate-12">
        {{ t('FOCOH_KANBAN.CONFIGURACOES.IMPORTAR_EXPORTAR.IMPORTAR_TITULO') }}
      </h3>
      <p class="text-body-main text-n-slate-11">
        {{ t('FOCOH_KANBAN.CONFIGURACOES.IMPORTAR_EXPORTAR.IMPORTAR_DESCRICAO') }}
      </p>
      <input type="file" accept="application/json" @change="onSelecionarArquivo" />
    </section>
  </div>
</template>
