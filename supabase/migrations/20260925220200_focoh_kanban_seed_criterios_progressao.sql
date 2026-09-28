-- ============================================================================
-- Kanban Clínico Rede Focoh — 20/20 · seed dos critérios reais do Anexo 1
-- ----------------------------------------------------------------------------
-- Conteúdo transcrito literalmente de `anexo fases.pdf` (Formulário Oficial
-- de Avaliação de Progressão de Fases). É o dado inicial do catálogo — depois
-- do primeiro deploy, a equipe da clínica edita pelo painel de configuração,
-- não mais por migration.
--
-- Cada checkbox é `obrigatorio = false`: o documento pede "marcar apenas
-- quando comportamento confirma", ou seja, um item desmarcado é informação
-- válida (o critério não foi observado), não um formulário incompleto. Quem
-- decide "Apto/Não apto" por bloco é o avaliador, no campo de decisão —
-- estes checkboxes são a evidência, não o veredito.
-- ============================================================================

insert into public.definicoes_formulario
  (programa, formulario_tipo, etapa, bloco, campo_chave, rotulo, tipo_campo, natureza, ordem)
values
-- ---------------------------------------------------------------- F1 -> F2 --
('jornada_superacao', 'progressao_fase', 'f1_f2', 'clinico', 'sintomas_agudos_controlados', 'Sintomas agudos controlados', 'checkbox', 'historico', 1),
('jornada_superacao', 'progressao_fase', 'f1_f2', 'clinico', 'ausencia_abstinencia_ativa', 'Ausência de quadro de abstinência ativa', 'checkbox', 'historico', 2),
('jornada_superacao', 'progressao_fase', 'f1_f2', 'clinico', 'estabilidade_clinica_minima', 'Estabilidade clínica mínima mantida', 'checkbox', 'historico', 3),
('jornada_superacao', 'progressao_fase', 'f1_f2', 'clinico', 'medicacoes_sintomaticas_estaveis', 'Medicações sintomáticas em regime estável', 'checkbox', 'historico', 4),
('jornada_superacao', 'progressao_fase', 'f1_f2', 'clinico', 'ausencia_intercorrencia_recente', 'Nenhuma intercorrência clínica recente', 'checkbox', 'historico', 5),
('jornada_superacao', 'progressao_fase', 'f1_f2', 'clinico', 'parecer_texto', 'Parecer do Médico Psiquiatra de Referência', 'texto_longo', 'historico', 6),

('jornada_superacao', 'progressao_fase', 'f1_f2', 'terapeutico', 'reducao_negacao', 'Redução clara da negação (verbal e comportamental)', 'checkbox', 'historico', 1),
('jornada_superacao', 'progressao_fase', 'f1_f2', 'terapeutico', 'reconhecimento_adoecimento', 'Reconhecimento do básico do adoecimento (mesmo parcial)', 'checkbox', 'historico', 2),
('jornada_superacao', 'progressao_fase', 'f1_f2', 'terapeutico', 'participacao_ativa_processo', 'Participação ativa no processo terapêutico (mesmo por supervisão)', 'checkbox', 'historico', 3),
('jornada_superacao', 'progressao_fase', 'f1_f2', 'terapeutico', 'reducao_discursos_defensivos', 'Redução de discursos defensivos (vitimização)', 'checkbox', 'historico', 4),
('jornada_superacao', 'progressao_fase', 'f1_f2', 'terapeutico', 'capacidade_escuta_sem_confronto', 'Capacidade de escuta sem confronto recorrente', 'checkbox', 'historico', 5),
('jornada_superacao', 'progressao_fase', 'f1_f2', 'terapeutico', 'observacoes_evidencias', 'Observações / evidências observáveis (exemplos concretos)', 'texto_longo', 'historico', 6),

