import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';
import KanbanClinicoHome from './Index.vue';

/**
 * Configurações do Kanban Clínico. Gate grosso aqui é o papel Chatwoot
 * 'administrator' (mesmo padrão de Custom Attributes) — quem pode ESCREVER
 * de fato é decidido pela RLS/RPCs no Supabase (papel governança ou flag de
 * editores_configuracao), não por esta permissão. As duas camadas existem
 * de propósito: esta esconde o item de menu de quem obviamente não deveria
 * vê-lo; aquela é a autoridade real.
 */
export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/kanban-clinico'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          redirect: to => {
            return { name: 'kanban_clinico_configuracoes', params: to.params };
          },
        },
        {
          path: 'configuracoes',
          name: 'kanban_clinico_configuracoes',
          component: KanbanClinicoHome,
          meta: {
            permissions: ['administrator'],
          },
        },
      ],
    },
  ],
};
