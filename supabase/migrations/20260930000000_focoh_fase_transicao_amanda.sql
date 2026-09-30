-- Separa "Alta Hospitalar e Transicao AMANDA" em duas fases distintas.
-- alta_transicao (existente) representa Alta Hospitalar.
-- transicao_amanda (nova) representa a fase de reintegracao AMANDA.
-- Nota: o enum esta em public.fase_jornada (nao focoh_interno.fase_paciente).
ALTER TYPE public.fase_jornada ADD VALUE IF NOT EXISTS 'transicao_amanda' AFTER 'alta_transicao';