USE mdb;
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

--------------------------------------------------------------------------------
-- Consulta de referencia FAIA + FARC - Virtual TI
--
-- Este arquivo e tambem a fonte da consulta do Power BI
-- (powerbi/consulta_virtual_ti_power_bi.m, gerada por
-- tools/gerar_powerbi_m.ps1): so o bloco de periodo muda.
--
-- Apuracao do fornecedor Virtual TI a partir do SDM. Metas, cobertura (Contagem),
-- fatores, Horario TCU e 24x7 vem do Edital PE 90028/2025, Anexo VII (Tabelas
-- 1 e 2, itens 3.1.13 e 3.1.14). A mecanica dos tempos (posse, primeiro
-- atendimento e Tempo de Atendimento) e a operacional da Decision, adaptada a
-- posse da Virtual TI. Devolve UM result set com todos os chamados
-- elegiveis; a coluna [Contagem] diz a janela de contagem de cada um (no
-- Anexo VII, a coluna "Cobertura" da Tabela 1):
--
--   24x7        = P1 e P2: 00:00:00-23:59:59, todos os dias (3.1.14);
--   Horario TCU = P3 a P5: 08:00-20:00, segunda a sexta, dias uteis, sem
--                 feriados e pontos facultativos (3.1.13).
--
-- A mesma Contagem vale para a resposta inicial (Tini) e para a resolucao
-- (Tsol): uma por Tipo + Prioridade (bloco [1]).
--
-- Regras (detalhe e rastreabilidade em docs/virtual-calculation.md):
--   Periodo     data escolhida em @DataReferencia dentro de
--               [@DataInicio, @DataFim), horario do Brasil. A chave so muda
--               quais chamados entram; nenhum calculo muda.
--   Escopo      chamado I/R e, conforme @DataReferencia:
--               FECHAMENTO (padrao): close_date no periodo, status terminal,
--                 grupo atual 'Fornecedores - Virtual' e ENCERROU na Virtual TI
--                 (nasceu nela sem transferencia de grupo, ou a ultima
--                 transferencia de grupo ate o fechamento foi uma entrada na
--                 Virtual TI).
--               RESOLUCAO: resolve_date no periodo e a resolucao ocorreu dentro
--                 de uma janela de posse da Virtual TI. close_date pode ser NULL.
--   Contagem    vem da tabela de parametros pela combinacao Tipo + Prioridade.
--   Posse       janelas em que o chamado esteve no grupo Virtual TI, pela linha do
--               tempo de transferencias de grupo. O relogio comeca na primeira
--               entrada (ou na abertura, se nasceu na Virtual TI), para nas saidas,
--               volta nas reentradas; todas as janelas sao somadas.
--   Inicio      [CONGELADO] primeira passagem para 'Em andamento' feita
--               enquanto o chamado esta no grupo Virtual TI. Sem ela, a primeira
--               atividade registrada na posse (act_log, exceto
--               transferencias); sem atividade, a entrada na Virtual TI.
--   Tini        [CONGELADO] Tempo Primeiro Atendimento: tempo de posse ate o
--               Inicio.
--   Tsol        Tempo de Atendimento (motor operacional da Decision adaptado a
--               posse da Virtual TI): tempo de posse ate a Resolucao em status
--               ativo ('Em andamento', 'Aberto, aguarda atendimento' ou
--               'Reaberto'). Os demais status pausam e vao para Tempo Parada
--               Contagem NMS. Tempo fora da Virtual TI nao conta.
--   Resolucao   call_req.resolve_date; se vazio, o ultimo evento RE
--               (passagem para 'Em homologacao'), desde que o chamado nao esteja
--               em status de atendimento aberto.
--   Fechamento  call_req.close_date.
--   Horario     Horario TCU: 08:00-20:00, segunda a sexta, fora dos feriados e
--               pontos facultativos (bloco [2], arquivo de feriados). 24x7:
--               tempo corrido.
--
-- Unidades: as colunas de duracao saem como texto [h]:mm:ss; o calculo e
-- feito em segundos. Indice = horas de excesso x fator, em pontos percentuais.
--
-- Execute o arquivo INTEIRO. Banco somente leitura: so cria tabelas #.
--------------------------------------------------------------------------------

-- >>> PERIODO REFERENCIA ------------------------------------------------------
-- Periodo de apuracao da consulta de referencia, horario do Brasil, intervalo
-- semiaberto [@DataInicio, @DataFim). Para um mes inteiro, use o dia 1 do mes e
-- o dia 1 do mes seguinte.
DECLARE @DataInicio datetime2(0) = '2026-05-01 00:00:00';
DECLARE @DataFim    datetime2(0) = '2026-06-01 00:00:00';

