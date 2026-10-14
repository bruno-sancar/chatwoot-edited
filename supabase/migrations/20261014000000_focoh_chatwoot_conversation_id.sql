-- Vincula cada paciente à conversa Chatwoot correspondente.
-- Usado pelo PacienteLayout para exibir o link "Ver conversa" no painel direito.
ALTER TABLE pacientes
  ADD COLUMN IF NOT EXISTS chatwoot_conversation_id bigint;