('jornada_superacao', 'progressao_fase', 'f1_f2', 'disciplinar', 'organizacao_pessoal_quarto', 'Organização básica pessoal e do quarto mantida', 'checkbox', 'historico', 1),
('jornada_superacao', 'progressao_fase', 'f1_f2', 'disciplinar', 'adesao_normas', 'Adesão às normas institucionais', 'checkbox', 'historico', 2),
('jornada_superacao', 'progressao_fase', 'f1_f2', 'disciplinar', 'comprometimento_prescricao', 'Comprometimento com sua prescrição (autorresponsabilidade nas medicações)', 'checkbox', 'historico', 3),
('jornada_superacao', 'progressao_fase', 'f1_f2', 'disciplinar', 'participacao_propostas_terapeuticas', 'Participação ativa mínima nas propostas terapêuticas', 'checkbox', 'historico', 4),
('jornada_superacao', 'progressao_fase', 'f1_f2', 'disciplinar', 'higiene_sono', 'Higiene do Sono restabelecida', 'checkbox', 'historico', 5),
('jornada_superacao', 'progressao_fase', 'f1_f2', 'disciplinar', 'alimentacao_menor_impulsividade', 'Alimentação com menor impulsividade', 'checkbox', 'historico', 6),
('jornada_superacao', 'progressao_fase', 'f1_f2', 'disciplinar', 'autocuidado_basico', 'Autocuidado básico preservado', 'checkbox', 'historico', 7),
('jornada_superacao', 'progressao_fase', 'f1_f2', 'disciplinar', 'atividade_fisica', 'Atividade física conforme condição clínica', 'checkbox', 'historico', 8),
('jornada_superacao', 'progressao_fase', 'f1_f2', 'disciplinar', 'reducao_opositores', 'Redução de comportamentos opositores', 'checkbox', 'historico', 9),

('jornada_superacao', 'progressao_fase', 'f1_f2', 'risco_sustentabilidade', 'discursos_defensivos_rigidos', 'Discursos defensivos rígidos (sem evolução)', 'checkbox', 'historico', 1),
('jornada_superacao', 'progressao_fase', 'f1_f2', 'risco_sustentabilidade', 'sem_escuta_confronto_constante', 'Sem capacidade de escuta e com confronto constante', 'checkbox', 'historico', 2),
('jornada_superacao', 'progressao_fase', 'f1_f2', 'risco_sustentabilidade', 'manipulacao_processo', 'Manipulação ativa do processo', 'checkbox', 'historico', 3),
('jornada_superacao', 'progressao_fase', 'f1_f2', 'risco_sustentabilidade', 'testagem_limites', 'Testagem deliberada de limites', 'checkbox', 'historico', 4),
('jornada_superacao', 'progressao_fase', 'f1_f2', 'risco_sustentabilidade', 'impulsividade_aguda', 'Impulsividade aguda', 'checkbox', 'historico', 5),

-- ---------------------------------------------------------------- F2 -> F3 --
('jornada_superacao', 'progressao_fase', 'f2_f3', 'clinico', 'diagnostico_estabelecido', 'Diagnóstico principal estabelecido', 'checkbox', 'historico', 1),
('jornada_superacao', 'progressao_fase', 'f2_f3', 'clinico', 'comorbidades_mapeadas', 'Comorbidades mapeadas e em manejo', 'checkbox', 'historico', 2),
('jornada_superacao', 'progressao_fase', 'f2_f3', 'clinico', 'medicacao_reduzida_estabilizada', 'Uso de medicação sintomática reduzido ou estabilizado', 'checkbox', 'historico', 3),
('jornada_superacao', 'progressao_fase', 'f2_f3', 'clinico', 'boa_adesao_plano_medico', 'Boa adesão ao plano médico', 'checkbox', 'historico', 4),
('jornada_superacao', 'progressao_fase', 'f2_f3', 'clinico', 'ausencia_abstinencia_ativa', 'Ausência de quadro de abstinência ativa', 'checkbox', 'historico', 5),
('jornada_superacao', 'progressao_fase', 'f2_f3', 'clinico', 'ausencia_intercorrencia_recente', 'Nenhuma intercorrência clínica recente', 'checkbox', 'historico', 6),
('jornada_superacao', 'progressao_fase', 'f2_f3', 'clinico', 'parecer_texto', 'Parecer do Médico Psiquiatra de Referência', 'texto_longo', 'historico', 7),