-- Data que define o periodo:
--   N'FECHAMENTO' = Data/Hora Fechamento (call_req.close_date)
--   N'RESOLUCAO'  = Data/Hora Resolucao  (call_req.resolve_date)
DECLARE @DataReferencia nvarchar(20) = N'FECHAMENTO';
-- <<< PERIODO REFERENCIA ------------------------------------------------------

-- >>> PERIODO POWER BI --------------------------------------------------------
-- Periodo da consulta do Power BI (powerbi/consulta_virtual_ti_power_bi.m).
-- Aqui fica comentado e nao e executado: tools/gerar_powerbi_m.ps1 tira o
-- bloco PERIODO REFERENCIA acima e ativa este. Para mudar a janela do
-- relatorio, altere aqui e gere o .m de novo (ou altere o mesmo trecho no
-- texto SqlTexto do .m, no Editor Avancado do Power BI).
/*
-- PARAMETRO EDITAVEL: quantos meses completos entram antes do mes corrente,
-- pela data escolhida em @DataReferencia. Padrao: 12 = os doze meses
-- anteriores inteiros + mes corrente ate hoje. Exemplos: 6, 24. E o unico
-- numero que muda o periodo. Nenhuma regra depende dele.
DECLARE @CoberturaMeses int = 12;

-- Data que define a janela (troque so esta linha):
--   N'FECHAMENTO' = Data/Hora Fechamento (call_req.close_date)
--   N'RESOLUCAO'  = Data/Hora Resolucao  (call_req.resolve_date)
DECLARE @DataReferencia nvarchar(20) = N'FECHAMENTO';

-- Janela pela data escolhida em @DataReferencia, horario do Brasil, semiaberta:
--   inicio = dia 1 do mes (corrente - @CoberturaMeses), 00:00
--   fim    = amanha 00:00, para o dia de hoje entrar inteiro
DECLARE @HojeBrasil date = CONVERT(date, DATEADD(HOUR, -3, SYSUTCDATETIME()));
DECLARE @DataInicio datetime2(0) =
    CONVERT(datetime2(0), DATEADD(MONTH, -@CoberturaMeses, DATEFROMPARTS(YEAR(@HojeBrasil), MONTH(@HojeBrasil), 1)));
DECLARE @DataFim datetime2(0) = CONVERT(datetime2(0), DATEADD(DAY, 1, @HojeBrasil));
*/
-- <<< PERIODO POWER BI --------------------------------------------------------

-- >>> MOTOR VIRTUAL_TI ---------------------------------------------------------
-- Bloco de calculo, o mesmo na referencia e no Power BI. Usa so @DataInicio,
-- @DataFim e @DataReferencia (bloco de periodo) e entrega #Virt_Saida com as
-- duas Contagens.

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

-- Horario TCU (Anexo VII 3.1.13): das 8h as 20h.
DECLARE @HoraInicioComercial int = 8;
DECLARE @HoraFimComercial    int = 20;

--------------------------------------------------------------------------------
-- [1] Parametros da Virtual TI por Tipo + Prioridade, transcritos do Anexo VII:
--     Tabela 1 (resposta inicial, resolucao e cobertura = Contagem) e
--     Tabela 2 (fatores FAIA e FARC, % por hora ou fracao excedida).
--------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#Virt_Parametros') IS NOT NULL DROP TABLE #Virt_Parametros;
CREATE TABLE #Virt_Parametros (
    Tipo           nvarchar(20) COLLATE DATABASE_DEFAULT NOT NULL,
    Prioridade     int NOT NULL,
    MetaRespostaH  decimal(9,4) NOT NULL,
    MetaResolucaoH decimal(9,4) NOT NULL,
    Contagem       nvarchar(20) COLLATE DATABASE_DEFAULT NOT NULL,
    FatorFAIA      decimal(9,4) NOT NULL,
    FatorFARC      decimal(9,4) NOT NULL,
    PRIMARY KEY (Tipo, Prioridade)
);
INSERT INTO #Virt_Parametros (Tipo, Prioridade, MetaRespostaH, MetaResolucaoH, Contagem, FatorFAIA, FatorFARC)
VALUES
    (N'Incidente',   1,  1.00,  12, N'24x7',        0.4, 0.4),
    (N'Incidente',   2,  2.00,  24, N'24x7',        0.4, 0.4),
    (N'Incidente',   3,  4.00,  36, N'Horário TCU', 0.4, 0.2),
    (N'Incidente',   4,  8.00,  60, N'Horário TCU', 0.4, 0.2),
    (N'Solicitação', 1,  0.25,  12, N'24x7',        0.4, 0.4),
    (N'Solicitação', 2,  2.00,  24, N'24x7',        0.4, 0.4),
    (N'Solicitação', 3,  4.00,  60, N'Horário TCU', 0.4, 0.2),
    (N'Solicitação', 4,  8.00, 180, N'Horário TCU', 0.4, 0.2),
    (N'Solicitação', 5, 12.00, 360, N'Horário TCU', 0.4, 0.2);

