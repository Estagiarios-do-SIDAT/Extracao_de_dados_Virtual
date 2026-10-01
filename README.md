# Extração de dados — Virtual

Consultas SQL e documentação da apuração de **FAIA** e **FARC** do fornecedor
**Virtual**, a partir da base do **CA Service Desk Manager** (`mdb`).

O objetivo é reproduzir, direto do SDM, as abas `Chamados_TCU` e `Chamados_24x7`
das planilhas mensais **Planilha_NMS_TCU** da Virtual. São duas planilhas,
**DCIM** e **Manutenção**, cada uma com seu valor mensal contratado.

Este repositório atende **somente a Virtual**. Decision, A2B/Protect4 e COI têm
repositórios próprios.

## Estrutura

```text
.
├── queries/
│   └── consulta_virtual_faia_farc.sql              consulta de referência
├── powerbi/
│   ├── consulta_virtual_chamados_tcu_power_bi.sql  aba Chamados_TCU
│   └── consulta_virtual_chamados_24x7_power_bi.sql aba Chamados_24x7
├── docs/
│   ├── virtual-calculation.md                      regras de cálculo
│   └── powerbi-query.md                            consultas do Power BI
├── project-context/
│   └── VIRTUAL-HISTORICO-CONTEXTO-MESTRE.md        contexto de manutenção
├── support/                                        consultas auxiliares de investigação
└── README.md
```

## Consulta de referência

[`queries/consulta_virtual_faia_farc.sql`](queries/consulta_virtual_faia_farc.sql)
devolve dois resultados, com as 23 colunas das abas, na ordem da planilha:

| Resultado | Aba |
|---|---|
| 1 | `Chamados_TCU` |
| 2 | `Chamados_24x7` |

Parâmetros no topo do arquivo:

| Parâmetro | Uso |
|---|---|
| `@DataInicio` | início do período, inclusivo (horário do Brasil) |
| `@DataFim` | fim do período, **exclusivo** |
| `@Planilha` | `N'DCIM'` ou `N'Manutenção'` |

O período seleciona os chamados pela **data de abertura**. Para um mês inteiro,
use o dia 1 do mês e o dia 1 do mês seguinte, por exemplo `2026-07-01` e
`2026-08-01`. Nunca use `23:59:59`.

Em resumo:

- **População:** chamados I/R abertos no período que passaram pelo grupo
  `Fornecedores - Virtual`.
- **DCIM:** rotinas registradas pela automação do SDM com IC `dcim`.
  **Manutenção:** os demais.
- **Regime:** TCU ou 24x7, pela combinação Tipo + Prioridade.
- **Horário comercial (TCU):** 08:00–20:00, segunda a sexta, fora do
  calendário TCU.

A regra completa está em [`docs/virtual-calculation.md`](docs/virtual-calculation.md).

Execute o arquivo **inteiro** na base `mdb`. A consulta só cria tabelas
temporárias.

## Consultas do Power BI

| Arquivo | Saída |
|---|---|
| [`powerbi/consulta_virtual_chamados_tcu_power_bi.sql`](powerbi/consulta_virtual_chamados_tcu_power_bi.sql) | `Chamados_TCU` das duas planilhas, com a coluna `Planilha` |
| [`powerbi/consulta_virtual_chamados_24x7_power_bi.sql`](powerbi/consulta_virtual_chamados_24x7_power_bi.sql) | `Chamados_24x7` das duas planilhas, com a coluna `Planilha` |

O período é automático: os últimos `@CoberturaMeses` meses fechados (padrão
**12**) mais o mês corrente, por data de abertura.

O bloco de cálculo (`MOTOR VIRTUAL`) é idêntico nos três arquivos. Mudanças de
regra são feitas na referência e copiadas para os dois arquivos do Power BI.
Detalhes em [`docs/powerbi-query.md`](docs/powerbi-query.md).

## Manutenção anual

O calendário TCU (feriados e pontos facultativos) fica no bloco `[2]` do motor,
tabela `#Virt_Calendario`, e hoje cobre **2025 e 2026**. A cada ano novo, inclua
as datas do ano no bloco da referência e copie o bloco para os dois arquivos do
Power BI.

## Como validar

1. Rode a referência com o período e a planilha do mês.
2. Compare, por SDM, com as abas `Chamados_TCU` e `Chamados_24x7` da planilha
   correspondente.
3. Diferenças de marco devem ser explicadas pelo `act_log` do chamado. A
   consulta `support/consulta_logs_chamados_listados.sql` lista todos os logs
   dos SDMs informados.
4. Para o Power BI, rode as duas consultas com o mesmo período da referência.
   Filtradas por `Planilha`, elas devem ter as mesmas linhas e os mesmos valores.

Os totais das abas Cálculos e Financeiro saem da soma dos índices das duas abas
de chamados (ver `docs/virtual-calculation.md`, seção 11).

## Consultas de apoio

| Arquivo | Uso |
|---|---|
| `support/consulta_logs_chamados_listados.sql` | todos os logs dos chamados informados |
| `support/consulta_status_chamados.sql` | status cadastrados no SDM |
| `support/consulta_status_hold.sql` | status e flag `cr_stat.hold` |
| `support/consulta_tipos_chamado.sql` | tipos de chamado e quantidades |

Elas não calculam indicadores. Servem para investigar chamados e conferir códigos.

## Contexto de manutenção

Decisões técnicas, validações feitas e divergências comprovadas das planilhas
ficam em
[`project-context/VIRTUAL-HISTORICO-CONTEXTO-MESTRE.md`](project-context/VIRTUAL-HISTORICO-CONTEXTO-MESTRE.md).
