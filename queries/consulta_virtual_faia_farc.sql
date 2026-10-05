USE mdb;
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

--------------------------------------------------------------------------------
-- Consulta de referencia FAIA + FARC - Virtual
--
-- Apuracao do fornecedor Virtual a partir do SDM, com a mesma arquitetura de
-- posse da Decision (Extracao_de_dados_Decision) e os parametros, o calendario
-- e o horario comercial proprios da Virtual. Devolve DOIS result sets:
--
--   Resultado 1 = Chamados_TCU
--   Resultado 2 = Chamados_24x7
--
-- Uma execucao devolve todos os chamados elegiveis: o Resultado 1 traz os do
-- regime TCU e o Resultado 2 os do regime 24x7.
--
-- Regras (detalhe em docs/virtual-calculation.md):
--   Periodo     data escolhida em @DataReferencia dentro de
--               [@DataInicio, @DataFim), horario do Brasil. A chave so muda
--               quais chamados entram; nenhum calculo muda.
--   Escopo      chamado I/R e, conforme @DataReferencia:
--               FECHAMENTO (padrao): close_date no periodo, status terminal,
--                 grupo atual 'Fornecedores - Virtual' e ENCERROU na Virtual
--                 (nasceu nela sem transferencia de grupo, ou a ultima
--                 transferencia de grupo ate o fechamento foi uma entrada na
--                 Virtual).
--               RESOLUCAO: resolve_date no periodo e a resolucao ocorreu dentro
--                 de uma janela de posse da Virtual. close_date pode ser NULL.
--   Regime      vem da tabela de parametros pela combinacao Tipo + Prioridade.
--   Posse       janelas em que o chamado esteve no grupo Virtual, pela linha do
--               tempo de transferencias de grupo. O relogio comeca na primeira
--               entrada (ou na abertura, se nasceu na Virtual), para nas saidas,
--               volta nas reentradas; todas as janelas sao somadas.
--   Inicio      primeira passagem para 'Em andamento' feita enquanto o chamado
--               esta no grupo Virtual (a captura da Decision). Sem ela, a
--               primeira atividade registrada na posse (act_log, exceto
--               transferencias); sem atividade, a entrada na Virtual.
--   Tini        Tempo Primeiro Atendimento: tempo de posse ate o Inicio.
--   Tsol        Tempo de Atendimento: tempo de posse ate a Resolucao em status
--               ativo ('Em andamento' ou 'Aberto, aguarda atendimento'), como
--               na Decision. Os demais status pausam e vao para Tempo suspenso.
--   Resolucao   call_req.resolve_date; se vazio, o ultimo evento RE (passagem
--               para 'Em homologacao'), desde que o chamado nao esteja em
--               status de atendimento aberto.
--   Fechamento  call_req.close_date.
--   Horario     TCU: 08:00-20:00, segunda a sexta, fora das datas com
--               Conta_SLA = 'N' no calendario TCU (bloco [2]). 24x7: tempo
--               corrido.
--
-- Unidades: as colunas de duracao saem como texto [h]:mm:ss; o calculo e
-- feito em segundos. Indice = horas de excesso x fator, em pontos percentuais.
--
-- Execute o arquivo INTEIRO. Banco somente leitura: so cria tabelas #.
--------------------------------------------------------------------------------

-- Periodo de apuracao, horario do Brasil, intervalo semiaberto
-- [@DataInicio, @DataFim). Para um mes inteiro, use o dia 1 do mes e o dia 1 do
-- mes seguinte.
DECLARE @DataInicio datetime2(0) = '2026-05-01 00:00:00';
DECLARE @DataFim    datetime2(0) = '2026-06-01 00:00:00';

-- Data que define o periodo:
--   N'FECHAMENTO' = Data/Hora Fechamento (call_req.close_date)
--   N'RESOLUCAO'  = Data/Hora Resolucao  (call_req.resolve_date)
DECLARE @DataReferencia nvarchar(20) = N'FECHAMENTO';

-- >>> MOTOR VIRTUAL ------------------------------------------------------------
-- Bloco identico nos tres arquivos (queries/ e powerbi/). Usa so @DataInicio,
-- @DataFim e @DataReferencia e entrega #Virt_Saida com os dois regimes.

IF @DataReferencia IS NULL OR @DataReferencia NOT IN (N'RESOLUCAO', N'FECHAMENTO')
BEGIN
    RAISERROR(N'Valor inválido para @DataReferencia. Use RESOLUCAO ou FECHAMENTO.', 16, 1);
    RETURN;
END;

DECLARE @HorasBrasilParaUTC int = 3;
DECLARE @Epoch datetime2(0) = '1970-01-01 00:00:00';
DECLARE @IniEpoch int = DATEDIFF(SECOND, @Epoch, DATEADD(HOUR, @HorasBrasilParaUTC, @DataInicio));
DECLARE @FimEpoch int = DATEDIFF(SECOND, @Epoch, DATEADD(HOUR, @HorasBrasilParaUTC, @DataFim));

-- Identidades por UUID; o nome do grupo e lido do cadastro porque o act_log
-- registra a transferencia pelo nome.
DECLARE @GrupoVirtual   varbinary(16) = 0x21679DF702A0EC478B1468D89E769836; -- Fornecedores - Virtual
DECLARE @GrupoVirtualNome nvarchar(200) =
    (SELECT LTRIM(RTRIM(c.last_name)) FROM dbo.ca_contact AS c WHERE c.contact_uuid = @GrupoVirtual);

-- Janela comercial do regime TCU.
DECLARE @HoraInicioComercial int = 8;
DECLARE @HoraFimComercial    int = 20;

--------------------------------------------------------------------------------
-- [1] Parametros da Virtual: metas (em horas), regime e fatores por Tipo +
--     Prioridade.
--------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#Virt_Parametros') IS NOT NULL DROP TABLE #Virt_Parametros;
CREATE TABLE #Virt_Parametros (
    Tipo           nvarchar(20) COLLATE DATABASE_DEFAULT NOT NULL,
    Prioridade     int NOT NULL,
    MetaRespostaH  decimal(9,4) NOT NULL,
    MetaResolucaoH decimal(9,4) NOT NULL,
    Regime         nvarchar(10) COLLATE DATABASE_DEFAULT NOT NULL,
    FatorFAIA      decimal(9,4) NOT NULL,
    FatorFARC      decimal(9,4) NOT NULL,
    PRIMARY KEY (Tipo, Prioridade)
);
INSERT INTO #Virt_Parametros (Tipo, Prioridade, MetaRespostaH, MetaResolucaoH, Regime, FatorFAIA, FatorFARC)
VALUES
    (N'Incidente',   1,  1.00,  12, N'24x7', 0.4, 0.4),
    (N'Incidente',   2,  2.00,  24, N'24x7', 0.4, 0.4),
    (N'Incidente',   3,  4.00,  36, N'TCU',  0.4, 0.2),
    (N'Incidente',   4,  8.00,  60, N'TCU',  0.4, 0.2),
    (N'Solicitação', 1,  0.25,  12, N'24x7', 0.4, 0.4),
    (N'Solicitação', 2,  2.00,  24, N'24x7', 0.4, 0.4),
    (N'Solicitação', 3,  4.00,  60, N'TCU',  0.4, 0.2),
    (N'Solicitação', 4,  8.00, 180, N'TCU',  0.4, 0.2),
    (N'Solicitação', 5, 12.00, 360, N'TCU',  0.4, 0.2);

