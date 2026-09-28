-- ============================================================================
-- Kanban Clínico Rede Focoh — camada de API para automações (n8n e futuro)
-- ----------------------------------------------------------------------------
-- Superfície SEPARADA da que o Chatwoot usa. O dashboard Vue fala com
-- `public.cards_do_quadro()` autenticado pelo JWT de 15 min que
-- Focoh::SupabaseTokenService emite por usuário (migration 01). O n8n não é
-- um usuário Chatwoot — não faz sentido ele carregar um papel clínico, e não
-- deveria precisar reautenticar a cada execução de fluxo.
--
-- Por isso: um role de Postgres dedicado (`focoh_automacao_n8n`, mesma
-- família de `anon`/`authenticated`/`service_role` que o Supabase já usa),
-- sem LOGIN direto — o n8n autentica via uma chave de serviço assinada com
-- este role no claim `role` do JWT (gerada uma vez, guardada como
-- credencial no n8n, não no código). O papel só executa RPCs deste schema;
-- nunca lê tabela diretamente, então não há RLS a burlar.
--
-- PASSO MANUAL FORA DESTA MIGRATION (config do projeto Supabase, não SQL):
-- adicionar `focoh_api` em Settings > API > Exposed schemas. Sem isso o
-- PostgREST não expõe as funções, mesmo com os GRANTs corretos.
-- ============================================================================

create role focoh_automacao_n8n nologin;

comment on role focoh_automacao_n8n is
  'Role de automação externa (n8n e integrações futuras). Só executa RPCs em focoh_api — nunca recebe SELECT direto em tabela. Autenticado via JWT com claim role=focoh_automacao_n8n, chave gerada fora do banco.';

grant usage on schema public to focoh_automacao_n8n;

create schema if not exists focoh_api;
comment on schema focoh_api is
  'Superfície de leitura estável para automação externa (n8n, integrações vendáveis como evolução). Contrato deliberadamente pequeno: adicionar campo é seguro, remover/renomear quebra fluxo do cliente em produção.';

grant usage on schema focoh_api to focoh_automacao_n8n, authenticated;
revoke all on schema focoh_api from anon;

-- ----------------------------------------------------------------------------
-- pacientes_resumo — o mesmo espírito de cards_do_quadro(), para consumo
-- externo. Repete a disciplina de nunca devolver escore/nível textual de
-- risco nem conteúdo de laudo — só o que já é seguro no cartão do Kanban.
-- ----------------------------------------------------------------------------
create function focoh_api.pacientes_resumo() returns table (
    id                uuid,
    nome              text,
    programa          text,
    fase              text,
    data_admissao     date,
    dias_internado    int,
    tem_3_laudos      boolean,
    protocolo_vermelho_ativo boolean,
    arquivado         boolean
  )
  language sql stable security definer set search_path = ''
  as $fn$
    select c.id, c.nome, c.programa, c.fase::text, c.data_admissao, c.dias_internado,
           c.tem_3_laudos, c.protocolo_vermelho_ativo, c.arquivado
      from public.cards_do_quadro(false) c
  $fn$;

comment on function focoh_api.pacientes_resumo() is
  'Resumo não sensível por paciente, para automação externa. Reaproveita cards_do_quadro() — não lê tabela sensível diretamente.';

revoke all on function focoh_api.pacientes_resumo() from public;
grant execute on function focoh_api.pacientes_resumo() to focoh_automacao_n8n, authenticated;

-- ----------------------------------------------------------------------------
-- formularios_pendentes — o que falta para a semana vigente, por paciente.
-- Leitura complementar ao outbox de webhooks (laudos.cobranca, migration 11):
-- aquele empurra alerta quando o gatilho dispara; esta função deixa o n8n
-- perguntar "o que está pendente agora" a qualquer momento, sem esperar
-- evento — útil para um fluxo de cobrança com lógica própria de horário/
-- destinatário, sem reescrever a trava.
-- ----------------------------------------------------------------------------
create function focoh_api.formularios_pendentes() returns table (
    paciente_id     uuid,
    paciente_nome   text,
    tipo_laudo      public.tipo_laudo,
    semana_ref      date
  )
  language sql stable security definer set search_path = ''
  as $fn$
    select p.id, p.nome, u.tipo_laudo, focoh_interno.semana_vigente()
      from public.pacientes p
      cross join pg_catalog.unnest(pg_catalog.enum_range(null::public.tipo_laudo)) as u(tipo_laudo)
     where not p.arquivado
       and not exists (
             select 1 from public.laudos_semanais l
              where l.paciente_id = p.id
                and l.tipo        = u.tipo_laudo
                and l.semana_ref  = focoh_interno.semana_vigente()
                and l.aprovado
           )
     order by p.nome, u.tipo_laudo
  $fn$;

comment on function focoh_api.formularios_pendentes() is
  'Laudos da semana vigente ainda não aprovados, por paciente. Fonte para automação de cobrança sob demanda (n8n), sem depender de webhook de evento.';

revoke all on function focoh_api.formularios_pendentes() from public;
grant execute on function focoh_api.formularios_pendentes() to focoh_automacao_n8n, authenticated;

-- ----------------------------------------------------------------------------
-- historico_paciente — linha do tempo de envios, sem o conteúdo sensível de
-- avaliacao_risco (a automação externa não precisa do detalhe da ideação).
-- ----------------------------------------------------------------------------
create function focoh_api.historico_paciente(p_paciente_id uuid) returns table (
    formulario_tipo  text,
    etapa            text,
    bloco            text,
    data_referencia  date,
    enviado_em       timestamptz,
    autor_papel      text,
    resultado        text
  )
  language sql stable security definer set search_path = ''
  as $fn$
    select r.formulario_tipo, r.etapa, r.bloco, r.data_referencia, r.enviado_em,
           r.autor_papel, r.resultado
      from public.respostas_formulario r
     where r.paciente_id = p_paciente_id
     order by r.enviado_em desc
  $fn$;

comment on function focoh_api.historico_paciente(uuid) is
  'Linha do tempo de formulários enviados por paciente, sem o jsonb de campos (que pode conter dado clínico restrito) — só metadado de quando/quem/resultado.';

revoke all on function focoh_api.historico_paciente(uuid) from public;
grant execute on function focoh_api.historico_paciente(uuid) to focoh_automacao_n8n, authenticated;
