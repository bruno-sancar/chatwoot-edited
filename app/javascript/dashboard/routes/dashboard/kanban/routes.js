import { CONVERSATION_PERMISSIONS, ROLES } from 'dashboard/constants/permissions';
import { frontendURL } from '../../../helper/URLHelper';
import KanbanIndex from './pages/KanbanIndex.vue';
import AdmissaoForm from './pages/AdmissaoForm.vue';
import ProgressaoFaseForm from './pages/ProgressaoFaseForm.vue';
import AvaliacaoRiscoForm from './pages/AvaliacaoRiscoForm.vue';
import HistoricoPaciente from './pages/HistoricoPaciente.vue';
import LaudoSemanalForm from './pages/LaudoSemanalForm.vue';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/kanban'),
    name: 'kanban_clinico_index',
    component: KanbanIndex,
    meta: {
      permissions: [...ROLES, ...CONVERSATION_PERMISSIONS],
    },
  },
  {
    path: frontendURL('accounts/:accountId/kanban/admissao'),
    name: 'kanban_clinico_admissao',
    component: AdmissaoForm,
    meta: {
      permissions: [...ROLES, ...CONVERSATION_PERMISSIONS],
    },
  },
  {
    path: frontendURL('accounts/:accountId/kanban/pacientes/:pacienteId/progressao'),
    name: 'kanban_clinico_progressao_fase',
    component: ProgressaoFaseForm,
    meta: {
      permissions: [...ROLES, ...CONVERSATION_PERMISSIONS],
    },
  },
  {
    path: frontendURL('accounts/:accountId/kanban/pacientes/:pacienteId/risco'),
    name: 'kanban_clinico_avaliacao_risco',
    component: AvaliacaoRiscoForm,
    meta: {
      permissions: [...ROLES, ...CONVERSATION_PERMISSIONS],
    },
  },
  {
    path: frontendURL('accounts/:accountId/kanban/pacientes/:pacienteId/historico'),
    name: 'kanban_clinico_historico_paciente',
    component: HistoricoPaciente,
    meta: {
      permissions: [...ROLES, ...CONVERSATION_PERMISSIONS],
    },
  },
  {
    path: frontendURL('accounts/:accountId/kanban/pacientes/:pacienteId/laudo'),
    name: 'kanban_clinico_laudo_semanal',
    component: LaudoSemanalForm,
    meta: {
      permissions: [...ROLES, ...CONVERSATION_PERMISSIONS],
    },
  },
];
