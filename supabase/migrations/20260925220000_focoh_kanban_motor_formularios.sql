-- ============================================================================
-- Kanban Clínico Rede Focoh — 18/20 · motor de formulários configuráveis
-- ----------------------------------------------------------------------------
-- Duas naturezas de dado, e cada uma tem sua tabela:
--
--   CADASTRAL  — um valor por paciente, editado no lugar (`pacientes.dados_cadastrais`).
--   HISTÓRICO  — uma linha nova a cada envio, nunca sobrescrita
--                (`respostas_formulario`).
--
-- O CATÁLOGO (`definicoes_formulario`) é o que descreve os campos de cada
-- formulário — e é editável pelo cliente (papel "editor de configuração"),
-- sem deploy. Ele é mutável em lugar (edição simples: rótulo, obrigatório,
-- ativo, ordem) porque a fidelidade histórica não depende de travar a
-- definição — depende de `respostas_formulario` guardar uma CÓPIA do que foi
-- perguntado e respondido no momento do envio, não uma referência a uma
-- linha que pode mudar depois. Ver comentário em `respostas_formulario`.
--
-- Fonte funcional: "Kanbans Clínicos — Mapa Objetivo (versão para o
-- desenvolvedor)", 16/09/2026 — "painel de configuração... configurável pelo
-- cliente, sem deploy" e "tabela de critérios parametrizada por (programa,
-- transição, bloco)".
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Enums
-- ----------------------------------------------------------------------------
create type public.tipo_campo_formulario as enum (
  'texto', 'texto_longo', 'numero', 'data', 'selecao', 'multipla', 'checkbox', 'assinatura'
);

create type public.natureza_propriedade as enum ('cadastral', 'historico');

-- ----------------------------------------------------------------------------
-- pacientes.dados_cadastrais — sidecar jsonb para campo cadastral novo sem
-- ALTER TABLE. Continua existindo `pacientes.nome`/`programa`/etc. como
-- colunas de primeira classe porque a trava de fase e `cards_do_quadro()` já
-- dependem delas; isto aqui é só para o que o catálogo adicionar depois.
-- ----------------------------------------------------------------------------
alter table public.pacientes
  add column dados_cadastrais jsonb not null default '{}'::jsonb;

comment on column public.pacientes.dados_cadastrais is
  'Campos cadastrais definidos via definicoes_formulario (natureza=cadastral) que não têm coluna própria em pacientes. Um valor por paciente, sobrescrito na edição — não é histórico.';

-- ----------------------------------------------------------------------------
-- definicoes_formulario — o catálogo, editável pelo painel de configuração
-- ----------------------------------------------------------------------------
create table public.definicoes_formulario (
  id               uuid primary key default gen_random_uuid(),
  -- 'jornada_superacao' | 'detox' | null (null = comum aos dois, ex. Aba A da admissão)
  programa         text,
  -- 'admissao' | 'progressao_fase' | 'avaliacao_risco' | 'evolucao_semanal' | ...
  formulario_tipo  text not null check (length(btrim(formulario_tipo)) > 0),
  -- fase_jornada como texto, etapa do Detox, ou 'F1_F2'/'F2_F3'/... para os 4
  -- blocos de transição do anexo fases.pdf. null = vale para qualquer etapa.
  etapa            text,
  -- 'clinico' | 'terapeutico' | 'disciplinar' | 'risco' | 'rede_apoio' | null
  bloco            text,
  campo_chave      text not null check (campo_chave ~ '^[a-z][a-z0-9_]*$'),
  rotulo           text not null check (length(btrim(rotulo)) > 0),
  tipo_campo       public.tipo_campo_formulario not null,
  -- Para 'selecao'/'multipla': [{"value": "...", "label": "..."}]. Ignorado
  -- para outros tipos — não é erro ter valor aqui mesmo assim, só não é lido.
  opcoes           jsonb,
  obrigatorio      boolean not null default false,
  natureza         public.natureza_propriedade not null default 'historico',
  ordem            int not null default 0,
  ativo            boolean not null default true,
  criado_por       uuid,
  criado_em        timestamptz not null default now(),
  atualizado_por   uuid,
  atualizado_em    timestamptz not null default now(),

  constraint definicoes_formulario_opcoes_exige_tipo
    check (tipo_campo in ('selecao', 'multipla') or opcoes is null),
  constraint definicoes_formulario_chave_unica
    unique (coalesce(programa, ''), formulario_tipo, coalesce(etapa, ''), coalesce(bloco, ''), campo_chave)
);

comment on table public.definicoes_formulario is
  'Catálogo de propriedades dos formulários clínicos. Mutável em lugar (edição simples pelo painel de configuração) — a fidelidade histórica vem de respostas_formulario guardar cópia, não de travar esta tabela.';
comment on column public.definicoes_formulario.natureza is
  'cadastral = um valor por paciente, editado em pacientes.dados_cadastrais. historico = uma linha nova por envio em respostas_formulario, nunca sobrescrita.';

