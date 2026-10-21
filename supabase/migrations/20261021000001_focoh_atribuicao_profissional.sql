-- Atribuição profissional por paciente (FOCO-106)
-- medico_responsavel_chatwoot_id e psicologo_gerente_caso_chatwoot_id referenciam
-- o agent.id do Chatwoot (integer); a sub UUID no Supabase é derivável via
-- uuid_generate_v5(IDENTITY_NAMESPACE, 'chatwoot-user-' || agent_id).

ALTER TABLE pacientes
  ADD COLUMN IF NOT EXISTS medico_responsavel_chatwoot_id integer,
  ADD COLUMN IF NOT EXISTS psicologo_gerente_caso_chatwoot_id integer;

COMMENT ON COLUMN pacientes.medico_responsavel_chatwoot_id
  IS 'ID do agente Chatwoot (time 9 – psiquiatria) responsável pelo paciente';
COMMENT ON COLUMN pacientes.psicologo_gerente_caso_chatwoot_id
  IS 'ID do agente Chatwoot (time 12 – psicologia) gerente de caso do paciente';