('jornada_superacao', 'progressao_fase', 'f2_f3', 'terapeutico', 'projeto_vida_validado', 'Projeto de Vida validado pelo gerente de caso (longo, médio e curto prazo)', 'checkbox', 'historico', 1),
('jornada_superacao', 'progressao_fase', 'f2_f3', 'terapeutico', 'reflexao_sem_vitimizacao', 'Capacidade de reflexão sem vitimização constante', 'checkbox', 'historico', 2),
('jornada_superacao', 'progressao_fase', 'f2_f3', 'terapeutico', 'reconhecimento_padroes_repetitivos', 'Reconhecimento de padrões repetitivos de comportamento', 'checkbox', 'historico', 3),
('jornada_superacao', 'progressao_fase', 'f2_f3', 'terapeutico', 'abertura_mudanca', 'Abertura para mudança (não apenas discurso)', 'checkbox', 'historico', 4),
('jornada_superacao', 'progressao_fase', 'f2_f3', 'terapeutico', 'participacao_consistente', 'Participação consistente no processo terapêutico', 'checkbox', 'historico', 5),
('jornada_superacao', 'progressao_fase', 'f2_f3', 'terapeutico', 'rede_apoio_estruturada', 'Rede de Apoio estruturada e alinhada à jornada do paciente (sabotadores e apoiadores identificados)', 'checkbox', 'historico', 6),
('jornada_superacao', 'progressao_fase', 'f2_f3', 'terapeutico', 'observacoes_evidencias', 'Observações / evidências observáveis (exemplos concretos)', 'texto_longo', 'historico', 7),

('jornada_superacao', 'progressao_fase', 'f2_f3', 'disciplinar', 'rotina_sem_supervisao', 'Rotina cumprida sem supervisão constante', 'checkbox', 'historico', 1),
('jornada_superacao', 'progressao_fase', 'f2_f3', 'disciplinar', 'organizacao_pessoal_consistente', 'Organização pessoal consistente', 'checkbox', 'historico', 2),
('jornada_superacao', 'progressao_fase', 'f2_f3', 'disciplinar', 'alimentacao_menor_impulsividade', 'Alimentação com menor impulsividade', 'checkbox', 'historico', 3),
('jornada_superacao', 'progressao_fase', 'f2_f3', 'disciplinar', 'atividade_fisica_habito', 'Atividade física incorporada como hábito', 'checkbox', 'historico', 4),
('jornada_superacao', 'progressao_fase', 'f2_f3', 'disciplinar', 'relacoes_interpessoais_estaveis', 'Relações interpessoais mais estáveis', 'checkbox', 'historico', 5),

('jornada_superacao', 'progressao_fase', 'f2_f3', 'risco_sustentabilidade', 'manipulacao_processo', 'Manipulação ativa do processo', 'checkbox', 'historico', 1),
('jornada_superacao', 'progressao_fase', 'f2_f3', 'risco_sustentabilidade', 'testagem_limites', 'Testagem deliberada de limites', 'checkbox', 'historico', 2),
('jornada_superacao', 'progressao_fase', 'f2_f3', 'risco_sustentabilidade', 'oscilacoes_comportamentos_sabotadores', 'Oscilações claras de comportamentos sabotadores', 'checkbox', 'historico', 3),
('jornada_superacao', 'progressao_fase', 'f2_f3', 'risco_sustentabilidade', 'necessidade_contencao_verbal', 'Maior necessidade de contenção verbal', 'checkbox', 'historico', 4),
('jornada_superacao', 'progressao_fase', 'f2_f3', 'risco_sustentabilidade', 'incapacidade_pedir_ajuda', 'Incapacidade de pedir ajuda antes de agir', 'checkbox', 'historico', 5),