create index definicoes_formulario_lookup_idx
  on public.definicoes_formulario (formulario_tipo, coalesce(programa, ''), coalesce(etapa, ''), coalesce(bloco, ''))
  where ativo;

-- ----------------------------------------------------------------------------
-- definicoes_formulario_historico — histórico de alteração campo a campo
--
-- "mudar um checkbox destrava a progressão de fase de um paciente; sem
-- rastro, a trava vira decorativa" (Mapa Objetivo). Isto audita mudanças NA
-- DEFINIÇÃO (quem tornou um critério obrigatório/opcional, quando) —
-- diferente da auditoria de transição de fase que já existe em
-- auditoria_transicoes_fase.
-- ----------------------------------------------------------------------------
create table public.definicoes_formulario_historico (
  id             bigint generated always as identity primary key,
  definicao_id   uuid not null references public.definicoes_formulario (id) on delete cascade,
  campo          text not null,
  valor_anterior jsonb,
  valor_novo     jsonb,
  alterado_por   uuid,
  alterado_em    timestamptz not null default now()
);

create index definicoes_formulario_historico_definicao_idx
  on public.definicoes_formulario_historico (definicao_id, alterado_em desc);

create function focoh_interno.tg_definicoes_formulario_auditar() returns trigger
  language plpgsql security definer set search_path = ''
  as $fn$
  begin
    if new.rotulo is distinct from old.rotulo then
      insert into public.definicoes_formulario_historico (definicao_id, campo, valor_anterior, valor_novo, alterado_por)
      values (new.id, 'rotulo', to_jsonb(old.rotulo), to_jsonb(new.rotulo), auth.uid());
    end if;
    if new.obrigatorio is distinct from old.obrigatorio then
      insert into public.definicoes_formulario_historico (definicao_id, campo, valor_anterior, valor_novo, alterado_por)
      values (new.id, 'obrigatorio', to_jsonb(old.obrigatorio), to_jsonb(new.obrigatorio), auth.uid());
    end if;
    if new.ativo is distinct from old.ativo then
      insert into public.definicoes_formulario_historico (definicao_id, campo, valor_anterior, valor_novo, alterado_por)
      values (new.id, 'ativo', to_jsonb(old.ativo), to_jsonb(new.ativo), auth.uid());
    end if;
    if new.opcoes is distinct from old.opcoes then
      insert into public.definicoes_formulario_historico (definicao_id, campo, valor_anterior, valor_novo, alterado_por)
      values (new.id, 'opcoes', old.opcoes, new.opcoes, auth.uid());
    end if;

    new.atualizado_em := now();
    new.atualizado_por := auth.uid();
    return new;
  end;
  $fn$;

create trigger definicoes_formulario_10_auditar
  before update on public.definicoes_formulario
  for each row execute function focoh_interno.tg_definicoes_formulario_auditar();

-- ----------------------------------------------------------------------------
-- editores_configuracao — allowlist simples, não é um sistema de papéis novo
-- ----------------------------------------------------------------------------
-- "podemos ter somente a possibilidade de definir usuários como editores,
-- para configurar propriedades" — camada rasa de propósito: não introduz
-- hierarquia nova, só marca quem, além de coordenação/direção, pode editar o
-- catálogo. Mesmo padrão de governança de config_protocolo_vermelho.
-- ----------------------------------------------------------------------------
create table public.editores_configuracao (
  user_sub      uuid primary key,
  nome_exibicao text,
  concedido_por uuid not null,
  concedido_em  timestamptz not null default now()
);

comment on table public.editores_configuracao is
  'Allowlist de quem pode editar definicoes_formulario além de coordenacao_tecnica/diretor_geral, que já têm acesso por papel. Gerida na tela Configurações > Usuários e permissões.';

create function focoh_interno.e_editor_configuracao() returns boolean
  language sql stable security definer set search_path = ''
  as $fn$
    select focoh_interno.papel_atual() = any (array['coordenacao_tecnica', 'diretor_geral'])
        or exists (select 1 from public.editores_configuracao where user_sub = auth.uid())
  $fn$;

comment on function focoh_interno.e_editor_configuracao() is
  'Quem pode escrever em definicoes_formulario: coordenacao_tecnica/diretor_geral por papel, ou quem está em editores_configuracao. SECURITY DEFINER porque a policy de editores_configuracao restringe SELECT e este helper precisa ler mesmo assim.';