--------------------------------------------------------------------------------
-- [2] Feriados e pontos facultativos: datas fora do Horario TCU (dias nao
--     uteis).
--
-- A lista de feriados NAO fica mais neste arquivo. Ela vem do arquivo de
-- feriados (docs/feriados.txt; no Power BI, a copia no SharePoint), o mesmo
-- calendario do TCU para Virtual TI, Decision e A2B, pelo parametro @Feriados
-- (JSON):
--   [{"data":"12-25","descricao":"Natal"},{"data":"2026-04-03","descricao":"..."}]
--   MM-DD      = feriado fixo, vale todo ano;
--   AAAA-MM-DD = data unica (feriado movel ou ponto facultativo).
-- Quem preenche @Feriados: tools/executar_consulta.ps1 (consultas de queries/)
-- e o codigo M de powerbi/*.m (Power BI). Sem @Feriados a consulta nem compila;
-- lista vazia, JSON ou data invalida param com erro: nunca se calcula com zero
-- feriados. Data repetida entra uma vez.
--------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#Virt_FeriadoEntrada') IS NOT NULL DROP TABLE #Virt_FeriadoEntrada;
CREATE TABLE #Virt_FeriadoEntrada (data nvarchar(100) NULL, descricao nvarchar(200) NULL);
IF ISJSON(@Feriados) = 1
    INSERT INTO #Virt_FeriadoEntrada (data, descricao)
    SELECT LTRIM(RTRIM(j.data)), LTRIM(RTRIM(j.descricao))
    FROM OPENJSON(@Feriados) WITH (data nvarchar(100) '$.data', descricao nvarchar(200) '$.descricao') AS j;
IF ISNULL(ISJSON(@Feriados), 0) = 0 OR NOT EXISTS (SELECT 1 FROM #Virt_FeriadoEntrada)
BEGIN
    ;THROW 50001, N'Feriados: @Feriados vazio ou invalido. Execute pelo tools/executar_consulta.ps1 (queries/) ou pelo Power BI (powerbi/*.m).', 1;
END;
IF EXISTS (
    SELECT 1
    FROM #Virt_FeriadoEntrada AS f
    WHERE f.data IS NULL
       OR NOT (   (LEN(f.data) = 10 AND f.data LIKE N'[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND TRY_CONVERT(date, f.data, 23) IS NOT NULL)
               OR (LEN(f.data) = 5  AND f.data LIKE N'[0-9][0-9]-[0-9][0-9]' AND TRY_CONVERT(date, N'2000-' + f.data, 23) IS NOT NULL))
)
BEGIN
    ;THROW 50002, N'Feriados: @Feriados tem data fora do formato AAAA-MM-DD ou MM-DD.', 1;
END;

IF OBJECT_ID('tempdb..#Virt_Feriado') IS NOT NULL DROP TABLE #Virt_Feriado;
CREATE TABLE #Virt_Feriado (Data date NOT NULL PRIMARY KEY);
INSERT INTO #Virt_Feriado (Data)
SELECT DISTINCT CONVERT(date, f.data, 23)
FROM #Virt_FeriadoEntrada AS f
WHERE LEN(f.data) = 10;

IF OBJECT_ID('tempdb..#Virt_FeriadoAnual') IS NOT NULL DROP TABLE #Virt_FeriadoAnual;
CREATE TABLE #Virt_FeriadoAnual (MesDia char(5) NOT NULL PRIMARY KEY);
INSERT INTO #Virt_FeriadoAnual (MesDia)
SELECT DISTINCT f.data
FROM #Virt_FeriadoEntrada AS f
WHERE LEN(f.data) = 5;

--------------------------------------------------------------------------------
-- [3] Candidatos do periodo, conforme @DataReferencia. Sem substituicao entre
--     as datas: se a data do modo estiver vazia, o chamado nao entra.
--     FECHAMENTO: close_date no periodo, I/R, status terminal (mesma lista da
--       Decision, por codigo), com grupo atual Virtual TI ou alguma transferencia
--       de grupo para a Virtual TI. A exigencia de o grupo NO FECHAMENTO ser a
--       Virtual TI (historico de transferencias) e aplicada em [5]/[6.2].
--     RESOLUCAO: resolve_date no periodo, I/R, com grupo atual Virtual TI ou
--       alguma transferencia de grupo para a Virtual TI. A exigencia de a
--       resolucao ter ocorrido na posse da Virtual TI e aplicada em [6.2].
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
--       status: "Status alterado de 'X' para 'Y'.", nos registros de status
--       do proprio chamado (ST, RE = ida para homologacao, RO = reabertura,
--       CL, CLREQ). O texto vem de description; quando ela traz so o
--       comentario do analista, de action_desc. Outros tipos (REL_TICKET de
--       mudanca relacionada, LOG...) nunca viram status do chamado.
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
    SELECT txt_st = CASE
        WHEN al.[type] NOT IN ('ST', 'RE', 'RO', 'CL', 'CLREQ') THEN NULL
        WHEN t.txt LIKE N'Status alterado de %' THEN t.txt
        WHEN CONVERT(nvarchar(4000), al.action_desc) LIKE N'Status alterado de %'
            THEN CONVERT(nvarchar(4000), al.action_desc)
    END
) AS ts
CROSS APPLY (
    SELECT ps = CASE WHEN ts.txt_st IS NOT NULL
                     THEN CHARINDEX(N''' para ''', ts.txt_st) ELSE 0 END
) AS ps
CROSS APPLY (
    SELECT status_resto = CASE WHEN ps.ps > 0 THEN SUBSTRING(ts.txt_st, ps.ps + 8, 4000) END
) AS sr
CROSS APPLY (
    SELECT
        -- "Status alterado de '" tem 20 caracteres: a origem comeca no 21o.
        status_de   = CASE WHEN ps.ps > 21 THEN SUBSTRING(ts.txt_st, 21, ps.ps - 21) END,
        status_para = CASE WHEN CHARINDEX(N'''', sr.status_resto) > 0
                           THEN LEFT(sr.status_resto, CHARINDEX(N'''', sr.status_resto) - 1) END
) AS st
WHERE (al.[type] IN ('TR', 'SOLN') OR ts.txt_st IS NOT NULL)
  AND al.system_time >= p.open_date
  AND (p.close_date IS NULL OR al.system_time <= p.close_date);
CREATE CLUSTERED INDEX IX_Virt_Log ON #Virt_Log (id, system_time, log_id);

--------------------------------------------------------------------------------
-- [5] Grupo inicial, encerramento na Virtual TI e movimentos de entrada/saida.
--     Nasceu no grupo = o grupo de origem da primeira transferencia de grupo e
--     o Virtual TI; sem transferencia de grupo, vale o grupo atual.
--     Encerrou na Virtual TI = sem transferencia de grupo (nasceu e ficou), ou a
--     ULTIMA transferencia de grupo ate o fechamento foi uma entrada na Virtual TI:
--     o grupo NO FECHAMENTO e a Virtual TI. Transferencia gravada no mesmo segundo
--     do fechamento conta antes dele, salvo se o registro CL desse segundo tiver
--     act_log.id menor (gravado antes da transferencia).
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
      AND NOT EXISTS (
            SELECT 1
            FROM #Virt_Log AS f
            WHERE f.id = l.id
              AND f.[type] = 'CL'
              AND f.system_time = p.close_date
              AND l.system_time = p.close_date
              AND f.log_id < l.log_id
      )
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
-- [6] Candidatos com os marcos e o indicador de encerramento na Virtual TI.
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
    -- Encerrou na Virtual TI: sem transferencia de grupo (nasceu e ficou nela) ou a
    -- ultima transferencia de grupo ate o fechamento foi uma entrada na Virtual TI.
    CASE WHEN (gi.grupo_ultima_transferencia IS NULL AND gi.grupo_inicial = @GrupoVirtualNome)
           OR gi.grupo_ultima_transferencia = @GrupoVirtualNome
         THEN 1 ELSE 0 END AS encerrou_virtual
INTO #Virt_Candidato
FROM #Virt_Periodo AS p
JOIN #Virt_GrupoInicial AS gi
    ON gi.id = p.id
JOIN dbo.cr_stat AS sa
    ON sa.code = p.status
-- Primeira entrada na Virtual TI: a abertura, se nasceu nela; senao a primeira
-- transferencia para o grupo.
OUTER APPLY (
    SELECT MIN(m.momento) AS entrada_epoch
    FROM #Virt_Movimento AS m
    WHERE m.id = p.id
      AND m.movimento = 'E'
) AS ent
-- Inicio (captura): primeira passagem para 'Em andamento', com o chamado dentro
-- de uma passagem pelo grupo Virtual TI (entrada antes do evento e nenhuma saida
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
-- [6.1] Janelas de posse da Virtual TI.
--     Linha do tempo de grupo: a abertura (no grupo inicial) e cada
--     transferencia de grupo, em ordem de system_time e act_log.id. Cada trecho
--     vai de um evento ao seguinte; ficam os trechos em que o grupo e o Virtual TI.
--     Fora da Virtual TI nao conta; saida para o relogio; reentrada o religa;
--     todas as janelas sao somadas. Quem nasceu na Virtual TI tem a primeira
--     janela iniciando na abertura. Janela sem fim (fim NULL) = o chamado
--     continuava na Virtual TI no ultimo evento lido.
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
    DATEADD(HOUR, -@HorasBrasilParaUTC, DATEADD(SECOND, x.proximo, @Epoch)) AS fim -- NULL = ainda na Virtual TI
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
-- [6.2] Chamados da Virtual TI: responsabilidade validada no marco escolhido.
--     FECHAMENTO: encerrou na Virtual TI (cadeia de transferencias ate o
--       fechamento).
--     RESOLUCAO: resolve_date dentro de uma janela de posse da Virtual TI,
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
-- [6.3] Data de Encerramento Virtual TI: ultimo encerramento da atuacao da Virtual TI,
--       como a Data de Encerramento Decision. Encerramento = evento de status
--       (ST, RE, RO, CL...) com DESTINO 'Em homologacao' (codigo EMHOM) ou SOLN,
--       que a Decision trata como entrada implicita em homologacao. Vale so a
--       ENTRADA: o evento anterior na linha do tempo nao pode ser outro
--       encerramento ('Em homologacao' -> 'Reaberto' nao conta; SOLN depois da
--       homologacao nao e novo encerramento). Posse: mesmo criterio do Inicio.
--       Com reabertura e novo encerramento, vale o ultimo. Sem evento valido,
--       fica NULL (sem substituto por resolve_date, close_date ou atividade).
--------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#Virt_Encerramento') IS NOT NULL DROP TABLE #Virt_Encerramento;
SELECT
    x.id,
    MAX(x.system_time) AS encerramento_epoch
INTO #Virt_Encerramento
FROM (
    SELECT
        l.id,
        l.system_time,
        z.encerra,
        LAG(z.encerra, 1, 0) OVER (PARTITION BY l.id ORDER BY l.system_time, l.log_id) AS anterior_encerra
    FROM #Virt_Log AS l
    JOIN #Virt_Chamado AS c
        ON c.id = l.id
    LEFT JOIN dbo.cr_stat AS sd
        ON sd.sym = l.status_para COLLATE DATABASE_DEFAULT
    CROSS APPLY (
        SELECT encerra = CASE WHEN sd.code = 'EMHOM' -- Em homologacao
                                OR l.[type] = 'SOLN' THEN 1 ELSE 0 END
    ) AS z
    WHERE l.status_para IS NOT NULL
       OR l.[type] = 'SOLN'
) AS x
WHERE x.encerra = 1
  AND x.anterior_encerra = 0
  AND EXISTS (
        SELECT 1
        FROM #Virt_Movimento AS e
        WHERE e.id = x.id
          AND e.movimento = 'E'
          AND e.momento < x.system_time
          AND NOT EXISTS (
                SELECT 1
                FROM #Virt_Movimento AS s
                WHERE s.id = x.id
                  AND s.movimento = 'S'
                  AND s.momento >= e.momento
                  AND s.momento <= x.system_time
          )
  )
GROUP BY x.id;
CREATE UNIQUE CLUSTERED INDEX IX_Virt_Encerramento ON #Virt_Encerramento (id);

--------------------------------------------------------------------------------
-- [7] Marcos em horario do Brasil, Contagem e parametros.
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
    pr.Contagem AS contagem,
    DATEADD(HOUR, -@HorasBrasilParaUTC, DATEADD(SECOND, c.abertura_epoch,   @Epoch)) AS abertura,
    DATEADD(HOUR, -@HorasBrasilParaUTC, DATEADD(SECOND, c.entrada_epoch,    @Epoch)) AS entrada,
    DATEADD(HOUR, -@HorasBrasilParaUTC, DATEADD(SECOND, c.inicio_epoch,     @Epoch)) AS inicio,
    DATEADD(HOUR, -@HorasBrasilParaUTC, DATEADD(SECOND, c.resolucao_epoch,  @Epoch)) AS resolucao,
    DATEADD(HOUR, -@HorasBrasilParaUTC, DATEADD(SECOND, c.fechamento_epoch, @Epoch)) AS fechamento,
    DATEADD(HOUR, -@HorasBrasilParaUTC, DATEADD(SECOND, enc.encerramento_epoch, @Epoch)) AS encerramento_virtual,
    pr.MetaRespostaH,
    pr.MetaResolucaoH,
    pr.FatorFAIA,
    pr.FatorFARC
INTO #Virt_Marco
FROM #Virt_Chamado AS c
LEFT JOIN #Virt_Parametros AS pr
    ON pr.Tipo = c.tipo
   AND pr.Prioridade = c.prioridade
LEFT JOIN #Virt_Encerramento AS enc
    ON enc.id = c.id;
CREATE UNIQUE CLUSTERED INDEX IX_Virt_Marco ON #Virt_Marco (id);

--------------------------------------------------------------------------------
-- [8] Dias uteis do Horario TCU (segunda a sexta, fora dos feriados e
--     pontos facultativos do bloco [2]), com a janela das 8h as 20h, cobrindo
--     da abertura ate o ultimo marco (Anexo VII 3.1.13).
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
  AND NOT EXISTS (SELECT 1 FROM #Virt_Feriado AS k WHERE k.Data = d.Dia)
  AND NOT EXISTS (SELECT 1 FROM #Virt_FeriadoAnual AS k WHERE k.MesDia = RIGHT(CONVERT(char(10), d.Dia, 23), 5));

--------------------------------------------------------------------------------
-- [9] Status ativos e trechos ate os marcos (motor operacional, Decision
--     adaptada a posse da Virtual TI).
--     Linha do tempo de status do chamado: na abertura vale a origem do
--     primeiro evento de status (sem evento, 'Aberto, aguarda atendimento'); cada
--     evento de status (ST, RE, RO, CL...) passa a valer o status de destino ate
--     o proximo, em ordem de system_time e act_log.id. Um SOLN e uma entrada
--     implicita em status nao ativo, como na Decision. Ativos: 'Em andamento'
--     (FIP), 'Aberto, aguarda atendimento' (OP) e 'Reaberto' (REAB; orientacao
--     do gerente de 2026-10-06: a reabertura corrige um encerramento indevido e
--     o tempo conta). Os demais (Aguarda atendimento, Agendado, Em
--     homologacao...) pausam o Tempo de Atendimento.
--------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#Virt_StatusLinha') IS NOT NULL DROP TABLE #Virt_StatusLinha;
SELECT
    c.id,
    c.abertura_epoch AS momento,
    0 AS ordem,
    CASE WHEN pe.code_de IS NULL OR pe.code_de IN ('FIP', 'OP', 'REAB') THEN 1 ELSE 0 END AS ativo
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
    CASE WHEN sd.code IN ('FIP', 'OP', 'REAB') THEN 1 ELSE 0 END
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
--      Resolucao para o Tempo Parada Contagem NMS. As horas no Horario TCU sao
--      calculadas nas duas Contagens (informativas na 24x7, cujo excesso e
--      medido sobre o corrido).
--------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#Virt_Tempo') IS NOT NULL DROP TABLE #Virt_Tempo;
SELECT
    m.id,
    CASE WHEN m.inicio IS NULL THEN NULL ELSE ISNULL(cor.resp, 0) END AS tini_s,
    CASE WHEN m.resolucao IS NULL THEN NULL ELSE ISNULL(cor.sol, 0) END AS tsol_s,
    CASE WHEN m.resolucao IS NULL THEN NULL ELSE ISNULL(cor.posse, 0) END AS posse_sol_s,
    CASE WHEN m.inicio IS NULL THEN NULL ELSE ISNULL(com.resp, 0) END AS com_resp_s,
    CASE WHEN m.resolucao IS NULL THEN NULL ELSE ISNULL(com.sol, 0) END AS com_sol_s
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
-- [11] Calculo numerico, em segundos. Excesso por chamado = Max(T | Meta) -
--      Meta (Anexo VII, Equacoes 1 e 4): Contagem Horario TCU sobre as horas
--      dentro do Horario TCU; 24x7 sobre o tempo corrido. Indice = horas de
--      excesso (6 casas) x fator (Equacoes 2 e 5), em pontos percentuais.
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
    -- Tempo Parada Contagem NMS: tempo de posse ate a Resolucao em status nao
    -- ativo (corrido). Tsol + parada = posse total ate a Resolucao.
    t.posse_sol_s - t.tsol_s AS parada_s,
    -- Tempo Total Virtual TI: posse ate a Resolucao, todas as janelas, em
    -- qualquer status (= tsol_s + parada_s). Informativo.
    t.posse_sol_s,
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
        base_resp = CASE WHEN m.contagem = N'24x7' THEN t.tini_s ELSE t.com_resp_s END,
        base_sol  = CASE WHEN m.contagem = N'24x7' THEN t.tsol_s ELSE t.com_sol_s  END
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
--      Bloco A: identificacao e datas. Bloco B: as colunas de apuracao. Bloco
--      C: colunas de contexto. Nomes na terminologia do Anexo VII:
--      [Prioridade] = numero 1 a 5 do SDM com o nome ('1 - Máxima' ... '5 -
--      Mínima'), so apresentacao: metas, fatores e [Chave] usam o numero
--      (m.prioridade); [Contagem] = '24x7' ou 'Horário TCU' (a
--      "Cobertura" da Tabela 1; sem parametro = N/A); [Chave] = Tipo |
--      Prioridade | Contagem. As duracoes saem como texto [h]:mm:ss (horas
--      acima de 24 sem virar o dia). A formatacao e feita so aqui, depois do
--      calculo; fatores e indices continuam numericos.
--------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#Virt_Saida') IS NOT NULL DROP TABLE #Virt_Saida;
SELECT
    -- Bloco A
    m.ref_num AS [ID Chamado],
    m.resumo AS [Resumo],
    m.tipo AS [Tipo (Incidente/Solicitação)],
    CASE m.prioridade
        WHEN 1 THEN N'1 - Máxima'
        WHEN 2 THEN N'2 - Alta'
        WHEN 3 THEN N'3 - Média'
        WHEN 4 THEN N'4 - Baixa'
        WHEN 5 THEN N'5 - Mínima'
        ELSE CONVERT(nvarchar(10), m.prioridade) -- fora de 1..5: o numero, sem nome; nulo segue nulo
    END AS [Prioridade],
    ISNULL(m.contagem, N'N/A') AS [Contagem],
    m.abertura AS [Data/Hora Abertura],
    m.inicio AS [Data/Hora Início Atendimento],
    m.resolucao AS [Data/Hora Resolução],
    m.fechamento AS [Data/Hora Fechamento],
    -- Bloco B
    f.tini AS [Tini (h)],
    f.tsol AS [Tsol (h)],
    f.com_resp AS [Horas Horário TCU Resposta (h)],
    f.ncom_resp AS [Horas Fora Horário TCU Resposta (h)],
    f.com_sol AS [Horas Horário TCU Resolução (h)],
    f.ncom_sol AS [Horas Fora Horário TCU Resolução (h)],
    f.meta_resp AS [Meta Resposta (h)],
    f.meta_sol AS [Meta Resolução (h)],
    f.exc_resp AS [Excesso Resposta (h)],
    f.exc_sol AS [Excesso Resolução (h)],
    CONCAT(m.tipo, N'|', m.prioridade, N'|', m.contagem) AS [Chave],
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
    m.entrada AS [Data Entrada Grupo Virtual TI],
    -- Tempo de posse ate a Resolucao em status que pausam (Anexo VII 6.19.13:
    -- tempo total de parada de contagem de NMS).
    f.parada AS [Tempo Parada Contagem NMS (h)],
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
         ELSE N'Atende' END AS [Situação Meta Resolução],
    -- Grupo no instante de referencia, pela linha do tempo de transferencias:
    -- FECHAMENTO = grupo no fechamento (o mesmo que decide o escopo em [5]);
    -- RESOLUCAO = grupo no instante da resolucao (ultima transferencia de grupo
    -- antes de resolve_date; sem transferencia, o grupo inicial).
    CASE WHEN @DataReferencia = N'FECHAMENTO'
         THEN COALESCE(gi.grupo_ultima_transferencia, gi.grupo_inicial)
         ELSE COALESCE(gres.grupo_para, gi.grupo_inicial) END AS [Grupo],
    -- Houve Agendamento: houve ao menos uma transicao com DESTINO
    -- 'Agendado' (em qualquer registro de status do act_log) dentro da posse da
    -- Virtual TI, com o mesmo criterio de posse do Inicio. Informativo: nao muda
    -- tempo, excesso nem indice.
    CASE WHEN EXISTS (
            SELECT 1
            FROM #Virt_Log AS l
            JOIN dbo.cr_stat AS sd
                ON sd.sym = l.status_para COLLATE DATABASE_DEFAULT
            WHERE l.id = m.id
              AND sd.code = 'AGENDADO' -- Agendado
              AND EXISTS (
                    SELECT 1
                    FROM #Virt_Movimento AS e
                    WHERE e.id = l.id
                      AND e.movimento = 'E'
                      AND e.momento < l.system_time
                      AND NOT EXISTS (
                            SELECT 1
                            FROM #Virt_Movimento AS s
                            WHERE s.id = l.id
                              AND s.movimento = 'S'
                              AND s.momento >= e.momento
                              AND s.momento <= l.system_time
                      )
              )
         ) THEN N'Sim' ELSE N'Não' END AS [Houve Agendamento],
    -- Data de Encerramento Virtual TI: bloco [6.3]. Nao e o fechamento (close_date)
    -- nem substitui a Resolucao.
    m.encerramento_virtual AS [Data de Encerramento Virtual TI],
    -- Tempo Total Virtual TI: posse da Virtual TI ate a Resolucao (todas as
    -- janelas; status ativos e que pausam) = Tsol + Tempo Parada Contagem NMS.
    -- Informativo: nao muda tempo, excesso nem indice.
    f.total AS [Tempo Total Virtual TI]
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
LEFT JOIN #Virt_GrupoInicial AS gi
    ON gi.id = m.id
LEFT JOIN #Virt_Chamado AS ch
    ON ch.id = m.id
OUTER APPLY (
    SELECT TOP (1) l.grupo_para
    FROM #Virt_Log AS l
    WHERE l.id = m.id
      AND l.grupo_para IS NOT NULL
      AND l.system_time < ch.resolve_date_sdm
    ORDER BY l.system_time DESC, l.log_id DESC
) AS gres
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
        parada    = CASE WHEN c.parada_s    IS NULL THEN NULL ELSE CONCAT(c.parada_s    / 3600, N':', RIGHT(CONCAT(N'0', c.parada_s    % 3600 / 60), 2), N':', RIGHT(CONCAT(N'0', c.parada_s    % 60), 2)) END,
        total     = CASE WHEN c.posse_sol_s IS NULL THEN NULL ELSE CONCAT(c.posse_sol_s / 3600, N':', RIGHT(CONCAT(N'0', c.posse_sol_s % 3600 / 60), 2), N':', RIGHT(CONCAT(N'0', c.posse_sol_s % 60), 2)) END
) AS f;

-- <<< MOTOR VIRTUAL_TI ---------------------------------------------------------

--------------------------------------------------------------------------------
-- Resultado unico: Horario TCU e 24x7 juntos; [Contagem] separa.
--------------------------------------------------------------------------------
SELECT
    [ID Chamado],
    [Resumo],
    [Tipo (Incidente/Solicitação)],
    [Prioridade],
    [Contagem],
    [Data/Hora Abertura],
    [Data/Hora Início Atendimento],
    [Data/Hora Resolução],
    [Data/Hora Fechamento],
    [Tini (h)],
    [Tsol (h)],
    [Horas Horário TCU Resposta (h)],
    [Horas Fora Horário TCU Resposta (h)],
    [Horas Horário TCU Resolução (h)],
    [Horas Fora Horário TCU Resolução (h)],
    [Meta Resposta (h)],
    [Meta Resolução (h)],
    [Excesso Resposta (h)],
    [Excesso Resolução (h)],
    [Chave],
    [Fator FARC],
    [Indice FARC],
    [Fator FAIA],
    [Indice FAIA],
    [Status],
    [Categoria],
    [Responsável Abertura],
    [Responsável Atendimento],
    [Item de Configuração],
    [Data Entrada Grupo Virtual TI],
    [Tempo Parada Contagem NMS (h)],
    [Meta Primeiro Atendimento],
    [Indicador Reabertura],
    [Acordo Prazo],
    [Acordo Qualidade],
    [Justificativa],
    [Situação Meta Resolução],
    [Grupo],
    [Houve Agendamento],
    [Data de Encerramento Virtual TI],
    [Tempo Total Virtual TI]
FROM #Virt_Saida
ORDER BY [Data/Hora Fechamento], [ID Chamado];