-- ---------------------------------------------------------------- F3 -> F4 --
('jornada_superacao', 'progressao_fase', 'f3_f4', 'clinico', 'estabilidade_psiquiatrica_sustentada', 'Estabilidade psiquiátrica sustentada', 'checkbox', 'historico', 1),
('jornada_superacao', 'progressao_fase', 'f3_f4', 'clinico', 'uso_minimo_medicacao_sos', 'Uso mínimo ou inexistente de medicação SOS', 'checkbox', 'historico', 2),
('jornada_superacao', 'progressao_fase', 'f3_f4', 'clinico', 'avaliacao_neuropsicologica_integrada', 'Avaliação neuropsicológica integrada ao plano (se indicado)', 'checkbox', 'historico', 3),
('jornada_superacao', 'progressao_fase', 'f3_f4', 'clinico', 'boa_adesao_planejamento_ambulatorial', 'Boa adesão na construção do planejamento do tratamento ambulatorial', 'checkbox', 'historico', 4),
('jornada_superacao', 'progressao_fase', 'f3_f4', 'clinico', 'parecer_texto', 'Parecer do Médico Psiquiatra de Referência', 'texto_longo', 'historico', 5),

('jornada_superacao', 'progressao_fase', 'f3_f4', 'terapeutico', 'reconhecimento_gatilhos', 'Reconhecimento claro de gatilhos pessoais', 'checkbox', 'historico', 1),
('jornada_superacao', 'progressao_fase', 'f3_f4', 'terapeutico', 'uso_estrategias_enfrentamento', 'Uso prático de estratégias de enfrentamento', 'checkbox', 'historico', 2),
('jornada_superacao', 'progressao_fase', 'f3_f4', 'terapeutico', 'autorresponsabilidade_escolhas', 'Autorresponsabilidade sobre escolhas', 'checkbox', 'historico', 3),
('jornada_superacao', 'progressao_fase', 'f3_f4', 'terapeutico', 'capacidade_lidar_frustracao', 'Capacidade de lidar com frustração sem fuga', 'checkbox', 'historico', 4),
('jornada_superacao', 'progressao_fase', 'f3_f4', 'terapeutico', 'empatia_real_reciproca', 'Empatia real (não performática) recíproca entre paciente e rede de apoio', 'checkbox', 'historico', 5),
('jornada_superacao', 'progressao_fase', 'f3_f4', 'terapeutico', 'alinhamento_rede_apoio_projeto_vida', 'Alinhamento da Rede de Apoio com o Projeto de Vida do paciente', 'checkbox', 'historico', 6),
('jornada_superacao', 'progressao_fase', 'f3_f4', 'terapeutico', 'observacoes_evidencias', 'Observações / evidências observáveis (exemplos concretos)', 'texto_longo', 'historico', 7),

('jornada_superacao', 'progressao_fase', 'f3_f4', 'disciplinar', 'rotina_sustentada_sem_vigilancia', 'Rotina sustentada sem vigilância', 'checkbox', 'historico', 1),
('jornada_superacao', 'progressao_fase', 'f3_f4', 'disciplinar', 'limites_por_escolha', 'Limites respeitados por escolha, não por medo', 'checkbox', 'historico', 2),
('jornada_superacao', 'progressao_fase', 'f3_f4', 'disciplinar', 'alimentacao_autocuidado_decisao', 'Alimentação e autocuidado como decisão consciente', 'checkbox', 'historico', 3),
('jornada_superacao', 'progressao_fase', 'f3_f4', 'disciplinar', 'atividade_fisica_mantida', 'Atividade física mantida', 'checkbox', 'historico', 4),
('jornada_superacao', 'progressao_fase', 'f3_f4', 'disciplinar', 'postura_gratidao', 'Postura de gratidão aplicada ao cotidiano, principalmente à rede de apoio', 'checkbox', 'historico', 5),

