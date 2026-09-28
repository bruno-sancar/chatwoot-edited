-- ============================================================================
-- Kanban Clínico Rede Focoh — 19/20 · sincronização respostas → trava existente
-- ----------------------------------------------------------------------------
-- PRINCÍPIO: a trava "Anexo Fases" (migration 05, `tg_pacientes_trava_avanco_fase`)
-- não muda uma linha. Ela já lê `laudos_semanais` e `avaliacoes_risco`, e essa
-- leitura já foi testada. Este arquivo só faz esses dados nascerem de um
-- formulário de verdade (`respostas_formulario`) em vez de nascerem vazios.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Helper: extrai o valor de um campo pela chave, do array `campos` de uma
-- resposta. Devolve jsonb (o chamador faz o cast que precisar).
-- ----------------------------------------------------------------------------
create function focoh_interno.valor_campo_resposta(p_campos jsonb, p_chave text) returns jsonb
  language sql immutable parallel safe set search_path = ''
  as $fn$
    select elem -> 'valor'
      from pg_catalog.jsonb_array_elements(p_campos) as elem
     where elem ->> 'campo_chave' = p_chave
     limit 1
  $fn$;

-- ----------------------------------------------------------------------------
-- Sincronização com laudos_semanais — blocos clínico/terapêutico/disciplinar
-- do Formulário de Progressão de Fase.
--
-- Upsert, não insert: o mesmo bloco pode ser reenviado na mesma semana depois
-- de um "Não apto" corrigido (Mapa Objetivo: "um ou mais por fase, sem limite,
-- enquanto a decisão for Não aprovado") — a unique constraint
-- laudos_semanais_unico_por_semana já existe para isso, só reaproveitamos.
-- ----------------------------------------------------------------------------
create function focoh_interno.tg_respostas_formulario_sincronizar() returns trigger
  language plpgsql security definer set search_path = ''
  as $fn$
  declare
    v_escore int;
  begin
    if new.formulario_tipo = 'progressao_fase'
       and new.bloco in ('clinico', 'terapeutico', 'disciplinar')
       and new.resultado in ('apto', 'nao_apto') then

      insert into public.laudos_semanais
        (paciente_id, tipo, semana_ref, aprovado, autor, autor_user_id, aprovado_em)
      values
        (new.paciente_id, new.bloco::public.tipo_laudo, focoh_interno.semana_vigente(),
         new.resultado = 'apto', new.autor_papel, new.autor_user_id,
         case when new.resultado = 'apto' then new.enviado_em end)
      on conflict (paciente_id, tipo, semana_ref) do update
        set aprovado      = excluded.aprovado,
            autor          = excluded.autor,
            autor_user_id  = excluded.autor_user_id,
            aprovado_em    = excluded.aprovado_em;

    elsif new.formulario_tipo = 'avaliacao_risco' then
      -- Escala de Avaliação de Risco de Suicídio (5 critérios, 1-4 cada,
      -- 5-20 no total). Chaves esperadas em `campos`, fixas porque são as
      -- do instrumento oficial da clínica (Avaliação de risco de suicídio
      -- Atualizado.docx) — não fazem sentido como propriedade configurável.
      select coalesce((focoh_interno.valor_campo_resposta(new.campos, 'comunicacao'))::int, 0)
           + coalesce((focoh_interno.valor_campo_resposta(new.campos, 'antecedentes_suicidas'))::int, 0)
           + coalesce((focoh_interno.valor_campo_resposta(new.campos, 'estado_mental'))::int, 0)
           + coalesce((focoh_interno.valor_campo_resposta(new.campos, 'padrao_comportamental'))::int, 0)
           + coalesce((focoh_interno.valor_campo_resposta(new.campos, 'fatores_predisponentes'))::int, 0)
        into v_escore;

      if v_escore not between 5 and 20 then
        raise exception 'Escala de risco incompleta ou fora do intervalo (esperado 5-20, calculado %). Envio rejeitado para não gravar avaliação inválida.', v_escore;
      end if;

      -- Uma avaliação vigente por paciente (índice único parcial na
      -- migration 03): encerra a anterior antes de abrir a nova.
      update public.avaliacoes_risco
         set ativo = false
       where paciente_id = new.paciente_id
         and ativo;

      insert into public.avaliacoes_risco
        (paciente_id, escore, nivel, avaliado_por, avaliado_em)
      values
        -- `nivel` é sobrescrito pelo trigger BEFORE INSERT da migration 17
        -- (tg_avaliacoes_risco_derivar_nivel) — o valor aqui é só para
        -- satisfazer a coluna not null antes do trigger rodar.
        (new.paciente_id, v_escore, 'baixo', new.autor_user_id, new.enviado_em);

    elsif new.formulario_tipo = 'progressao_fase' and new.bloco = 'risco_sustentabilidade' then
      -- ######################################################################
      -- # NÃO SINCRONIZA COM avaliacoes_risco DE PROPÓSITO.                  #
      -- #                                                                    #
      -- # O Bloco 4 do anexo fases.pdf ("Avaliação de Risco e                #
      -- # Sustentabilidade") pontua por CONTAGEM de itens comportamentais    #
      -- # (1 item = baixo, 2 = moderado, 3+ = alto) — instrumento diferente  #
      -- # da Escala de Risco de Suicídio (escore 5-20) que avaliacoes_risco  #
      -- # representa. Somar os dois na mesma coluna corromperia o dado       #
      -- # sensível que a trava de fase já lê.                                #
      -- #                                                                    #
      -- # A trava de fase (migration 05) já bloqueia por risco através da    #
      -- # Escala de Suicídio recorrente (avaliacoes_risco.nivel). Este bloco #
      -- # fica registrado aqui em respostas_formulario.resultado para        #
      -- # exibição e histórico, mas NÃO é uma segunda porta de bloqueio.     #
      -- #                                                                    #
      -- # PENDENTE DE VALIDAÇÃO CLÍNICA: confirmar com a Rede Focoh se o     #
      -- # Bloco 4 deveria bloquear a progressão por si só, independente da   #
      -- # Escala de Suicídio recorrente. Se sim, é uma trava NOVA a          #
      -- # desenhar — não uma gravação em avaliacoes_risco.                   #
      -- ######################################################################
      null;
    end if;

    return new;
  end;
  $fn$;

comment on function focoh_interno.tg_respostas_formulario_sincronizar() is
  'Traduz um envio de formulário para as tabelas que a trava Anexo Fases (migration 05) já lê. Não altera a trava; só passa a alimentá-la com dado real.';

create trigger respostas_formulario_10_sincronizar
  after insert on public.respostas_formulario
  for each row execute function focoh_interno.tg_respostas_formulario_sincronizar();

-- ----------------------------------------------------------------------------
-- pacientes.dados_cadastrais — atualização em lugar pela Ficha de Admissão
--
-- Diferente de respostas_formulario (histórico), campo cadastral é UPDATE
-- direto na linha do paciente. Sem trigger dedicado: o controller Rails faz
-- `update public.pacientes set dados_cadastrais = dados_cadastrais || $1`
-- (merge raso) diretamente, com RLS de pacientes_update_staff (migration 09)
-- já cobrindo a permissão.
-- ----------------------------------------------------------------------------
