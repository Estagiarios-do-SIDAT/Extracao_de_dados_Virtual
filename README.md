# Extração de dados — Virtual

Consultas SQL e documentação da apuração de **FAIA** e **FARC** do fornecedor
**Virtual**, a partir da base do **CA Service Desk Manager** (`mdb`).

A consulta lê só o SDM e entrega os chamados da Virtual em duas grades, por
regime: `Chamados_TCU` e `Chamados_24x7`. A contagem de tempo segue a
arquitetura de posse da Decision; metas, fatores, regime e calendário são os da
Virtual e ficam no próprio SQL. Não há dependência de arquivo externo.

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
devolve dois resultados, com as mesmas 37 colunas:

| Resultado | Conteúdo |
|---|---|
| 1 | `Chamados_TCU`: todos os chamados elegíveis do regime TCU |
| 2 | `Chamados_24x7`: todos os chamados elegíveis do regime 24x7 |

Parâmetros no topo do arquivo:

| Parâmetro | Uso |
|---|---|
| `@DataInicio` | início do período de fechamento, inclusivo (horário do Brasil) |
| `@DataFim` | fim do período de fechamento, **exclusivo** |

O período seleciona os chamados pela **data de fechamento**. Para um mês inteiro,
use o dia 1 do mês e o dia 1 do mês seguinte, por exemplo `2026-07-01` e
`2026-08-01`. Nunca use `23:59:59`.

Em resumo:

- **Escopo:** chamados I/R fechados no período, em status terminal, com grupo
  atual `Fornecedores - Virtual` e que encerraram na Virtual (última
  transferência de grupo foi uma entrada na Virtual, ou nasceram nela sem
  transferência).
- **Regime:** TCU ou 24x7, pela combinação Tipo + Prioridade.
- **Posse:** o relógio começa na primeira entrada na Virtual (na abertura, se
  o chamado nasceu nela), para nas saídas e volta nas reentradas; todas as
  janelas de posse são somadas.
- **Colunas:** identificação e datas (com `Data/Hora Fechamento`), as 15
  colunas de apuração da Virtual e colunas de contexto no padrão da Decision,
  entre elas `Item de Configuração` e `Categoria`, que identificam o serviço ou
  o objeto atendido.
  `Tempo suspenso` vale `0:00:00`, porque a regra da Virtual não tem status
  que suspendam a contagem. As durações saem como `[h]:mm:ss`; fatores e
  índices são numéricos e calculados em segundos.
- **Horário comercial (TCU):** 08:00–20:00, segunda a sexta, fora do
  calendário TCU.

A regra completa está em [`docs/virtual-calculation.md`](docs/virtual-calculation.md).

Execute o arquivo **inteiro** na base `mdb`. A consulta só cria tabelas
temporárias.

## Consultas do Power BI

| Arquivo | Saída |
|---|---|
| [`powerbi/consulta_virtual_chamados_tcu_power_bi.sql`](powerbi/consulta_virtual_chamados_tcu_power_bi.sql) | `Chamados_TCU`, com as mesmas 37 colunas da referência |
| [`powerbi/consulta_virtual_chamados_24x7_power_bi.sql`](powerbi/consulta_virtual_chamados_24x7_power_bi.sql) | `Chamados_24x7`, com as mesmas 37 colunas da referência |

O período é automático: os últimos `@CoberturaMeses` meses (padrão **12**) mais
o mês corrente, por data de fechamento.

O bloco de cálculo (`MOTOR VIRTUAL`) é idêntico nos três arquivos. Mudanças de
regra são feitas na referência e copiadas para os dois arquivos do Power BI.
Detalhes em [`docs/powerbi-query.md`](docs/powerbi-query.md).

## Manutenção anual

O calendário TCU (feriados e pontos facultativos) fica no bloco `[2]` do motor,
tabela `#Virt_Calendario`, e hoje cobre **2025 e 2026**. A cada ano novo, inclua
as datas do ano no bloco da referência e copie o bloco para os dois arquivos do
Power BI.

## Como validar

1. Rode a referência com o período de fechamento do mês.
2. Confira, por SDM, os marcos (abertura, entrada na Virtual, início,
   resolução, fechamento) e as janelas de posse contra o `act_log` do chamado.
   A consulta `support/consulta_logs_chamados_listados.sql` lista todos os
   logs dos SDMs informados.
3. Para o Power BI, rode as duas consultas com o mesmo período da referência.
   Elas devem ter as mesmas linhas e os mesmos valores dos dois resultados.

O total de FAIA ou FARC de um período é a soma de `Indice FAIA` ou
`Indice FARC` dos dois resultados (ver `docs/virtual-calculation.md`, seção 9).

## Consultas de apoio

| Arquivo | Uso |
|---|---|
| `support/consulta_logs_chamados_listados.sql` | todos os logs dos chamados informados |
| `support/consulta_status_chamados.sql` | status cadastrados no SDM |
| `support/consulta_status_hold.sql` | status e flag `cr_stat.hold` |
| `support/consulta_tipos_chamado.sql` | tipos de chamado e quantidades |

Elas não calculam indicadores. Servem para investigar chamados e conferir códigos.

## Contexto de manutenção

Decisões técnicas, validações feitas e o histórico da engenharia reversa das
planilhas manuais ficam em
[`project-context/VIRTUAL-HISTORICO-CONTEXTO-MESTRE.md`](project-context/VIRTUAL-HISTORICO-CONTEXTO-MESTRE.md).