('jornada_superacao', 'progressao_fase', 'f3_f4', 'risco_sustentabilidade', 'incapacidade_antecipar_risco', 'Incapacidade de antecipar risco', 'checkbox', 'historico', 1),
('jornada_superacao', 'progressao_fase', 'f3_f4', 'risco_sustentabilidade', 'nao_procura_ajuda_antes_crise', 'Não procura ajuda antes da crise', 'checkbox', 'historico', 2),
('jornada_superacao', 'progressao_fase', 'f3_f4', 'risco_sustentabilidade', 'romantiza_recaida', 'Romantiza recaída', 'checkbox', 'historico', 3),
('jornada_superacao', 'progressao_fase', 'f3_f4', 'risco_sustentabilidade', 'testa_autonomia_fora_combinado', 'Testa "autonomia" fora do combinado', 'checkbox', 'historico', 4),

-- -------------------------------------------------------------- F4 -> Alta --
('jornada_superacao', 'progressao_fase', 'f4_alta', 'clinico', 'estabilidade_psiquiatrica_fora_ambiente', 'Estabilidade psiquiátrica mantida fora do ambiente protegido', 'checkbox', 'historico', 1),
('jornada_superacao', 'progressao_fase', 'f4_alta', 'clinico', 'uso_minimo_medicacao_sos', 'Uso mínimo ou inexistente de medicação SOS', 'checkbox', 'historico', 2),
('jornada_superacao', 'progressao_fase', 'f4_alta', 'clinico', 'adesao_plano_ambulatorial_amanda', 'Adesão consistente ao plano médico ambulatorial AMANDA', 'checkbox', 'historico', 3),
('jornada_superacao', 'progressao_fase', 'f4_alta', 'clinico', 'reconhece_sinais_precoces', 'Capacidade de reconhecer sinais precoces de desorganização clínica', 'checkbox', 'historico', 4),
('jornada_superacao', 'progressao_fase', 'f4_alta', 'clinico', 'ausencia_intercorrencia_recente', 'Não houve intercorrências clínicas recentes relacionadas a impulsividade ou recaída', 'checkbox', 'historico', 5),
('jornada_superacao', 'progressao_fase', 'f4_alta', 'clinico', 'parecer_texto', 'Parecer do Médico Psiquiatra de Referência', 'texto_longo', 'historico', 6),

('jornada_superacao', 'progressao_fase', 'f4_alta', 'terapeutico', 'age_empatia_rede_apoio', 'Age com empatia com sua rede de apoio', 'checkbox', 'historico', 1),
('jornada_superacao', 'progressao_fase', 'f4_alta', 'terapeutico', 'sustenta_autorresponsabilidade', 'Sustenta autorresponsabilidade sem terceirização', 'checkbox', 'historico', 2),
('jornada_superacao', 'progressao_fase', 'f4_alta', 'terapeutico', 'reconhece_gatilhos_age_preventivamente', 'Reconhece gatilhos e age preventivamente', 'checkbox', 'historico', 3),
('jornada_superacao', 'progressao_fase', 'f4_alta', 'terapeutico', 'usa_estrategias_sem_contencao', 'Usa estratégias de enfrentamento sem depender de contenção externa', 'checkbox', 'historico', 4),
('jornada_superacao', 'progressao_fase', 'f4_alta', 'terapeutico', 'tolera_frustracao_sem_fuga', 'Tolera frustração sem fuga, sabotagem ou vitimização', 'checkbox', 'historico', 5),
('jornada_superacao', 'progressao_fase', 'f4_alta', 'terapeutico', 'capacidade_pedir_ajuda_antes_crise', 'Capacidade real de pedir ajuda antes da crise', 'checkbox', 'historico', 6),
('jornada_superacao', 'progressao_fase', 'f4_alta', 'terapeutico', 'vinculo_ativo_amanda', 'Vínculo ativo, contínuo e comprometido com o Programa AMANDA', 'checkbox', 'historico', 7),
('jornada_superacao', 'progressao_fase', 'f4_alta', 'terapeutico', 'observacoes_evidencias', 'Observações / evidências observáveis (exemplos concretos)', 'texto_longo', 'historico', 8),

