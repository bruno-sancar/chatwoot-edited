-- ============================================================================
-- Kanban Clínico Rede Focoh — Correções reunião Nayara 23/10/2026
-- FOCO-117: Opção "Não definido" em modalidade_internacao e alojamento
-- FOCO-118: Renomear sigla PCI → PTI no campo alojamento
-- FOCO-119: Campos obrigatórios nome e COREN do enfermeiro na avaliação de risco
-- ============================================================================

-- ----------------------------------------------------------------------------
-- FOCO-118: PCI → PTI no campo alojamento
-- Aplica tanto a labels "UPCI"→"UPTI" quanto "PCI"→"PTI".
-- Também corrige o rótulo do campo se contiver a sigla.
-- ----------------------------------------------------------------------------
UPDATE public.definicoes_formulario
SET
    rotulo = REPLACE(REPLACE(rotulo, 'UPCI', 'UPTI'), 'PCI', 'PTI'),
    opcoes = (
        SELECT jsonb_agg(
            CASE
                WHEN (opcao->>'label') IN ('UPCI', 'PCI')
                THEN jsonb_build_object(
                    'value', REPLACE(REPLACE(opcao->>'value', 'upci', 'upti'), 'pci', 'pti'),
                    'label', REPLACE(REPLACE(opcao->>'label', 'UPCI', 'UPTI'), 'PCI', 'PTI')
                )
                ELSE opcao
            END
            ORDER BY ord
        )
        FROM jsonb_array_elements(opcoes) WITH ORDINALITY AS t(opcao, ord)
    )
WHERE formulario_tipo = 'admissao'
  AND campo_chave = 'alojamento';

-- ----------------------------------------------------------------------------
-- FOCO-117: Adicionar opção "Não definido" como primeira opção em
-- modalidade_internacao e alojamento (admissões emergenciais).
-- A opção tem valor 'nao_definido' (string não vazia) para passar na validação
-- de campo obrigatório — o profissional precisa escolher explicitamente.
-- ----------------------------------------------------------------------------
UPDATE public.definicoes_formulario
SET opcoes = jsonb_build_array(
    '{"value":"nao_definido","label":"— Não definido (a definir) —"}'::jsonb
) || opcoes
WHERE formulario_tipo = 'admissao'
  AND campo_chave IN ('modalidade_internacao', 'alojamento')
  AND NOT EXISTS (
    SELECT 1 FROM jsonb_array_elements(opcoes) o WHERE o->>'value' = 'nao_definido'
  );

-- ----------------------------------------------------------------------------
-- FOCO-119: Campos nome e COREN do enfermeiro na avaliação de risco.
-- Obrigatórios para validade legal. programa=null → vale para todos os
-- programas (filtro do composable: "igual OU nulo"). Ordem 90/91 → aparecem
-- ao final do formulário, antes do botão de envio.
-- ----------------------------------------------------------------------------
INSERT INTO public.definicoes_formulario
    (programa, formulario_tipo, etapa, bloco, campo_chave, rotulo, tipo_campo, obrigatorio, natureza, ordem, ativo)
VALUES
    (null, 'avaliacao_risco', null, null, 'nome_enfermeiro',  'Nome do Enfermeiro',  'texto', true, 'historico', 90, true),
    (null, 'avaliacao_risco', null, null, 'coren_enfermeiro', 'COREN do Enfermeiro', 'texto', true, 'historico', 91, true)
ON CONFLICT ON CONSTRAINT definicoes_formulario_chave_unica DO NOTHING;
