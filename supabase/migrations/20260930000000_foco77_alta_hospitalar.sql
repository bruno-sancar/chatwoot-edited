-- FOCO-77: separar alta_hospitalar de alta_transicao no enum fase_jornada
--
-- A coluna "Alta Hospitalar" da Jornada de Superação agora usa o valor
-- dedicado `alta_hospitalar`. O valor `alta_transicao` continua existindo
-- para o Programa Detox e para retrocompatibilidade com registros antigos.
--
-- IMPORTANTE: ADD VALUE é irreversível no Postgres — não há DROP VALUE.
-- Aplicar apenas uma vez.

ALTER TYPE fase_jornada ADD VALUE IF NOT EXISTS 'alta_hospitalar' BEFORE 'alta_transicao';
