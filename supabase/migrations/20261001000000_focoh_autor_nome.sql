-- FOCO-78: adiciona autor_nome em respostas_formulario para exibir o nome
-- do usuário que realizou cada envio no histórico do paciente.
alter table public.respostas_formulario
  add column if not exists autor_nome text;