-- ----------------------------------------------------------------------------
-- respostas_formulario — HISTÓRICO. Uma linha por envio, nunca sobrescrita.
-- ----------------------------------------------------------------------------
-- `campos` guarda uma CÓPIA do que foi perguntado (rótulo, tipo, obrigatório)
-- e respondido no momento do envio — não uma referência a definicoes_formulario.
-- Motivo: definicoes_formulario é editável em lugar (decisão de manter o
-- painel simples, ver plano). Se a resposta só referenciasse o id da
-- definição, editar o rótulo depois do envio reescreveria silenciosamente o
-- que o formulário perguntava — exatamente o problema que o Mapa Objetivo
-- pede para evitar ("formulário já respondido precisa continuar legível
-- depois de a definição mudar").
-- ----------------------------------------------------------------------------
create table public.respostas_formulario (
  id                 uuid primary key default gen_random_uuid(),
  paciente_id        uuid not null references public.pacientes (id) on delete cascade,
  formulario_tipo    text not null,
  etapa              text,
  bloco              text,
  -- Duas datas, de propósito (Mapa Objetivo): a semana/momento clínico a que
  -- o envio se refere, e o carimbo de quando o sistema recebeu. As duas
  -- divergem quando um profissional preenche atrasado.
  data_referencia    date not null,
  enviado_em         timestamptz not null default now(),
  autor_user_id      uuid,
  autor_papel        text,
  -- [{"campo_chave","rotulo","tipo_campo","obrigatorio","valor"}, ...] — a
  -- cópia congelada dos campos respondidos, na ordem em que foram exibidos.
  campos             jsonb not null,
  -- Resultado do bloco, quando o formulário tem decisão binária/graduada:
  -- 'apto' | 'nao_apto' | 'baixo' | 'moderado' | 'alto' | null (formulários
  -- sem decisão, como a Ficha de Admissão).
  resultado          text,
  criado_em          timestamptz not null default now(),

  constraint respostas_formulario_campos_e_array
    check (jsonb_typeof(campos) = 'array')
);

comment on table public.respostas_formulario is
  'Um envio de formulário = uma linha. Nunca é editada depois de criada (exceto correção formal via nova linha) — é a série temporal que o painel de histórico do paciente lê.';
comment on column public.respostas_formulario.campos is
  'Cópia congelada dos campos perguntados e respondidos neste envio — não referencia definicoes_formulario, para permanecer legível mesmo se o catálogo mudar depois.';

create index respostas_formulario_paciente_idx
  on public.respostas_formulario (paciente_id, formulario_tipo, enviado_em desc);

-- ----------------------------------------------------------------------------
-- RLS
-- ----------------------------------------------------------------------------
alter table public.definicoes_formulario            enable row level security;
alter table public.definicoes_formulario_historico   enable row level security;
alter table public.editores_configuracao             enable row level security;
alter table public.respostas_formulario               enable row level security;

revoke all on table
  public.definicoes_formulario,
  public.definicoes_formulario_historico,
  public.editores_configuracao,
  public.respostas_formulario
from anon, authenticated;

-- definicoes_formulario: toda a equipe lê (o formulário precisa saber o que
-- perguntar); só editor de configuração escreve.
grant select, insert, update on table public.definicoes_formulario to authenticated;

create policy definicoes_formulario_select_staff on public.definicoes_formulario
  for select to authenticated
  using (focoh_interno.e_staff());

create policy definicoes_formulario_insert_editor on public.definicoes_formulario
  for insert to authenticated
  with check (focoh_interno.e_editor_configuracao());

create policy definicoes_formulario_update_editor on public.definicoes_formulario
  for update to authenticated
  using (focoh_interno.e_editor_configuracao())
  with check (focoh_interno.e_editor_configuracao());

-- Histórico de alteração: só leitura, só para quem edita configuração — é
-- auditoria de governança, não operação do dia a dia.
grant select on table public.definicoes_formulario_historico to authenticated;

create policy definicoes_formulario_historico_select_editor on public.definicoes_formulario_historico
  for select to authenticated
  using (focoh_interno.e_editor_configuracao());

-- editores_configuracao: só coordenação/direção veem e gerem a lista — um
-- editor comum não precisa (nem deve) ver quem mais é editor para conceder a
-- si mesmo mais acesso.
grant select, insert, delete on table public.editores_configuracao to authenticated;

create policy editores_configuracao_select_governanca on public.editores_configuracao
  for select to authenticated
  using (focoh_interno.papel_atual() = any (array['coordenacao_tecnica', 'diretor_geral']));

create policy editores_configuracao_insert_governanca on public.editores_configuracao
  for insert to authenticated
  with check (focoh_interno.papel_atual() = any (array['coordenacao_tecnica', 'diretor_geral']));

create policy editores_configuracao_delete_governanca on public.editores_configuracao
  for delete to authenticated
  using (focoh_interno.papel_atual() = any (array['coordenacao_tecnica', 'diretor_geral']));

-- respostas_formulario: leitura por equipe clínica (mesmo critério de
-- laudos_semanais — recepção não lê conteúdo de laudo, só o status via
-- cards_do_quadro()); inserção por quem tem papel de staff (a trava de QUEM
-- pode aprovar qual bloco continua sendo aplicada depois, na sincronização
-- com laudos_semanais/avaliacoes_risco, que já valida por
-- papeis_aprovadores_laudo). Sem UPDATE/DELETE: histórico é append-only.
grant select, insert on table public.respostas_formulario to authenticated;

create policy respostas_formulario_select_equipe_clinica on public.respostas_formulario
  for select to authenticated
  using (focoh_interno.e_equipe_clinica());

create policy respostas_formulario_insert_staff on public.respostas_formulario
  for insert to authenticated
  with check (focoh_interno.e_staff());