--------------------------------------------------------------------------------
-- [2] Calendario TCU: feriados e pontos facultativos. Conta_SLA = 'N': a data
--     nao tem horario comercial. Demais datas da tabela contam normalmente.
--------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#Virt_Calendario') IS NOT NULL DROP TABLE #Virt_Calendario;
CREATE TABLE #Virt_Calendario (
    Data      date NOT NULL PRIMARY KEY,
    Tipo      nvarchar(20) COLLATE DATABASE_DEFAULT NOT NULL,
    Descricao nvarchar(60) COLLATE DATABASE_DEFAULT NULL,
    Conta_SLA nchar(1) COLLATE DATABASE_DEFAULT NOT NULL
);
INSERT INTO #Virt_Calendario (Data, Tipo, Descricao, Conta_SLA)
VALUES
    ('2025-01-01', N'Feriado',     N'Ano Novo',                 N'N'),
    ('2025-03-03', N'Facultativo', N'Carnaval',                 N'N'),
    ('2025-03-04', N'Facultativo', N'Carnaval',                 N'N'),
    ('2025-03-05', N'Facultativo', N'Carnaval',                 N'S'),
    ('2025-04-17', N'Facultativo', NULL,                        N'N'),
    ('2025-04-18', N'Feriado',     NULL,                        N'N'),
    ('2025-04-21', N'Feriado',     N'Tiradentes',               N'N'),
    ('2025-05-01', N'Feriado',     N'Dia do Trabalhador',       N'N'),
    ('2025-05-02', N'Facultativo', NULL,                        N'N'),
    ('2025-06-19', N'Facultativo', NULL,                        N'N'),
    ('2025-07-20', N'Facultativo', NULL,                        N'N'),
    ('2025-09-07', N'Feriado',     N'Independência do Brasil',  N'N'),
    ('2025-10-12', N'Feriado',     N'Nossa Senhora Aparecida',  N'N'),
    ('2025-10-27', N'Facultativo', NULL,                        N'N'),
    ('2025-11-02', N'Feriado',     NULL,                        N'N'),
    ('2025-11-15', N'Feriado',     N'Proclamação da República', N'N'),
    ('2025-11-20', N'Feriado',     N'Consciência Negra',        N'N'),
    ('2025-11-21', N'Facultativo', NULL,                        N'N'),
    ('2025-12-24', N'Facultativo', N'Véspera de Natal',         N'N'),
    ('2025-12-25', N'Feriado',     N'Natal',                    N'N'),
    ('2025-12-26', N'Facultativo', NULL,                        N'N'),
    ('2025-12-31', N'Facultativo', N'Véspera de Ano Novo',      N'N'),
    ('2026-01-01', N'Feriado',     N'Ano Novo',                 N'N'),
    ('2026-01-02', N'Facultativo', NULL,                        N'N'),
    ('2026-02-16', N'Facultativo', N'Carnaval',                 N'N'),
    ('2026-02-17', N'Facultativo', N'Carnaval',                 N'N'),
    ('2026-02-18', N'Facultativo', N'Carnaval',                 N'N'),
    ('2026-04-02', N'Facultativo', NULL,                        N'N'),
    ('2026-04-03', N'Feriado',     N'Sexta-feira Santa',        N'N'),
    ('2026-04-20', N'Facultativo', NULL,                        N'N'),
    ('2026-04-21', N'Feriado',     N'Tiradentes',               N'N'),
    ('2026-05-01', N'Feriado',     N'Dia do Trabalhador',       N'N'),
    ('2026-06-04', N'Facultativo', N'Corpus Christi',           N'N'),
    ('2026-06-05', N'Facultativo', NULL,                        N'N'),
    ('2026-09-07', N'Feriado',     N'Independência do Brasil',  N'N'),
    ('2026-10-12', N'Feriado',     N'Nossa Senhora Aparecida',  N'N'),
    ('2026-10-28', N'Facultativo', NULL,                        N'N'),
    ('2026-11-02', N'Feriado',     N'Finados',                  N'N'),
    ('2026-11-15', N'Feriado',     N'Proclamação da República', N'N'),
    ('2026-11-20', N'Feriado',     N'Consciência Negra',        N'N'),
    ('2026-12-24', N'Facultativo', N'Véspera de Natal',         N'N'),
    ('2026-12-25', N'Feriado',     N'Natal',                    N'N'),
    ('2026-12-31', N'Facultativo', N'Véspera de Ano Novo',      N'N');

--------------------------------------------------------------------------------
-- [3] Candidatos do periodo, conforme @DataReferencia. Sem substituicao entre
--     as datas: se a data do modo estiver vazia, o chamado nao entra.
--     FECHAMENTO: close_date no periodo, I/R, status terminal (mesma lista da
--       Decision, por codigo) e grupo atual 'Fornecedores - Virtual'.
--     RESOLUCAO: resolve_date no periodo, I/R, com grupo atual Virtual ou
--       alguma transferencia de grupo para a Virtual. A exigencia de a
--       resolucao ter ocorrido na posse da Virtual e aplicada em [6.2].
--------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#Virt_Periodo') IS NOT NULL DROP TABLE #Virt_Periodo;
SELECT
    r.id,
    r.persid,
    r.ref_num,
    r.[type],
    r.priority,
    r.status,
    r.category,
    r.group_id,
    r.log_agent,
    r.assignee,
    r.affected_rc,
    r.open_date,
    r.resolve_date,
    r.close_date,
    LTRIM(RTRIM(CONVERT(nvarchar(4000), r.summary))) AS resumo
