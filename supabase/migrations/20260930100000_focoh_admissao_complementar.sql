-- Seed: Ficha de Admissão Complementar (Aba B/C)
-- Bloco historico_clinico + rede_apoio, etapa='aba_bc'
-- formulario_tipo='admissao', sem etapa conflicts com aba_a

INSERT INTO definicoes_formulario
  (formulario_tipo, etapa, bloco, campo_chave, rotulo, tipo_campo, opcoes, obrigatorio, ordem)
VALUES
  -- Bloco 1: Histórico Clínico
  ('admissao', 'aba_bc', 'historico_clinico', 'motivo_internacao',       'Motivo da internação',                          'texto_longo',   NULL, true,  1),
  ('admissao', 'aba_bc', 'historico_clinico', 'historico_substancias',   'Histórico de uso de substâncias',               'texto_longo',   NULL, false, 2),
  ('admissao', 'aba_bc', 'historico_clinico', 'historico_psiquiatrico',  'Histórico psiquiátrico anterior',               'texto_longo',   NULL, false, 3),
  ('admissao', 'aba_bc', 'historico_clinico', 'medicamentos_uso',        'Medicamentos em uso na internação',             'texto_longo',   NULL, false, 4),
  ('admissao', 'aba_bc', 'historico_clinico', 'alergias',                'Alergias e reações adversas conhecidas',        'texto',         NULL, false, 5),
  ('admissao', 'aba_bc', 'historico_clinico', 'comorbidades',            'Comorbidades clínicas',                         'texto_longo',   NULL, false, 6),

  -- Bloco 2: Rede de Apoio e Contatos
  ('admissao', 'aba_bc', 'rede_apoio', 'responsavel_nome',              'Nome do responsável familiar',                  'texto',         NULL, true,  1),
  ('admissao', 'aba_bc', 'rede_apoio', 'responsavel_relacao',           'Grau de parentesco',                            'selecao',
    '[{"valor":"mae","rotulo":"Mãe"},{"valor":"pai","rotulo":"Pai"},{"valor":"conjuge","rotulo":"Cônjuge/Companheiro(a)"},{"valor":"filho","rotulo":"Filho(a)"},{"valor":"irmao","rotulo":"Irmão/Irmã"},{"valor":"amigo","rotulo":"Amigo(a)"},{"valor":"outro","rotulo":"Outro"}]'::jsonb,
    false, 2),
  ('admissao', 'aba_bc', 'rede_apoio', 'responsavel_telefone',          'Telefone do responsável',                       'texto',         NULL, false, 3),
  ('admissao', 'aba_bc', 'rede_apoio', 'contato_emergencia_nome',       'Contato de emergência (se diferente)',          'texto',         NULL, false, 4),
  ('admissao', 'aba_bc', 'rede_apoio', 'contato_emergencia_telefone',   'Telefone emergência',                           'texto',         NULL, false, 5),
  ('admissao', 'aba_bc', 'rede_apoio', 'observacoes_admissao',          'Observações e informações adicionais',          'texto_longo',   NULL, false, 6);
