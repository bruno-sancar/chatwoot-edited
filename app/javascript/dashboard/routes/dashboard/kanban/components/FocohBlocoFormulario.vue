<script setup>
import { reactive, ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import FocohCampoFormulario from './FocohCampoFormulario.vue';

const props = defineProps({
  titulo: { type: String, required: true },
  definicoes: { type: Array, required: true },
  valoresIniciais: { type: Object, default: () => ({}) },
  comDecisao: { type: Boolean, default: false },
  opcoesDecisao: { type: Array, default: () => [
    { value: 'apto', label: 'Apto' },
    { value: 'nao_apto', label: 'Não apto' },
  ]},
  isSubmitting: { type: Boolean, default: false },
  ultimoEnvio: { type: Object, default: null },
  enviado: { type: Boolean, default: false },
});
const emit = defineEmits(['enviar']);
const { t } = useI18n();
const valores = reactive({});
const decisao = ref('');
const tentouEnviar = ref(false);
const aberto = ref(true);

watch(
  () => props.valoresIniciais,
  v => { if (v) Object.assign(valores, v); },
  { immediate: true }
);

const camposFaltando = computed(() =>
  props.definicoes.filter(def => {
    if (!def.obrigatorio) return false;
    const valor = valores[def.campo_chave];
    return valor === undefined || valor === null || valor === '';
  })
);

const camposComErro = computed(() => new Set(camposFaltando.value.map(d => d.campo_chave)));

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
  emit('enviar', { respostas, resultado: props.comDecisao ? decisao.value : null });
};
</script>

<template>
  <div class="flex flex-col gap-4 rounded-xl border border-n-strong bg-n-surface-1 overflow-hidden">
    <!-- Cabeçalho clicável para colapsar -->
    <button
      type="button"
      class="flex items-center justify-between gap-3 px-5 py-4 text-left hover:bg-n-surface-2 transition-colors"
      @click="aberto = !aberto"
    >
      <h3 class="text-heading-2 text-n-slate-12">{{ titulo }}</h3>
      <div class="flex items-center gap-2 shrink-0">
        <span
          v-if="enviado"
          class="flex items-center gap-1 text-label-small text-n-teal-11"
        >
          <span class="i-lucide-check-circle size-3.5" />
          {{ t('FOCOH_KANBAN.BLOCO.ENVIADO') }}
        </span>
        <span
          v-else-if="ultimoEnvio"
          class="text-label-small text-n-slate-11"
        >
          {{ t('FOCOH_KANBAN.BLOCO.ULTIMO_ENVIO', { data: ultimoEnvio.data }) }}
        </span>
        <span
          class="i-lucide-chevron-down size-4 text-n-slate-11 transition-transform"
          :class="aberto ? 'rotate-0' : '-rotate-90'"
        />
      </div>
    </button>

    <div v-show="aberto" class="flex flex-col gap-5 px-5 pb-5">
      <!-- Campos do formulário -->
      <div class="flex flex-col gap-4">
        <FocohCampoFormulario
          v-for="def in definicoes"
          :key="def.campo_chave"
          :definicao="def"
          :model-value="valores[def.campo_chave]"
          :has-error="tentouEnviar && camposComErro.has(def.campo_chave)"
          @update:model-value="v => (valores[def.campo_chave] = v)"
        />
      </div>

      <!-- Decisão (ex: apto/não apto) -->
      <div v-if="comDecisao" class="flex flex-col gap-1.5">
        <label class="text-heading-3 text-n-slate-12">
          {{ t('FOCOH_KANBAN.BLOCO.DECISAO') }}
          <span class="text-n-ruby-9">*</span>
        </label>
        <Select
          :model-value="decisao"
          :options="opcoesDecisao"
          :placeholder="t('FOCOH_KANBAN.CAMPO.SELECIONE')"
          @update:model-value="v => (decisao = v)"
        />
      </div>

      <!-- Alerta de campos faltando -->
      <p
        v-if="tentouEnviar && !podeEnviar"
        class="text-label-small text-n-ruby-11"
      >
        {{
          t('FOCOH_KANBAN.BLOCO.CAMPOS_OBRIGATORIOS_FALTANDO', {
            n: camposFaltando.length,
          })
        }}
      </p>

      <Button
        :label="enviado ? t('FOCOH_KANBAN.BLOCO.ENVIADO') : t('FOCOH_KANBAN.BLOCO.ENVIAR')"
        :is-loading="isSubmitting"
        :disabled="enviado"
        size="sm"
        class="self-start"
        @click="enviar"
      />
    </div>
  </div>
</template>
