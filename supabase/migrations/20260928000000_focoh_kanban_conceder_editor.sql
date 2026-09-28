-- ============================================================================
-- Kanban Clínico Rede Focoh — conceder acesso de editor por usuário Chatwoot
-- ----------------------------------------------------------------------------
-- A tela Configurações > Usuários e permissões escolhe um agente do Chatwoot
-- (id numérico, já conhecido pelo frontend) — não faz sentido pedir pro
-- operador digitar um UUID do Supabase que ele nunca viu. Esta função faz a
-- mesma derivação que `Focoh::SupabaseTokenService#supabase_user_id`
-- (`app/services/focoh/supabase_token_service.rb`) faz no Rails, para que o
-- `user_sub` gravado aqui seja EXATAMENTE o `sub` que aquele token emite.
--
-- Precisa bater com o Rails nos três pontos: mesmo namespace, mesmo formato
-- de string ("chatwoot-user-#{id}"), mesmo algoritmo (UUIDv5). Se um dia o
-- namespace mudar lá, muda aqui também — são a mesma verdade em dois lugares
-- por necessidade de linguagem, não por acaso.
-- ============================================================================

create extension if not exists "uuid-ossp" with schema extensions;

-- Guardado só para a tela conseguir mostrar/revogar por agente sem
-- recalcular UUIDv5 no cliente. Não é usado por nenhuma policy — a
-- autorização continua sendo `user_sub` (o que o JWT realmente carrega).
alter table public.editores_configuracao
  add column chatwoot_user_id bigint;

create function public.conceder_editor_configuracao(
  p_chatwoot_user_id bigint,
  p_nome_exibicao     text default null
) returns public.editores_configuracao
  language plpgsql security definer set search_path = ''
  as $fn$
  declare
    v_user_sub uuid;
    v_row      public.editores_configuracao;
  begin
    if not (focoh_interno.papel_atual() = any (array['coordenacao_tecnica', 'diretor_geral'])) then
      raise exception 'Só coordenação técnica ou direção pode conceder acesso de editor de configuração.'
        using errcode = 'FCH08';
    end if;

    -- Namespace IDENTITY_NAMESPACE de Focoh::SupabaseTokenService — não
    -- alterar aqui sem alterar lá também (ver aviso na classe Rails).
    v_user_sub := extensions.uuid_generate_v5(
      'b3f0c8a2-5d41-4a7e-9c6b-1f2e3d4c5b6a'::uuid,
      'chatwoot-user-' || p_chatwoot_user_id::text
    );

    insert into public.editores_configuracao (user_sub, nome_exibicao, concedido_por, chatwoot_user_id)
    values (v_user_sub, p_nome_exibicao, auth.uid(), p_chatwoot_user_id)
    on conflict (user_sub) do update
      set nome_exibicao    = excluded.nome_exibicao,
          chatwoot_user_id = excluded.chatwoot_user_id
    returning * into v_row;

    return v_row;
  end;
  $fn$;

comment on function public.conceder_editor_configuracao(bigint, text) is
  'Concede a flag de editor de configuração a partir do id numérico do agente no Chatwoot, derivando o user_sub da mesma forma que o token JWT (Focoh::SupabaseTokenService). SECURITY DEFINER: a checagem de papel está DENTRO da função porque editores_configuracao_insert_governanca já exige o mesmo papel — redundante de propósito, não uma brecha.';

revoke all on function public.conceder_editor_configuracao(bigint, text) from public;
grant execute on function public.conceder_editor_configuracao(bigint, text) to authenticated;

-- ----------------------------------------------------------------------------
-- revogar_editor_configuracao — mesma checagem, sem exigir que o frontend
-- calcule o user_sub para o DELETE também.
-- ----------------------------------------------------------------------------
create function public.revogar_editor_configuracao(p_chatwoot_user_id bigint) returns void
  language plpgsql security definer set search_path = ''
  as $fn$
  declare
    v_user_sub uuid;
  begin
    if not (focoh_interno.papel_atual() = any (array['coordenacao_tecnica', 'diretor_geral'])) then
      raise exception 'Só coordenação técnica ou direção pode revogar acesso de editor de configuração.'
        using errcode = 'FCH08';
    end if;

    v_user_sub := extensions.uuid_generate_v5(
      'b3f0c8a2-5d41-4a7e-9c6b-1f2e3d4c5b6a'::uuid,
      'chatwoot-user-' || p_chatwoot_user_id::text
    );

    delete from public.editores_configuracao where user_sub = v_user_sub;
  end;
  $fn$;

revoke all on function public.revogar_editor_configuracao(bigint) from public;
grant execute on function public.revogar_editor_configuracao(bigint) to authenticated;

-- ----------------------------------------------------------------------------
-- sou_editor_configuracao — wrapper público de focoh_interno.e_editor_configuracao().
-- O frontend usa isto só para decidir se mostra o item de menu
-- "Configurações" — a permissão de verdade continua sendo a RLS de
-- definicoes_formulario, não esta checagem de UI.
-- ----------------------------------------------------------------------------
create function public.sou_editor_configuracao() returns boolean
  language sql stable security definer set search_path = ''
  as $fn$ select focoh_interno.e_editor_configuracao() $fn$;

revoke all on function public.sou_editor_configuracao() from public;
grant execute on function public.sou_editor_configuracao() to authenticated;