('jornada_superacao', 'progressao_fase', 'f4_alta', 'disciplinar', 'rotina_estruturada_fora_instituicao', 'Rotina estruturada e mantida fora da instituição', 'checkbox', 'historico', 1),
('jornada_superacao', 'progressao_fase', 'f4_alta', 'disciplinar', 'cumpre_limites_por_escolha', 'Cumpre limites por escolha, não por medo', 'checkbox', 'historico', 2),
('jornada_superacao', 'progressao_fase', 'f4_alta', 'disciplinar', 'organizacao_pessoal_financeira', 'Organização pessoal e financeira compatível com sua realidade', 'checkbox', 'historico', 3),
('jornada_superacao', 'progressao_fase', 'f4_alta', 'disciplinar', 'alimentacao_sono_autocuidado_sustentados', 'Alimentação, sono e autocuidado sustentados', 'checkbox', 'historico', 4),
('jornada_superacao', 'progressao_fase', 'f4_alta', 'disciplinar', 'atividade_fisica_habito', 'Atividade física incorporada como hábito', 'checkbox', 'historico', 5),
('jornada_superacao', 'progressao_fase', 'f4_alta', 'disciplinar', 'postura_ativa_responsabilidade', 'Postura ativa de responsabilidade com a própria vida', 'checkbox', 'historico', 6),

('jornada_superacao', 'progressao_fase', 'f4_alta', 'risco_sustentabilidade', 'romantiza_recaida_minimiza_riscos', 'Romantiza recaída ou minimiza riscos', 'checkbox', 'historico', 1),
('jornada_superacao', 'progressao_fase', 'f4_alta', 'risco_sustentabilidade', 'testa_autonomia_fora_combinados', 'Testa autonomia fora dos combinados', 'checkbox', 'historico', 2),
('jornada_superacao', 'progressao_fase', 'f4_alta', 'risco_sustentabilidade', 'rede_apoio_desalinhada_90_dias', 'Rede de Apoio em desalinhamento para os próximos 90 dias', 'checkbox', 'historico', 3),
('jornada_superacao', 'progressao_fase', 'f4_alta', 'risco_sustentabilidade', 'oscilacoes_comportamentais_significativas', 'Oscilações comportamentais significativas', 'checkbox', 'historico', 4),
('jornada_superacao', 'progressao_fase', 'f4_alta', 'risco_sustentabilidade', 'historico_autoengano_omissao', 'Histórico recente de autoengano ou omissão', 'checkbox', 'historico', 5),

-- Bloco 4.A, exclusivo da transição F4 -> Alta
('jornada_superacao', 'progressao_fase', 'f4_alta', 'rede_apoio_continuidade', 'rede_apoio_orientada_alinhada', 'Rede de Apoio orientada e alinhada aos combinados', 'checkbox', 'historico', 1),
('jornada_superacao', 'progressao_fase', 'f4_alta', 'rede_apoio_continuidade', 'familia_compreende_riscos', 'Família compreende riscos reais do pós-alta', 'checkbox', 'historico', 2),
('jornada_superacao', 'progressao_fase', 'f4_alta', 'rede_apoio_continuidade', 'sem_pactos_implicitos_permissividade', 'Não há pactos implícitos de permissividade', 'checkbox', 'historico', 3),
('jornada_superacao', 'progressao_fase', 'f4_alta', 'rede_apoio_continuidade', 'combinados_claros_moradia_rotina', 'Combinados claros sobre moradia, rotina, finanças e responsabilidades', 'checkbox', 'historico', 4),
('jornada_superacao', 'progressao_fase', 'f4_alta', 'rede_apoio_continuidade', 'rede_reconhece_amanda_tratamento', 'Rede reconhece AMANDA como parte do tratamento, não como opção', 'checkbox', 'historico', 5),

