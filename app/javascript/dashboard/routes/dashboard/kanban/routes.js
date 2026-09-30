import { CONVERSATION_PERMISSIONS, ROLES } from 'dashboard/constants/permissions';
import { frontendURL } from '../../../helper/URLHelper';
import KanbanIndex from './pages/KanbanIndex.vue';
import AdmissaoForm from './pages/AdmissaoForm.vue';
import PacienteLayout from './pages/PacienteLayout.vue';
import ProgressaoFaseForm from './pages/ProgressaoFaseForm.vue';
import AvaliacaoRiscoForm from './pages/AvaliacaoRiscoForm.vue';
import HistoricoPaciente from './pages/HistoricoPaciente.vue';
import LaudoSemanalForm from './pages/LaudoSemanalForm.vue';
import FichaAdmissaoForm from './pages/FichaAdmissaoForm.vue';
import KanbanConfiguracoes from './pages/KanbanConfiguracoes.vue';

const PATIENT_META = { permissions: [...ROLES, ...CONVERSATION_PERMISSIONS] };

export const routes = [
  {
    path: frontendURL('accounts/:accountId/kanban'),
    name: 'kanban_clinico_index',
    component: KanbanIndex,
    meta: PATIENT_META,
  },
  {
    path: frontendURL('accounts/:accountId/kanban/admissao'),
    name: 'kanban_clinico_admissao',
    component: AdmissaoForm,
    meta: PATIENT_META,
  },
  {
    path: frontendURL('accounts/:accountId/kanban/pacientes/:pacienteId'),
    component: PacienteLayout,
    redirect: to => ({ name: 'kanban_clinico_ficha_admissao', params: to.params }),
    meta: PATIENT_META,
    children: [
      {
        path: 'progressao',
        name: 'kanban_clinico_progressao_fase',
        component: ProgressaoFaseForm,
        meta: PATIENT_META,
      },
      {
        path: 'risco',
        name: 'kanban_clinico_avaliacao_risco',
        component: AvaliacaoRiscoForm,
        meta: PATIENT_META,
      },
      {
        path: 'historico',
        name: 'kanban_clinico_historico_paciente',
        component: HistoricoPaciente,
        meta: PATIENT_META,
      },
      {
        path: 'laudo',
        name: 'kanban_clinico_laudo_semanal',
        component: LaudoSemanalForm,
        meta: PATIENT_META,
      },
      {
        path: 'ficha',
        name: 'kanban_clinico_ficha_admissao',
        component: FichaAdmissaoForm,
        meta: PATIENT_META,
      },
    ],
  },
  {
    path: frontendURL('accounts/:accountId/kanban/configuracoes'),
    name: 'kanban_clinico_configuracoes',
    component: KanbanConfiguracoes,
    meta: PATIENT_META,
  },
];
