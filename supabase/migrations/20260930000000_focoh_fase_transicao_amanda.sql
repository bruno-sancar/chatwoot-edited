-- Separa "Alta Hospitalar e Transição AMANDA" em duas fases distintas.
-- alta_transicao (existente) passa a representar "Alta Hospitalar".
-- transicao_amanda (nova) representa a fase de reintegração AMANDA.
ALTER TYPE focoh_interno.fase_paciente ADD VALUE IF NOT EXISTS 'transicao_amanda' AFTER 'alta_transicao';
