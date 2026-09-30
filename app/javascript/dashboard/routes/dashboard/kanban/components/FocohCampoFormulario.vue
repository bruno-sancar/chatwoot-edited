<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';

const props = defineProps({
  definicao: { type: Object, required: true },
  modelValue: { type: [String, Number, Boolean, Array], default: null },
  hasError: { type: Boolean, default: false },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

const opcoesSelect = computed(() =>
  (props.definicao.opcoes ?? []).map(opcao => ({
    value: opcao.value,
    label: opcao.label,
  }))
);

const valorMultipla = computed(() =>
  Array.isArray(props.modelValue) ? props.modelValue : []
);

const ehTelefone = computed(() =>
  /telefon|celular/i.test(props.definicao.campo_chave ?? '')
);

const ehCPF = computed(() =>
  /^cpf$/i.test(props.definicao.campo_chave ?? '')
);

const formatarTelefone = v => {
  const d = String(v ?? '').replace(/\D/g, '').slice(0, 11);
  if (d.length === 0) return '';
  if (d.length <= 2) return `(${d}`;
  if (d.length <= 7) return `(${d.slice(0, 2)}) ${d.slice(2)}`;
  if (d.length <= 10) return `(${d.slice(0, 2)}) ${d.slice(2, 6)}-${d.slice(6)}`;
  return `(${d.slice(0, 2)}) ${d.slice(2, 7)}-${d.slice(7)}`;
};

const formatarCPF = v => {
  const d = String(v ?? '').replace(/\D/g, '').slice(0, 11);
  if (d.length === 0) return '';
  if (d.length <= 3) return d;
  if (d.length <= 6) return `${d.slice(0, 3)}.${d.slice(3)}`;
  if (d.length <= 9) return `${d.slice(0, 3)}.${d.slice(3, 6)}.${d.slice(6)}`;
  return `${d.slice(0, 3)}.${d.slice(3, 6)}.${d.slice(6, 9)}-${d.slice(9)}`;
};

const handleTextoUpdate = v => {
  if (ehTelefone.value) emit('update:modelValue', formatarTelefone(v));
  else if (ehCPF.value) emit('update:modelValue', formatarCPF(v));
  else emit('update:modelValue', v);
};

const alternarOpcaoMultipla = valor => {
  const atual = valorMultipla.value;
  const proximo = atual.includes(valor)
    ? atual.filter(item => item !== valor)
    : [...atual, valor];
  emit('update:modelValue', proximo);
};

const atualizar = valor => emit('update:modelValue', valor);
</script>

<template>
  <div class="flex flex-col gap-1.5">
    <label
      v-if="definicao.tipo_campo !== 'checkbox'"
      class="text-heading-3 text-n-slate-12"
    >
      {{ definicao.rotulo }}
      <span v-if="definicao.obrigatorio" class="text-n-ruby-9">*</span>
    </label>

    <div
      :class="hasError ? 'rounded-lg ring-2 ring-n-ruby-8' : ''"
    >
      <Input
        v-if="definicao.tipo_campo === 'texto'"
        :model-value="modelValue"
        :input-type="ehTelefone ? 'tel' : 'text'"
        :placeholder="ehCPF ? '000.000.000-00' : ehTelefone ? '(00) 00000-0000' : undefined"
        @update:model-value="handleTextoUpdate"
      />

      <Input
        v-else-if="definicao.tipo_campo === 'numero'"
        type="number"
        :model-value="modelValue"
        @update:model-value="atualizar"
      />

      <Input
        v-else-if="definicao.tipo_campo === 'data'"
        type="date"
        :model-value="modelValue"
        @update:model-value="atualizar"
      />

      <TextArea
        v-else-if="definicao.tipo_campo === 'texto_longo'"
        :model-value="modelValue"
        auto-height
        @update:model-value="atualizar"
      />

      <Select
        v-else-if="definicao.tipo_campo === 'selecao'"
        :model-value="modelValue"
        :options="opcoesSelect"
        :placeholder="t('FOCOH_KANBAN.CAMPO.SELECIONE')"
        @update:model-value="atualizar"
      />

      <div v-else-if="definicao.tipo_campo === 'multipla'" class="flex flex-col gap-2">
        <label
          v-for="opcao in opcoesSelect"
          :key="opcao.value"
          class="flex items-center gap-2 text-body-main text-n-slate-12"
        >
          <Checkbox
            :model-value="valorMultipla.includes(opcao.value)"
            @update:model-value="() => alternarOpcaoMultipla(opcao.value)"
          />
          {{ opcao.label }}
        </label>
      </div>

      <label
        v-else-if="definicao.tipo_campo === 'checkbox'"
        class="flex items-center gap-2 text-body-main text-n-slate-12"
      >
        <Checkbox :model-value="Boolean(modelValue)" @update:model-value="atualizar" />
        {{ definicao.rotulo }}
        <span v-if="definicao.obrigatorio" class="text-n-ruby-9">*</span>
      </label>

      <label
        v-else-if="definicao.tipo_campo === 'assinatura'"
        class="flex items-center gap-2 text-body-main text-n-slate-12"
      >
        <Checkbox :model-value="Boolean(modelValue)" @update:model-value="atualizar" />
        {{ t('FOCOH_KANBAN.CAMPO.CONFIRMO_AVALIACAO') }}
      </label>
    </div>

    <p v-if="hasError" class="text-label-small text-n-ruby-11">
      {{ t('FOCOH_KANBAN.CAMPO.OBRIGATORIO') }}
    </p>
  </div>
</template>
