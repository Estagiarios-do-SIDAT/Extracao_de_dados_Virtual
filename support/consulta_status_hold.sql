USE mdb;

--------------------------------------------------------------------------------
-- Consulta de apoio: status x flag de hold (cr_stat.hold)
--
-- Mostra cada status do SDM e o seu flag de hold. O flag vem do proprio produto
-- (atributo "Stop Service Type Events"): ao entrar num status com esse atributo,
-- o relogio de SLA do SDM para. No banco esse atributo e a coluna
-- dbo.cr_stat.hold (0 ou 1).
--
--   hold = 1 -> SUSPENSO -> status que para o relogio de SLA do SDM
--   hold = 0 -> ATIVO    -> status em que o relogio corre
--
-- A apuracao da Virtual TI nao usa cr_stat.hold: o Tempo de Atendimento (Tsol)
-- conta uma lista explicita de status ativos, dentro da posse da Virtual TI
-- (docs/virtual-calculation.md, secao 7.2). Esta consulta serve para
-- investigar chamados e conferir codigos.
--------------------------------------------------------------------------------

-- [1] Todos os status e sua classificacao
SELECT
    s.sym                                                 AS [Status],
    s.code                                                AS [Codigo],
    s.hold                                                AS [hold],
    CASE WHEN s.hold = 1 THEN 'SUSPENSO' ELSE 'ATIVO' END AS [Classificacao],
    s.active                                              AS [Ativo (em uso)],
    s.del                                                 AS [Excluido]
FROM dbo.cr_stat AS s
ORDER BY
    s.hold   DESC,   -- primeiro os que param o relogio de SLA do SDM
    s.active DESC,   -- depois os em uso antes dos legados
    s.sym;

-- [2] Somente os status que param o relogio de SLA do SDM (hold = 1)
SELECT
    s.sym    AS [Status],
    s.code   AS [Codigo],
    s.active AS [Ativo (em uso)],
    s.del    AS [Excluido]
FROM dbo.cr_stat AS s
WHERE s.hold = 1
ORDER BY s.active DESC, s.sym;

-- [3] Somente os status de hold OPERACIONAIS (param o relogio de um chamado em
--     andamento): hold = 1, em uso e nao excluidos. Exclui os status finais
--     (Resolvido/Fechado/Cancelado), que tambem tem hold = 1 mas com active = 0.
SELECT
    s.sym    AS [Status],
    s.code   AS [Codigo]
FROM dbo.cr_stat AS s
WHERE s.hold = 1
  AND s.active = 1
  AND s.del = 0
ORDER BY s.sym;
