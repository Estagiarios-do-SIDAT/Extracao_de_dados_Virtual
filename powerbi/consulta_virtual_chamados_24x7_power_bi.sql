USE mdb;
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

-- =============================================================================
-- PARAMETRO EDITAVEL  (Power Query > Etapas aplicadas > Fonte > engrenagem)
--
--   Quantos meses FECHADOS entram antes do mes corrente.
--   Padrao: 12 = os doze meses anteriores inteiros + mes corrente ate hoje.
--   Exemplos: 6, 24.
--
--   E o unico numero que muda o periodo. Nenhuma regra depende dele.
--   O calendario do motor (bloco [2]) precisa cobrir toda a janela.
-- =============================================================================
DECLARE @CoberturaMeses int = 12;

--------------------------------------------------------------------------------
-- Power BI - Chamados_24x7 - Virtual
--
-- Mesma regra de queries/consulta_virtual_faia_farc.sql: o bloco MOTOR VIRTUAL
-- abaixo e uma copia identica do bloco da consulta de referencia. Mudam so:
--   - o periodo, calculado a partir de hoje (abaixo);
--   - a saida: um unico resultado, com DCIM e Manutencao juntos e a coluna
--     [Planilha] no final para separa-los.
--
-- Uso: conector SQL Server, banco mdb, modo Importacao, colar o arquivo
-- inteiro em 'Instrucao SQL'.
--------------------------------------------------------------------------------

-- Janela por data de ABERTURA, horario do Brasil, semiaberta:
--   inicio = dia 1 do mes (corrente - @CoberturaMeses), 00:00
--   fim    = amanha 00:00, para o dia de hoje entrar inteiro
DECLARE @HojeBrasil date = CONVERT(date, DATEADD(HOUR, -3, SYSUTCDATETIME()));
DECLARE @DataInicio datetime2(0) =
    CONVERT(datetime2(0), DATEADD(MONTH, -@CoberturaMeses, DATEFROMPARTS(YEAR(@HojeBrasil), MONTH(@HojeBrasil), 1)));
DECLARE @DataFim datetime2(0) = CONVERT(datetime2(0), DATEADD(DAY, 1, @HojeBrasil));

-- >>> MOTOR VIRTUAL ------------------------------------------------------------
-- Bloco identico nos tres arquivos (queries/ e powerbi/). Usa so @DataInicio e
-- @DataFim e entrega #Virt_Saida com as duas planilhas e os dois regimes.

DECLARE @HorasBrasilParaUTC int = 3;
DECLARE @Epoch datetime2(0) = '1970-01-01 00:00:00';
DECLARE @IniEpoch int = DATEDIFF(SECOND, @Epoch, DATEADD(HOUR, @HorasBrasilParaUTC, @DataInicio));
DECLARE @FimEpoch int = DATEDIFF(SECOND, @Epoch, DATEADD(HOUR, @HorasBrasilParaUTC, @DataFim));

-- Identidades por UUID; o nome do grupo e lido do cadastro porque o act_log
-- registra a transferencia pelo nome.
DECLARE @GrupoVirtual   varbinary(16) = 0x21679DF702A0EC478B1468D89E769836; -- Fornecedores - Virtual
DECLARE @AgenteAutomacao varbinary(16) = 0xC6BB355348EE414B9EAA9870ADA5C9E5; -- Usuario de Servico - ServiceDesk
DECLARE @IC_DCIM        varbinary(16) = 0xA39FE15C43351C41BA9478BA4000BAF5; -- IC 'dcim'
DECLARE @GrupoVirtualNome nvarchar(200) =
    (SELECT LTRIM(RTRIM(c.last_name)) FROM dbo.ca_contact AS c WHERE c.contact_uuid = @GrupoVirtual);

-- Janela comercial do regime TCU.
DECLARE @HoraInicioComercial int = 8;
DECLARE @HoraFimComercial    int = 20;

--------------------------------------------------------------------------------
-- [1] Parametros (aba Parametros). Metas em horas.
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
-- [2] CALENDARIO_TCU (tabela tblCalendarioTCU). Conta_SLA = 'N': a data nao
--     tem horario comercial. Demais datas da tabela contam normalmente.
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
-- [3] Chamados abertos no periodo (I e R), fora dos encerrados sem atendimento.
--------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#Virt_Periodo') IS NOT NULL DROP TABLE #Virt_Periodo;
SELECT
    r.id,
    r.persid,
    r.ref_num,
    r.[type],
    r.priority,
    r.status,
    r.group_id,
    r.log_agent,
    r.affected_rc,
    r.open_date,
    r.resolve_date,
    LTRIM(RTRIM(CONVERT(nvarchar(4000), r.summary))) AS resumo
