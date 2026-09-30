/**
 * Kanban Clínico Rede Focoh — constantes do quadro.
 *
 * Dois programas com quadros distintos: Jornada de Superação (4 fases) e
 * Programa Detox (4 semanas + alta). As fases do Detox reutilizam os mesmos
 * enum values do banco, mas com labels diferentes — nenhuma migration necessária.
 * Fase real por programa é separada via filtro pelo campo `programa` do paciente.
 */

export const FASES_JORNADA = [
  { id: 'admissao_triagem', labelKey: 'ADMISSAO_TRIAGEM', dotClass: 'bg-n-teal-9' },
  { id: 'fase1_autocritica', labelKey: 'FASE_1', dotClass: 'bg-n-blue-9' },
  { id: 'fase2_disciplina', labelKey: 'FASE_2', dotClass: 'bg-n-amber-9' },
  { id: 'fase3_empatia', labelKey: 'FASE_3', dotClass: 'bg-n-amber-11' },
  { id: 'fase4_identidade', labelKey: 'FASE_4', dotClass: 'bg-n-violet-9' },
  { id: 'alta_transicao', labelKey: 'ALTA_TRANSICAO', dotClass: 'bg-n-slate-9' },
];

export const FASES_DETOX = [
  { id: 'admissao_triagem', labelKey: 'DETOX_ADMISSAO', dotClass: 'bg-n-teal-9' },
  { id: 'fase1_autocritica', labelKey: 'DETOX_SEMANA_1', dotClass: 'bg-n-blue-9' },
  { id: 'fase2_disciplina', labelKey: 'DETOX_SEMANA_2', dotClass: 'bg-n-blue-10' },
  { id: 'fase3_empatia', labelKey: 'DETOX_SEMANA_3', dotClass: 'bg-n-amber-9' },
  { id: 'fase4_identidade', labelKey: 'DETOX_SEMANA_4', dotClass: 'bg-n-amber-11' },
  { id: 'alta_transicao', labelKey: 'DETOX_ALTA_POS_ALTA', dotClass: 'bg-n-slate-9' },
];

export const PROGRAMAS = [
  { id: 'jornada_superacao', labelKey: 'PROGRAMA_JORNADA', fases: FASES_JORNADA },
  { id: 'detox_30_dias', labelKey: 'PROGRAMA_DETOX', fases: FASES_DETOX },
];

/**
 * SQLSTATEs levantados pelas travas clínicas no Postgres.
 */
export const CODIGOS_TRAVA = {
  AVANCO_BLOQUEADO: 'FCH01',
  ARQUIVAMENTO_BLOQUEADO: 'FCH02',
  VISITA_BLOQUEADA: 'FCH03',
  PACIENTE_ARQUIVADO: 'FCH04',
  REGRESSAO_SEM_PAPEL_CLINICO: 'FCH05',
  JORNADA_SEQUENCIAL: 'FCH06',
  ADMISSAO_FORA_DA_COLUNA_1: 'FCH07',
};

export const GRUPO_DRAG = 'focoh-kanban';
