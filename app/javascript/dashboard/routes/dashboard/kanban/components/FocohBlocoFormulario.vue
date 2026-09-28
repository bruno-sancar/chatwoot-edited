<script setup>
import { reactive, ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import FocohCampoFormulario from './FocohCampoFormulario.vue';

/**
 * Um bloco do formulário (ex.: "1 — Avaliação Clínica"), com submissão
 * própria — cada bloco do anexo fases.pdf é preenchido por um profissional
 * diferente, em momentos diferentes ("Kanbans Clínicos — Mapa Objetivo":
 * "empilhadas, uma abaixo da outra, cada uma recolhível"), então não faz
 * sentido um único botão "enviar" para o formulário inteiro.
 */
const props = defineProps({
  titulo: { type: String, required: true },
  definicoes: { type: Array, required: true },
  comDecisao: { type: Boolean, default: false },
  opcoesDecisao: {
    type: Array,
    default: () => [
      { value: 'apto', label: 'Apto' },
      { value: 'nao_apto', label: 'Não apto' },
    ],
  },
  isSubmitting: { type: Boolean, default: false },
  ultimoEnvio: { type: Object, default: null },
});

const emit = defineEmits(['enviar']);

const { t } = useI18n();

const valores = reactive({});
// '' e não null: Select.vue tipa modelValue como String/Number/Boolean (o
// componente nativo <select> não representa "nenhuma opção" com null).
const decisao = ref('');
const tentouEnviar = ref(false);
const aberto = ref(true);

const camposFaltando = computed(() =>
  props.definicoes.filter(def => {
    if (!def.obrigatorio) return false;
    const valor = valores[def.campo_chave];
    return valor === undefined || valor === null || valor === '';
  })
);

const podeEnviar = computed(
  () => camposFaltando.value.length === 0 && (!props.comDecisao || decisao.value)
);

const enviar = () => {
  tentouEnviar.value = true;
  if (!podeEnviar.value) return;

  const respostas = props.definicoes.map(definicao => ({
    definicao,
    valor: valores[definicao.campo_chave] ?? null,
  }));

  // Bloco sem decisão manda `null`, não '' — a coluna `resultado` no banco
  // é o veredito do bloco, e string vazia não é um veredito válido.
  emit('enviar', { respostas, resultado: props.comDecisao ? decisao.value : null });
};
</script>

<template>
  <section class="border rounded-xl border-n-weak bg-n-solid-1">
    <header
      class="flex items-center justify-between px-4 py-3 cursor-pointer"
      @click="aberto = !aberto"
    >
      <div class="flex items-center gap-2">
        <h3 class="text-heading-2 text-n-slate-12">{{ titulo }}</h3>
        <span
          v-if="ultimoEnvio"
          class="rounded-full px-2 py-0.5 text-label-small"
          :class="
            ultimoEnvio.resultado === 'apto'
              ? 'bg-n-teal-3 text-n-teal-11'
              : 'bg-n-amber-3 text-n-amber-11'
          "
        >
          {{ t('FOCOH_KANBAN.BLOCO.ULTIMO_ENVIO', { data: ultimoEnvio.enviado_em }) }}
        </span>
      </div>
      <span class="text-n-slate-11 i-lucide-chevron-down size-4" :class="{ 'rotate-180': aberto }" />
    </header>

    <div v-if="aberto" class="flex flex-col gap-4 px-4 pb-4">
      <FocohCampoFormulario
        v-for="definicao in definicoes"
        :key="definicao.id"
        v-model="valores[definicao.campo_chave]"
        :definicao="definicao"
      />

      <div v-if="comDecisao" class="flex flex-col gap-1.5">
        <label class="text-heading-3 text-n-slate-12">
          {{ t('FOCOH_KANBAN.BLOCO.DECISAO') }}
          <span class="text-n-ruby-9">*</span>
        </label>
        <Select v-model="decisao" :options="opcoesDecisao" :placeholder="t('FOCOH_KANBAN.CAMPO.SELECIONE')" />
      </div>

      <p v-if="tentouEnviar && camposFaltando.length" class="text-label-small text-n-ruby-11">
        {{ t('FOCOH_KANBAN.BLOCO.CAMPOS_OBRIGATORIOS_FALTANDO', { n: camposFaltando.length }) }}
      </p>

      <Button
        :label="t('FOCOH_KANBAN.BLOCO.ENVIAR')"
        :is-loading="isSubmitting"
        class="self-start"
        @click="enviar"
      />
    </div>
  </section>
</template>