INTO #Virt_Periodo
FROM dbo.call_req AS r
WHERE r.open_date >= @IniEpoch
  AND r.open_date <  @FimEpoch
  AND r.[type] IN ('I', 'R')
  AND r.status NOT IN ('CLUNRSLV', 'ATGR', 'CNCL'); -- Nao resolvido, fechado / Cancelado / Cancelada
CREATE UNIQUE CLUSTERED INDEX IX_Virt_Periodo ON #Virt_Periodo (id);
CREATE UNIQUE INDEX IX_Virt_Periodo_persid ON #Virt_Periodo (persid);

--------------------------------------------------------------------------------
-- [4] Eventos de grupo e de status desses chamados, com os nomes extraidos do
--     texto padrao do act_log:
--       TR: "Transferir Grupo de 'X' para 'Y'"
--       ST/RE: "Status alterado de 'X' para 'Y'."
--------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#Virt_Log') IS NOT NULL DROP TABLE #Virt_Log;
SELECT
    p.id,
    al.id AS log_id,
    al.system_time,
    al.[type],
    g.grupo_de,
    g.grupo_para,
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
    SELECT ps = CASE WHEN al.[type] IN ('ST', 'RE') AND t.txt LIKE N'Status alterado de %'
                     THEN CHARINDEX(N''' para ''', t.txt) ELSE 0 END
) AS ps
CROSS APPLY (
    SELECT status_resto = CASE WHEN ps.ps > 0 THEN SUBSTRING(t.txt, ps.ps + 8, 4000) END
) AS sr
CROSS APPLY (
    SELECT status_para = CASE WHEN CHARINDEX(N'''', sr.status_resto) > 0
                              THEN LEFT(sr.status_resto, CHARINDEX(N'''', sr.status_resto) - 1) END
) AS st
WHERE al.[type] IN ('TR', 'ST', 'RE');
CREATE CLUSTERED INDEX IX_Virt_Log ON #Virt_Log (id, system_time, log_id);

--------------------------------------------------------------------------------
-- [5] Passagens pelo grupo Virtual.
--     Entrada: transferencia para o grupo, ou a abertura quando o chamado nasceu
--     nele. Nasceu no grupo = o grupo de origem da primeira transferencia de
--     grupo e o Virtual; sem transferencia de grupo, vale o grupo atual.
--     Saida: transferencia do grupo Virtual para outro.
--------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#Virt_GrupoInicial') IS NOT NULL DROP TABLE #Virt_GrupoInicial;
SELECT
    p.id,
    COALESCE(prim.grupo_de, LTRIM(RTRIM(ga.last_name))) AS grupo_inicial
INTO #Virt_GrupoInicial
FROM #Virt_Periodo AS p
OUTER APPLY (
    SELECT TOP (1) l.grupo_de
    FROM #Virt_Log AS l
    WHERE l.id = p.id
      AND l.grupo_para IS NOT NULL
    ORDER BY l.system_time, l.log_id
) AS prim
LEFT JOIN dbo.ca_contact AS ga
    ON ga.contact_uuid = p.group_id;

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
-- [6] Chamados da Virtual e os tres marcos.
--------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#Virt_Chamado') IS NOT NULL DROP TABLE #Virt_Chamado;
SELECT
    p.id,
    p.ref_num,
    p.resumo,
    CASE p.[type] WHEN 'I' THEN N'Incidente' WHEN 'R' THEN N'Solicitação' END AS tipo,
    p.priority AS prioridade,
    CASE WHEN p.log_agent = @AgenteAutomacao AND p.affected_rc = @IC_DCIM
         THEN N'DCIM' ELSE N'Manutenção' END AS planilha,
    p.open_date AS abertura_epoch,
    ini.inicio_epoch,
    COALESCE(
        p.resolve_date,
        CASE WHEN NOT (sa.resolved = 0 AND sa.hold = 0) THEN re.ultimo_re END
    ) AS resolucao_epoch
INTO #Virt_Chamado
FROM #Virt_Periodo AS p
JOIN dbo.cr_stat AS sa
    ON sa.code = p.status
-- Inicio: primeira mudanca de status para um status fora da fila, com o
-- chamado dentro de uma passagem pelo grupo Virtual (entrada antes do evento e
-- nenhuma saida entre a entrada e o evento, inclusive no mesmo segundo).
OUTER APPLY (
    SELECT MIN(l.system_time) AS inicio_epoch
    FROM #Virt_Log AS l
    JOIN dbo.cr_stat AS sd
        ON sd.sym = l.status_para COLLATE DATABASE_DEFAULT
    WHERE l.id = p.id
      AND l.[type] IN ('ST', 'RE')
      AND sd.code NOT IN ('OP', 'REOP') -- Aberto, aguarda atendimento / Aguarda atendimento
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
OUTER APPLY (
    SELECT MAX(l.system_time) AS ultimo_re
    FROM #Virt_Log AS l
    WHERE l.id = p.id
      AND l.[type] = 'RE'
) AS re
WHERE EXISTS (SELECT 1 FROM #Virt_Movimento AS m WHERE m.id = p.id AND m.movimento = 'E')
   OR p.group_id = @GrupoVirtual;
CREATE UNIQUE CLUSTERED INDEX IX_Virt_Chamado ON #Virt_Chamado (id);

--------------------------------------------------------------------------------
-- [7] Marcos em horario do Brasil, regime e parametros.
--------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#Virt_Marco') IS NOT NULL DROP TABLE #Virt_Marco;
SELECT
    c.id,
    c.ref_num,
    c.resumo,
    c.tipo,
    c.prioridade,
    c.planilha,
    pr.Regime AS regime,
    DATEADD(HOUR, -@HorasBrasilParaUTC, DATEADD(SECOND, c.abertura_epoch,  @Epoch)) AS abertura,
    DATEADD(HOUR, -@HorasBrasilParaUTC, DATEADD(SECOND, c.inicio_epoch,    @Epoch)) AS inicio,
    DATEADD(HOUR, -@HorasBrasilParaUTC, DATEADD(SECOND, c.resolucao_epoch, @Epoch)) AS resolucao,
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
-- [9] Tempos em segundos. Tini/Tsol sao tempo corrido; as horas comerciais
--     so existem no regime TCU. No 24x7 todo o tempo fica no bloco nao
--     comercial e o excesso e medido sobre o tempo corrido.
--------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#Virt_Tempo') IS NOT NULL DROP TABLE #Virt_Tempo;
SELECT
    m.id,
    CASE WHEN m.inicio IS NULL THEN NULL
         WHEN m.inicio <= m.abertura THEN 0
         ELSE DATEDIFF_BIG(SECOND, m.abertura, m.inicio) END AS tini_s,
    CASE WHEN m.resolucao IS NULL THEN NULL
         WHEN m.resolucao <= m.abertura THEN 0
         ELSE DATEDIFF_BIG(SECOND, m.abertura, m.resolucao) END AS tsol_s,
    CASE WHEN m.inicio IS NULL THEN NULL
         WHEN m.regime = N'24x7' THEN 0
         ELSE ISNULL(cr.seg, 0) END AS com_resp_s,
    CASE WHEN m.resolucao IS NULL THEN NULL
         WHEN m.regime = N'24x7' THEN 0
         ELSE ISNULL(cs.seg, 0) END AS com_sol_s
INTO #Virt_Tempo
FROM #Virt_Marco AS m
OUTER APPLY (
    SELECT SUM(d.seg) AS seg
    FROM (
        SELECT DATEDIFF_BIG(SECOND,
                   CASE WHEN m.abertura > u.InicioCom THEN m.abertura ELSE u.InicioCom END,
                   CASE WHEN m.inicio   < u.FimCom    THEN m.inicio   ELSE u.FimCom    END) AS seg
        FROM #Virt_DiaUtil AS u
        WHERE u.Dia BETWEEN CONVERT(date, m.abertura) AND CONVERT(date, m.inicio)
          AND m.inicio > u.InicioCom
          AND m.abertura < u.FimCom
    ) AS d
) AS cr
OUTER APPLY (
    SELECT SUM(d.seg) AS seg
    FROM (
        SELECT DATEDIFF_BIG(SECOND,
                   CASE WHEN m.abertura  > u.InicioCom THEN m.abertura  ELSE u.InicioCom END,
                   CASE WHEN m.resolucao < u.FimCom    THEN m.resolucao ELSE u.FimCom    END) AS seg
        FROM #Virt_DiaUtil AS u
        WHERE u.Dia BETWEEN CONVERT(date, m.abertura) AND CONVERT(date, m.resolucao)
          AND m.resolucao > u.InicioCom
          AND m.abertura < u.FimCom
    ) AS d
) AS cs;
CREATE UNIQUE CLUSTERED INDEX IX_Virt_Tempo ON #Virt_Tempo (id);

--------------------------------------------------------------------------------
-- [10] Linhas finais, em horas. Excesso: TCU sobre horas comerciais, 24x7
--      sobre tempo corrido. Indice = horas de excesso x fator.
--------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#Virt_Saida') IS NOT NULL DROP TABLE #Virt_Saida;
SELECT
    m.planilha AS Planilha,
    CASE WHEN m.regime = N'24x7' THEN N'Chamados_24x7' ELSE N'Chamados_TCU' END AS Aba,
    m.ref_num AS [ID Chamado],
    m.resumo AS [Descrição do Chamado],
    m.tipo AS [Tipo (Incidente/Solicitação)],
    m.prioridade AS [Prioridade],
    m.regime AS [Regime],
    m.abertura AS [Data/Hora Abertura],
    m.inicio AS [Data/Hora Início Atendimento],
    m.resolucao AS [Data/Hora Resolução],
    h.tini AS [Tini (h)],
    h.tsol AS [Tsol (h)],
    h.com_resp AS [Horas Comerciais Resposta (h)],
    h.tini - h.com_resp AS [Horas Não Comerciais Resposta (h)],
    h.com_sol AS [Horas Comerciais Resolução (h)],
    h.tsol - h.com_sol AS [Horas Não Comerciais Resolução (h)],
    m.MetaRespostaH AS [Meta Resposta (h)],
    m.MetaResolucaoH AS [Meta Resolução (h)],
    x.exc_resp AS [Excesso Resposta (h)],
    x.exc_sol AS [Excesso Resolução (h)],
    CONCAT(m.tipo, N'|', m.prioridade, N'|', m.regime) AS [chave],
    m.FatorFARC AS [Fator FARC],
    CONVERT(decimal(18,6), x.exc_sol * m.FatorFARC) AS [Indice FARC],
    m.FatorFAIA AS [Fator FAIA],
    CONVERT(decimal(18,6), x.exc_resp * m.FatorFAIA) AS [Indice FAIA]
INTO #Virt_Saida
FROM #Virt_Marco AS m
JOIN #Virt_Tempo AS t
    ON t.id = m.id
CROSS APPLY (
    SELECT
        tini     = CONVERT(decimal(18,6), t.tini_s     / 3600.0),
        tsol     = CONVERT(decimal(18,6), t.tsol_s     / 3600.0),
        com_resp = CONVERT(decimal(18,6), t.com_resp_s / 3600.0),
        com_sol  = CONVERT(decimal(18,6), t.com_sol_s  / 3600.0)
) AS h
CROSS APPLY (
    SELECT
        exc_resp = CONVERT(decimal(18,6),
                   CASE WHEN m.MetaRespostaH IS NULL OR t.tini_s IS NULL THEN NULL
                        WHEN m.regime = N'24x7'
                             THEN CASE WHEN t.tini_s > m.MetaRespostaH * 3600
                                       THEN (t.tini_s - m.MetaRespostaH * 3600) / 3600.0 ELSE 0 END
                        ELSE CASE WHEN t.com_resp_s > m.MetaRespostaH * 3600
                                  THEN (t.com_resp_s - m.MetaRespostaH * 3600) / 3600.0 ELSE 0 END
                   END),
        exc_sol  = CONVERT(decimal(18,6),
                   CASE WHEN m.MetaResolucaoH IS NULL OR t.tsol_s IS NULL THEN NULL
                        WHEN m.regime = N'24x7'
                             THEN CASE WHEN t.tsol_s > m.MetaResolucaoH * 3600
                                       THEN (t.tsol_s - m.MetaResolucaoH * 3600) / 3600.0 ELSE 0 END
                        ELSE CASE WHEN t.com_sol_s > m.MetaResolucaoH * 3600
                                  THEN (t.com_sol_s - m.MetaResolucaoH * 3600) / 3600.0 ELSE 0 END
                   END)
) AS x;

-- <<< MOTOR VIRTUAL ------------------------------------------------------------

--------------------------------------------------------------------------------
-- Resultado unico = Chamados_24x7 (DCIM e Manutencao)
--------------------------------------------------------------------------------
SELECT
    [ID Chamado], [Descrição do Chamado], [Tipo (Incidente/Solicitação)], [Prioridade], [Regime],
    [Data/Hora Abertura], [Data/Hora Início Atendimento], [Data/Hora Resolução],
    [Tini (h)], [Tsol (h)],
    [Horas Comerciais Resposta (h)], [Horas Não Comerciais Resposta (h)],
    [Horas Comerciais Resolução (h)], [Horas Não Comerciais Resolução (h)],
    [Meta Resposta (h)], [Meta Resolução (h)],
    [Excesso Resposta (h)], [Excesso Resolução (h)],
    [chave], [Fator FARC], [Indice FARC], [Fator FAIA], [Indice FAIA],
    [Planilha]
FROM #Virt_Saida
WHERE Aba = N'Chamados_24x7'
ORDER BY [Planilha], [Data/Hora Abertura], [ID Chamado];