INTO #Virt_Periodo
FROM dbo.call_req AS r
WHERE r.[type] IN ('I', 'R')
  AND (
        (    @DataReferencia = N'FECHAMENTO'
         AND r.close_date IS NOT NULL
         AND r.close_date >= @IniEpoch
         AND r.close_date <  @FimEpoch
         AND r.group_id = @GrupoVirtual
         AND r.status IN (
                'CL',        -- Resolvido, concluido
                'CLD',       -- Fechado, Solucao Implantada
                'CLUNRSLV',  -- Nao resolvido, fechado
                'CNCL',      -- Cancelada
                'ATGR',      -- Cancelado
                'END',       -- Encerrado
                'PC',        -- Fechado, solucao nao implantada
                'RE',        -- Resolvido, Solucao Definida
                'VARES'      -- Resolvido pelo VA
             )
        )
     OR (    @DataReferencia = N'RESOLUCAO'
         AND r.resolve_date IS NOT NULL
         AND r.resolve_date >= @IniEpoch
         AND r.resolve_date <  @FimEpoch
         AND (    r.group_id = @GrupoVirtual
               OR EXISTS (
                      SELECT 1
                      FROM dbo.act_log AS al
                      WHERE al.call_req_id = r.persid
                        AND al.[type] = 'TR'
                        AND CONVERT(nvarchar(4000), al.[description])
                            LIKE N'%Transferir Grupo de %para ''' + @GrupoVirtualNome + N'''%'
                  )
             )
        )
      )
OPTION (RECOMPILE);
CREATE UNIQUE CLUSTERED INDEX IX_Virt_Periodo ON #Virt_Periodo (id);
CREATE UNIQUE INDEX IX_Virt_Periodo_persid ON #Virt_Periodo (persid);

--------------------------------------------------------------------------------
-- [4] Eventos de grupo e de status desses chamados, da abertura ao fechamento
--     (sem fechamento: todos os eventos registrados; o calculo termina nos
--     marcos, nunca na data atual), com os nomes extraidos do texto padrao do
--     act_log:
--       TR: "Transferir Grupo de 'X' para 'Y'"
--       status: "Status alterado de 'X' para 'Y'.", em qualquer tipo de
--       registro (ST, RE = ida para homologacao, RO = reabertura, CL...)
--       SOLN: solucao registrada, que muda o status sem gravar a transicao
--     Transferencia so de responsavel nao tem grupo_de/grupo_para e nao muda a
--     posse.
--------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#Virt_Log') IS NOT NULL DROP TABLE #Virt_Log;
SELECT
    p.id,
    al.id AS log_id,
    al.system_time,
    al.[type],
    g.grupo_de,
    g.grupo_para,
    st.status_de,
    st.status_para
INTO #Virt_Log
FROM #Virt_Periodo AS p
JOIN dbo.act_log AS al
    ON al.call_req_id = p.persid
CROSS APPLY (SELECT txt = CONVERT(nvarchar(4000), al.[description])) AS t
CROSS APPLY (SELECT pg = CHARINDEX(N'Transferir Grupo de ''', t.txt)) AS pg
CROSS APPLY (
    SELECT resto = CASE WHEN al.[type] = 'TR' AND pg.pg > 0
                        THEN SUBSTRING(t.txt, pg.pg + 21, 4000) END
) AS rg
CROSS APPLY (
    SELECT
        grupo_de = CASE WHEN CHARINDEX(N'''', rg.resto) > 0
                        THEN LEFT(rg.resto, CHARINDEX(N'''', rg.resto) - 1) END,
        para     = CASE WHEN CHARINDEX(N''' para ''', rg.resto) > 0
                        THEN SUBSTRING(rg.resto, CHARINDEX(N''' para ''', rg.resto) + 8, 4000) END
) AS g0
CROSS APPLY (
    SELECT
        grupo_de   = g0.grupo_de,
        grupo_para = CASE WHEN CHARINDEX(N'''', g0.para) > 0
                          THEN LEFT(g0.para, CHARINDEX(N'''', g0.para) - 1) END
) AS g
CROSS APPLY (
    SELECT ps = CASE WHEN t.txt LIKE N'Status alterado de %'
                     THEN CHARINDEX(N''' para ''', t.txt) ELSE 0 END
) AS ps
CROSS APPLY (
    SELECT status_resto = CASE WHEN ps.ps > 0 THEN SUBSTRING(t.txt, ps.ps + 8, 4000) END
) AS sr
CROSS APPLY (
    SELECT
        -- "Status alterado de '" tem 20 caracteres: a origem comeca no 21o.
        status_de   = CASE WHEN ps.ps > 21 THEN SUBSTRING(t.txt, 21, ps.ps - 21) END,
        status_para = CASE WHEN CHARINDEX(N'''', sr.status_resto) > 0
                           THEN LEFT(sr.status_resto, CHARINDEX(N'''', sr.status_resto) - 1) END
) AS st
WHERE (al.[type] IN ('TR', 'SOLN') OR t.txt LIKE N'Status alterado de %')
  AND al.system_time >= p.open_date
  AND (p.close_date IS NULL OR al.system_time <= p.close_date);
CREATE CLUSTERED INDEX IX_Virt_Log ON #Virt_Log (id, system_time, log_id);

--------------------------------------------------------------------------------
-- [5] Grupo inicial, encerramento na Virtual e movimentos de entrada/saida.
--     Nasceu no grupo = o grupo de origem da primeira transferencia de grupo e
--     o Virtual; sem transferencia de grupo, vale o grupo atual.
--     Encerrou na Virtual = sem transferencia de grupo (nasceu e ficou), ou a
--     ULTIMA transferencia de grupo ate o fechamento foi uma entrada na Virtual.
--------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#Virt_GrupoInicial') IS NOT NULL DROP TABLE #Virt_GrupoInicial;
SELECT
    p.id,
    COALESCE(prim.grupo_de, LTRIM(RTRIM(ga.last_name))) AS grupo_inicial,
    ult.grupo_para AS grupo_ultima_transferencia
INTO #Virt_GrupoInicial
FROM #Virt_Periodo AS p
OUTER APPLY (
    SELECT TOP (1) l.grupo_de
    FROM #Virt_Log AS l
    WHERE l.id = p.id
      AND l.grupo_para IS NOT NULL
    ORDER BY l.system_time, l.log_id
) AS prim
OUTER APPLY (
    SELECT TOP (1) l.grupo_para
    FROM #Virt_Log AS l
    WHERE l.id = p.id
      AND l.grupo_para IS NOT NULL
    ORDER BY l.system_time DESC, l.log_id DESC
) AS ult
LEFT JOIN dbo.ca_contact AS ga
    ON ga.contact_uuid = p.group_id;
CREATE UNIQUE CLUSTERED INDEX IX_Virt_GrupoInicial ON #Virt_GrupoInicial (id);

IF OBJECT_ID('tempdb..#Virt_Movimento') IS NOT NULL DROP TABLE #Virt_Movimento;
CREATE TABLE #Virt_Movimento (
    id          int NOT NULL,
    momento     int NOT NULL,
    movimento   char(1) NOT NULL  -- E = entrada, S = saida
);
INSERT INTO #Virt_Movimento (id, momento, movimento)
SELECT p.id, p.open_date, 'E'
FROM #Virt_Periodo AS p
JOIN #Virt_GrupoInicial AS gi
    ON gi.id = p.id
WHERE gi.grupo_inicial = @GrupoVirtualNome;

INSERT INTO #Virt_Movimento (id, momento, movimento)
SELECT l.id, l.system_time, 'E'
FROM #Virt_Log AS l
WHERE l.grupo_para = @GrupoVirtualNome
  AND l.grupo_de <> @GrupoVirtualNome;

INSERT INTO #Virt_Movimento (id, momento, movimento)
SELECT l.id, l.system_time, 'S'
FROM #Virt_Log AS l
WHERE l.grupo_de = @GrupoVirtualNome
  AND l.grupo_para <> @GrupoVirtualNome;
CREATE CLUSTERED INDEX IX_Virt_Movimento ON #Virt_Movimento (id, movimento, momento);

--------------------------------------------------------------------------------
-- [6] Candidatos com os marcos e o indicador de encerramento na Virtual.
--------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#Virt_Candidato') IS NOT NULL DROP TABLE #Virt_Candidato;
SELECT
    p.id,
    p.persid,
    p.ref_num,
    p.resumo,
    p.status,
    p.category,
    p.log_agent,
    p.assignee,
    p.affected_rc,
    p.group_id,
    CASE p.[type] WHEN 'I' THEN N'Incidente' WHEN 'R' THEN N'Solicitação' END AS tipo,
    p.priority AS prioridade,
    p.open_date AS abertura_epoch,
    ent.entrada_epoch,
    COALESCE(ini.inicio_epoch, atv.atividade_epoch, ent.entrada_epoch) AS inicio_epoch,
    COALESCE(
        p.resolve_date,
        CASE WHEN NOT (sa.resolved = 0 AND sa.hold = 0) THEN re.ultimo_re END
    ) AS resolucao_epoch,
    p.close_date AS fechamento_epoch,
    p.resolve_date AS resolve_date_sdm,
    -- Encerrou na Virtual: sem transferencia de grupo (nasceu e ficou nela) ou a
    -- ultima transferencia de grupo ate o fechamento foi uma entrada na Virtual.
    CASE WHEN (gi.grupo_ultima_transferencia IS NULL AND gi.grupo_inicial = @GrupoVirtualNome)
           OR gi.grupo_ultima_transferencia = @GrupoVirtualNome
         THEN 1 ELSE 0 END AS encerrou_virtual
INTO #Virt_Candidato
FROM #Virt_Periodo AS p
JOIN #Virt_GrupoInicial AS gi
    ON gi.id = p.id
JOIN dbo.cr_stat AS sa
    ON sa.code = p.status
-- Primeira entrada na Virtual: a abertura, se nasceu nela; senao a primeira
-- transferencia para o grupo.
OUTER APPLY (
    SELECT MIN(m.momento) AS entrada_epoch
    FROM #Virt_Movimento AS m
    WHERE m.id = p.id
      AND m.movimento = 'E'
) AS ent
-- Inicio (captura): primeira passagem para 'Em andamento', com o chamado dentro
-- de uma passagem pelo grupo Virtual (entrada antes do evento e nenhuma saida
-- entre a entrada e o evento, inclusive no mesmo segundo).
OUTER APPLY (
    SELECT MIN(l.system_time) AS inicio_epoch
    FROM #Virt_Log AS l
    JOIN dbo.cr_stat AS sd
        ON sd.sym = l.status_para COLLATE DATABASE_DEFAULT
    WHERE l.id = p.id
      AND l.[type] IN ('ST', 'RE')
      AND sd.code = 'FIP' -- Em andamento
      AND EXISTS (
            SELECT 1
            FROM #Virt_Movimento AS e
            WHERE e.id = p.id
              AND e.movimento = 'E'
              AND e.momento < l.system_time
              AND NOT EXISTS (
                    SELECT 1
                    FROM #Virt_Movimento AS s
                    WHERE s.id = p.id
                      AND s.movimento = 'S'
                      AND s.momento >= e.momento
                      AND s.momento <= l.system_time
              )
      )
) AS ini
-- Fallback da captura, como na Decision: sem 'Em andamento' na posse, a primeira
-- atividade registrada na posse (qualquer act_log, exceto transferencias), com
-- o mesmo criterio de posse do Inicio. Sem atividade, vale a entrada (Tini 0).
OUTER APPLY (
    SELECT MIN(al.system_time) AS atividade_epoch
    FROM dbo.act_log AS al
    WHERE ini.inicio_epoch IS NULL
      AND al.call_req_id = p.persid
      AND ISNULL(al.[type], '') <> 'TR'
      AND al.system_time >= p.open_date
      AND (p.close_date IS NULL OR al.system_time <= p.close_date)
      AND EXISTS (
            SELECT 1
            FROM #Virt_Movimento AS e
            WHERE e.id = p.id
              AND e.movimento = 'E'
              AND e.momento < al.system_time
              AND NOT EXISTS (
                    SELECT 1
                    FROM #Virt_Movimento AS s
                    WHERE s.id = p.id
                      AND s.movimento = 'S'
                      AND s.momento >= e.momento
                      AND s.momento <= al.system_time
              )
      )
) AS atv
OUTER APPLY (
    SELECT MAX(l.system_time) AS ultimo_re
    FROM #Virt_Log AS l
    WHERE l.id = p.id
      AND l.[type] = 'RE'
) AS re;
CREATE UNIQUE CLUSTERED INDEX IX_Virt_Candidato ON #Virt_Candidato (id);

--------------------------------------------------------------------------------
-- [6.1] Janelas de posse da Virtual.
--     Linha do tempo de grupo: a abertura (no grupo inicial) e cada
--     transferencia de grupo, em ordem de system_time e act_log.id. Cada trecho
--     vai de um evento ao seguinte; ficam os trechos em que o grupo e o Virtual.
--     Fora da Virtual nao conta; saida para o relogio; reentrada o religa;
--     todas as janelas sao somadas. Quem nasceu na Virtual tem a primeira
--     janela iniciando na abertura. Janela sem fim (fim NULL) = o chamado
--     continuava na Virtual no ultimo evento lido.
--------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#Virt_LinhaGrupo') IS NOT NULL DROP TABLE #Virt_LinhaGrupo;
SELECT
    c.id,
    c.abertura_epoch AS momento,
    0 AS ordem,
    CASE WHEN gi.grupo_inicial = @GrupoVirtualNome THEN 1 ELSE 0 END AS na_virtual
INTO #Virt_LinhaGrupo
FROM #Virt_Candidato AS c
JOIN #Virt_GrupoInicial AS gi
    ON gi.id = c.id
UNION ALL
SELECT
    l.id,
    l.system_time,
    l.log_id,
    CASE WHEN l.grupo_para = @GrupoVirtualNome THEN 1 ELSE 0 END
FROM #Virt_Log AS l
JOIN #Virt_Candidato AS c
    ON c.id = l.id
WHERE l.grupo_para IS NOT NULL;

IF OBJECT_ID('tempdb..#Virt_Janela') IS NOT NULL DROP TABLE #Virt_Janela;
SELECT
    x.id,
    ROW_NUMBER() OVER (PARTITION BY x.id ORDER BY x.momento, x.ordem) AS passagem,
    x.momento AS ini_epoch,
    x.proximo AS fim_epoch,
    DATEADD(HOUR, -@HorasBrasilParaUTC, DATEADD(SECOND, x.momento, @Epoch)) AS ini,
    DATEADD(HOUR, -@HorasBrasilParaUTC, DATEADD(SECOND, x.proximo, @Epoch)) AS fim -- NULL = ainda na Virtual
INTO #Virt_Janela
FROM (
    SELECT
        g.id, g.momento, g.ordem, g.na_virtual,
        LEAD(g.momento) OVER (PARTITION BY g.id ORDER BY g.momento, g.ordem) AS proximo
    FROM #Virt_LinhaGrupo AS g
) AS x
WHERE x.na_virtual = 1
  AND (x.proximo IS NULL OR x.proximo > x.momento);
CREATE CLUSTERED INDEX IX_Virt_Janela ON #Virt_Janela (id, passagem);

--------------------------------------------------------------------------------
-- [6.2] Chamados da Virtual: responsabilidade validada no marco escolhido.
--     FECHAMENTO: encerrou na Virtual (cadeia de transferencias ate o
--       fechamento).
--     RESOLUCAO: resolve_date dentro de uma janela de posse da Virtual,
--       limites inclusivos; janela sem fim vale ate qualquer instante posterior.
--------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#Virt_Chamado') IS NOT NULL DROP TABLE #Virt_Chamado;
SELECT c.*
INTO #Virt_Chamado
FROM #Virt_Candidato AS c
WHERE (@DataReferencia = N'FECHAMENTO' AND c.encerrou_virtual = 1)
   OR (@DataReferencia = N'RESOLUCAO'
       AND EXISTS (
             SELECT 1
             FROM #Virt_Janela AS j
             WHERE j.id = c.id
               AND c.resolve_date_sdm >= j.ini_epoch
               AND (j.fim_epoch IS NULL OR c.resolve_date_sdm <= j.fim_epoch)
       ));
CREATE UNIQUE CLUSTERED INDEX IX_Virt_Chamado ON #Virt_Chamado (id);

--------------------------------------------------------------------------------
-- [7] Marcos em horario do Brasil, regime e parametros.
--------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#Virt_Marco') IS NOT NULL DROP TABLE #Virt_Marco;
SELECT
    c.id,
    c.persid,
    c.ref_num,
    c.resumo,
    c.status,
    c.category,
    c.log_agent,
    c.assignee,
    c.affected_rc,
    c.group_id,
    c.tipo,
    c.prioridade,
    pr.Regime AS regime,
    DATEADD(HOUR, -@HorasBrasilParaUTC, DATEADD(SECOND, c.abertura_epoch,   @Epoch)) AS abertura,
    DATEADD(HOUR, -@HorasBrasilParaUTC, DATEADD(SECOND, c.entrada_epoch,    @Epoch)) AS entrada,
    DATEADD(HOUR, -@HorasBrasilParaUTC, DATEADD(SECOND, c.inicio_epoch,     @Epoch)) AS inicio,
    DATEADD(HOUR, -@HorasBrasilParaUTC, DATEADD(SECOND, c.resolucao_epoch,  @Epoch)) AS resolucao,
    DATEADD(HOUR, -@HorasBrasilParaUTC, DATEADD(SECOND, c.fechamento_epoch, @Epoch)) AS fechamento,
    pr.MetaRespostaH,
    pr.MetaResolucaoH,
    pr.FatorFAIA,
    pr.FatorFARC
INTO #Virt_Marco
FROM #Virt_Chamado AS c
LEFT JOIN #Virt_Parametros AS pr
    ON pr.Tipo = c.tipo
   AND pr.Prioridade = c.prioridade;
CREATE UNIQUE CLUSTERED INDEX IX_Virt_Marco ON #Virt_Marco (id);

--------------------------------------------------------------------------------
-- [8] Dias com horario comercial (segunda a sexta, fora das datas com
--     Conta_SLA = 'N'), cobrindo de abertura ate o ultimo marco.
--------------------------------------------------------------------------------
DECLARE @DiaMin date = (SELECT MIN(CONVERT(date, abertura)) FROM #Virt_Marco);
DECLARE @DiaMax date = (SELECT MAX(CONVERT(date, CASE WHEN resolucao > inicio OR inicio IS NULL THEN resolucao ELSE inicio END)) FROM #Virt_Marco);

IF OBJECT_ID('tempdb..#Virt_DiaUtil') IS NOT NULL DROP TABLE #Virt_DiaUtil;
CREATE TABLE #Virt_DiaUtil (
    Dia       date NOT NULL PRIMARY KEY,
    InicioCom datetime2(0) NOT NULL,
    FimCom    datetime2(0) NOT NULL
);
IF @DiaMin IS NOT NULL AND @DiaMax IS NOT NULL
INSERT INTO #Virt_DiaUtil (Dia, InicioCom, FimCom)
SELECT
    d.Dia,
    DATEADD(HOUR, @HoraInicioComercial, CONVERT(datetime2(0), d.Dia)),
    DATEADD(HOUR, @HoraFimComercial,    CONVERT(datetime2(0), d.Dia))
FROM (
    SELECT TOP (DATEDIFF(DAY, @DiaMin, @DiaMax) + 1)
        DATEADD(DAY, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1, @DiaMin) AS Dia
    FROM sys.all_columns AS a
    CROSS JOIN sys.all_columns AS b
) AS d
-- 1900-01-01 foi segunda-feira: resto 5 e 6 = sabado e domingo, sem depender
-- de SET DATEFIRST.
WHERE DATEDIFF(DAY, '19000101', d.Dia) % 7 < 5
  AND NOT EXISTS (
        SELECT 1 FROM #Virt_Calendario AS k
        WHERE k.Data = d.Dia AND k.Conta_SLA = N'N'
  );

--------------------------------------------------------------------------------
-- [9] Status ativos e trechos ate os marcos.
--     Linha do tempo de status do chamado: na abertura vale a origem do
--     primeiro evento de status (sem evento, 'Aberto, aguarda atendimento'); cada
--     evento de status (ST, RE, RO, CL...) passa a valer o status de destino ate
--     o proximo, em ordem de system_time e act_log.id. Um SOLN e uma entrada
--     implicita em status nao ativo, como na Decision. Ativos, como no Tempo de
--     Atendimento da Decision: 'Em andamento' (FIP) e 'Aberto, aguarda
--     atendimento' (OP). Os demais (Aguarda atendimento, Agendado, Em
--     homologacao, Reaberto...) pausam o Tempo de Atendimento.
--------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#Virt_StatusLinha') IS NOT NULL DROP TABLE #Virt_StatusLinha;
SELECT
    c.id,
    c.abertura_epoch AS momento,
    0 AS ordem,
    CASE WHEN pe.code_de IS NULL OR pe.code_de IN ('FIP', 'OP') THEN 1 ELSE 0 END AS ativo
INTO #Virt_StatusLinha
FROM #Virt_Chamado AS c
OUTER APPLY (
    SELECT TOP (1) sdd.code AS code_de
    FROM #Virt_Log AS l
    LEFT JOIN dbo.cr_stat AS sdd
        ON sdd.sym = l.status_de COLLATE DATABASE_DEFAULT
    WHERE l.id = c.id
      AND l.status_para IS NOT NULL
    ORDER BY l.system_time, l.log_id
) AS pe
UNION ALL
SELECT
    l.id,
    l.system_time,
    l.log_id,
    CASE WHEN sd.code IN ('FIP', 'OP') THEN 1 ELSE 0 END
FROM #Virt_Log AS l
JOIN #Virt_Chamado AS c
    ON c.id = l.id
LEFT JOIN dbo.cr_stat AS sd
    ON sd.sym = l.status_para COLLATE DATABASE_DEFAULT
WHERE l.status_para IS NOT NULL
   OR l.[type] = 'SOLN'; -- SOLN: sem destino gravado, fica nao ativo

IF OBJECT_ID('tempdb..#Virt_StatusAtivo') IS NOT NULL DROP TABLE #Virt_StatusAtivo;
SELECT
    x.id,
    DATEADD(HOUR, -@HorasBrasilParaUTC, DATEADD(SECOND, x.momento, @Epoch)) AS ini,
    DATEADD(HOUR, -@HorasBrasilParaUTC, DATEADD(SECOND, x.proximo, @Epoch)) AS fim -- NULL = ainda ativo
INTO #Virt_StatusAtivo
FROM (
    SELECT
        s.id, s.momento, s.ordem, s.ativo,
        LEAD(s.momento) OVER (PARTITION BY s.id ORDER BY s.momento, s.ordem) AS proximo
    FROM #Virt_StatusLinha AS s
) AS x
WHERE x.ativo = 1
  AND (x.proximo IS NULL OR x.proximo > x.momento);
CREATE CLUSTERED INDEX IX_Virt_StatusAtivo ON #Virt_StatusAtivo (id, ini);

-- Trechos de posse ate o marco: R = ate o Inicio (resposta); T = ate a
-- Resolucao (posse total, base do Tempo suspenso); S = ate a Resolucao e so em
-- status ativo (Tempo de Atendimento).
IF OBJECT_ID('tempdb..#Virt_Trecho') IS NOT NULL DROP TABLE #Virt_Trecho;
SELECT
    j.id,
    k.medida,
    j.ini AS a,
    CASE WHEN j.fim IS NULL OR j.fim > k.marco THEN k.marco ELSE j.fim END AS b
INTO #Virt_Trecho
FROM #Virt_Janela AS j
JOIN #Virt_Marco AS m
    ON m.id = j.id
CROSS APPLY (VALUES ('R', m.inicio), ('T', m.resolucao)) AS k (medida, marco)
WHERE k.marco IS NOT NULL
  AND j.ini < k.marco;

INSERT INTO #Virt_Trecho (id, medida, a, b)
SELECT
    j.id,
    'S',
    lim.a,
    lim.b
FROM #Virt_Janela AS j
JOIN #Virt_Marco AS m
    ON m.id = j.id
JOIN #Virt_StatusAtivo AS sa
    ON sa.id = j.id
CROSS APPLY (
    SELECT
        a = (SELECT MAX(v) FROM (VALUES (j.ini), (sa.ini)) AS x (v)),
        b = (SELECT MIN(v) FROM (VALUES (j.fim), (sa.fim), (m.resolucao)) AS x (v))
) AS lim
WHERE m.resolucao IS NOT NULL
  AND lim.a < lim.b;
CREATE CLUSTERED INDEX IX_Virt_Trecho ON #Virt_Trecho (id, medida);

--------------------------------------------------------------------------------
-- [10] Tempos em segundos, somados sobre os trechos. Tini = posse ate o
--      Inicio; Tsol = posse em status ativo ate a Resolucao; posse total ate a
--      Resolucao para o Tempo suspenso. As horas comerciais so existem no
--      regime TCU. No 24x7 todo o tempo fica no bloco nao comercial e o excesso
--      e medido sobre o corrido.
--------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#Virt_Tempo') IS NOT NULL DROP TABLE #Virt_Tempo;
SELECT
    m.id,
    CASE WHEN m.inicio IS NULL THEN NULL ELSE ISNULL(cor.resp, 0) END AS tini_s,
    CASE WHEN m.resolucao IS NULL THEN NULL ELSE ISNULL(cor.sol, 0) END AS tsol_s,
    CASE WHEN m.resolucao IS NULL THEN NULL ELSE ISNULL(cor.posse, 0) END AS posse_sol_s,
    CASE WHEN m.inicio IS NULL THEN NULL
         WHEN m.regime = N'24x7' THEN 0
         ELSE ISNULL(com.resp, 0) END AS com_resp_s,
    CASE WHEN m.resolucao IS NULL THEN NULL
         WHEN m.regime = N'24x7' THEN 0
         ELSE ISNULL(com.sol, 0) END AS com_sol_s
INTO #Virt_Tempo
FROM #Virt_Marco AS m
OUTER APPLY (
    SELECT
        SUM(CASE WHEN t.medida = 'R' THEN DATEDIFF_BIG(SECOND, t.a, t.b) END) AS resp,
        SUM(CASE WHEN t.medida = 'S' THEN DATEDIFF_BIG(SECOND, t.a, t.b) END) AS sol,
        SUM(CASE WHEN t.medida = 'T' THEN DATEDIFF_BIG(SECOND, t.a, t.b) END) AS posse
    FROM #Virt_Trecho AS t
    WHERE t.id = m.id
) AS cor
OUTER APPLY (
    SELECT
        SUM(CASE WHEN d.medida = 'R' THEN d.seg END) AS resp,
        SUM(CASE WHEN d.medida = 'S' THEN d.seg END) AS sol
    FROM (
        SELECT
            t.medida,
            DATEDIFF_BIG(SECOND,
                CASE WHEN t.a > u.InicioCom THEN t.a ELSE u.InicioCom END,
                CASE WHEN t.b < u.FimCom    THEN t.b ELSE u.FimCom    END) AS seg
        FROM #Virt_Trecho AS t
        JOIN #Virt_DiaUtil AS u
            ON u.Dia BETWEEN CONVERT(date, t.a) AND CONVERT(date, t.b)
           AND t.b > u.InicioCom
           AND t.a < u.FimCom
        WHERE t.id = m.id
    ) AS d
) AS com;
CREATE UNIQUE CLUSTERED INDEX IX_Virt_Tempo ON #Virt_Tempo (id);

--------------------------------------------------------------------------------
-- [11] Calculo numerico, em segundos. Excesso: TCU sobre horas comerciais,
--      24x7 sobre tempo corrido. Indice = horas de excesso (arredondadas em
--      6 casas) x fator.
--------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#Virt_Calculo') IS NOT NULL DROP TABLE #Virt_Calculo;
SELECT
    m.id,
    t.tini_s,
    t.tsol_s,
    t.com_resp_s,
    t.tini_s - t.com_resp_s AS ncom_resp_s,
    t.com_sol_s,
    t.tsol_s - t.com_sol_s AS ncom_sol_s,
    mt.meta_resp_s,
    mt.meta_sol_s,
    x.exc_resp_s,
    x.exc_sol_s,
    -- Tempo suspenso: tempo de posse ate a Resolucao em status nao ativo
    -- (corrido). Tsol + Tempo suspenso = posse total ate a Resolucao.
    t.posse_sol_s - t.tsol_s AS suspenso_s,
    CONVERT(decimal(18,6), CONVERT(decimal(18,6), x.exc_sol_s  / 3600.0000000000) * m.FatorFARC) AS indice_farc,
    CONVERT(decimal(18,6), CONVERT(decimal(18,6), x.exc_resp_s / 3600.0000000000) * m.FatorFAIA) AS indice_faia
INTO #Virt_Calculo
FROM #Virt_Marco AS m
JOIN #Virt_Tempo AS t
    ON t.id = m.id
CROSS APPLY (
    SELECT
        meta_resp_s = CONVERT(bigint, m.MetaRespostaH  * 3600),
        meta_sol_s  = CONVERT(bigint, m.MetaResolucaoH * 3600)
) AS mt
CROSS APPLY (
    SELECT
        base_resp = CASE WHEN m.regime = N'24x7' THEN t.tini_s ELSE t.com_resp_s END,
        base_sol  = CASE WHEN m.regime = N'24x7' THEN t.tsol_s ELSE t.com_sol_s  END
) AS b
CROSS APPLY (
    SELECT
        exc_resp_s = CASE WHEN mt.meta_resp_s IS NULL OR b.base_resp IS NULL THEN NULL
                          WHEN b.base_resp > mt.meta_resp_s THEN b.base_resp - mt.meta_resp_s
                          ELSE 0 END,
        exc_sol_s  = CASE WHEN mt.meta_sol_s IS NULL OR b.base_sol IS NULL THEN NULL
                          WHEN b.base_sol > mt.meta_sol_s THEN b.base_sol - mt.meta_sol_s
                          ELSE 0 END
) AS x;
CREATE UNIQUE CLUSTERED INDEX IX_Virt_Calculo ON #Virt_Calculo (id);

--------------------------------------------------------------------------------
-- [12] Linhas finais.
--      Bloco A: identificacao e datas. Bloco B: as 15 colunas de apuracao da
--      Virtual. Bloco C: colunas de contexto no padrao da Decision.
--      As duracoes saem como texto [h]:mm:ss (horas acima de 24 sem virar o
--      dia). A formatacao e feita so aqui, depois do
--      calculo; fatores e indices continuam numericos.
--------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#Virt_Saida') IS NOT NULL DROP TABLE #Virt_Saida;
SELECT
    CASE WHEN m.regime = N'24x7' THEN N'Chamados_24x7' ELSE N'Chamados_TCU' END AS Aba,
    -- Bloco A
    m.ref_num AS [ID Chamado],
    m.resumo AS [Descrição do Chamado],
    m.tipo AS [Tipo (Incidente/Solicitação)],
    m.prioridade AS [Prioridade],
    m.regime AS [Regime],
    m.abertura AS [Data/Hora Abertura],
    m.inicio AS [Data/Hora Início Atendimento],
    m.resolucao AS [Data/Hora Resolução],
    m.fechamento AS [Data/Hora Fechamento],
    -- Bloco B
    f.tini AS [Tini (h)],
    f.tsol AS [Tsol (h)],
    f.com_resp AS [Horas Comerciais Resposta (h)],
    f.ncom_resp AS [Horas Não Comerciais Resposta (h)],
    f.com_sol AS [Horas Comerciais Resolução (h)],
    f.ncom_sol AS [Horas Não Comerciais Resolução (h)],
    f.meta_resp AS [Meta Resposta (h)],
    f.meta_sol AS [Meta Resolução (h)],
    f.exc_resp AS [Excesso Resposta (h)],
    f.exc_sol AS [Excesso Resolução (h)],
    CONCAT(m.tipo, N'|', m.prioridade, N'|', m.regime) AS [chave],
    m.FatorFARC AS [Fator FARC],
    c.indice_farc AS [Indice FARC],
    m.FatorFAIA AS [Fator FAIA],
    c.indice_faia AS [Indice FAIA],
    -- Bloco C
    ISNULL(st.sym, N'N/A') AS [Status],
    ISNULL(pc.sym, N'N/A') AS [Categoria],
    LTRIM(RTRIM(
        CASE
            WHEN (ISNULL(la.first_name, N'') <> N'' OR ISNULL(la.last_name, N'') <> N'')
                THEN CONCAT(ISNULL(la.first_name, N''), N' ', ISNULL(la.last_name, N''))
            WHEN ISNULL(la.userid, N'') <> N'' THEN la.userid
            ELSE N'N/A'
        END
    )) AS [Responsável Abertura],
    LTRIM(RTRIM(
        CASE
            WHEN (ISNULL(asg.first_name, N'') <> N'' OR ISNULL(asg.last_name, N'') <> N'')
                THEN CONCAT(ISNULL(asg.first_name, N''), N' ', ISNULL(asg.last_name, N''))
            WHEN ISNULL(asg.userid, N'') <> N'' THEN asg.userid
            ELSE N'N/A'
        END
    )) AS [Responsável Atendimento],
    ic.resource_name AS [Item de Configuração],
    m.entrada AS [Data Entrada Grupo Virtual],
    f.suspenso AS [Tempo suspenso],
    CASE WHEN c.exc_resp_s IS NULL THEN N'N/A'
         WHEN c.exc_resp_s > 0 THEN N'Não Atende'
         ELSE N'Atende' END AS [Meta Primeiro Atendimento],
    CASE WHEN EXISTS (
            SELECT 1
            FROM dbo.act_log AS al
            WHERE al.call_req_id = m.persid
              AND (
                    CONVERT(nvarchar(max), ISNULL(al.[type], N''))       COLLATE Latin1_General_CI_AI LIKE N'%reab%'
                 OR CONVERT(nvarchar(max), ISNULL(al.[description], N'')) COLLATE Latin1_General_CI_AI LIKE N'%reabert%'
                 OR CONVERT(nvarchar(max), ISNULL(al.action_desc, N''))   COLLATE Latin1_General_CI_AI LIKE N'%reabert%'
              )
         ) THEN N'Sim' ELSE N'Não' END AS [Indicador Reabertura],
    N'-' AS [Acordo Prazo],
    N'-' AS [Acordo Qualidade],
    N'-' AS [Justificativa],
    CASE WHEN c.exc_sol_s IS NULL THEN N'N/A'
         WHEN c.exc_sol_s > 0 THEN N'Não Atende'
         ELSE N'Atende' END AS [Meta Atendimento],
    -- Grupo atual do chamado no SDM (call_req.group_id), pelo nome do cadastro.
    -- Informativo: nao e a posse historica nem participa do escopo.
    LTRIM(RTRIM(grp.last_name)) AS [Grupo]
INTO #Virt_Saida
FROM #Virt_Marco AS m
JOIN #Virt_Calculo AS c
    ON c.id = m.id
-- Juncoes pela chave primaria do lado direito: no maximo uma linha cada.
LEFT JOIN dbo.cr_stat AS st
    ON st.code = m.status
LEFT JOIN dbo.prob_ctg AS pc
    ON pc.persid = m.category
LEFT JOIN dbo.ca_contact AS la
    ON la.contact_uuid = m.log_agent
LEFT JOIN dbo.ca_contact AS asg
    ON asg.contact_uuid = m.assignee
LEFT JOIN dbo.ca_owned_resource AS ic
    ON ic.own_resource_uuid = m.affected_rc
LEFT JOIN dbo.ca_contact AS grp
    ON grp.contact_uuid = m.group_id
-- [h]:mm:ss a partir de segundos inteiros: horas = s / 3600 (sem limite de 24),
-- minutos = (s % 3600) / 60, segundos = s % 60.
CROSS APPLY (
    SELECT
        tini      = CASE WHEN c.tini_s      IS NULL THEN NULL ELSE CONCAT(c.tini_s      / 3600, N':', RIGHT(CONCAT(N'0', c.tini_s      % 3600 / 60), 2), N':', RIGHT(CONCAT(N'0', c.tini_s      % 60), 2)) END,
        tsol      = CASE WHEN c.tsol_s      IS NULL THEN NULL ELSE CONCAT(c.tsol_s      / 3600, N':', RIGHT(CONCAT(N'0', c.tsol_s      % 3600 / 60), 2), N':', RIGHT(CONCAT(N'0', c.tsol_s      % 60), 2)) END,
        com_resp  = CASE WHEN c.com_resp_s  IS NULL THEN NULL ELSE CONCAT(c.com_resp_s  / 3600, N':', RIGHT(CONCAT(N'0', c.com_resp_s  % 3600 / 60), 2), N':', RIGHT(CONCAT(N'0', c.com_resp_s  % 60), 2)) END,
        ncom_resp = CASE WHEN c.ncom_resp_s IS NULL THEN NULL ELSE CONCAT(c.ncom_resp_s / 3600, N':', RIGHT(CONCAT(N'0', c.ncom_resp_s % 3600 / 60), 2), N':', RIGHT(CONCAT(N'0', c.ncom_resp_s % 60), 2)) END,
        com_sol   = CASE WHEN c.com_sol_s   IS NULL THEN NULL ELSE CONCAT(c.com_sol_s   / 3600, N':', RIGHT(CONCAT(N'0', c.com_sol_s   % 3600 / 60), 2), N':', RIGHT(CONCAT(N'0', c.com_sol_s   % 60), 2)) END,
        ncom_sol  = CASE WHEN c.ncom_sol_s  IS NULL THEN NULL ELSE CONCAT(c.ncom_sol_s  / 3600, N':', RIGHT(CONCAT(N'0', c.ncom_sol_s  % 3600 / 60), 2), N':', RIGHT(CONCAT(N'0', c.ncom_sol_s  % 60), 2)) END,
        meta_resp = CASE WHEN c.meta_resp_s IS NULL THEN NULL ELSE CONCAT(c.meta_resp_s / 3600, N':', RIGHT(CONCAT(N'0', c.meta_resp_s % 3600 / 60), 2), N':', RIGHT(CONCAT(N'0', c.meta_resp_s % 60), 2)) END,
        meta_sol  = CASE WHEN c.meta_sol_s  IS NULL THEN NULL ELSE CONCAT(c.meta_sol_s  / 3600, N':', RIGHT(CONCAT(N'0', c.meta_sol_s  % 3600 / 60), 2), N':', RIGHT(CONCAT(N'0', c.meta_sol_s  % 60), 2)) END,
        exc_resp  = CASE WHEN c.exc_resp_s  IS NULL THEN NULL ELSE CONCAT(c.exc_resp_s  / 3600, N':', RIGHT(CONCAT(N'0', c.exc_resp_s  % 3600 / 60), 2), N':', RIGHT(CONCAT(N'0', c.exc_resp_s  % 60), 2)) END,
        exc_sol   = CASE WHEN c.exc_sol_s   IS NULL THEN NULL ELSE CONCAT(c.exc_sol_s   / 3600, N':', RIGHT(CONCAT(N'0', c.exc_sol_s   % 3600 / 60), 2), N':', RIGHT(CONCAT(N'0', c.exc_sol_s   % 60), 2)) END,
        suspenso  = CASE WHEN c.suspenso_s  IS NULL THEN NULL ELSE CONCAT(c.suspenso_s  / 3600, N':', RIGHT(CONCAT(N'0', c.suspenso_s  % 3600 / 60), 2), N':', RIGHT(CONCAT(N'0', c.suspenso_s  % 60), 2)) END
) AS f;

-- <<< MOTOR VIRTUAL ------------------------------------------------------------

--------------------------------------------------------------------------------
-- Resultado 1 = Chamados_TCU
--------------------------------------------------------------------------------
SELECT
    [ID Chamado],
    [Descrição do Chamado],
    [Tipo (Incidente/Solicitação)],
    [Prioridade],
    [Regime],
    [Data/Hora Abertura],
    [Data/Hora Início Atendimento],
    [Data/Hora Resolução],
    [Data/Hora Fechamento],
    [Tini (h)],
    [Tsol (h)],
    [Horas Comerciais Resposta (h)],
    [Horas Não Comerciais Resposta (h)],
    [Horas Comerciais Resolução (h)],
    [Horas Não Comerciais Resolução (h)],
    [Meta Resposta (h)],
    [Meta Resolução (h)],
    [Excesso Resposta (h)],
    [Excesso Resolução (h)],
    [chave],
    [Fator FARC],
    [Indice FARC],
    [Fator FAIA],
    [Indice FAIA],
    [Status],
    [Categoria],
    [Responsável Abertura],
    [Responsável Atendimento],
    [Item de Configuração],
    [Data Entrada Grupo Virtual],
    [Tempo suspenso],
    [Meta Primeiro Atendimento],
    [Indicador Reabertura],
    [Acordo Prazo],
    [Acordo Qualidade],
    [Justificativa],
    [Meta Atendimento],
    [Grupo]
FROM #Virt_Saida
WHERE Aba = N'Chamados_TCU'
ORDER BY [Data/Hora Fechamento], [ID Chamado];

--------------------------------------------------------------------------------
-- Resultado 2 = Chamados_24x7
--------------------------------------------------------------------------------
SELECT
    [ID Chamado],
    [Descrição do Chamado],
    [Tipo (Incidente/Solicitação)],
    [Prioridade],
    [Regime],
    [Data/Hora Abertura],
    [Data/Hora Início Atendimento],
    [Data/Hora Resolução],
    [Data/Hora Fechamento],
    [Tini (h)],
    [Tsol (h)],
    [Horas Comerciais Resposta (h)],
    [Horas Não Comerciais Resposta (h)],
    [Horas Comerciais Resolução (h)],
    [Horas Não Comerciais Resolução (h)],
    [Meta Resposta (h)],
    [Meta Resolução (h)],
    [Excesso Resposta (h)],
    [Excesso Resolução (h)],
    [chave],
    [Fator FARC],
    [Indice FARC],
    [Fator FAIA],
    [Indice FAIA],
    [Status],
    [Categoria],
    [Responsável Abertura],
    [Responsável Atendimento],
    [Item de Configuração],
    [Data Entrada Grupo Virtual],
    [Tempo suspenso],
    [Meta Primeiro Atendimento],
    [Indicador Reabertura],
    [Acordo Prazo],
    [Acordo Qualidade],
    [Justificativa],
    [Meta Atendimento],
    [Grupo]
FROM #Virt_Saida
WHERE Aba = N'Chamados_24x7'
ORDER BY [Data/Hora Fechamento], [ID Chamado];
