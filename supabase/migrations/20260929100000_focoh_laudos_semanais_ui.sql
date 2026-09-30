-- ============================================================================
-- Kanban Clínico Rede Focoh — Laudos Semanais UI
-- ----------------------------------------------------------------------------
-- 1. Estende o trigger de sincronização para aceitar 'evolucao_semanal'
--    (além de 'progressao_fase') como origem de laudos_semanais.
-- 2. Semeia definicoes_formulario para os 3 blocos do laudo semanal.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Atualiza a função do trigger de sincronização
--    A única mudança: `= 'progressao_fase'` → `in ('progressao_fase', 'evolucao_semanal')`
-- ----------------------------------------------------------------------------
create or replace function focoh_interno.tg_respostas_formulario_sincronizar() returns trigger
  language plpgsql security definer set search_path = ''
  as $fn$
  declare
    v_escore int;
  begin
    if new.formulario_tipo in ('progressao_fase', 'evolucao_semanal')
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
      select coalesce((focoh_interno.valor_campo_resposta(new.campos, 'comunicacao'))::int, 0)
           + coalesce((focoh_interno.valor_campo_resposta(new.campos, 'antecedentes_suicidas'))::int, 0)
           + coalesce((focoh_interno.valor_campo_resposta(new.campos, 'estado_mental'))::int, 0)
           + coalesce((focoh_interno.valor_campo_resposta(new.campos, 'padrao_comportamental'))::int, 0)
           + coalesce((focoh_interno.valor_campo_resposta(new.campos, 'fatores_predisponentes'))::int, 0)
        into v_escore;

      if v_escore not between 5 and 20 then
        raise exception 'Escala de risco incompleta ou fora do intervalo (esperado 5-20, calculado %). Envio rejeitado para não gravar avaliação inválida.', v_escore;
      end if;

      update public.avaliacoes_risco
         set ativo = false
       where paciente_id = new.paciente_id
         and ativo;

      insert into public.avaliacoes_risco
        (paciente_id, escore, nivel, avaliado_por, avaliado_em)
      values
        (new.paciente_id, v_escore, 'baixo', new.autor_user_id, new.enviado_em);

    elsif new.formulario_tipo = 'progressao_fase' and new.bloco = 'risco_sustentabilidade' then
      null;
    end if;

    return new;
  end;
  $fn$;

comment on function focoh_interno.tg_respostas_formulario_sincronizar() is
  'Traduz um envio de formulário para as tabelas que a trava Anexo Fases (migration 05) já lê. Aceita progressao_fase e evolucao_semanal como origem dos laudos_semanais.';

-- ----------------------------------------------------------------------------
-- 2. Catálogo de campos para evolucao_semanal (laudos semanais)
--    Três blocos, cada um submetido pelo respectivo profissional.
-- ----------------------------------------------------------------------------
insert into public.definicoes_formulario
  (programa, formulario_tipo, bloco, campo_chave, rotulo, tipo_campo, obrigatorio, ordem, opcoes)
values

-- Bloco Clínico — médico psiquiatra
  ('jornada_superacao', 'evolucao_semanal', 'clinico',
   'aderencia_medicacao', 'Aderência à medicação',
   'selecao', true, 1,
   '[{"value":"boa","label":"Boa"},{"value":"regular","label":"Regular"},{"value":"ruim","label":"Ruim"}]'::jsonb),

  ('jornada_superacao', 'evolucao_semanal', 'clinico',
   'sintomas_psiquiatricos', 'Sintomas psiquiátricos observados na semana',
   'texto_longo', false, 2, null),

  ('jornada_superacao', 'evolucao_semanal', 'clinico',
   'intercorrencias', 'Intercorrências clínicas',
   'texto_longo', false, 3, null),

  ('jornada_superacao', 'evolucao_semanal', 'clinico',
   'avaliacao_clinica_geral', 'Avaliação clínica geral',
   'texto_longo', true, 4, null),

-- Bloco Terapêutico — psicólogo
  ('jornada_superacao', 'evolucao_semanal', 'terapeutico',
   'engajamento_terapia', 'Engajamento nas atividades terapêuticas',
   'selecao', true, 1,
   '[{"value":"alto","label":"Alto"},{"value":"medio","label":"Médio"},{"value":"baixo","label":"Baixo"}]'::jsonb),

  ('jornada_superacao', 'evolucao_semanal', 'terapeutico',
   'participacao_grupos', 'Participação em grupos terapêuticos',
   'selecao', true, 2,
   '[{"value":"ativa","label":"Ativa"},{"value":"parcial","label":"Parcial"},{"value":"ausente","label":"Ausente"}]'::jsonb),

  ('jornada_superacao', 'evolucao_semanal', 'terapeutico',
   'evolucao_emocional', 'Evolução emocional e comportamental',
   'texto_longo', true, 3, null),

  ('jornada_superacao', 'evolucao_semanal', 'terapeutico',
   'avaliacao_terapeutica_geral', 'Observações terapêuticas gerais',
   'texto_longo', false, 4, null),

-- Bloco Disciplinar — coordenação técnica
  ('jornada_superacao', 'evolucao_semanal', 'disciplinar',
   'cumprimento_rotina', 'Cumprimento da rotina diária',
   'selecao', true, 1,
   '[{"value":"integral","label":"Integral"},{"value":"parcial","label":"Parcial"},{"value":"insatisfatorio","label":"Insatisfatório"}]'::jsonb),

  ('jornada_superacao', 'evolucao_semanal', 'disciplinar',
   'relacionamento_grupo', 'Relacionamento com o grupo',
   'selecao', true, 2,
   '[{"value":"positivo","label":"Positivo"},{"value":"neutro","label":"Neutro"},{"value":"conflituoso","label":"Conflituoso"}]'::jsonb),

  ('jornada_superacao', 'evolucao_semanal', 'disciplinar',
   'ocorrencias', 'Ocorrências disciplinares',
   'texto_longo', false, 3, null),

  ('jornada_superacao', 'evolucao_semanal', 'disciplinar',
   'avaliacao_disciplinar_geral', 'Avaliação geral do período',
   'texto_longo', true, 4, null);