-- -------------------------------------------------- Escala de Risco de Suicídio --
-- Único formulário_tipo fora de 'progressao_fase' — recorrência própria
-- (diária/3x/2x por semana conforme a última classificação), não por fase.
('jornada_superacao', 'avaliacao_risco', null, null, 'comunicacao', 'Comunicação (1=plano verbalizado … 4=não fala de morte)', 'numero', 'historico', 1),
('jornada_superacao', 'avaliacao_risco', null, null, 'antecedentes_suicidas', 'Antecedentes suicidas (1=tentativa alta letalidade … 4=nunca tentou)', 'numero', 'historico', 2),
('jornada_superacao', 'avaliacao_risco', null, null, 'estado_mental', 'Estado mental (1=vozes de comando … 4=sem alterações)', 'numero', 'historico', 3),
('jornada_superacao', 'avaliacao_risco', null, null, 'padrao_comportamental', 'Padrão comportamental (1=impulsividade … 4=adequado ao contexto)', 'numero', 'historico', 4),
('jornada_superacao', 'avaliacao_risco', null, null, 'fatores_predisponentes', 'Fatores predisponentes/precipitantes (1=história de abusos … 4=sem correlatos)', 'numero', 'historico', 5),
('jornada_superacao', 'avaliacao_risco', null, null, 'ideacao_detalhes', 'Detalhes da ideação (texto restrito, nunca aparece no cartão)', 'texto_longo', 'historico', 6),

-- -------------------------------------------------- Ficha de Admissão — Aba A --
-- natureza = 'cadastral': um valor por paciente, grava em
-- pacientes.nome/pacientes.dados_cadastrais, não em respostas_formulario.
(null, 'admissao', 'aba_a', 'identificacao', 'nome', 'Nome do paciente', 'texto', 'cadastral', 1),
(null, 'admissao', 'aba_a', 'identificacao', 'como_e_chamado', 'Como é chamado (apelido de uso interno)', 'texto', 'cadastral', 2),
(null, 'admissao', 'aba_a', 'identificacao', 'data_nascimento', 'Data de nascimento', 'data', 'cadastral', 3),
(null, 'admissao', 'aba_a', 'identificacao', 'cpf', 'CPF', 'texto', 'cadastral', 4),
(null, 'admissao', 'aba_a', 'identificacao', 'principal_contato', 'Principal contato (telefone)', 'texto', 'cadastral', 5),
(null, 'admissao', 'aba_a', 'identificacao', 'data_internacao', 'Data de internação', 'data', 'cadastral', 6),
(null, 'admissao', 'aba_a', 'identificacao', 'modalidade_internacao', 'Modalidade de internação', 'selecao', 'cadastral', 7),
(null, 'admissao', 'aba_a', 'identificacao', 'alojamento', 'Alojamento (UPCI / Suíte comum)', 'selecao', 'cadastral', 8);

update public.definicoes_formulario
   set opcoes = '[{"value":"voluntaria","label":"Voluntária"},{"value":"involuntaria","label":"Involuntária"},{"value":"compulsoria","label":"Compulsória"}]'::jsonb
 where formulario_tipo = 'admissao' and campo_chave = 'modalidade_internacao';

update public.definicoes_formulario
   set opcoes = '[{"value":"upci","label":"UPCI"},{"value":"suite_comum","label":"Suíte comum"}]'::jsonb
 where formulario_tipo = 'admissao' and campo_chave = 'alojamento';

-- Campos marcados obrigatório no documento oficial (identificação e rede de
-- apoio na admissão; decisão final na progressão continua sendo um campo à
-- parte na tela, não uma propriedade do catálogo).
update public.definicoes_formulario
   set obrigatorio = true
 where formulario_tipo = 'admissao'
   and campo_chave in ('nome', 'data_nascimento', 'cpf', 'principal_contato', 'data_internacao', 'modalidade_internacao', 'alojamento');

update public.definicoes_formulario
   set obrigatorio = true
 where formulario_tipo = 'avaliacao_risco'
   and campo_chave in ('comunicacao', 'antecedentes_suicidas', 'estado_mental', 'padrao_comportamental', 'fatores_predisponentes');
