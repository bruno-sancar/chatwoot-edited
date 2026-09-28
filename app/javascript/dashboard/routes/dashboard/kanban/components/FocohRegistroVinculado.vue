<script setup>
import { ref, computed } from 'vue';
import { useStore } from 'vuex';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';

import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import { getFocohSupabaseClient, obterFocohToken, isFocohConfigurado } from '../focohSupabaseClient';

/**
 * Bloco "Registro vinculado" do sidebar da conversa — o vínculo conversa ↔
 * paciente do Mapa Objetivo ("aparece no painel lateral direito da
 * conversa... de mão dupla"). Guarda a referência em
 * `contact.custom_attributes.focoh_patient_id`: coluna jsonb que já existe
 * no Chatwoot, sem migração nova (ver plano — Decisão de arquitetura 3).
 *
 * O paciente em si nunca é lido daqui como fonte da verdade — só o nome,
 * pra exibição. O quadro clínico continua sendo a única leitura oficial.
 */
const props = defineProps({
  contactId: { type: [Number, String], required: true },
  customAttributes: { type: Object, default: () => ({}) },
});

const { t } = useI18n();
const store = useStore();
const route = useRoute();
const router = useRouter();

const pacienteVinculadoId = computed(() => props.customAttributes?.focoh_patient_id || null);
const nomePacienteVinculado = ref(props.customAttributes?.focoh_patient_nome || '');

const modoVincular = ref(false);
const buscaNome = ref('');
const resultadosBusca = ref([]);
const isBuscando = ref(false);

const atualizarCustomAttribute = async valores => {
  await store.dispatch('contacts/update', {
    id: props.contactId,
    customAttributes: { ...props.customAttributes, ...valores },
  });
};

const abrirRegistro = () => {
  router.push({
    name: 'kanban_clinico_progressao_fase',
    params: { accountId: route.params.accountId, pacienteId: pacienteVinculadoId.value },
  });
};

const criarRegistro = () => {
  // A Ficha de Admissão lê estes query params e, ao criar o paciente,
  // grava o vínculo de volta nesta conversa antes de navegar — ver
  // AdmissaoForm.vue. É o botão "Criar registro" do Mapa Objetivo: abre em
  // branco, sem preenchimento automático a partir da conversa.
  router.push({
    name: 'kanban_clinico_admissao',
    params: { accountId: route.params.accountId },
    query: { vincularContatoId: props.contactId },
  });
};

const buscarPacientes = async () => {
  const supabase = getFocohSupabaseClient();
  if (!supabase || !buscaNome.value.trim()) {
    resultadosBusca.value = [];
    return;
  }

  isBuscando.value = true;
  try {
    await obterFocohToken();
    const { data, error } = await supabase
      .from('pacientes')
      .select('id, nome')
      .ilike('nome', `%${buscaNome.value.trim()}%`)
      .eq('arquivado', false)
      .limit(8);

    if (error) throw error;
    resultadosBusca.value = data ?? [];
  } finally {
    isBuscando.value = false;
  }
};

const vincular = async paciente => {
  await atualizarCustomAttribute({
    focoh_patient_id: paciente.id,
    focoh_patient_nome: paciente.nome,
  });
  nomePacienteVinculado.value = paciente.nome;
  modoVincular.value = false;
  buscaNome.value = '';
  resultadosBusca.value = [];
  useAlert(t('FOCOH_KANBAN.VINCULO.VINCULADO'));
};

const desvincular = async () => {
  const { focoh_patient_id, focoh_patient_nome, ...resto } = props.customAttributes;
  await store.dispatch('contacts/update', { id: props.contactId, customAttributes: resto });
  useAlert(t('FOCOH_KANBAN.VINCULO.DESVINCULADO'));
};
</script>

<template>
  <div v-if="isFocohConfigurado()" class="flex flex-col gap-2 px-1">
    <template v-if="pacienteVinculadoId">
      <button
        type="button"
        class="flex items-center justify-between gap-2 px-3 py-2 text-left border rounded-lg border-n-weak hover:bg-n-slate-2"
        @click="abrirRegistro"
      >
        <span class="truncate text-body-main text-n-slate-12">
          {{ nomePacienteVinculado || pacienteVinculadoId }}
        </span>
        <span class="i-lucide-arrow-up-right size-4 text-n-slate-10 shrink-0" />
      </button>
      <Button
        :label="t('FOCOH_KANBAN.VINCULO.DESVINCULAR')"
        variant="ghost"
        color="ruby"
        size="sm"
        @click="desvincular"
      />
    </template>

    <template v-else-if="modoVincular">
      <Input
        v-model="buscaNome"
        size="sm"
        :placeholder="t('FOCOH_KANBAN.VINCULO.BUSCAR_PLACEHOLDER')"
        @input="buscarPacientes"
      />
      <ul v-if="resultadosBusca.length" class="flex flex-col gap-1">
        <li v-for="paciente in resultadosBusca" :key="paciente.id">
          <button
            type="button"
            class="w-full px-2 py-1 text-left rounded text-body-main text-n-slate-12 hover:bg-n-slate-2"
            @click="vincular(paciente)"
          >
            {{ paciente.nome }}
          </button>
        </li>
      </ul>
      <Button
        :label="t('FOCOH_KANBAN.VINCULO.CANCELAR')"
        variant="ghost"
        size="sm"
        @click="modoVincular = false"
      />
    </template>

    <template v-else>
      <Button
        :label="t('FOCOH_KANBAN.VINCULO.CRIAR_REGISTRO')"
        size="sm"
        @click="criarRegistro"
      />
      <Button
        :label="t('FOCOH_KANBAN.VINCULO.VINCULAR_REGISTRO')"
        variant="outline"
        size="sm"
        @click="modoVincular = true"
      />
    </template>
  </div>
</template>
